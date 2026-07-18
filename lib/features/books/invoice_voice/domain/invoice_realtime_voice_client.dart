import 'invoice_voice_parameters.dart';

typedef InvoiceRealtimeTranscriptCallback = void Function(String transcript, bool isFinal);
typedef InvoiceRealtimeValuesCallback = void Function(InvoiceVoiceParameters values);
typedef InvoiceRealtimeStatusCallback = void Function(String status);
typedef InvoiceRealtimeErrorCallback = void Function(String message);

abstract interface class InvoiceRealtimeVoiceClient {
  Future<void> start({
    required InvoiceRealtimeTranscriptCallback onTranscript,
    required InvoiceRealtimeValuesCallback onValues,
    required VoidCallback onFinished,
    required InvoiceRealtimeStatusCallback onStatus,
    required InvoiceRealtimeErrorCallback onError,
  });

  Future<void> stop();
}

typedef VoidCallback = void Function();
