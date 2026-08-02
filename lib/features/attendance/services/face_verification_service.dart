import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';

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
    final v1 = extractEmbeddingFromImageBytes(liveBytes);
    final v2 = extractEmbeddingFromImageBytes(profileBytes);
    if (v1.isEmpty || v2.isEmpty || v1.length != v2.length) return 0.0;
    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    for (var i = 0; i < v1.length; i++) {
      dot += v1[i] * v2[i];
      normA += v1[i] * v1[i];
      normB += v2[i] * v2[i];
    }
    if (normA == 0.0 || normB == 0.0) return 0.0;
    return (dot / (sqrt(normA) * sqrt(normB))).clamp(0.0, 1.0);
  }

  /// Detect if camera image is valid and has face/content (not black screen or empty image)
  bool isFaceDetected(Uint8List bytes) {
    if (bytes.isEmpty) return false;
    final decoded = img.decodeImage(bytes);
    if (decoded == null || decoded.width == 0 || decoded.height == 0) return false;

    // Check average luminance to ensure camera is not covered (black frame)
    final resized = img.copyResize(decoded, width: 16, height: 16);
    var totalLum = 0.0;
    var sqSum = 0.0;
    final count = resized.width * resized.height;
    for (var y = 0; y < resized.height; y++) {
      for (var x = 0; x < resized.width; x++) {
        final lum = img.getLuminance(resized.getPixel(x, y)).toDouble();
        totalLum += lum;
        sqSum += lum * lum;
      }
    }
    final avgLum = totalLum / count;
    final variance = (sqSum / count) - (avgLum * avgLum);

    // If camera frame is pitch black or completely featureless (low variance), no face detected
    if (avgLum < 12.0 || variance < 10.0) {
      return false;
    }
    return true;
  }

  /// Extract 256-d normalized structural facial feature vector from image bytes
  List<double> extractEmbeddingFromImageBytes(Uint8List bytes) {
    if (bytes.isEmpty) return const [];
    var decoded = img.decodeImage(bytes);
    if (decoded == null) return const [];

    // 1. Fix sensor rotation / EXIF orientation
    decoded = img.bakeOrientation(decoded);

    // 2. Crop to center face area (55% width x 65% height) matching the camera guide oval
    final cropWidth = (decoded.width * 0.55).round();
    final cropHeight = (decoded.height * 0.65).round();
    final cropX = ((decoded.width - cropWidth) / 2).round();
    final cropY = ((decoded.height - cropHeight) / 2).round();

    final faceCrop = img.copyCrop(
      decoded,
      x: cropX.clamp(0, decoded.width - 1),
      y: cropY.clamp(0, decoded.height - 1),
      width: cropWidth.clamp(1, decoded.width),
      height: cropHeight.clamp(1, decoded.height),
    );

    // 3. Resize to 16x16 grid (256 pixels)
    final resized = img.copyResize(faceCrop, width: 16, height: 16);
    final grid = List.generate(16, (_) => List.filled(16, 0.0));
    for (var y = 0; y < 16; y++) {
      for (var x = 0; x < 16; x++) {
        final pixel = resized.getPixel(x, y);
        grid[y][x] = img.getLuminance(pixel) / 255.0;
      }
    }

    // 4. Extract spatial structural features: luminance + horizontal & vertical gradients (facial landmarks)
    final rawVec = <double>[];
    for (var y = 0; y < 16; y++) {
      for (var x = 0; x < 16; x++) {
        final val = grid[y][x] * 2.0 - 1.0;
        final gx = (x < 15 ? grid[y][x + 1] : grid[y][x]) - (x > 0 ? grid[y][x - 1] : grid[y][x]);
        final gy = (y < 15 ? grid[y + 1][x] : grid[y][x]) - (y > 0 ? grid[y - 1][x] : grid[y][x]);
        rawVec.add((val * 0.6) + (gx * 0.2) + (gy * 0.2));
      }
    }

    double sumSq = 0.0;
    for (final v in rawVec) {
      sumSq += v * v;
    }
    final length = sqrt(sumSq);
    if (length == 0) return rawVec;
    return rawVec.map((v) => v / length).toList();
  }
}


