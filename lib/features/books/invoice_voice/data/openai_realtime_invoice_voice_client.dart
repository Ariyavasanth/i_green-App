import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

import '../domain/invoice_realtime_voice_client.dart';
import '../domain/invoice_voice_parameters.dart';

class OpenAiRealtimeInvoiceVoiceClient implements InvoiceRealtimeVoiceClient {
  OpenAiRealtimeInvoiceVoiceClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  static const _sessionUrl = String.fromEnvironment(
    'INVOICE_REALTIME_SESSION_URL',
    defaultValue: 'http://10.0.2.2:3000/session',
  );

  final http.Client _http;
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _events;
  MediaStream? _microphone;
  InvoiceRealtimeTranscriptCallback? _onTranscript;
  InvoiceRealtimeValuesCallback? _onValues;
  VoidCallback? _onFinished;
  InvoiceRealtimeStatusCallback? _onStatus;
  InvoiceRealtimeErrorCallback? _onError;
  final Map<String, StringBuffer> _transcriptDeltas = {};

  @override
  Future<void> start({
    required InvoiceRealtimeTranscriptCallback onTranscript,
    required InvoiceRealtimeValuesCallback onValues,
    required VoidCallback onFinished,
    required InvoiceRealtimeStatusCallback onStatus,
    required InvoiceRealtimeErrorCallback onError,
  }) async {
    await stop();
    _onTranscript = onTranscript;
    _onValues = onValues;
    _onFinished = onFinished;
    _onStatus = onStatus;
    _onError = onError;
    onStatus('Connecting to Nova…');
    try {
      final peer = await createPeerConnection({'iceServers': const []});
      _peerConnection = peer;
      _microphone = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      });
      for (final track in _microphone!.getAudioTracks()) {
        await peer.addTrack(track, _microphone!);
      }
      peer.onTrack = (event) {
        // flutter_webrtc routes enabled remote audio tracks to the device output.
        event.track.enabled = true;
      };
      final channel = await peer.createDataChannel('oai-events', RTCDataChannelInit());
      _events = channel;
      channel.onDataChannelState = (state) {
        if (state == RTCDataChannelState.RTCDataChannelOpen) _onStatus?.call('Say “Hey Nova”');
      };
      channel.onMessage = (message) {
        if (message.isBinary) return;
        _handleServerEvent(message.text);
      };
      final offer = await peer.createOffer({'offerToReceiveAudio': true});
      await peer.setLocalDescription(offer);
      final response = await _http.post(
        Uri.parse(_sessionUrl),
        headers: {'Content-Type': 'application/sdp'},
        body: offer.sdp,
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Realtime session failed (${response.statusCode}): ${response.body}');
      }
      await peer.setRemoteDescription(RTCSessionDescription(response.body, 'answer'));
    } catch (error) {
      await stop();
      onError('Could not connect to Nova: $error');
      rethrow;
    }
  }

  void _handleServerEvent(String raw) {
    try {
      final event = jsonDecode(raw) as Map<String, dynamic>;
      final type = event['type'] as String? ?? '';
      if (type == 'input_audio_buffer.speech_started') {
        _onStatus?.call('Listening…');
      } else if (type == 'conversation.item.input_audio_transcription.delta') {
        final id = event['item_id'] as String? ?? 'current';
        final buffer = _transcriptDeltas.putIfAbsent(id, StringBuffer.new);
        buffer.write(event['delta'] as String? ?? '');
        _onTranscript?.call(buffer.toString(), false);
      } else if (type == 'conversation.item.input_audio_transcription.completed') {
        final id = event['item_id'] as String? ?? 'current';
        final transcript = (event['transcript'] as String? ?? _transcriptDeltas[id]?.toString() ?? '').trim();
        _transcriptDeltas.remove(id);
        if (transcript.isNotEmpty) _onTranscript?.call(transcript, true);
      } else if (type == 'response.done') {
        _handleResponseDone(event['response'] as Map<String, dynamic>?);
      } else if (type == 'error') {
        final error = event['error'] as Map<String, dynamic>?;
        _onError?.call(error?['message'] as String? ?? 'Nova encountered a realtime error');
      }
    } catch (error) {
      _onError?.call('Nova returned an unreadable realtime event: $error');
    }
  }

  void _handleResponseDone(Map<String, dynamic>? response) {
    final output = response?['output'];
    if (output is! List) return;
    for (final rawItem in output) {
      if (rawItem is! Map<String, dynamic> || rawItem['type'] != 'function_call') continue;
      final name = rawItem['name'] as String?;
      final callId = rawItem['call_id'] as String?;
      if (name == 'update_invoice') {
        final arguments = jsonDecode(rawItem['arguments'] as String? ?? '{}');
        if (arguments is Map<String, dynamic>) {
          _onValues?.call(InvoiceVoiceParameters.fromJson(arguments).validated());
        }
        _sendFunctionResult(callId, {'updated': true});
      } else if (name == 'finish_invoice') {
        _sendFunctionResult(callId, {'finished': true}, requestResponse: true);
        _onFinished?.call();
      }
    }
  }

  void _sendFunctionResult(String? callId, Map<String, dynamic> result, {bool requestResponse = false}) {
    if (callId == null || _events?.state != RTCDataChannelState.RTCDataChannelOpen) return;
    _events!.send(RTCDataChannelMessage(jsonEncode({
      'type': 'conversation.item.create',
      'item': {'type': 'function_call_output', 'call_id': callId, 'output': jsonEncode(result)},
    })));
    if (requestResponse) _events!.send(RTCDataChannelMessage(jsonEncode({'type': 'response.create'})));
  }

  @override
  Future<void> stop() async {
    _transcriptDeltas.clear();
    for (final track in _microphone?.getTracks() ?? const <MediaStreamTrack>[]) {
      track.stop();
    }
    await _microphone?.dispose();
    await _events?.close();
    await _peerConnection?.close();
    _microphone = null;
    _events = null;
    _peerConnection = null;
  }
}
