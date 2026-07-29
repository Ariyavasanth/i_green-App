import 'dart:typed_data';
import 'dart:convert';

import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;

class FaceVerificationResult {
  const FaceVerificationResult({
    required this.allowed,
    required this.similarityScore,
    required this.message,
    required this.capturedImagePath,
  });

  final bool allowed;
  final double similarityScore;
  final String message;
  final String capturedImagePath;
}

class FaceVerificationService {
  const FaceVerificationService();

  Future<FaceVerificationResult> verifyCapturedBytes({
    required Uint8List capturedBytes,
    required String profileImageUrl,
    required double threshold,
    String capturedImagePath = '',
  }) async {
    final profileBytes = await _loadProfileBytes(profileImageUrl);
    if (profileBytes == null) {
      return FaceVerificationResult(
        allowed: false,
        similarityScore: 0,
        message: 'Face verification failed. Please try again.',
        capturedImagePath: capturedImagePath,
      );
    }
    final similarity = _compareImages(capturedBytes, profileBytes);
    final allowed = similarity >= threshold;
    return FaceVerificationResult(
      allowed: allowed,
      similarityScore: similarity,
      message: allowed ? 'Attendance marked successfully.' : 'Face verification failed. Please try again.',
      capturedImagePath: capturedImagePath,
    );
  }

  Future<Uint8List?> _loadProfileBytes(String profileImageUrl) async {
    if (profileImageUrl.isEmpty) return null;
    if (profileImageUrl.startsWith('http://') || profileImageUrl.startsWith('https://')) {
      final response = await http.get(Uri.parse(profileImageUrl));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }
      return null;
    }
    if (profileImageUrl.startsWith('data:image/')) {
      final commaIndex = profileImageUrl.indexOf(',');
      if (commaIndex > 0) {
        final payload = profileImageUrl.substring(commaIndex + 1);
        return base64Decode(payload);
      }
    }
    if (profileImageUrl.isNotEmpty) {
      try {
        return base64Decode(profileImageUrl);
      } catch (_) {}
    }
    return null;
  }

  double _compareImages(Uint8List liveBytes, Uint8List profileBytes) {
    final liveHash = _averageHash(liveBytes);
    final profileHash = _averageHash(profileBytes);
    if (liveHash.isEmpty || profileHash.isEmpty || liveHash.length != profileHash.length) return 0;
    var matches = 0;
    for (var i = 0; i < liveHash.length; i++) {
      if (liveHash[i] == profileHash[i]) matches++;
    }
    return matches / liveHash.length;
  }

  List<int> _averageHash(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return const [];
    final resized = img.copyResize(decoded, width: 8, height: 8);
    final pixels = <int>[];
    var total = 0;
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        final pixel = resized.getPixel(x, y);
        final gray = img.getLuminance(pixel).toInt();
        pixels.add(gray);
        total += gray;
      }
    }
    final avg = total / pixels.length;
    return pixels.map((p) => p >= avg ? 1 : 0).toList(growable: false);
  }
}
