class OdVoiceResult {
  const OdVoiceResult({
    required this.englishSummary,
    this.originalTranscript = '',
    this.detectedLanguage = 'English',
  });

  final String englishSummary;
  final String originalTranscript;
  final String detectedLanguage;

  bool get hasTamilOrigin =>
      detectedLanguage.toLowerCase() == 'tamil' ||
      detectedLanguage.toLowerCase() == 'tanglish' ||
      originalTranscript.contains(RegExp(r'[\u0B80-\u0BFF]'));

  Map<String, dynamic> toMap() => {
        'english_summary': englishSummary,
        'original_transcript': originalTranscript,
        'detected_language': detectedLanguage,
      };

  factory OdVoiceResult.fromMap(Map<String, dynamic> map) {
    return OdVoiceResult(
      englishSummary: map['english_summary']?.toString() ?? '',
      originalTranscript: map['original_transcript']?.toString() ?? '',
      detectedLanguage: map['detected_language']?.toString() ?? 'English',
    );
  }
}

abstract class OdVoiceService {
  Future<bool> initialize();
  Future<void> startListening({
    required void Function(String liveText) onLiveTranscript,
    String? localeId,
  });
  Future<void> stopListening();
  Future<void> cancelListening();
  bool get isListening;

  Future<OdVoiceResult> processWithGemini({
    required String rawSpokenText,
    String contextInfo = '',
  });
}
