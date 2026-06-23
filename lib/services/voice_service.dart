import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  static final VoiceService instance = VoiceService._();

  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _initialized = false;
  bool _isListening = false;
  bool _isSpeaking = false;

  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;

  VoiceService._();

  Future<void> init() async {
    if (_initialized) return;

    try {
      await _speech.initialize(
        onError: (error) {
          debugPrint('VoiceService STT init error: $error');
        },
        onStatus: (status) {
          debugPrint('VoiceService STT status: $status');
          if (status == 'notListening' && _isListening) {
            _isListening = false;
          }
        },
      );

      await _tts.setLanguage('fr-FR');
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);

      _tts.setStartHandler(() {
        _isSpeaking = true;
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
      });

      _tts.setErrorHandler((error) {
        debugPrint('VoiceService TTS error: $error');
        _isSpeaking = false;
      });

      _initialized = true;
      debugPrint('VoiceService initialized');
    } catch (e) {
      debugPrint('VoiceService init error: $e');
    }
  }

  Future<void> startListening({
    required void Function(String text) onResult,
    required void Function() onDone,
  }) async {
    await init();

    if (!_initialized) {
      debugPrint('VoiceService: STT non disponible');
      return;
    }

    if (_isListening) {
      await stopListening();
      return;
    }

    // Arrêter la parole en cours
    await stopSpeaking();

    _isListening = true;

    await _speech.listen(
      localeId: 'fr_FR',
      onResult: (result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
          _isListening = false;
          onDone();
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      listenOptions: SpeechListenOptions(
        partialResults: false,
        cancelOnError: true,
      ),
    );
  }

  Future<void> stopListening() async {
    if (!_isListening) return;

    _isListening = false;
    await _speech.stop();
  }

  Future<void> speak(String text) async {
    await init();

    if (!_initialized) {
      debugPrint('VoiceService: TTS non disponible');
      return;
    }

    if (text.trim().isEmpty) return;

    try {
      await _tts.speak(text);
    } catch (e) {
      debugPrint('VoiceService TTS speak error: $e');
    }
  }

  Future<void> stopSpeaking() async {
    if (!_isSpeaking) return;

    _isSpeaking = false;
    await _tts.stop();
  }
}
