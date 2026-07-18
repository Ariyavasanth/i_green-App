import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/invoice_voice_parameters.dart';
import '../domain/invoice_voice_parser.dart';

class OpenRouterInvoiceVoiceParser implements InvoiceVoiceParser {
  OpenRouterInvoiceVoiceParser({http.Client? client}) : _client = client ?? http.Client();
  static const _key = String.fromEnvironment('OPENROUTER_API_KEY');
  final http.Client _client;

  @override
  Future<InvoiceVoiceParameters> parse(String transcript) async {
    if (_key.isEmpty) throw StateError('OPENROUTER_API_KEY is not configured.');
    final command = transcript.trim();
    if (command.isEmpty || command.length > 8000) throw const FormatException('Voice command is empty or too long.');
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final response = await _client.post(
      Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
      headers: {'Authorization': 'Bearer $_key', 'Content-Type': 'application/json', 'X-Title': 'Invoice Voice Fill'},
      body: jsonEncode({
        'model': 'openrouter/free',
        'temperature': 0,
        'max_tokens': 1400,
        'provider': {'require_parameters': true},
        'messages': [
          {'role': 'system', 'content': 'Extract only explicitly spoken invoice values from natural English, Tamil, or Tanglish. Map meaning and common mixed-language phrases correctly: customer peru/name -> customerName, order peru/name/number -> orderNumber, invoice number -> invoiceNumber, porul/item -> item name, ennikkai/quantity -> quantity, vilai/rate -> rate. Set appendItems to true when the user asks to add a new/additional item, including phrases such as "add another item", and include that item and its spoken details in items. Never interpret such a request as an update to item index zero. Otherwise set appendItems to false. Understand spoken Tamil numbers and convert them to numeric values. Speech recognition may remove date separators: after a date label, "2007 2026" means 20/07/2026 and must become 2026-07-20. Interpret spoken dates in Indian day-month-year order unless the month is spoken by name. The speaker may pause, repeat, or correct a value; use the latest explicit correction. Never guess. Use null for unmentioned fields. Dates are YYYY-MM-DD. Today is $today in Asia/Calcutta. Allowed payment terms: Due on Receipt, Net 15, Net 30, Net 45, Net 60. Allowed taxes: No Tax, GST 5%, GST 12%, GST 18%, GST 28%. Discount type: % or Amount. Return data only.'},
          {'role': 'user', 'content': command},
        ],
        'response_format': {'type': 'json_schema', 'json_schema': {'name': 'invoice_voice_parameters', 'strict': true, 'schema': _schema}},
      }),
    ).timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) throw StateError('OpenRouter request failed (${response.statusCode}).');
    final body = jsonDecode(response.body);
    final content = body['choices']?[0]?['message']?['content'];
    if (content is! String) throw const FormatException('OpenRouter returned no invoice data.');
    final value = jsonDecode(content);
    if (value is! Map<String, dynamic>) throw const FormatException('OpenRouter returned invalid invoice data.');
    return InvoiceVoiceParameters.fromJson(value).validated();
  }

  static const _string = {'type': ['string', 'null']};
  static const _number = {'type': ['number', 'null']};
  static const Map<String, dynamic> _schema = {
    'type': 'object', 'additionalProperties': false,
    'properties': {
      'customerName': _string, 'invoiceNumber': _string, 'orderNumber': _string,
      'invoiceDate': _string, 'paymentTerms': _string, 'dueDate': _string,
      'items': {'type': 'array', 'maxItems': 25, 'items': {'type': 'object', 'additionalProperties': false, 'properties': {'name': _string, 'description': _string, 'quantity': _number, 'rate': _number, 'tax': _string}, 'required': ['name', 'description', 'quantity', 'rate', 'tax']}},
      'appendItems': {'type': 'boolean'},
      'discount': _number, 'discountType': _string, 'advanceReceived': _number,
      'notes': _string, 'termsAndConditions': _string,
    },
    'required': ['customerName', 'invoiceNumber', 'orderNumber', 'invoiceDate', 'paymentTerms', 'dueDate', 'items', 'appendItems', 'discount', 'discountType', 'advanceReceived', 'notes', 'termsAndConditions'],
  };
}
