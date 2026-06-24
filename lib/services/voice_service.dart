import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';

class VoiceService {
  static final VoiceService instance = VoiceService._();

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final SpeechToText _speech = SpeechToText();
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _initialized = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  String? _recordPath;
  bool _speechAvailable = false;

  void Function(String text)? _onResult;
  void Function()? _onDone;
  final StreamController<void> _onSpeakingComplete =
      StreamController<void>.broadcast();

  Stream<void> get onSpeakingComplete => _onSpeakingComplete.stream;

  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;

  VoiceService._();

  Future<void> init() async {
    if (_initialized) return;

    try {
      _player.onPlayerComplete.listen((_) {
        _isSpeaking = false;
        _onSpeakingComplete.add(null);
      });

      _speechAvailable = await _speech.initialize(
        onError: (err) => debugPrint('SpeechToText init error: $err'),
        onStatus: (status) => debugPrint('SpeechToText status: $status'),
      );

      _initialized = true;
      debugPrint('VoiceService initialized (speech_to_text + Azure)');
    } catch (e) {
      debugPrint('VoiceService init error: $e');
    }
  }

  Future<void> startListening({
    required void Function(String text) onResult,
    required void Function() onDone,
  }) async {
    _onResult = onResult;
    _onDone = onDone;
    await init();

    if (!_initialized) {
      debugPrint('VoiceService: non disponible');
      return;
    }

    if (_isListening) {
      await stopListening();
      return;
    }

    await stopSpeaking();

    try {
      if (await _recorder.hasPermission() != true) {
        debugPrint('VoiceService: permission micro refusée');
        return;
      }

      _isListening = true;

      if (_speechAvailable) {
        await _speech.listen(
          onResult: (result) {
            if (_isListening && result.recognizedWords.isNotEmpty) {
              _onResult?.call(result.recognizedWords);
            }
          },
          listenOptions: SpeechListenOptions(
            partialResults: true,
            listenMode: ListenMode.confirmation,
            listenFor: const Duration(seconds: 30),
            pauseFor: const Duration(seconds: 2),
            localeId: 'fr-FR',
          ),
        );
      } else {
        final dir = await getTemporaryDirectory();
        _recordPath =
            '${dir.path}/aricie_voice_${DateTime.now().millisecondsSinceEpoch}.wav';

        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: _recordPath!,
        );
      }
    } catch (e) {
      debugPrint('VoiceService start error: $e');

      try {
        final dir = await getTemporaryDirectory();
        _recordPath =
            '${dir.path}/aricie_voice_${DateTime.now().millisecondsSinceEpoch}.wav';

        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: _recordPath!,
        );
      } catch (e2) {
        debugPrint('VoiceService fallback error: $e2');
        _isListening = false;
      }
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;

    _isListening = false;

    try {
      if (_speechAvailable && _speech.isListening) {
        await _speech.stop();
        final sttResult = _speech.lastRecognizedWords;
        if (sttResult.isNotEmpty) {
          _onResult?.call(sttResult);
        }
      }

      String? recordPath = _recordPath;
      _recordPath = null;

      if (recordPath != null) {
        try {
          await _recorder.stop();
        } catch (_) {}

        final file = File(recordPath);
        if (await file.exists()) {
          final azureText = await _transcribeAudio(file);
          if (azureText.isNotEmpty) {
            _onResult?.call(azureText);
          }
          try {
            await file.delete();
          } catch (_) {}
        }
      }

      _onDone?.call();
    } catch (e) {
      debugPrint('VoiceService stop error: $e');
      _onDone?.call();
    }
  }

  Future<String> _transcribeAudio(File audioFile) async {
    try {
      final session = _supabase.auth.currentSession;
      final token = session?.accessToken ?? '';

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          '${AppConstants.supabaseUrl}/functions/v1/transcribe-audio',
        ),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http.MultipartFile.fromPath('audio', audioFile.path,
            contentType: null),
      );

      final response = await request.send();
      final body = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        debugPrint('Transcribe error: $body');
        return '';
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['text'] as String? ?? '';
    } catch (e) {
      debugPrint('Transcribe exception: $e');
      return '';
    }
  }

  String _sanitizeForTTS(String text) {
    final cleaned = text
        .replaceAll(RegExp(r'[^\p{L}\p{N}\p{P}\p{Z}]', unicode: true), '');
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<void> speak(String text) async {
    await init();

    if (!_initialized || text.trim().isEmpty) return;

    await stopSpeaking();

    try {
      final session = _supabase.auth.currentSession;
      final token = session?.accessToken ?? '';

      final cleanText = _sanitizeForTTS(text);
      if (cleanText.isEmpty) return;

      final response = await http.post(
        Uri.parse(
          '${AppConstants.supabaseUrl}/functions/v1/text-to-speech',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'text': cleanText}),
      );

      if (response.statusCode != 200) {
        debugPrint('TTS error: ${response.statusCode} ${response.body}');
        return;
      }

      final dir = await getTemporaryDirectory();
      final ttsPath =
          '${dir.path}/aricie_tts_${DateTime.now().millisecondsSinceEpoch}.mp3';

      final file = File(ttsPath);
      await file.writeAsBytes(response.bodyBytes);

      _isSpeaking = true;
      await _player.play(DeviceFileSource(ttsPath));
    } catch (e) {
      debugPrint('TTS exception: $e');
    }
  }

  Future<void> stopSpeaking() async {
    if (!_isSpeaking) return;

    _isSpeaking = false;
    await _player.stop();
  }

  void dispose() {
    _recorder.dispose();
    _player.dispose();
    _onSpeakingComplete.close();
  }
}
