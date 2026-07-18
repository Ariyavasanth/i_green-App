import 'package:speech_to_text/speech_to_text.dart';

import '../domain/invoice_speech_recognizer.dart';

class DeviceInvoiceSpeechRecognizer implements InvoiceSpeechRecognizer {
  DeviceInvoiceSpeechRecognizer(this._speech);
  final SpeechToText _speech;

  @override
  Future<bool> initialize() => _speech.initialize();

  @override
  Future<void> listen(InvoiceTranscriptCallback onTranscript) => _speech.listen(
    onResult: (result) => onTranscript(result.recognizedWords, result.finalResult),
    listenFor: const Duration(minutes: 2),
    pauseFor: const Duration(seconds: 7),
    listenOptions: SpeechListenOptions(
      partialResults: true,
      cancelOnError: true,
      listenMode: ListenMode.dictation,
    ),
  );

  @override
  Future<void> stop() => _speech.stop();
  @override
  Future<void> cancel() => _speech.cancel();
}
