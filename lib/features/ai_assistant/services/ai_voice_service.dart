import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class AiVoiceService {
  static final AiVoiceService instance = AiVoiceService._internal();
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  bool _isAutoSpeakEnabled = true;

  AiVoiceService._internal() {
    _initTts();
  }

  bool get isSpeaking => _isSpeaking;
  bool get isAutoSpeakEnabled => _isAutoSpeakEnabled;

  void setAutoSpeakEnabled(bool enabled) {
    _isAutoSpeakEnabled = enabled;
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.5); // Natural conversational cadence
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _tts.setStartHandler(() {
        _isSpeaking = true;
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
      });

      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
        debugPrint('TTS Error: $msg');
      });
    } catch (e) {
      debugPrint('Error initializing TTS: $e');
    }
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    try {
      if (_isSpeaking) {
        await stop();
      }
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS speak error: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
      _isSpeaking = false;
    } catch (e) {
      debugPrint('TTS stop error: $e');
    }
  }
}
