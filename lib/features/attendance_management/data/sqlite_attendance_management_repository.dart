import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../attendance/domain/attendance_record.dart';
import '../domain/attendance_management_repository.dart';
import '../domain/attendance_management_stats.dart';

class SqliteAttendanceManagementRepository implements AttendanceManagementRepository {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app_database.db');
    _database = await openDatabase(path);
    return _database!;
  }

  @override
  Future<List<AttendanceRecord>> getAllAttendanceRecords({
    int? employeeId,
    String? monthYear,
    String? statusFilter,
  }) async {
    final db = await database;
    final maps = await db.query('attendance_records', orderBy: 'date DESC');
    return maps.map(AttendanceRecord.fromMap).toList();
  }

  @override
  Future<AttendanceManagementStats> getAttendanceStats({String? date}) async {
    return AttendanceManagementStats.empty();
  }

  @override
  Future<void> saveOrOverrideAttendance(AttendanceRecord record) async {
    final db = await database;
    await db.insert('attendance_records', record.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteAttendanceRecord(int employeeId, String date) async {
    final db = await database;
    await db.delete('attendance_records', where: 'employee_id = ? AND date = ?', whereArgs: [employeeId, date]);
  }

  @override
  Future<List<Map<String, dynamic>>> getAuditAttempts({int? employeeId, int limit = 100}) async {
    final db = await database;
    return await db.query('attendance_attempts', limit: limit, orderBy: 'created_at DESC');
  }

  @override
  Future<void> bulkMarkAttendance({
    required List<int> employeeIds,
    required String date,
    required String status,
    required String checkInTime,
  }) async {}
}
