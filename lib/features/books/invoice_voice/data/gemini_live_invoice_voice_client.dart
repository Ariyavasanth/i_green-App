import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../domain/invoice_realtime_voice_client.dart';
import '../domain/invoice_voice_parameters.dart';

class GeminiLiveInvoiceVoiceClient implements InvoiceRealtimeVoiceClient {
  GeminiLiveInvoiceVoiceClient({http.Client? httpClient})
    : _http = httpClient ?? http.Client();
  static const _tokenUrl = String.fromEnvironment(
    'INVOICE_GEMINI_TOKEN_URL',
    defaultValue: 'http://10.0.2.2:3000/token',
  );
  static const _liveUrl =
      'wss://generativelanguage.googleapis.com/ws/google.ai.'
      'generativelanguage.v1alpha.GenerativeService.BidiGenerateContentConstrained';
  final http.Client _http;
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _socketSub;
  StreamController<Uint8List>? _micController;
  StreamSubscription<Uint8List>? _micSub;
  InvoiceRealtimeTranscriptCallback? _onTranscript;
  InvoiceRealtimeValuesCallback? _onValues;
  VoidCallback? _onFinished;
  InvoiceRealtimeStatusCallback? _onStatus;
  InvoiceRealtimeErrorCallback? _onError;
  bool _audioStarted = false;
  bool _audioOpened = false;
  bool _closing = false;
  bool _pendingAppendItems = false;
  Future<void> _playbackQueue = Future.value();
  BytesBuilder _playbackBuffer = BytesBuilder(copy: false);
  Timer? _playbackFlushTimer;

  static const _playbackBatchBytes = 12 * 1024;
  static const _playbackFlushDelay = Duration(milliseconds: 180);

  @override
  Future<void> start({
    required InvoiceRealtimeTranscriptCallback onTranscript,
    required InvoiceRealtimeValuesCallback onValues,
    required VoidCallback onFinished,
    required InvoiceRealtimeStatusCallback onStatus,
    required InvoiceRealtimeErrorCallback onError,
  }) async {
    await stop();
    _closing = false;
    _pendingAppendItems = false;
    _onTranscript = onTranscript;
    _onValues = onValues;
    _onFinished = onFinished;
    _onStatus = onStatus;
    _onError = onError;
    onStatus('Connecting to Nova...');
    try {
      final response = await _http
          .post(Uri.parse(_tokenUrl))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw StateError('Token request failed: ${response.body}');
      }
      final token =
          (jsonDecode(response.body) as Map<String, dynamic>)['token'];
      if (token is! String)
        throw const FormatException('Invalid token response');
      final socket = WebSocketChannel.connect(
        Uri.parse(_liveUrl).replace(queryParameters: {'access_token': token}),
      );
      _socket = socket;
      await socket.ready.timeout(const Duration(seconds: 15));
      _socketSub = socket.stream.listen(
        _handleMessage,
        onError: (Object error) {
          if (!_closing) _onError?.call('Nova connection error: $error');
        },
        onDone: () {
          if (!_closing)
            _onError?.call('Nova disconnected. Tap microphone to reconnect.');
        },
      );
      _send(_setupMessage);
    } catch (error) {
      await stop();
      onError('Could not connect to Nova: $error');
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    _closing = true;
    _pendingAppendItems = false;
    await _micSub?.cancel();
    _micSub = null;
    if (_audioStarted) {
      await _recorder.stopRecorder();
      await _player.stopPlayer();
    }
    _audioStarted = false;
    await _micController?.close();
    _micController = null;
    if (_audioOpened) {
      await _recorder.closeRecorder();
      await _player.closePlayer();
    }
    _audioOpened = false;
    _playbackFlushTimer?.cancel();
    _playbackFlushTimer = null;
    _playbackBuffer = BytesBuilder(copy: false);
    _playbackQueue = Future.value();
    await _socketSub?.cancel();
    _socketSub = null;
    await _socket?.sink.close();
    _socket = null;
  }

  void _send(Map<String, dynamic> value) {
    if (!_closing) _socket?.sink.add(jsonEncode(value));
  }

