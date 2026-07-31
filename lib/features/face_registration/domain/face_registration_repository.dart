import 'dart:async';

class FaceVerificationResult {
  const FaceVerificationResult({
    required this.isMatched,
    required this.similarityScore,
    required this.verificationStatus,
    required this.message,
    this.evidenceImagePath,
  });

  final bool isMatched;
  final double similarityScore; // 0.0 to 1.0 (1.0 = 100%)
  final String verificationStatus;
  final String message;
  final String? evidenceImagePath;
}

abstract class FaceRegistrationRepository {
  /// Save 10-20 face embedding vectors for an employee
  Future<void> registerFaceEmbeddings({
    required int employeeId,
    required String employeeName,
    required List<List<double>> embeddings,
  });

  /// Retrieve stored face embeddings for an employee
  Future<List<List<double>>> getFaceEmbeddings(int employeeId);

  /// Check if an employee has completed face registration
  Future<bool> isFaceRegistered(int employeeId);

  /// Verify a live face embedding vector against stored 10-20 embeddings.
  /// Returns [FaceVerificationResult] with similarity score and >95% (0.95) match status.
  Future<FaceVerificationResult> verifyLiveEmbedding({
    required int employeeId,
    required List<double> liveEmbedding,
    required String date,
    required String time,
    required String employeeName,
    required String actionType, // 'CHECK_IN' or 'CHECK_OUT'
    String? liveFrameImagePath,
  });

  /// Delete registered face embeddings for an employee
  Future<void> deleteFaceEmbeddings(int employeeId);

  /// Get failed mismatch attempts for admin notification
  Future<List<Map<String, dynamic>>> getMismatchAttempts();
}
