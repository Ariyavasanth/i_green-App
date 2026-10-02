import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.html) 'dart:html' as io_or_html;
import 'dart:io' if (dart.library.js_interop) 'dart:io' as universal_io;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../domain/od_voice_service.dart';

final odVoiceServiceProvider = Provider<OdVoiceService>((ref) {
  return GeminiOdVoiceService();
});

class GeminiOdVoiceService implements OdVoiceService {
  GeminiOdVoiceService({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  bool _isInitialized = false;
  bool _isRecordingAudio = false;

  Uint8List? _recordedAudioBytes;
  String _recordedMimeType = 'audio/webm';

  // Gemini API key from dart-define environment variable with robust fallback
  static const String _envGeminiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static const String _defaultGoogleKey = 'AIzaSyCRV3CEy0trgd_EGdX4L6D1tvhJ_GOKxO0';

  String get _geminiApiKey {
    if (_envGeminiKey.isNotEmpty) return _envGeminiKey;
    return _defaultGoogleKey;
  }

  @override
  bool get isListening => _isRecordingAudio || _speech.isListening;

  @override
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      if (!kIsWeb) {
        final status = await Permission.microphone.request();
        if (!status.isGranted) {
          debugPrint('[OdVoiceService] Microphone permission denied');
          return false;
        }
      }

      await _recorder.openRecorder();

      try {
        await _speech.initialize(
          onError: (val) => debugPrint('[OdVoiceService] STT Error: ${val.errorMsg}'),
          onStatus: (val) => debugPrint('[OdVoiceService] STT Status: $val'),
        );
      } catch (e) {
        debugPrint('[OdVoiceService] STT init warning: $e');
      }

      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('[OdVoiceService] Error initializing voice service: $e');
      return false;
    }
  }