  Future<void> _startAudio() async {
    if (_audioStarted || _closing) return;
    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      throw StateError('Microphone permission was denied.');
    }
    await _recorder.openRecorder();
    await _player.openPlayer();
    _audioOpened = true;
    await _player.startPlayerFromStream(
      codec: Codec.pcm16,
      interleaved: true,
      numChannels: 1,
      sampleRate: 24000,
      bufferSize: 16384,
    );
    final micController = StreamController<Uint8List>();
    _micController = micController;
    _micSub = micController.stream.listen(
      (samples) => _send({
        'realtimeInput': {
          'audio': {
            'data': base64Encode(samples),
            'mimeType': 'audio/pcm;rate=16000',
          },
        },
      }),
    );
    await _recorder.startRecorder(
      codec: Codec.pcm16,
      toStream: micController.sink,
      sampleRate: 16000,
      numChannels: 1,
      bufferSize: 4096,
      // Prevent Nova's playback from being captured and sent back to Gemini.
      enableEchoCancellation: true,
      enableNoiseSuppression: true,
    );
    _audioStarted = true;
    _onStatus?.call('Say "Hey Nova"');
  }

  void _handleMessage(dynamic raw) {
    try {
      final text = raw is String ? raw : utf8.decode(raw as List<int>);
      final event = jsonDecode(text);
      if (event is! Map<String, dynamic>) return;
      if (event.containsKey('setupComplete')) {
        unawaited(
          _startAudio().catchError(
            (Object error) =>
                _onError?.call('Microphone could not start: $error'),
          ),
        );
      }
      final content = event['serverContent'];
      if (content is Map<String, dynamic>) _handleServerContent(content);
      final tool = event['toolCall'];
      if (tool is Map<String, dynamic> && tool['functionCalls'] is List) {
        for (final call in tool['functionCalls'] as List) {
          if (call is Map<String, dynamic>) _handleTool(call);
        }
      }
    } catch (error) {
      _onError?.call('Nova returned an unreadable event: $error');
    }
  }

  void _handleServerContent(Map<String, dynamic> content) {
    final input = content['inputTranscription'];
    if (input is Map<String, dynamic>) {
      final text = (input['text'] as String? ?? '').trim();
      if (text.isNotEmpty) {
        // Keep append intent deterministic even if Gemini returns the wrong tool argument.
        _pendingAppendItems =
            _pendingAppendItems ||
            RegExp(
              r'\b(?:add\s+(?:another|a\s+new|an\s+additional)|another|new|additional)\s+item\b',
              caseSensitive: false,
            ).hasMatch(text);
        _onTranscript?.call(text, content['turnComplete'] == true);
      }
    }
    final turn = content['modelTurn'];
    if (turn is! Map<String, dynamic> || turn['parts'] is! List) return;
    for (final part in turn['parts'] as List) {
      if (part is! Map<String, dynamic>) continue;
      final inline = part['inlineData'];
      if (inline is Map<String, dynamic> && inline['data'] is String) {
        _bufferPlaybackAudio(base64Decode(inline['data'] as String));
      }
    }
  }

  void _bufferPlaybackAudio(Uint8List audio) {
    if (audio.isEmpty || _closing) return;
    _playbackBuffer.add(audio);
    if (_playbackBuffer.length >= _playbackBatchBytes) {
      _flushPlaybackAudio();
      return;
    }
    // A short jitter buffer smooths irregular network chunks without adding noticeable delay.
    _playbackFlushTimer ??= Timer(_playbackFlushDelay, _flushPlaybackAudio);
  }

  void _flushPlaybackAudio() {
    _playbackFlushTimer?.cancel();
    _playbackFlushTimer = null;
    if (_playbackBuffer.isEmpty || _closing) return;
    final audio = _playbackBuffer.takeBytes();
    _playbackQueue = _playbackQueue
        .then((_) async {
          if (_audioStarted && !_closing) {
            await _player.feedUint8FromStream(audio);
          }
        })
        .catchError((Object error) {
          if (!_closing) _onError?.call('Nova audio playback error: $error');
        });
  }

  void _handleTool(Map<String, dynamic> call) {
    final name = call['name'] as String?;
    final id = call['id'] as String?;
    if (name == 'update_invoice') {
      final args = call['args'];
      if (args is Map<String, dynamic>) {
        final values = Map<String, dynamic>.from(args);
        if (_pendingAppendItems) values['appendItems'] = true;
        _pendingAppendItems = false;
        _onValues?.call(InvoiceVoiceParameters.fromJson(values).validated());
      }
      _sendToolResult(name!, id, {'updated': true});
    } else if (name == 'finish_invoice') {
      _sendToolResult(name!, id, {'finished': true});
      _onFinished?.call();
    }
  }

  void _sendToolResult(String name, String? id, Map<String, dynamic> result) {
    _send({
      'toolResponse': {
        'functionResponses': [
          {'name': name, if (id != null) 'id': id, 'response': result},
        ],
      },
    });
  }
}

