import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiBackendResponse {
  final bool success;
  final String? reply;
  final String? actionType;
  final Map<String, dynamic>? actionPayload;
  final String? imageUrl;
  final String? base64Data;
  final String? sessionId;
  final Map<String, dynamic>? credits;
  final String? errorMessage;

  AiBackendResponse({
    required this.success,
    this.reply,
    this.actionType,
    this.actionPayload,
    this.imageUrl,
    this.base64Data,
    this.sessionId,
    this.credits,
    this.errorMessage,
  });
}

class AiBackendClient {
  static const String _prefBackendUrlKey = 'ai_assistant_backend_url';
  static const String _defaultUrl = 'https://compliance-light-delhi-euros.trycloudflare.com';

  static final AiBackendClient instance = AiBackendClient._internal();
  String _backendUrl = _defaultUrl;
  bool _isConfigured = false;

  AiBackendClient._internal() {
    _loadUrl();
  }

  String get backendUrl => _backendUrl;
  bool get isConfigured => _isConfigured;

  Future<void> _loadUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_prefBackendUrlKey);
      if (savedUrl != null && savedUrl.isNotEmpty) {
        _backendUrl = savedUrl.trim();
        _isConfigured = true;
      }
    } catch (e) {
      debugPrint('Error loading backend URL: $e');
    }
  }

  Future<void> setBackendUrl(String url) async {
    _backendUrl = url.trim();
    if (_backendUrl.endsWith('/')) {
      _backendUrl = _backendUrl.substring(0, _backendUrl.length - 1);
    }
    _isConfigured = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefBackendUrlKey, _backendUrl);
  }

  /// Ping the backend health endpoint
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final uri = Uri.parse('$_backendUrl/api/health/');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        return {
          'online': true,
          'data': jsonDecode(response.body),
        };
      }
      return {
        'online': false,
        'error': 'Server returned HTTP ${response.statusCode}',
      };
    } catch (e) {
      return {
        'online': false,
        'error': e.toString(),
      };
    }
  }

  /// Fetches real-time available credits from the backend
  Future<Map<String, dynamic>?> getCredits() async {
    try {
      final uri = Uri.parse('$_backendUrl/api/assistant/credits/');
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['credits'] as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint('Error fetching credits: $e');
    }
    return null;
  }

  /// Sends a chat message to NVIDIA LLM Django Backend
  Future<AiBackendResponse> sendChatMessage({
    required String message,
    String? sessionId,
  }) async {
    try {
      final uri = Uri.parse('$_backendUrl/api/assistant/chat/');
      final nowFormatted = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

      final body = jsonEncode({
        'message': message,
        'session_id': sessionId,
        'current_time': nowFormatted,
      });

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 35));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return AiBackendResponse(
          success: true,
          reply: data['reply'] as String?,
          actionType: data['action_type'] as String?,
          actionPayload: data['action_payload'] as Map<String, dynamic>?,
          imageUrl: data['image_url'] as String?,
          base64Data: data['base64_data'] as String?,
          sessionId: data['session_id'] as String?,
          credits: data['credits'] as Map<String, dynamic>?,
        );
      } else {
        return AiBackendResponse(
          success: false,
          errorMessage: 'Server HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      return AiBackendResponse(
        success: false,
        errorMessage: 'Connection failed: $e. Check server URL.',
      );
    }
  }

  /// Dedicated image generation
  Future<Map<String, dynamic>> generateImage(String prompt) async {
    try {
      final uri = Uri.parse('$_backendUrl/api/assistant/generate-image/');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': prompt}),
      ).timeout(const Duration(seconds: 40));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return {'status': 'error', 'message': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Reference Image Editing & Background Removal
  Future<Map<String, dynamic>> editImage({
    required String imageBase64,
    required String prompt,
    String mode = 'edit', // 'rembg' or 'edit' or 'blend'
  }) async {
    try {
      final uri = Uri.parse('$_backendUrl/api/assistant/edit-image/');
      final body = jsonEncode({
        'image': imageBase64,
        'prompt': prompt,
        'mode': mode,
      });

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return {'status': 'error', 'message': 'HTTP ${response.statusCode}: ${response.body}'};
      }
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }
}
