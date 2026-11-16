import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ai_message.dart';
import '../services/ai_action_executor.dart';
import '../services/ai_backend_client.dart';
import '../services/ai_voice_service.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<AiMessage> _messages = [];
  final AiBackendClient _backend = AiBackendClient.instance;
  final AiVoiceService _voice = AiVoiceService.instance;
  final AiActionExecutor _executor = AiActionExecutor.instance;

  String? _currentSessionId;
  bool _isSending = false;
  bool _isBackendOnline = false;
  String _backendStatusText = 'Checking backend...';

  final List<String> _quickSuggestions = [
    'Remind me to call John at 5:00 PM',
    'Spent ₹150 for lunch at cafe',
    'Generate image of futuristic neon cyber city',
    'Received salary ₹45,000 from company',
  ];

  @override
  void initState() {
    super.initState();
    _checkBackendStatus();
    _messages.add(
      AiMessage(
        role: MessageRole.assistant,
        text: 'Hello! I am your LifeSync AI Assistant powered by NVIDIA NIM.\n\n'
            'I can:\n'
            '• Speak and converse with you in real time\n'
            '• Automatically set reminders on your phone\n'
            '• Auto-log your expenses and income directly to your database\n'
            '• Generate AI artwork and images for you for free!\n\n'
            'What would you like to do today?',
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _voice.stop();
    super.dispose();
  }

  Future<void> _checkBackendStatus() async {
    final res = await _backend.checkHealth();
    if (mounted) {
      setState(() {
        _isBackendOnline = res['online'] == true;
        _backendStatusText = _isBackendOnline ? 'Online (NVIDIA NIM)' : 'Offline / Tap to configure';
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String userText) async {
    final text = userText.trim();
    if (text.isEmpty || _isSending) return;

    _textController.clear();
    setState(() {
      _messages.add(AiMessage(role: MessageRole.user, text: text));
      _isSending = true;
      // Add temporary loading indicator message
      _messages.add(
        AiMessage(
          role: MessageRole.assistant,
          text: 'Thinking...',
          isLoading: true,
        ),
      );
    });
    _scrollToBottom();

    final response = await _backend.sendChatMessage(
      message: text,
      sessionId: _currentSessionId,
    );

    if (!mounted) return;

    // Remove loading indicator
    setState(() {
      _messages.removeWhere((m) => m.isLoading);
      _isSending = false;
    });

    if (response.success && response.reply != null) {
      _currentSessionId = response.sessionId ?? _currentSessionId;

      String? executionStatus;
      bool isExecuted = false;

      // Automatically execute detected action if present
      if (response.actionType != null &&
          response.actionPayload != null &&
          response.actionType != 'none') {
        final execResult = await _executor.executeAction(
          actionType: response.actionType!,
          payload: response.actionPayload!,
        );
        isExecuted = execResult.success;
        executionStatus = execResult.message;
      }

      final assistantMessage = AiMessage(
        role: MessageRole.assistant,
        text: response.reply!,
        actionType: response.actionType,
        actionPayload: response.actionPayload,
        imageUrl: response.imageUrl,
        isExecuted: isExecuted,
        executionStatus: executionStatus,
      );

      setState(() {
        _messages.add(assistantMessage);
      });
      _scrollToBottom();

      // Read reply aloud if auto-speak is enabled
      if (_voice.isAutoSpeakEnabled) {
        await _voice.speak(response.reply!);
      }
    } else {
      setState(() {
        _messages.add(
          AiMessage(
            role: MessageRole.assistant,
            text: '⚠️ Could not connect to backend server.\n\n'
                '${response.errorMessage ?? "Unknown error"}\n\n'
                '👉 Tap the status banner at the top to set your Cloudflare / Server URL.',
          ),
        );
      });
      _scrollToBottom();
    }
  }

  void _showServerConfigDialog() {
    final urlController = TextEditingController(text: _backend.backendUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cloud_outlined, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text('Server Backend URL'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your Instabox Cloudflare Tunnel URL or local machine URL:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'https://xxx.trycloudflare.com',
                labelText: 'Backend URL',
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Emulator: http://10.0.2.2:8000\n• Physical Phone: https://<your-id>.trycloudflare.com',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newUrl = urlController.text.trim();
              if (newUrl.isNotEmpty) {
                await _backend.setBackendUrl(newUrl);
                Navigator.pop(ctx);
                _checkBackendStatus();
              }
            },
            child: const Text('Save & Connect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'LifeSync AI Assistant',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isBackendOnline ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _backendStatusText,
                  style: TextStyle(
                    fontSize: 11,
                    color: _isBackendOnline ? Colors.green.shade700 : Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Voice auto-speak toggle button
          IconButton(
            tooltip: _voice.isAutoSpeakEnabled ? 'Voice output ON' : 'Voice output MUTED',
            icon: Icon(
              _voice.isAutoSpeakEnabled ? Icons.volume_up : Icons.volume_off,
              color: _voice.isAutoSpeakEnabled ? theme.colorScheme.primary : Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _voice.setAutoSpeakEnabled(!_voice.isAutoSpeakEnabled);
              });
              if (!_voice.isAutoSpeakEnabled) {
                _voice.stop();
              }
            },
          ),
          // Server config button
          IconButton(
            tooltip: 'Configure Backend URL',
            icon: const Icon(Icons.settings_ethernet),
            onPressed: _showServerConfigDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Status notice banner if offline
          if (!_isBackendOnline)
            GestureDetector(
              onTap: _showServerConfigDialog,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.orange.withOpacity(0.15),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Backend server offline. Tap here to set Cloudflare / Host URL.',
                        style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 18, color: Colors.orange),
                  ],
                ),
              ),
            ),

          // Chat message list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          // Quick prompt chips
          Container(
            height: 38,
            margin: const EdgeInsets.only(bottom: 6),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: _quickSuggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final suggestion = _quickSuggestions[i];
                return ActionChip(
                  label: Text(
                    suggestion,
                    style: const TextStyle(fontSize: 11),
                  ),
                  onPressed: () => _sendMessage(suggestion),
                  backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                );
              },
            ),
          ),

          // Input control bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Speak or type to assistant...',
                        hintStyle: const TextStyle(fontSize: 14),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send action button
                  IconButton.filled(
                    onPressed: _isSending ? null : () => _sendMessage(_textController.text),
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(AiMessage msg) {
    final isUser = msg.role == MessageRole.user;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(Icons.auto_awesome, size: 18, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceVariant.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16),
                  bottomLeft: !isUser ? const Radius.circular(0) : const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (msg.isLoading)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          msg.text,
                          style: TextStyle(
                            fontSize: 13,
                            color: isUser ? Colors.white : theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      msg.text,
                      style: TextStyle(
                        fontSize: 14,
                        color: isUser ? Colors.white : theme.colorScheme.onSurface,
                        height: 1.35,
                      ),
                    ),

                  // Generated image preview card if present
                  if (msg.imageUrl != null && msg.imageUrl!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        msg.imageUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            height: 180,
                            alignment: Alignment.center,
                            color: Colors.black12,
                            child: const CircularProgressIndicator(),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          height: 100,
                          color: Colors.black12,
                          alignment: Alignment.center,
                          child: const Text('Failed to load generated image'),
                        ),
                      ),
                    ),
                  ],

                  // Action execution badge
                  if (msg.isExecuted && msg.executionStatus != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade400, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              msg.executionStatus!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Action buttons on assistant message: Speak / Re-speak
                  if (!isUser && !msg.isLoading) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: IconButton(
                        icon: const Icon(Icons.volume_up_outlined, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Read aloud',
                        onPressed: () => _voice.speak(msg.text),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 14,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
              child: const Icon(Icons.person, size: 16),
            ),
          ],
        ],
      ),
    );
  }
}