const _setupMessage = {
  'setup': {
    'model': 'models/gemini-3.1-flash-live-preview',
    'generationConfig': {
      'responseModalities': ['AUDIO'],
      'temperature': 0.0,
    },
    'inputAudioTranscription': {},
    'outputAudioTranscription': {},
    'systemInstruction': {
      'parts': [
        {'text': _novaInstructions},
      ],
    },
    'tools': [
      {'functionDeclarations': _invoiceFunctions},
    ],
  },
};

const _invoiceFunctions = [
  {
    'name': 'update_invoice',
    'description':
        'Extract every invoice field mentioned in the current user speech. '
        'Call this function exactly once for every completed user request. '
        'Never invent values. '
        'Never ignore explicitly spoken values. '
        'Update every field provided by the user.',
    'parameters': {
      'type': 'OBJECT',
      'properties': {
        'customerName': {'type': 'STRING'},
        'invoiceNumber': {'type': 'STRING'},
        'orderNumber': {'type': 'STRING'},
        'invoiceDate': {'type': 'STRING', 'description': 'YYYY-MM-DD'},
        'paymentTerms': {'type': 'STRING'},
        'dueDate': {'type': 'STRING', 'description': 'YYYY-MM-DD'},
        'items': {
          'type': 'ARRAY',
          'items': {
            'type': 'OBJECT',
            'properties': {
              'name': {'type': 'STRING'},
              'description': {'type': 'STRING'},
              'quantity': {'type': 'NUMBER'},
              'rate': {'type': 'NUMBER'},
              'tax': {'type': 'STRING'},
            },
          },
        },
        'appendItems': {
          'type': 'BOOLEAN',
          'description':
              'True only when the user asks for a new or additional item, such as "add another item".',
        },
        'duplicateItem': {'type': 'BOOLEAN'},
        'discount': {'type': 'NUMBER'},
        'discountType': {'type': 'STRING'},
        'taxMode': {'type': 'STRING'},
        'invoiceTax': {'type': 'STRING'},
        'advanceReceived': {'type': 'NUMBER'},
        'notes': {'type': 'STRING'},
        'termsAndConditions': {'type': 'STRING'},
      },
      'required': ['appendItems'],
    },
  },
  {
    'name': 'finish_invoice',
    'description': 'Finish entry and return Nova to wake mode.',
    'parameters': {'type': 'OBJECT', 'properties': <String, dynamic>{}},
  },
];

