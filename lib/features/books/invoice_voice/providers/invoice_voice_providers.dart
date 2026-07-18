import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/gemini_live_invoice_voice_client.dart';
import '../data/openrouter_invoice_voice_parser.dart';
import '../domain/invoice_speech_recognizer.dart';
import '../domain/invoice_realtime_voice_client.dart';
import '../domain/invoice_voice_parser.dart';
import '../domain/invoice_voice_speaker.dart';

// Legacy providers remain compile-safe while all active voice work uses Gemini Live.
final invoiceSpeechRecognizerProvider = Provider<InvoiceSpeechRecognizer>(
  (ref) => throw UnsupportedError('Legacy speech recognition is disabled'),
);
final invoiceVoiceParserProvider = Provider<InvoiceVoiceParser>(
  (ref) => OpenRouterInvoiceVoiceParser(),
);
final invoiceVoiceSpeakerProvider = Provider<InvoiceVoiceSpeaker>(
  (ref) => throw UnsupportedError('Legacy text-to-speech is disabled'),
);

final invoiceRealtimeVoiceClientProvider = Provider<InvoiceRealtimeVoiceClient>((ref) {
  final client = GeminiLiveInvoiceVoiceClient();
  ref.onDispose(client.stop);
  return client;
});
