import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  final ImagePicker _picker = ImagePicker();

  String? _currentSessionId;
  bool _isSending = false;
  bool _isBackendOnline = false;
  String _backendStatusText = 'Checking backend...';

  // Credit quota state
  int _remainingNvidiaCredits = 1000;
  int _usedNvidiaCredits = 0;
  String _imageCreditsText = 'Unlimited (Free)';

  // Reference image attachment state
  File? _selectedReferenceFile;
  String? _selectedImageBase64;
  String _referenceEditMode = 'edit'; // 'edit', 'rembg', 'blend'

  final List<String> _quickSuggestions = [
    'Remind me to call John at 5:00 PM',
    'Spent ₹150 for lunch at cafe',
    'Generate image of a cute puppy in snow',
    'Generate image of a girl in traditional dress',
  ];

  @override
  void initState() {
    super.initState();
    _checkBackendStatus();
    _fetchCredits();
    _messages.add(
      AiMessage(
        role: MessageRole.assistant,
        text: 'Hello! I am your LifeSync AI Assistant powered by NVIDIA NIM.\n\n'
            'I can:\n'
            '• Speak and converse with you in real time\n'
            '• Automatically set reminders on your phone\n'
            '• Auto-log your expenses and income directly to your database\n'
            '• Generate AI artwork & photorealistic images for free\n'
            '• Remove backgrounds or edit photos using reference images (tap 📎)!\n\n'
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
        if (res['online'] == true && res['data']?['credits'] != null) {
          _updateCreditsFromMap(res['data']['credits']);
        }
      });
    }
  }

  Future<void> _fetchCredits() async {
    final credits = await _backend.getCredits();
    if (credits != null && mounted) {
      setState(() {
        _updateCreditsFromMap(credits);
      });
    }
  }

  void _updateCreditsFromMap(Map<String, dynamic> credits) {
    _usedNvidiaCredits = credits['nvidia_used'] ?? _usedNvidiaCredits;
    _remainingNvidiaCredits = credits['nvidia_remaining'] ?? _remainingNvidiaCredits;
    _imageCreditsText = credits['image_limit'] ?? _imageCreditsText;
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

  Future<void> _pickReferenceImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, maxWidth: 1200, maxHeight: 1200, imageQuality: 85);
      if (picked != null) {
        final file = File(picked.path);
        final bytes = await file.readAsBytes();
        setState(() {
          _selectedReferenceFile = file;
          _selectedImageBase64 = base64Encode(bytes);
          _referenceEditMode = 'edit';
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _executeRemoveBackground() async {
    if (_selectedImageBase64 == null) return;
    final file = _selectedReferenceFile;

    setState(() {
      _isSending = true;
      _messages.add(
        AiMessage(
          role: MessageRole.user,
          text: '✂️ Remove background from this photo',
          referenceImagePath: file?.path,
        ),
      );
      _messages.add(
        AiMessage(
          role: MessageRole.assistant,
          text: 'Removing background and creating transparent cut-out...',
          isLoading: true,
        ),
      );
      _selectedReferenceFile = null;
      _selectedImageBase64 = null;
    });
    _scrollToBottom();

    final result = await _backend.editImage(
      imageBase64: _selectedImageBase64 ?? '',
      prompt: 'Remove background',
      mode: 'rembg',
    );

    if (!mounted) return;

    setState(() {
      _messages.removeWhere((m) => m.isLoading);
      _isSending = false;
    });

    if (result['status'] == 'success') {
      final imageUrl = result['image_url'] as String?;
      final base64Data = result['base64_data'] as String?;
      if (result['credits'] != null) {
        _updateCreditsFromMap(result['credits']);
      }

      setState(() {
        _messages.add(
          AiMessage(
            role: MessageRole.assistant,
            text: 'Here is your image with the background removed!',
            imageUrl: imageUrl,
            base64Data: base64Data,
            actionType: 'image',
          ),
        );
      });
      _scrollToBottom();
    } else {
      setState(() {
        _messages.add(
          AiMessage(
            role: MessageRole.assistant,
            text: '⚠️ Could not remove background: ${result['message'] ?? result['error']}',
          ),
        );
      });
      _scrollToBottom();
    }
  }

  Future<void> _sendMessage(String userText) async {
    final text = userText.trim();
    if ((text.isEmpty && _selectedImageBase64 == null) || _isSending) return;

    final hasReferenceImage = _selectedImageBase64 != null;
    final refBase64 = _selectedImageBase64;
    final refFile = _selectedReferenceFile;

    _textController.clear();
    setState(() {
      _messages.add(
        AiMessage(
          role: MessageRole.user,
          text: text.isEmpty ? 'Process this reference photo' : text,
          referenceImagePath: refFile?.path,
        ),
      );
      _isSending = true;
      _selectedReferenceFile = null;
      _selectedImageBase64 = null;
      _messages.add(
        AiMessage(
          role: MessageRole.assistant,
          text: hasReferenceImage ? 'Editing photo with your instructions...' : 'Thinking...',
          isLoading: true,
        ),
      );
    });
    _scrollToBottom();

    // 1. If reference image was attached, call editImage
    if (hasReferenceImage && refBase64 != null) {
      final result = await _backend.editImage(
        imageBase64: refBase64,
        prompt: text.isEmpty ? 'Enhance this photo, highly detailed, photorealistic 8k' : text,
        mode: 'edit',
      );

      if (!mounted) return;

      setState(() {
        _messages.removeWhere((m) => m.isLoading);
        _isSending = false;
      });

      if (result['status'] == 'success') {
        final imageUrl = result['image_url'] as String?;
        final base64Data = result['base64_data'] as String?;
        if (result['credits'] != null) {
          _updateCreditsFromMap(result['credits']);
        }

        setState(() {
          _messages.add(
            AiMessage(
              role: MessageRole.assistant,
              text: 'I have modified the image based on your instructions!',
              imageUrl: imageUrl,
              base64Data: base64Data,
              actionType: 'image',
            ),
          );
        });
        _scrollToBottom();
      } else {
        setState(() {
          _messages.add(
            AiMessage(
              role: MessageRole.assistant,
              text: '⚠️ Could not process reference image: ${result['message'] ?? result['error']}',
            ),
          );
        });
        _scrollToBottom();
      }
      return;
    }

    // 2. Normal conversational & image generation message
    final response = await _backend.sendChatMessage(
      message: text,
      sessionId: _currentSessionId,
    );

    if (!mounted) return;

    setState(() {
      _messages.removeWhere((m) => m.isLoading);
      _isSending = false;
      if (response.credits != null) {
        _updateCreditsFromMap(response.credits!);
      }
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
        base64Data: response.base64Data,
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
                _fetchCredits();
              }
            },
            child: const Text('Save & Connect'),
          ),
        ],
      ),
    );
  }

  void _showCreditsDetailsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bolt_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Available Credits & Quota'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCreditDetailRow('NVIDIA NIM Model', 'nvidia/nemotron-3.5-bolt-e4b'),
            const SizedBox(height: 8),
            _buildCreditDetailRow('Daily LLM Budget', '1,000 requests / day (Free)'),
            const SizedBox(height: 8),
            _buildCreditDetailRow('Credits Used Today', '$_usedNvidiaCredits queries'),
            const SizedBox(height: 8),
            _buildCreditDetailRow('Remaining Today', '$_remainingNvidiaCredits queries'),
            const Divider(height: 24),
            _buildCreditDetailRow('Image Generation', '♾️ Unlimited Free (Flux / SDXL)'),
            const SizedBox(height: 8),
            _buildCreditDetailRow('Background Removal', '♾️ Unlimited Free (RMBG)'),
            const SizedBox(height: 12),
            const Text(
              'Credits reset daily at 00:00 UTC automatically.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
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
          IconButton(
            tooltip: 'Configure Backend URL',
            icon: const Icon(Icons.settings_ethernet),
            onPressed: _showServerConfigDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Available Credits Banner at the Top
          GestureDetector(
            onTap: _showCreditsDetailsDialog,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.08),
                border: Border(bottom: BorderSide(color: theme.dividerColor.withOpacity(0.2))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    'NVIDIA NIM: $_remainingNvidiaCredits / 1000',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  const Icon(Icons.brush_rounded, size: 14, color: Colors.indigoAccent),
                  const SizedBox(width: 4),
                  const Text(
                    'Image Gen: Free ♾️',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigoAccent),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.info_outline, size: 13, color: Colors.grey),
                ],
              ),
            ),
          ),

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

          // Selected reference image tray
          if (_selectedReferenceFile != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _selectedReferenceFile!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reference Photo Attached',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            ActionChip(
                              avatar: const Icon(Icons.cut, size: 14),
                              label: const Text('Remove BG', style: TextStyle(fontSize: 10)),
                              onPressed: _executeRemoveBackground,
                            ),
                            const SizedBox(width: 6),
                            const Text('or type prompt below', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      setState(() {
                        _selectedReferenceFile = null;
                        _selectedImageBase64 = null;
                      });
                    },
                  ),
                ],
              ),
            ),

          // Input control bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                  // Attachment / Reference Image Picker Button
                  IconButton(
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    tooltip: 'Attach reference image',
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (ctx) => SafeArea(
                          child: Wrap(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.photo_library_outlined),
                                title: const Text('Pick from Gallery'),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _pickReferenceImage(ImageSource.gallery);
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.camera_alt_outlined),
                                title: const Text('Take a Photo'),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _pickReferenceImage(ImageSource.camera);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: _selectedReferenceFile != null
                            ? 'e.g. Add a friend beside me / Make anime...'
                            : 'Speak or type to assistant...',
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
                  const SizedBox(width: 6),
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
                  // User attached reference photo thumbnail
                  if (msg.referenceImagePath != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(msg.referenceImagePath!),
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],

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

                  // Image Display (Supports Base64 memory bytes with 0ms delay + Network Fallback)
                  if ((msg.base64Data != null && msg.base64Data!.isNotEmpty) ||
                      (msg.imageUrl != null && msg.imageUrl!.isNotEmpty)) ...[
                    const SizedBox(height: 10),
                    _buildImageCard(msg),
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

  /// Robust Image Renderer: Prefers zero-latency Base64 bytes, falls back to Image.network
  Widget _buildImageCard(AiMessage msg) {
    Widget imageWidget;

    if (msg.base64Data != null && msg.base64Data!.isNotEmpty) {
      try {
        final rawBase64 = msg.base64Data!.contains(',')
            ? msg.base64Data!.split(',')[1]
            : msg.base64Data!;
        final bytes = base64Decode(rawBase64);
        imageWidget = Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildNetworkFallback(msg.imageUrl),
        );
      } catch (_) {
        imageWidget = _buildNetworkFallback(msg.imageUrl);
      }
    } else {
      imageWidget = _buildNetworkFallback(msg.imageUrl);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: imageWidget,
    );
  }

  Widget _buildNetworkFallback(String? url) {
    if (url == null || url.isEmpty) {
      return Container(
        height: 100,
        color: Colors.black12,
        alignment: Alignment.center,
        child: const Text('No image data available'),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return Container(
          height: 180,
          alignment: Alignment.center,
          color: Colors.black12,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 8),
              Text('Rendering high-res artwork...', style: TextStyle(fontSize: 11)),
            ],
          ),
        );
      },
      errorBuilder: (_, error, __) {
        return Container(
          padding: const EdgeInsets.all(16),
          color: Colors.black12,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
              const SizedBox(height: 6),
              const Text('Could not load image preview', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              TextButton.icon(
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Retry', style: TextStyle(fontSize: 11)),
                onPressed: () => setState(() {}),
              ),
            ],
          ),
        );
      },
    );
  }
}
