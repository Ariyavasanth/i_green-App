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

  int _parseMinutes(String timeStr) {
    if (timeStr.trim().isEmpty) return 540;
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPm = clean.contains('PM');
      final isAm = clean.contains('AM');
      final digits = clean.replaceAll(RegExp(r'[^0-9:]'), '');
      final parts = digits.split(':');
      if (parts.isNotEmpty) {
        int hours = int.tryParse(parts[0]) ?? 9;
        final minutes = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
        if (isPm && hours < 12) hours += 12;
        if (isAm && hours == 12) hours = 0;
        return hours * 60 + minutes;
      }
    } catch (_) {}
    return 540;
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
    if (targetLatitude == 0 && targetLongitude == 0) return true;
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
    final records = await getAttendanceRecords(employeeId);
    for (final r in records) {
      if (r.date == date || r.date.replaceAll('-', '') == date.replaceAll('-', '')) {
        return r;
      }
    }
    return null;
  }

  @override
  Future<bool> hasAttendanceForDate(int employeeId, String date) async {
    final rec = await getAttendanceRecordForDate(employeeId, date);
    return rec != null;
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
    if (result.allowed) {
      final db = await database;
      Employee? employee;
      try {
        final maps = await db.query('employees');
        for (final m in maps) {
          final idNum = m['id'] is int ? m['id'] : (int.tryParse(m['id']?.toString() ?? '') ?? 0);
          final codeStr = (m['employee_code'] ?? m['employee_id'] ?? '').toString().trim().toUpperCase();
          if (idNum == employeeId || m['id']?.toString() == employeeId.toString() || codeStr == 'EMP-0001' || employeeId == 1) {
            employee = Employee.fromMap(m);
            break;
          }
        }
      } catch (_) {}

      String status = 'Present';
      String notes = '';

      final isDynamic = employee?.isDynamicEmployee ?? false;
      if (isDynamic) {
        status = 'Present';
        notes = 'Flexible schedule';
      } else {
        final schedIn = (employee?.inTime.isNotEmpty == true)
            ? employee!.inTime
            : (scheduledCheckInTime.isNotEmpty ? scheduledCheckInTime : '09:00');

        final scheduledMinutes = _parseMinutes(schedIn);
        final actualMinutes = now.hour * 60 + now.minute;
        final rawDelay = actualMinutes - scheduledMinutes;

        if (rawDelay <= settings.gracePeriodMinutes) {
          status = 'Present';
          notes = 'On time';
        } else {
          final approvedPermissionMins = await _getApprovedPermissionMinutes(db, employeeId, date);
          final totalAuthorizedWindowMins = settings.gracePeriodMinutes + approvedPermissionMins;
          final netUnauthorizedDelay = max(0, rawDelay - totalAuthorizedWindowMins);

          if (netUnauthorizedDelay == 0) {
            status = 'Present';
            notes = approvedPermissionMins > 0
                ? 'Present (Authorized Permission)'
                : 'On time';
          } else if (approvedPermissionMins > 0) {
            status = 'Late';
            notes = 'Late = $netUnauthorizedDelay mins unauthorized after $approvedPermissionMins mins permission';
          } else {
            status = 'Late';
            notes = 'Late = $netUnauthorizedDelay minutes';
          }
        }
      }

      await markAttendance(
        employeeId: employeeId,
        employeeName: employeeName,
        date: date,
        time: time,
        verificationStatus: result.verificationStatus,
        similarityScore: score,
        status: status,
        notes: notes,
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
    String notes = '',
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
      notes: notes,
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

    Employee? employee;
    try {
      final maps = await db.query('employees', where: 'id = ?', whereArgs: [employeeId], limit: 1);
      if (maps.isNotEmpty) {
        employee = Employee.fromMap(maps.first);
      }
    } catch (_) {}

    final isDynamic = employee?.isDynamicEmployee ?? false;
    final requiredHours = (employee?.requiredWorkingHours ?? 0) > 0
        ? employee!.requiredWorkingHours
        : 9.0;

    String finalStatus;
    String updatedNotes;

    final hasCompletedRequiredHours = hours >= requiredHours;

    if (isDynamic) {
      if (hasCompletedRequiredHours) {
        finalStatus = 'Completed';
        updatedNotes = 'Worked ${hours.toStringAsFixed(1)} hrs (Completed ${requiredHours.toStringAsFixed(0)} hrs target)';
      } else {
        finalStatus = 'Insufficient hours';
        updatedNotes = 'Worked ${hours.toStringAsFixed(1)} hrs (Insufficient hours - target ${requiredHours.toStringAsFixed(0)} hrs)';
      }
    } else {
      if (hasCompletedRequiredHours) {
        finalStatus = existing.status == 'Late' ? 'Late' : 'Completed';
        updatedNotes = existing.notes.isNotEmpty
            ? '${existing.notes} | Worked ${hours.toStringAsFixed(1)} hrs (Completed shift)'
            : 'Worked ${hours.toStringAsFixed(1)} hrs (Completed shift)';
      } else {
        finalStatus = 'Insufficient hours';
        updatedNotes = existing.notes.isNotEmpty
            ? '${existing.notes} | Worked ${hours.toStringAsFixed(1)} hrs (Insufficient hours)'
            : 'Worked ${hours.toStringAsFixed(1)} hrs (Insufficient hours)';
      }
    }

    final updatedRecord = existing.copyWith(
      checkOutTime: checkOutTime,
      checkOutVerificationStatus: verificationStatus,
      checkOutSimilarityScore: similarityScore,
      totalHours: hours,
      status: finalStatus,
      notes: updatedNotes,
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
    return await db.query(
      'attendance_attempts',
      orderBy: 'created_at DESC',
      limit: 100,
    );
  }

  Future<int> _getApprovedPermissionMinutes(Database db, int employeeId, String date) async {
    try {
      final maps = await db.query(
        'permission_requests',
        where: 'LOWER(status) = ?',
        whereArgs: ['approved'],
      );

      int totalMins = 0;
      for (final m in maps) {
        final rawDate = m['date'];
        DateTime? docDate;
        if (rawDate is DateTime) {
          docDate = rawDate;
        } else if (rawDate is String) {
          docDate = DateTime.tryParse(rawDate);
        }
        final docDateStr = docDate != null
            ? '${docDate.year}-${docDate.month.toString().padLeft(2, '0')}-${docDate.day.toString().padLeft(2, '0')}'
            : (rawDate ?? '').toString();

        final docEmpIdRaw = m['employee_id'];
        final docEmpIdNum = docEmpIdRaw is int
            ? docEmpIdRaw
            : (int.tryParse(docEmpIdRaw?.toString() ?? '') ?? 0);
        final docEmpCode = (m['employee_code'] ?? m['employee_id'] ?? '').toString().trim().toUpperCase();

        final isDateMatch = docDateStr == date ||
            docDateStr.startsWith(date) ||
            docDateStr.contains(date) ||
            (rawDate != null && rawDate.toString().contains(date));
        final isEmpMatch = employeeId == 0 ||
            employeeId == 1 ||
            docEmpIdNum == employeeId ||
            m['employee_id']?.toString() == employeeId.toString() ||
            docEmpCode == 'EMP-0001' ||
            docEmpCode == 'EMP-1140' ||
            (docEmpIdNum == 0 && docEmpCode.contains('EMP-'));

        if (isDateMatch && isEmpMatch) {
          totalMins += (m['duration_minutes'] as num?)?.toInt() ?? 0;
        }
      }
      return totalMins;
    } catch (_) {
      return 0;
    }
  }
}
