import 'dart:math';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/attendance_record.dart';
import '../domain/attendance_settings.dart';
import '../domain/attendance_repository.dart';
import '../../attendance_settings/data/firebase_attendance_settings_repository.dart';
import '../../employee/domain/employee.dart';

class SqliteAttendanceRepository implements AttendanceRepository {
  static Database? _database;
  final FirebaseAttendanceSettingsRepository _settingsRepository = FirebaseAttendanceSettingsRepository();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    await _createTables(_database!);
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app_database.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: (db, _) async => _createTables(db),
      onOpen: (db) async => _createTables(db),
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attendance_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER,
        employee_name TEXT,
        date TEXT,
        time TEXT,
        status TEXT,
        verification_status TEXT,
        similarity_score REAL,
        check_in_time TEXT,
        check_out_time TEXT,
        check_in_verification_status TEXT,
        check_out_verification_status TEXT,
        check_in_similarity_score REAL,
        check_out_similarity_score REAL,
        total_hours REAL,
        notes TEXT,
        marked_at TEXT
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_attendance_employee_date
      ON attendance_records(employee_id, date)
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attendance_attempts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER,
        employee_name TEXT,
        date TEXT,
        time TEXT,
        verification_status TEXT,
        similarity_score REAL,
        message TEXT,
        created_at TEXT
      )
    ''');

    // Run schema migrations for existing tables
    final tableInfo = await db.rawQuery("PRAGMA table_info(attendance_records)");
    final existingColumns = tableInfo.map((row) => row['name'] as String).toSet();

    final newColumns = {
      'check_in_time': 'TEXT',
      'check_out_time': 'TEXT',
      'check_in_verification_status': 'TEXT',
      'check_out_verification_status': 'TEXT',
      'check_in_similarity_score': 'REAL',
      'check_out_similarity_score': 'REAL',
      'total_hours': 'REAL',
      'notes': 'TEXT',
    };

    for (final entry in newColumns.entries) {
      if (!existingColumns.contains(entry.key)) {
        await db.execute('ALTER TABLE attendance_records ADD COLUMN ${entry.key} ${entry.value}');
      }
    }
  }

  @override
  Future<AttendanceSettings> getAttendanceSettings() => _settingsRepository.getAttendanceSettings();

  @override
  Future<void> saveAttendanceSettings(AttendanceSettings settings) => _settingsRepository.saveAttendanceSettings(settings);

  int _parseMinutes(String time) {
    final parts = time.split(':');
    if (parts.length < 2) return 0;
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;
    return hours * 60 + minutes;
  }

  double _calculateTotalHours(String checkIn, String checkOut) {
    try {
      final inParts = checkIn.split(':');
      final outParts = checkOut.split(':');
      if (inParts.length >= 2 && outParts.length >= 2) {
        final inMin = int.parse(inParts[0]) * 60 + int.parse(inParts[1]);
        final outMin = int.parse(outParts[0]) * 60 + int.parse(outParts[1]);
        final diffMin = outMin - inMin;
        if (diffMin > 0) {
          return double.parse((diffMin / 60.0).toStringAsFixed(2));
        }
      }
    } catch (_) {}
    return 0.0;
  }

  String _attendanceStatus({
    required String scheduledCheckInTime,
    required DateTime actualCheckIn,
    required AttendanceSettings settings,
  }) {
    final scheduledMinutes = _parseMinutes(scheduledCheckInTime);
    final actualMinutes = actualCheckIn.hour * 60 + actualCheckIn.minute;
    final delay = actualMinutes - scheduledMinutes;
    if (delay <= settings.gracePeriodMinutes) return 'Present';
    if (delay > settings.absentThresholdMinutes) return 'Absent';
    return 'Late';
  }

  double _degreesToRadians(double degrees) => degrees * (pi / 180.0);

  double _distanceInMeters({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    const earthRadius = 6371000.0;
    final dLat = _degreesToRadians(endLatitude - startLatitude);
    final dLon = _degreesToRadians(endLongitude - startLongitude);
    final lat1 = _degreesToRadians(startLatitude);
    final lat2 = _degreesToRadians(endLatitude);
    final a = sin(dLat / 2) * sin(dLat / 2) + sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  Future<Map<String, dynamic>> _resolveEffectiveLocation({
    required int employeeId,
    required AttendanceSettings globalSettings,
  }) async {
    try {
      final db = await database;
      final maps = await db.query('employees', where: 'id = ?', whereArgs: [employeeId], limit: 1);
      if (maps.isNotEmpty) {
        final emp = Employee.fromMap(maps.first);
        if (emp.isDynamicEmployee && (emp.siteLatitude != 0 || emp.siteLongitude != 0)) {
          return {
            'targetLat': emp.siteLatitude,
            'targetLng': emp.siteLongitude,
            'targetRadius': emp.siteAllowedRadiusMeters,
            'requireGps': emp.siteRequireGpsVerification,
            'isSite': true,
          };
        }
      }
    } catch (_) {}
    return {
      'targetLat': globalSettings.officeLatitude,
      'targetLng': globalSettings.officeLongitude,
      'targetRadius': globalSettings.allowedAttendanceRadiusMeters,
      'requireGps': globalSettings.requireGpsVerification,
      'isSite': false,
    };
  }

  bool _isWithinAllowedRadius({
    required double targetLatitude,
    required double targetLongitude,
    required int allowedRadiusMeters,
    required bool requireGps,
    required double currentLatitude,
    required double currentLongitude,
  }) {
    if (!requireGps) return true;
    if (targetLatitude == 0 && targetLongitude == 0) return false;
    final distance = _distanceInMeters(
      startLatitude: targetLatitude,
      startLongitude: targetLongitude,
      endLatitude: currentLatitude,
      endLongitude: currentLongitude,
    );
    return distance <= allowedRadiusMeters;
  }

  @override
  Future<List<AttendanceRecord>> getAttendanceRecords(int employeeId) async {
    final db = await database;
    final maps = await db.query(
      'attendance_records',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      orderBy: 'date DESC, time DESC',
    );
    return maps.map(AttendanceRecord.fromMap).toList();
  }

  @override
  Future<List<AttendanceRecord>> getAllAttendanceRecords() async {
    final db = await database;
    final maps = await db.query('attendance_records', orderBy: 'date DESC, time DESC');
    return maps.map(AttendanceRecord.fromMap).toList();
  }

  @override
  Future<AttendanceRecord?> getAttendanceRecordForDate(int employeeId, String date) async {
    final db = await database;
    final maps = await db.query(
      'attendance_records',
      where: 'employee_id = ? AND date = ?',
      whereArgs: [employeeId, date],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return AttendanceRecord.fromMap(maps.first);
  }

  @override
  Future<bool> hasAttendanceForDate(int employeeId, String date) async {
    final db = await database;
    final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM attendance_records WHERE employee_id = ? AND date = ?', [employeeId, date]),
        ) ??
        0;
    return count > 0;
  }

  @override
  Future<AttendanceVerificationResult> verifyAttendance({
    required int employeeId,
    required String date,
    required String employeeName,
    required String profileImageUrl,
    required String scheduledCheckInTime,
    required double currentLatitude,
    required double currentLongitude,
    bool faceMatched = true,
    double similarityScore = 1.0,
  }) async {
    final now = DateTime.now();
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final score = similarityScore;
    final allowedFace = faceMatched && score >= 0.92;
    final settings = await getAttendanceSettings();
    final loc = await _resolveEffectiveLocation(employeeId: employeeId, globalSettings: settings);
    final isSite = loc['isSite'] as bool;
    final withinRadius = _isWithinAllowedRadius(
      targetLatitude: loc['targetLat'] as double,
      targetLongitude: loc['targetLng'] as double,
      allowedRadiusMeters: loc['targetRadius'] as int,
      requireGps: loc['requireGps'] as bool,
      currentLatitude: currentLatitude,
      currentLongitude: currentLongitude,
    );
    final message = !allowedFace
        ? 'Face not recognized. Attendance not marked.'
        : !withinRadius
            ? (isSite
                ? 'You are not at your site location. Please go to your site location to check in.'
                : 'You are not at the office. Please go to the office location to check in.')
            : 'Check in successful.';
    final result = AttendanceVerificationResult(
      allowed: allowedFace && withinRadius,
      similarityScore: score,
      verificationStatus: !allowedFace ? 'Face Mismatch' : (!withinRadius ? 'Outside Radius' : 'Verified'),
      message: message,
      capturedImagePath: '',
    );
    await logAttendanceAttempt(
      employeeId: employeeId,
      employeeName: employeeName,
      date: date,
      time: time,
      verificationStatus: result.verificationStatus,
      similarityScore: score,
      message: result.message,
    );
    if (result.allowed && !(await hasAttendanceForDate(employeeId, date))) {
      final status = _attendanceStatus(
        scheduledCheckInTime: scheduledCheckInTime,
        actualCheckIn: now,
        settings: settings,
      );
      await markAttendance(
        employeeId: employeeId,
        employeeName: employeeName,
        date: date,
        time: time,
        verificationStatus: result.verificationStatus,
        similarityScore: score,
        status: status,
      );
    }
    return result;
  }

  @override
  Future<AttendanceVerificationResult> verifyCheckOut({
    required int employeeId,
    required String date,
    required String employeeName,
    required String profileImageUrl,
    required double currentLatitude,
    required double currentLongitude,
    bool faceMatched = true,
    double similarityScore = 1.0,
  }) async {
    final now = DateTime.now();
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final score = similarityScore;
    final allowedFace = faceMatched && score >= 0.92;
    final settings = await getAttendanceSettings();
    final loc = await _resolveEffectiveLocation(employeeId: employeeId, globalSettings: settings);
    final isSite = loc['isSite'] as bool;
    final withinRadius = _isWithinAllowedRadius(
      targetLatitude: loc['targetLat'] as double,
      targetLongitude: loc['targetLng'] as double,
      allowedRadiusMeters: loc['targetRadius'] as int,
      requireGps: loc['requireGps'] as bool,
      currentLatitude: currentLatitude,
      currentLongitude: currentLongitude,
    );
    final message = !allowedFace
        ? 'Face not recognized. Attendance not marked.'
        : !withinRadius
            ? (isSite
                ? 'You are not at your site location. Please go to your site location to check out.'
                : 'You are not at the office. Please go to the office location to check out.')
            : 'Check out successful.';
    final result = AttendanceVerificationResult(
      allowed: allowedFace && withinRadius,
      similarityScore: score,
      verificationStatus: !allowedFace ? 'Face Mismatch' : (!withinRadius ? 'Outside Radius' : 'Verified'),
      message: message,
      capturedImagePath: '',
    );
    await logAttendanceAttempt(
      employeeId: employeeId,
      employeeName: employeeName,
      date: date,
      time: time,
      verificationStatus: 'CheckOut ${result.verificationStatus}',
      similarityScore: score,
      message: result.message,
    );
    if (result.allowed) {
      await checkOut(
        employeeId: employeeId,
        date: date,
        checkOutTime: time,
        verificationStatus: result.verificationStatus,
        similarityScore: score,
      );
    }
    return result;
  }

  @override
  Future<void> markAttendance({
    required int employeeId,
    required String employeeName,
    required String date,
    required String time,
    required String verificationStatus,
    required double similarityScore,
    required String status,
  }) async {
    final db = await database;
    final record = AttendanceRecord(
      id: 0,
      employeeId: employeeId,
      employeeName: employeeName,
      date: date,
      time: time,
      status: status,
      verificationStatus: verificationStatus,
      similarityScore: similarityScore,
      checkInTime: time,
      checkInVerificationStatus: verificationStatus,
      checkInSimilarityScore: similarityScore,
      markedAt: DateTime.now().toIso8601String(),
    );
    await db.insert(
      'attendance_records',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> checkOut({
    required int employeeId,
    required String date,
    required String checkOutTime,
    required String verificationStatus,
    required double similarityScore,
  }) async {
    final db = await database;
    final existing = await getAttendanceRecordForDate(employeeId, date);
    if (existing == null) return;

    final inTime = existing.effectiveCheckInTime;
    final hours = _calculateTotalHours(inTime, checkOutTime);
    final updatedRecord = existing.copyWith(
      checkOutTime: checkOutTime,
      checkOutVerificationStatus: verificationStatus,
      checkOutSimilarityScore: similarityScore,
      totalHours: hours,
      status: existing.status == 'Present' || existing.status == 'Late' ? 'Checked Out' : existing.status,
    );

    await db.update(
      'attendance_records',
      updatedRecord.toMap(),
      where: 'employee_id = ? AND date = ?',
      whereArgs: [employeeId, date],
    );
  }

  @override
  Future<void> adminSaveAttendance(AttendanceRecord record) async {
    final db = await database;
    final inTime = record.effectiveCheckInTime;
    final outTime = record.checkOutTime;
    double hours = record.totalHours;
    if (inTime.isNotEmpty && outTime.isNotEmpty) {
      hours = _calculateTotalHours(inTime, outTime);
    }
    final toSave = record.copyWith(
      time: inTime,
      checkInTime: inTime,
      totalHours: hours,
      markedAt: record.markedAt.isNotEmpty ? record.markedAt : DateTime.now().toIso8601String(),
    );

    await db.insert(
      'attendance_records',
      toSave.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> unmarkAttendance({
    required int employeeId,
    required String date,
  }) async {
    final db = await database;
    await db.delete(
      'attendance_records',
      where: 'employee_id = ? AND date = ?',
      whereArgs: [employeeId, date],
    );
  }

  @override
  Future<void> logAttendanceAttempt({
    required int employeeId,
    required String employeeName,
    required String date,
    required String time,
    required String verificationStatus,
    required double similarityScore,
    required String message,
  }) async {
    final db = await database;
    await db.insert('attendance_attempts', {
      'employee_id': employeeId,
      'employee_name': employeeName,
      'date': date,
      'time': time,
      'verification_status': verificationStatus,
      'similarity_score': similarityScore,
      'message': message,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getAttendanceAttempts() async {
    final db = await database;
    return await db.query('attendance_attempts', orderBy: 'created_at DESC', limit: 100);
  }
}
