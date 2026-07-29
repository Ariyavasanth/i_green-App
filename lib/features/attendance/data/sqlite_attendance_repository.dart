import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../leave/domain/leave_request.dart';
import '../../leave/domain/leave_repository.dart';
import '../../leave/providers/leave_providers.dart';
import '../domain/attendance_record.dart';
import '../domain/attendance_repository.dart';

class SqliteAttendanceRepository implements AttendanceRepository {
  static Database? _database;

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
      version: 1,
      onCreate: (db, version) async => _createTables(db),
      onOpen: (db) async => _createTables(db),
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attendance_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER,
        date TEXT,
        status TEXT,
        marked_at TEXT
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_attendance_employee_date
      ON attendance_records(employee_id, date)
    ''');

    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM attendance_records'),
    );
    if (count == 0) {
      await db.insert('attendance_records', {
        'employee_id': 2,
        'date': '28-07-2026',
        'status': 'Present',
        'marked_at': DateTime.now().toIso8601String(),
      });
    }
  }

  @override
  Future<List<AttendanceRecord>> getAttendanceRecords(int employeeId) async {
    final db = await database;
    final maps = await db.query(
      'attendance_records',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      orderBy: 'date DESC',
    );
    return maps.map((map) => AttendanceRecord.fromMap(map)).toList();
  }

  @override
  Future<void> markAttendance(int employeeId, String date) async {
    final db = await database;
    await db.insert(
      'attendance_records',
      AttendanceRecord(
        id: 0,
        employeeId: employeeId,
        date: date,
        status: 'Present',
        markedAt: DateTime.now().toIso8601String(),
      ).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