  @override
  Future<void> startListening({
    required void Function(String liveText) onLiveTranscript,
    String? localeId,
  }) async {
    _recordedAudioBytes = null;
    final hasInit = await initialize();
    if (!hasInit) return;

    _isRecordingAudio = true;

    // 1. Start Direct Audio Recorder
    try {
      if (kIsWeb) {
        _recordedMimeType = 'audio/webm';
        await _recorder.startRecorder(
          toFile: 'od_audio.webm',
          codec: Codec.opusWebM,
        );
      } else {
        _recordedMimeType = 'audio/aac';
        await _recorder.startRecorder(
          toFile: 'od_audio.aac',
          codec: Codec.aacADTS,
        );
      }
    } catch (e) {
      debugPrint('[OdVoiceService] Warning starting audio recorder: $e');
    }

    // 2. Start STT for live on-screen draft feedback while recording
    try {
      await _speech.listen(
        onResult: (result) {
          onLiveTranscript(result.recognizedWords);
        },
        localeId: localeId,
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 4),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
        ),
      );
    } catch (e) {
      debugPrint('[OdVoiceService] STT listening warning: $e');
    }
  }

  @override
  Future<void> stopListening() async {
    _isRecordingAudio = false;

    // 1. Stop audio recorder and extract raw audio bytes
    try {
      final recordedPath = await _recorder.stopRecorder();
      if (recordedPath != null && recordedPath.isNotEmpty) {
        if (kIsWeb ||
            recordedPath.startsWith('http://') ||
            recordedPath.startsWith('https://') ||
            recordedPath.startsWith('blob:')) {
          final response = await _httpClient.get(Uri.parse(recordedPath));
          if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
            _recordedAudioBytes = response.bodyBytes;
          }
        } else {
          // Mobile / Desktop native file
          try {
            final file = universal_io.File(recordedPath);
            if (await file.exists()) {
              _recordedAudioBytes = await file.readAsBytes();
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[OdVoiceService] Error stopping audio recorder: $e');
    }

    // 2. Stop STT
    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (_) {}
  }

  @override
  Future<void> cancelListening() async {
    _isRecordingAudio = false;
    _recordedAudioBytes = null;
    try {
      await _recorder.stopRecorder();
    } catch (_) {}
    try {
      if (_speech.isListening) {
        await _speech.cancel();
      }
    } catch (_) {}
  }

  @override
  Future<OdVoiceResult> processWithGemini({
    required String rawSpokenText,
    String contextInfo = '',
  }) async {
    final trimmedDraft = rawSpokenText.trim();
    final hasAudio = _recordedAudioBytes != null && _recordedAudioBytes!.isNotEmpty;

    if (!hasAudio && trimmedDraft.isEmpty) {
      return const OdVoiceResult(englishSummary: '', originalTranscript: '');
    }

    final apiKey = _geminiApiKey;
    if (apiKey.isEmpty) {
      return OdVoiceResult(
        englishSummary: trimmedDraft.isNotEmpty ? trimmedDraft : 'Work completed at site.',
        originalTranscript: trimmedDraft,
        detectedLanguage: 'English',
      );
    }

    final prompt = hasAudio
        ? '''
You are an expert AI assistant for an On-Duty (OD) Field Attendance & Work Management application.
An employee recorded the attached audio note after completing or attempting their site visit/duty.
Context: "$contextInfo"
${trimmedDraft.isNotEmpty ? 'Live draft preview: "$trimmedDraft"' : ''}

Instructions:
1. Listen carefully to the real spoken audio soundwaves. The employee may speak naturally in Tamil, Tanglish (Tamil spoken casually or in English script), Hindi, Hinglish, Telugu, Kannada, Malayalam, Marathi, Bengali, Gujarati, Punjabi, English, or any regional/mixed dialect.
2. Accurately transcribe what the employee actually said in their original spoken words/language into "originalTranscript". (For example, if they spoke Tanglish like "Naan site-ku ponen, client meeting mudichiten, document sign vangiten", preserve that exact transcript).
3. Identify the exact language or dialect in "detectedLanguage" (e.g., "Tamil", "Tanglish", "Hindi", "Hinglish", "Telugu", "Kannada", "Malayalam", "English").
4. Translate and summarize the actual meaning into clear, formal, professional English suitable for company HR and manager reports (e.g., "Completed client meeting at the site and obtained the signed document." or "Unable to complete work because the client office was closed."). Place this in "englishSummary".
5. You MUST reply ONLY with a valid JSON object without markdown formatting or code blocks:
{
  "englishSummary": "...",
  "originalTranscript": "...",
  "detectedLanguage": "..."
}
'''
        : '''
You are an expert AI assistant for an On-Duty (OD) Field Attendance & Work Management application.
An employee submitted the following spoken voice note after finishing or attempting their site visit/duty:
Context: "$contextInfo"
Spoken voice text: "$trimmedDraft"

Instructions:
1. Detect the language used in the input (e.g., Tamil, Hindi, Telugu, Kannada, Malayalam, Marathi, Bengali, Gujarati, Punjabi, English, Tanglish, Hinglish, or any regional/mixed dialect).
2. If the input is in any non-English language or mixed dialect:
   - Accurately translate and summarize it into clear, formal, professional English suitable for HR and manager reports (e.g., "Completed client meeting at Site A and received signed AMC document." or "Unable to complete work due to client office being closed.").
   - Retain the exact original spoken text in "originalTranscript".
3. If the input is in English:
   - Polish grammar, brevity, and clarity while retaining all original facts, names, issues, and site information.
   - Keep the original text in "originalTranscript".
4. You MUST reply ONLY with valid JSON in this exact structure without markdown formatting or code blocks:
{
  "englishSummary": "...",
  "originalTranscript": "...",
  "detectedLanguage": "..."
}
''';

    final modelsToTry = [
      'gemini-1.5-flash',
      'gemini-2.0-flash',
      'gemini-2.5-flash',
      'gemini-1.5-pro',
    ];

    for (final model in modelsToTry) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
        );

        final List<Map<String, dynamic>> parts = [];

        // If raw audio was captured, send directly to Gemini Multimodal Audio
        if (hasAudio) {
          parts.add({
            'inline_data': {
              'mime_type': _recordedMimeType,
              'data': base64Encode(_recordedAudioBytes!),
            }
          });
        }

        parts.add({'text': prompt});

        final response = await _httpClient.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {'parts': parts}
            ],
            'generationConfig': {
              'temperature': 0.2,
              'responseMimeType': 'application/json',
            },
          }),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final candidates = data['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final contentParts = candidates[0]['content']?['parts'] as List?;
            if (contentParts != null && contentParts.isNotEmpty) {
              final rawJsonText = contentParts[0]['text']?.toString() ?? '';
              final cleaned = _cleanJsonString(rawJsonText);
              final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
              return OdVoiceResult(
                englishSummary: parsed['englishSummary']?.toString() ?? trimmedDraft,
                originalTranscript: parsed['originalTranscript']?.toString() ?? trimmedDraft,
                detectedLanguage: parsed['detectedLanguage']?.toString() ?? 'English',
              );
            }
          }
        } else {
          debugPrint('[OdVoiceService] Gemini API status ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        debugPrint('[OdVoiceService] Gemini audio processing error with model $model: $e');
      }
    }

    // Fallback if network/Gemini fails
    return OdVoiceResult(
      englishSummary: trimmedDraft.isNotEmpty ? trimmedDraft : 'Duty performed at site.',
      originalTranscript: trimmedDraft,
      detectedLanguage: trimmedDraft.contains(RegExp(r'[\u0B80-\u0BFF]')) ? 'Tamil' : 'English',
    );
  }

  String _cleanJsonString(String raw) {
    String str = raw.trim();
    if (str.startsWith('```json')) {
      str = str.substring(7);
    } else if (str.startsWith('```')) {
      str = str.substring(3);
    }
    if (str.endsWith('```')) {
      str = str.substring(0, str.length - 3);
    }
    return str.trim();
  }
}