const _novaInstructions = r'''
You are Nova.

You are NOT a chatbot.

You are NOT a conversational assistant.

You are ONLY an invoice form filling engine.

Your only responsibility is to extract invoice information from speech and update the invoice form.

--------------------------------------------------
WAKE MODE
--------------------------------------------------

HIGHEST-PRIORITY WAKE RULE:

Whenever the user says an accepted wake phrase, your FIRST response must always
be the single spoken word "Listening". Do not call update_invoice or
finish_invoice before speaking "Listening". This rule also applies when the
wake phrase and invoice details are spoken in the same utterance: speak
"Listening" first, then process the details. No other response may come before
"Listening".

Remain completely silent.

Do not speak.

Do not call any tool.

Ignore everything until the wake phrase is detected.

Accepted wake phrases include:

- Hey Nova
- Hey Noba
- Hey Noah
- Hey Nove
- Hi Nova

When the wake phrase is detected:

Speak exactly

Listening

Nothing else.

--------------------------------------------------
ACTIVE MODE
--------------------------------------------------

After saying "Listening", wait for invoice information.

Understand:

• English
• Tamil
• Tanglish
• Mixed language
• Imperfect pronunciation
• Background pauses
• Natural conversation

Examples:

Customer Ravi

Customer name ABC Traders

Invoice number INV1005

Order number ORD55

Invoice date 18 July 2026

Due date 25 July

Payment terms Due on Receipt

One laptop quantity two rate forty thousand

One mouse quantity five rate five hundred

Discount five percent

Advance received ten thousand

Notes urgent delivery

Terms payment within fifteen days

The user may provide

one field

or

multiple fields

in one sentence.

Example

Customer Ravi invoice number INV1005 payment terms Due on Receipt

Extract every field.

Never ignore any value.

When the user says "add another item", "add a new item", or otherwise asks for
an additional item, set appendItems to true and return the new item with all of
its spoken details. Never map an additional item request to the first item.
For ordinary item updates, set appendItems to false.

--------------------------------------------------
FIELD MAPPING
--------------------------------------------------

customer name

customer peru

client

buyer

→ customerName

invoice number

bill number

→ invoiceNumber

order number

→ orderNumber

invoice date

bill date

→ invoiceDate

payment terms

→ paymentTerms

due date

→ dueDate

item

product

porul

→ items.name

description

→ items.description

quantity

qty

ennikkai

→ items.quantity

rate

price

vilai

→ items.rate

tax

GST

CGST

SGST

IGST

→ items.tax

discount

→ discount

advance

advance received

→ advanceReceived

notes

→ notes

terms

conditions

→ termsAndConditions
--------------------------------------------------
ADVANCED INVOICE ACTIONS
--------------------------------------------------

Understand user commands that modify the invoice form as well as field values.

When the user asks to add another item, create a new item entry in the items array.

Examples:

Add another item

Add one more item

Next item

New item

Another product

One more product

→ Create a new item object and continue filling that item only.

Never overwrite a previously created item unless the user explicitly says to edit it.

--------------------------------------------------

If the user asks to duplicate an item, duplicate the specified item with all its values.

Examples:

Duplicate item

Duplicate first item

Copy this item

Duplicate previous item

→ Set duplicateItem to true.

--------------------------------------------------

Understand discount type changes.

If the user says:

Discount in percentage

Use percentage

Percentage discount

Change discount to percentage

→ Set discountType to Percentage.

If the user says:

Discount amount

Use amount

Fixed discount

Change discount to amount

→ Set discountType to Amount.

--------------------------------------------------

Understand tax mode changes.

If the user says:

Use TDS

Change to TDS

Select TDS

→ Set taxMode to TDS.

If the user says:

Use TCS

Change to TCS

Select TCS

→ Set taxMode to TCS.

--------------------------------------------------

Understand invoice tax selection.

Examples:

No Tax

GST

IGST

CGST SGST

5 percent GST

12 percent GST

18 percent GST

28 percent GST

→ Set invoiceTax to the matching supported invoice tax value.

--------------------------------------------------

Every action that changes the form, including:

• Adding an item
• Duplicating an item
• Changing discount type
• Switching between Percentage and Amount
• Switching between TDS and TCS
• Changing invoice tax selection

must be included in the single update_invoice() function call for that user turn.

Never ignore these commands.

Treat these actions exactly like normal invoice field updates.

Respond using the same confirmation rules:

Customer added

Added

Details added

Done

Do not speak anything else.

--------------------------------------------------
DATES
--------------------------------------------------

Interpret all spoken dates using Indian format.

18/07/2026

means

2026-07-18

Always send dates as

YYYY-MM-DD

--------------------------------------------------
FUNCTION CALL
--------------------------------------------------

After EVERY completed user instruction

call

update_invoice()

EXACTLY ONCE.

Include every detected field.

Never invent values.

Never skip values.

--------------------------------------------------
VOICE RESPONSE RULES
--------------------------------------------------

These are the ONLY responses you are allowed to speak.

Wake word detected

Listening

----------------------------------

Only customer name updated

Customer added

----------------------------------

Exactly one field updated

Added

----------------------------------

Two or more fields updated

Details added

----------------------------------

Need clarification

Ask only ONE short question.

Examples

Please repeat the customer name.

Please repeat the invoice number.

Please repeat the quantity.

Nothing more.

--------------------------------------------------
SAVE AS DRAFT
--------------------------------------------------

If the user says:

Save Draft

Save as Draft

Draft

Store Draft

Save this as Draft

Then

Call

update_invoice()

including

saveAsDraft = true

Speak exactly

Added

--------------------------------------------------
SAVE & SEND
--------------------------------------------------

If the user says:

Save and Send

Send Invoice

Send

Save & Send

Send this invoice

Then

Call

update_invoice()

including

saveAndSend = true

Speak exactly

Added

--------------------------------------------------
FINISH VOICE SESSION
--------------------------------------------------

If the user says:

Done

Finished

Finish

Complete

That's all

That's it

Stop

Cancel

Exit

Close

Enough

Podhum

Avlothan

Mudinjudhu

Then

Call

finish_invoice()

Speak exactly

Done

Immediately stop listening.

Return to Wake Mode.

Do not process any further speech until the wake phrase is spoken again.


--------------------------------------------------
STRICTLY FORBIDDEN
--------------------------------------------------

Never say

Hello

Hi

Welcome

Good morning

Sure

Okay

Alright

Got it

I understand

I have updated

Invoice updated

Customer name is

The customer has been added

Anything else?

How may I help?

Thank you

Goodbye

Never greet.

Never explain.

Never summarize.

Never repeat user values.

Never describe what you updated.

Never read the form.

Never speak more than one of these phrases:

Listening

Customer added

Added

Details added

Done

No other spoken response is allowed.
''';
