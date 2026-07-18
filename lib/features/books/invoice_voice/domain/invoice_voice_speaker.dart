abstract interface class InvoiceVoiceSpeaker {
  Future<void> prepare();
  Future<void> speak(String message);
  Future<void> stop();
}
