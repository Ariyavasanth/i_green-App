import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/leave_request.dart';
import '../domain/leave_repository.dart';

class SqliteLeaveRepository implements LeaveRepository {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app_database.db');

    final db = await openDatabase(
      path,
      version: 1,
      onOpen: (db) async {
        await _createTables(db);
      },
    );

    return db;
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS leave_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER,
        date TEXT,
        reason TEXT,
        status TEXT,
        created_at TEXT
      )
    ''');
  }

  @override
  Future<List<LeaveRequest>> getLeaveRequests(int employeeId) async {
    final db = await database;
    final maps = await db.query(
      'leave_requests',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      orderBy: 'id DESC',
    );
    return maps.map((map) => LeaveRequest.fromMap(map)).toList();
  }

  @override
  Future<void> submitLeaveRequest(LeaveRequest request) async {
    final db = await database;
    await db.insert('leave_requests', request.toMap());
  }

  @override
  Future<void> updateLeaveRequestStatus(int id, String status) async {
    final db = await database;
    await db.update(
      'leave_requests',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
