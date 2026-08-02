import 'dart:convert';
import 'dart:math';
import 'package:sqflite/sqflite.dart';
import '../../employee/data/sqlite_employee_repository.dart';
import '../domain/face_registration_repository.dart';

class SqliteFaceRegistrationRepository implements FaceRegistrationRepository {
  SqliteFaceRegistrationRepository({SqliteEmployeeRepository? sqliteRepo})
      : _sqliteRepo = sqliteRepo ?? SqliteEmployeeRepository();

  final SqliteEmployeeRepository _sqliteRepo;

  Future<Database> get _db async => await _sqliteRepo.database;

  Future<void> _ensureTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS employee_face_embeddings (
        employee_id INTEGER PRIMARY KEY,
        employee_name TEXT,
        embeddings_count INTEGER,
        embeddings_json TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS face_attendance_attempts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER,
        employee_name TEXT,
        date TEXT,
        time TEXT,
        action_type TEXT,
        verification_status TEXT,
        similarity_score REAL,
        evidence_image_path TEXT,
        created_at TEXT
      )
    ''');
  }

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
    final db = await _db;
    await _ensureTable(db);

    final jsonStr = jsonEncode(embeddings);
    await db.insert(
      'employee_face_embeddings',
      {
        'employee_id': employeeId,
        'employee_name': employeeName,
        'embeddings_count': embeddings.length,
        'embeddings_json': jsonStr,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<List<double>>> getFaceEmbeddings(int employeeId) async {
    final db = await _db;
    await _ensureTable(db);

    final maps = await db.query(
      'employee_face_embeddings',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      limit: 1,
    );

    if (maps.isEmpty) return [];
    final jsonStr = maps.first['embeddings_json'] as String?;
    if (jsonStr == null || jsonStr.isEmpty) return [];

    final rawList = jsonDecode(jsonStr) as List<dynamic>;
    return rawList.map((e) {
      final list = e as List<dynamic>;
      return list.map((val) => (val as num).toDouble()).toList();
    }).toList();
  }

  @override
  Future<bool> isFaceRegistered(int employeeId) async {
    final db = await _db;
    await _ensureTable(db);

    final maps = await db.query(
      'employee_face_embeddings',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      limit: 1,
    );
    if (maps.isEmpty) return false;
    final count = maps.first['embeddings_count'] as int? ?? 0;
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

    final bool isMatched = maxScore >= 0.80;
    final String status = isMatched ? 'VERIFIED' : 'MISMATCH';
    final String message = isMatched
        ? 'Face Verified (${(maxScore * 100).toStringAsFixed(1)}% Match)'
        : 'Face not recognized. Attendance not marked (${(maxScore * 100).toStringAsFixed(1)}% Match).';

    final db = await _db;
    await _ensureTable(db);

    if (!isMatched) {
      await db.insert('face_attendance_attempts', {
        'employee_id': employeeId,
        'employee_name': employeeName,
        'date': date,
        'time': time,
        'action_type': actionType,
        'verification_status': 'MISMATCH',
        'similarity_score': maxScore,
        'evidence_image_path': liveFrameImagePath ?? '',
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
    final db = await _db;
    await _ensureTable(db);
    await db.delete(
      'employee_face_embeddings',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getMismatchAttempts() async {
    final db = await _db;
    await _ensureTable(db);
    return await db.query(
      'face_attendance_attempts',
      where: 'verification_status = ?',
      whereArgs: ['MISMATCH'],
      orderBy: 'id DESC',
    );
  }
}
