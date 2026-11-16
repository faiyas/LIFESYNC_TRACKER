import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceNavigationService {
  static final VoiceNavigationService instance = VoiceNavigationService._init();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isMuted = false;
  bool _isInitialized = false;

  VoiceNavigationService._init();

  bool get isMuted => _isMuted;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _isInitialized = true;
    } catch (e) {
      debugPrint('VoiceNavigationService init error: $e');
    }
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    if (_isMuted) {
      stop();
    }
  }

  Future<void> speakInstruction(String text) async {
    if (_isMuted) return;
    if (!_isInitialized) await init();
    try {
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('Error speaking voice instruction: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('Error stopping voice TTS: $e');
    }
  }
}
