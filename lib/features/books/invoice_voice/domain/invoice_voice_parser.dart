import 'invoice_voice_parameters.dart';

abstract interface class InvoiceVoiceParser {
  Future<InvoiceVoiceParameters> parse(String transcript);
}
