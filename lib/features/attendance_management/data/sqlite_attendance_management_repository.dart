import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../attendance/domain/attendance_record.dart';
import '../domain/attendance_management_repository.dart';
import '../domain/attendance_management_stats.dart';

class SqliteAttendanceManagementRepository implements AttendanceManagementRepository {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
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
    await _seedSampleAttendanceData(db);
  }

  Future<void> _seedSampleAttendanceData(Database db) async {
    final countRes = await db.rawQuery('SELECT COUNT(*) FROM attendance_records');
    final count = Sqflite.firstIntValue(countRes) ?? 0;
    if (count == 0) {
      final now = DateTime.now();
      final todayStr = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
      final sampleRecords = [
        AttendanceRecord(
          id: 1,
          employeeId: 1,
          employeeName: 'Ariyavasanth S',
          date: todayStr,
          time: '09:00:00',
          status: 'Present',
          verificationStatus: 'Verified',
          similarityScore: 0.98,
          checkInTime: '09:00',
          checkOutTime: '17:30',
          totalHours: 8.5,
          markedAt: now.toIso8601String(),
        ),
        AttendanceRecord(
          id: 2,
          employeeId: 2,
          employeeName: 'Saravanan G S',
          date: todayStr,
          time: '09:25:00',
          status: 'Late',
          verificationStatus: 'Verified',
          similarityScore: 0.95,
          checkInTime: '09:25',
          checkOutTime: '18:00',
          totalHours: 8.58,
          markedAt: now.toIso8601String(),
        ),
      ];

      for (final r in sampleRecords) {
        await db.insert('attendance_records', r.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
  }

  @override
  Future<List<AttendanceRecord>> getAllAttendanceRecords({
    int? employeeId,
    String? monthYear,
    String? statusFilter,
  }) async {
    final db = await database;
    String? whereClause;
    List<dynamic>? whereArgs;

    if (employeeId != null) {
      whereClause = 'employee_id = ?';
      whereArgs = [employeeId];
    }

    final maps = await db.query(
      'attendance_records',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'date DESC',
    );
    var list = maps.map(AttendanceRecord.fromMap).toList();

    if (monthYear != null && monthYear.isNotEmpty) {
      list = list.where((r) {
        if (r.date.length >= 10) {
          final parts = r.date.split('-');
          if (parts.length == 3) {
            final recordMonthYear = '${parts[1]}-${parts[2]}';
            return recordMonthYear == monthYear;
          }
        }
        return true;
      }).toList();
    }

    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'All') {
      list = list.where((r) => r.status == statusFilter).toList();
    }

    return list;
  }

  @override
  Future<AttendanceManagementStats> getAttendanceStats({String? date}) async {
    final targetDate = date ??
        '${DateTime.now().day.toString().padLeft(2, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().year}';
    final db = await database;

    int totalEmployees = 0;
    try {
      final empRes = await db.rawQuery('SELECT COUNT(*) FROM employees');
      totalEmployees = Sqflite.firstIntValue(empRes) ?? 0;
    } catch (_) {}

    final maps = await db.query(
      'attendance_records',
      where: 'date = ?',
      whereArgs: [targetDate],
    );
    final todayRecords = maps.map(AttendanceRecord.fromMap).toList();

    int present = 0;
    int late = 0;
    int checkedOut = 0;
    double totalHoursSum = 0;
    int hoursCount = 0;

    for (final r in todayRecords) {
      if (r.status == 'Present') present++;
      if (r.status == 'Late') late++;
      if (r.status == 'Checked Out') checkedOut++;
      if (r.totalHours > 0) {
        totalHoursSum += r.totalHours;
        hoursCount++;
      }
    }

    final markedTotal = present + late + checkedOut;
    final absent = (totalEmployees - markedTotal).clamp(0, 9999);
    final avgHours = hoursCount > 0 ? double.parse((totalHoursSum / hoursCount).toStringAsFixed(1)) : 0.0;

    return AttendanceManagementStats(
      totalEmployees: totalEmployees > 0 ? totalEmployees : markedTotal,
      presentToday: present,
      lateToday: late,
      checkedOutToday: checkedOut,
      absentToday: absent,
      onLeaveToday: 0,
      averageWorkHours: avgHours,
    );
  }

  @override
  Future<void> saveOrOverrideAttendance(AttendanceRecord record) async {
    final db = await database;
    double totalHours = record.totalHours;
    if (record.effectiveCheckInTime.isNotEmpty && record.checkOutTime.isNotEmpty) {
      try {
        final inParts = record.effectiveCheckInTime.split(':');
        final outParts = record.checkOutTime.split(':');
        if (inParts.length >= 2 && outParts.length >= 2) {
          final inMin = int.parse(inParts[0]) * 60 + int.parse(inParts[1]);
          final outMin = int.parse(outParts[0]) * 60 + int.parse(outParts[1]);
          if (outMin > inMin) {
            totalHours = double.parse(((outMin - inMin) / 60.0).toStringAsFixed(2));
          }
        }
      } catch (_) {}
    }

    final toSave = record.copyWith(
      time: record.effectiveCheckInTime,
      checkInTime: record.effectiveCheckInTime,
      totalHours: totalHours,
      markedAt: record.markedAt.isNotEmpty ? record.markedAt : DateTime.now().toIso8601String(),
    );

    await db.insert(
      'attendance_records',
      toSave.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteAttendanceRecord(int employeeId, String date) async {
    final db = await database;
    await db.delete('attendance_records', where: 'employee_id = ? AND date = ?', whereArgs: [employeeId, date]);
  }

  @override
  Future<List<Map<String, dynamic>>> getAuditAttempts({int? employeeId, int limit = 100}) async {
    final db = await database;
    if (employeeId != null) {
      return await db.query(
        'attendance_attempts',
        where: 'employee_id = ?',
        whereArgs: [employeeId],
        orderBy: 'created_at DESC',
        limit: limit,
      );
    }
    return await db.query('attendance_attempts', limit: limit, orderBy: 'created_at DESC');
  }

  @override
  Future<void> bulkMarkAttendance({
    required List<int> employeeIds,
    required String date,
    required String status,
    required String checkInTime,
  }) async {
    final db = await database;
    final batch = db.batch();
    for (final empId in employeeIds) {
      batch.insert(
        'attendance_records',
        {
          'employee_id': empId,
          'date': date,
          'time': checkInTime,
          'check_in_time': checkInTime,
          'status': status,
          'verification_status': 'Admin Bulk Mark',
          'similarity_score': 1.0,
          'marked_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }
}
