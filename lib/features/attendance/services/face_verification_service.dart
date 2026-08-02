import 'dart:typed_data';
import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'adaface_service.dart';

class FaceVerificationResult {
  const FaceVerificationResult({
    required this.allowed,
    required this.similarityScore,
    required this.message,
    required this.capturedImagePath,
    this.isLowLight = false,
  });

  final bool allowed;
  final double similarityScore;
  final String message;
  final String capturedImagePath;
  final bool isLowLight;
}

/// Face Verification Service powered by AdaFace (Adaptive Margin Face Recognition Engine)
class FaceVerificationService {
  const FaceVerificationService({AdaFaceService? adaFaceService})
      : _adaFaceService = adaFaceService ?? const AdaFaceService();

  final AdaFaceService _adaFaceService;

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
    
    final liveAdaFace = _adaFaceService.extractAdaFaceEmbedding(capturedBytes);
    final profileAdaFace = _adaFaceService.extractAdaFaceEmbedding(profileBytes);

    final similarity = _adaFaceService.calculateAdaptiveSimilarity(
      liveVector: liveAdaFace.vector,
      storedVector: profileAdaFace.vector,
      liveQualityScore: liveAdaFace.qualityScore,
    );

    final allowed = similarity >= threshold;
    return FaceVerificationResult(
      allowed: allowed,
      similarityScore: similarity,
      message: allowed ? 'Attendance marked successfully.' : 'Face verification failed. Please try again.',
      capturedImagePath: capturedImagePath,
      isLowLight: liveAdaFace.isLowLight,
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

  /// Detect if camera image is valid and has face/content (not pitch black or completely featureless)
  bool isFaceDetected(Uint8List bytes) {
    if (bytes.isEmpty) return false;
    final decoded = img.decodeImage(bytes);
    if (decoded == null || decoded.width == 0 || decoded.height == 0) return false;

    // Check average luminance & variance to ensure camera is not completely covered
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

    // AdaFace relaxed threshold allows working under low light (avgLum >= 5.0)
    if (avgLum < 5.0 || variance < 4.0) {
      return false;
    }
    return true;
  }

  /// Extract 512-d AdaFace embedding from image bytes
  List<double> extractEmbeddingFromImageBytes(Uint8List bytes) {
    return _adaFaceService.extractAdaFaceEmbedding(bytes).vector;
  }

  /// Extract complete AdaFace embedding metadata
  AdaFaceEmbedding extractAdaFaceEmbedding(Uint8List bytes) {
    return _adaFaceService.extractAdaFaceEmbedding(bytes);
  }

  /// Calculate AdaFace quality-adaptive similarity between live & stored embeddings
  double calculateAdaFaceSimilarity(List<double> liveVec, List<double> storedVec, {double qualityScore = 1.0}) {
    return _adaFaceService.calculateAdaptiveSimilarity(
      liveVector: liveVec,
      storedVector: storedVec,
      liveQualityScore: qualityScore,
    );
  }
}
