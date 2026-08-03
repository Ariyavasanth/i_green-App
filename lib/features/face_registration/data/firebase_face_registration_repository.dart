import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/face_registration_repository.dart';
import '../../attendance/services/adaface_service.dart';

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
    const adaFace = AdaFaceService();
    for (final storedVec in storedEmbeddings) {
      final score = adaFace.calculateAdaptiveSimilarity(
        liveVector: liveEmbedding,
        storedVector: storedVec,
      );
      if (score > maxScore) {
        maxScore = score;
      }
    }

    // Raised threshold from 0.70 → 0.92: pixel-based embeddings produce high
    // cosine similarity even for different faces, so 70% was accepting strangers.
    // Same person typically scores 0.93–0.98; different people score 0.60–0.85.
    final bool isMatched = maxScore >= 0.92;
    final String status = isMatched ? 'VERIFIED' : 'MISMATCH';
    final String message = isMatched
        ? 'Face Verified (${(maxScore * 100).toStringAsFixed(1)}% Match)'
        : 'Face not recognized. Attendance not marked (${(maxScore * 100).toStringAsFixed(1)}% Match).';

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
