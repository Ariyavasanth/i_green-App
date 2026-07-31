import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/face_registration_repository.dart';

class FirebaseFaceRegistrationRepository implements FaceRegistrationRepository {
  FirebaseFaceRegistrationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _embeddingsRef =>
      _firestore.collection('employee_face_embeddings');

  CollectionReference<Map<String, dynamic>> get _attemptsRef =>
      _firestore.collection('attendance_attempts');

  CollectionReference<Map<String, dynamic>> get _recordsRef =>
      _firestore.collection('attendance_records');

  /// Cosine Similarity calculation between two numerical vectors
  double _cosineSimilarity(List<double> v1, List<double> v2) {
    if (v1.length != v2.length || v1.isEmpty) return 0.0;
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < v1.length; i++) {
      dotProduct += v1[i] * v2[i];
      normA += v1[i] * v1[i];
      normB += v2[i] * v2[i];
    }

    if (normA == 0.0 || normB == 0.0) return 0.0;
    final similarity = dotProduct / (sqrt(normA) * sqrt(normB));
    return similarity.clamp(0.0, 1.0);
  }

  @override
  Future<void> registerFaceEmbeddings({
    required int employeeId,
    required String employeeName,
    required List<List<double>> embeddings,
  }) async {
    final docId = employeeId.toString();
    final Map<String, List<double>> vectorsMap = {};
    for (int i = 0; i < embeddings.length; i++) {
      vectorsMap['v_$i'] = embeddings[i];
    }

    await _embeddingsRef.doc(docId).set({
      'employee_id': employeeId,
      'employee_name': employeeName,
      'embeddings_count': embeddings.length,
      'vectors': vectorsMap,
      'updated_at': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  @override
  Future<List<List<double>>> getFaceEmbeddings(int employeeId) async {
    final doc = await _embeddingsRef.doc(employeeId.toString()).get();
    if (!doc.exists || doc.data() == null) return [];
    final data = doc.data()!;

    final rawVectorsMap = data['vectors'] as Map<String, dynamic>?;
    if (rawVectorsMap != null && rawVectorsMap.isNotEmpty) {
      final List<List<double>> result = [];
      rawVectorsMap.forEach((key, val) {
        if (val is List) {
          result.add(val.map((e) => (e as num).toDouble()).toList());
        }
      });
      return result;
    }

    // Fallback if legacy list format exists
    final rawList = data['embeddings'] as List<dynamic>?;
    if (rawList == null) return [];

    return rawList.map((e) {
      final list = e as List<dynamic>;
      return list.map((val) => (val as num).toDouble()).toList();
    }).toList();
  }

  @override
  Future<bool> isFaceRegistered(int employeeId) async {
    final doc = await _embeddingsRef.doc(employeeId.toString()).get();
    if (!doc.exists || doc.data() == null) return false;
    final count = doc.data()?['embeddings_count'] as int? ?? 0;
    return count > 0;
  }

  @override
  Future<FaceVerificationResult> verifyLiveEmbedding({
    required int employeeId,
    required String date,
    required String time,
    required String employeeName,
    required String actionType,
    required List<double> liveEmbedding,
    String? liveFrameImagePath,
  }) async {
    final storedEmbeddings = await getFaceEmbeddings(employeeId);

    if (storedEmbeddings.isEmpty) {
      return const FaceVerificationResult(
        isMatched: false,
        similarityScore: 0.0,
        verificationStatus: 'NOT_REGISTERED',
        message: 'Face not registered yet. Please complete Face Registration first.',
      );
    }

    double maxScore = 0.0;
    for (final storedVec in storedEmbeddings) {
      final score = _cosineSimilarity(liveEmbedding, storedVec);
      if (score > maxScore) {
        maxScore = score;
      }
    }

    // Match threshold > 95% (0.95)
    final bool isMatched = maxScore >= 0.95;
    final String status = isMatched ? 'VERIFIED' : 'MISMATCH';
    final String message = isMatched
        ? 'Face Verified (${(maxScore * 100).toStringAsFixed(1)}% Match)'
        : 'Face Mismatch (${(maxScore * 100).toStringAsFixed(1)}% Match). Alert Sent to Admin.';

    if (isMatched) {
      // YES (>95%): Save METADATA ONLY (no photo binary stored to conserve disk/cloud storage)
      final recordDocId = '${employeeId}_$date';
      await _recordsRef.doc(recordDocId).set({
        'employee_id': employeeId,
        'employee_name': employeeName,
        'date': date,
        'status': 'PRESENT',
        'verification_status': 'FACE_VERIFIED',
        'similarity_score': maxScore,
        'face_verified': true,
        if (actionType == 'CHECK_IN') 'check_in_time': time,
        if (actionType == 'CHECK_OUT') 'check_out_time': time,
        'updated_at': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } else {
      // NO (<95%): Save image as evidence + notify admin log
      await _attemptsRef.add({
        'employee_id': employeeId,
        'employee_name': employeeName,
        'date': date,
        'time': time,
        'action_type': actionType,
        'verification_status': 'MISMATCH',
        'similarity_score': maxScore,
        'evidence_image_path': liveFrameImagePath ?? '',
        'admin_notified': true,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    return FaceVerificationResult(
      isMatched: isMatched,
      similarityScore: maxScore,
      verificationStatus: status,
      message: message,
      evidenceImagePath: isMatched ? null : liveFrameImagePath,
    );
  }

  @override
  Future<void> deleteFaceEmbeddings(int employeeId) async {
    await _embeddingsRef.doc(employeeId.toString()).delete();
  }

  @override
  Future<List<Map<String, dynamic>>> getMismatchAttempts() async {
    final snap = await _attemptsRef
        .where('verification_status', isEqualTo: 'MISMATCH')
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }
}
