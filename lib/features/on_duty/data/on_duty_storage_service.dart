import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class OnDutyStorageService {
  final FirebaseStorage _storage;

  OnDutyStorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  /// Uploads proof photo bytes to Firebase Storage under `on_duty/{assignmentId}/{action}_{timestamp}.jpg`
  /// and returns the download URL.
  /// [photoData] can be either raw JPEG Uint8List or a base64 Data URL (e.g. data:image/jpeg;base64,...).
  Future<String> uploadOdProof({
    required int assignmentId,
    required String action,
    required dynamic photoData,
  }) async {
    Uint8List bytes;
    if (photoData is Uint8List) {
      bytes = photoData;
    } else if (photoData is List<int>) {
      bytes = Uint8List.fromList(photoData);
    } else if (photoData is String) {
      if (photoData.startsWith('data:')) {
        final commaIdx = photoData.indexOf(',');
        final base64Str = commaIdx != -1 ? photoData.substring(commaIdx + 1) : photoData;
        bytes = base64Decode(base64Str.trim());
      } else {
        try {
          bytes = base64Decode(photoData.trim());
        } catch (_) {
          // If already a valid http(s) URL, return directly
          if (photoData.startsWith('http://') || photoData.startsWith('https://')) {
            return photoData;
          }
          throw Exception('Invalid photo data format');
        }
      }
    } else {
      throw Exception('Unsupported photo data type');
    }

    if (bytes.isEmpty) {
      throw Exception('Photo bytes cannot be empty');
    }

    final sanitizedAction = action.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_').toLowerCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'on_duty/$assignmentId/${sanitizedAction}_$timestamp.jpg';

    try {
      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'assignmentId': assignmentId.toString(),
          'action': sanitizedAction,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = await ref.putData(bytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Firebase Storage upload failed for $path: $e');
      rethrow;
    }
  }
}

