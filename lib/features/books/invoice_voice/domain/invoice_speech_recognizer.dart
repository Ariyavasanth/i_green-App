typedef InvoiceTranscriptCallback = void Function(String transcript, bool isFinal);

abstract interface class InvoiceSpeechRecognizer {
  Future<bool> initialize();
  Future<void> listen(InvoiceTranscriptCallback onTranscript);
  Future<void> stop();
  Future<void> cancel();
}
