import 'package:flutter_tts/flutter_tts.dart';

import '../domain/invoice_voice_speaker.dart';

class DeviceInvoiceVoiceSpeaker implements InvoiceVoiceSpeaker {
  DeviceInvoiceVoiceSpeaker(this._tts);

  final FlutterTts _tts;
  bool _configured = false;

  @override
  Future<void> prepare() async {
    if (_configured) return;
    await _tts.setLanguage('en-IN');
    await _tts.setSpeechRate(0.58);
    await _tts.setVolume(1);
    await _tts.awaitSpeakCompletion(true);
    _configured = true;
  }

  @override
  Future<void> speak(String message) async {
    await prepare();
    await _tts.stop();
    await _tts.speak(message);
  }

  @override
  Future<void> stop() => _tts.stop();
}
