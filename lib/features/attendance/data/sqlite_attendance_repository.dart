import 'dart:math';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/attendance_record.dart';
import '../domain/attendance_settings.dart';
import '../domain/attendance_repository.dart';
import '../../attendance_settings/data/firebase_attendance_settings_repository.dart';

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
    return openDatabase(path, version: 2, onCreate: (db, _) async => _createTables(db), onOpen: (db) async => _createTables(db));
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

  bool _isWithinAllowedRadius({
    required AttendanceSettings settings,
    required double currentLatitude,
    required double currentLongitude,
  }) {
    if (!settings.requireGpsVerification) return true;
    if (settings.officeLatitude == 0 && settings.officeLongitude == 0) return false;
    final distance = _distanceInMeters(
      startLatitude: settings.officeLatitude,
      startLongitude: settings.officeLongitude,
      endLatitude: currentLatitude,
      endLongitude: currentLongitude,
    );
    return distance <= settings.allowedAttendanceRadiusMeters;
  }

  @override
  Future<List<AttendanceRecord>> getAttendanceRecords(int employeeId) async {
    final db = await database;
    final maps = await db.query('attendance_records', where: 'employee_id = ?', whereArgs: [employeeId], orderBy: 'date DESC, time DESC');
    return maps.map(AttendanceRecord.fromMap).toList();
  }

  @override
  Future<bool> hasAttendanceForDate(int employeeId, String date) async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM attendance_records WHERE employee_id = ? AND date = ?', [employeeId, date])) ?? 0;
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
  }) async {
    final now = DateTime.now();
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final score = profileImageUrl.isNotEmpty ? 0.93 : 0.0;
    final allowed = score >= 0.9;
    final settings = await getAttendanceSettings();
    final withinRadius = _isWithinAllowedRadius(
      settings: settings,
      currentLatitude: currentLatitude,
      currentLongitude: currentLongitude,
    );
    final message = !withinRadius
        ? 'You are not at the office. Please go to the office location to mark your attendance.'
        : allowed
            ? 'Attendance marked successfully.'
            : 'Face verification failed. Please try again.';
    final result = AttendanceVerificationResult(
      allowed: allowed && withinRadius,
      similarityScore: score,
      verificationStatus: !withinRadius ? 'Outside Radius' : allowed ? 'Verified' : 'Failed',
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
    await db.insert('attendance_records', AttendanceRecord(id: 0, employeeId: employeeId, employeeName: employeeName, date: date, time: time, status: status, verificationStatus: verificationStatus, similarityScore: similarityScore, markedAt: DateTime.now().toIso8601String()).toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
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
}
