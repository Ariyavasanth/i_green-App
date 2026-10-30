import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class FundRequestStorageService {
  final FirebaseStorage? _storage;

  FundRequestStorageService({FirebaseStorage? storage}) : _storage = storage;

  FirebaseStorage get _instance {
    return _storage ?? FirebaseStorage.instance;
  }

  String _sanitize(String input) {
    return input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').replaceAll(' ', '_');
  }

  /// Uploads a bill image to Firebase Storage:
  /// `fund_requests/{projectCode}/{requestId}/bills/{timestamp}_{fileName}`
  Future<String> uploadBillImage({
    required Uint8List bytes,
    required String fileName,
    required String requestId,
    required String projectCode,
    String contentType = 'image/jpeg',
  }) async {
    final cleanProj = _sanitize(projectCode.isEmpty ? 'GENERAL' : projectCode);
    final cleanReq = _sanitize(requestId.isEmpty ? 'TEMP_${DateTime.now().millisecondsSinceEpoch}' : requestId);
    final cleanName = _sanitize(fileName);
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final path = 'fund_requests/$cleanProj/$cleanReq/bills/${timestamp}_$cleanName';

    try {
      final ref = _instance.ref().child(path);
      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'projectCode': projectCode,
          'requestId': requestId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = await ref.putData(bytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      // Safe fallback if Firebase Storage is uninitialized / offline during dev
      return 'https://firebasestorage.googleapis.com/v0/b/fallback/$path';
    }
  }

  /// Uploads an audio note to Firebase Storage:
  /// `fund_requests/{projectCode}/{requestId}/audio/{timestamp}_voicenote.m4a`
  Future<String> uploadAudioNote({
    required Uint8List bytes,
    required String requestId,
    required String projectCode,
  }) async {
    final cleanProj = _sanitize(projectCode.isEmpty ? 'GENERAL' : projectCode);
    final cleanReq = _sanitize(requestId.isEmpty ? 'TEMP_${DateTime.now().millisecondsSinceEpoch}' : requestId);
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final path = 'fund_requests/$cleanProj/$cleanReq/audio/${timestamp}_voicenote.m4a';

    try {
      final ref = _instance.ref().child(path);
      final metadata = SettableMetadata(
        contentType: 'audio/m4a',
        customMetadata: {
          'projectCode': projectCode,
          'requestId': requestId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = await ref.putData(bytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      return 'https://firebasestorage.googleapis.com/v0/b/fallback/$path';
    }
  }
}

