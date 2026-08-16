import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/on_duty_assignment.dart';
import '../domain/on_duty_repository.dart';

class SqliteOnDutyRepository implements OnDutyRepository {
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
      onCreate: (db, _) async => _createTables(db),
      onOpen: (db) async => _createTables(db),
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS on_duty_assignments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL,
        employee_name TEXT NOT NULL,
        attendance_id INTEGER,
        from_location TEXT NOT NULL,
        from_latitude REAL,
        from_longitude REAL,
        destination TEXT NOT NULL,
        destination_latitude REAL,
        destination_longitude REAL,
        task TEXT NOT NULL,
        instructions TEXT NOT NULL DEFAULT '',
        assigned_by TEXT NOT NULL DEFAULT 'Supervisor',
        assigned_time TEXT NOT NULL,
        started_time TEXT,
        completed_time TEXT,
        duration_minutes INTEGER NOT NULL DEFAULT 0,
        allow_checkout_from_destination INTEGER NOT NULL DEFAULT 0,
        photo_proof_path TEXT,
        status TEXT NOT NULL DEFAULT 'assigned',
        date TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    try {
      await db.execute('ALTER TABLE on_duty_assignments ADD COLUMN photo_proof_path TEXT');
    } catch (_) {}
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_on_duty_emp_date
      ON on_duty_assignments(employee_id, date)
    ''');
  }

  @override
  Future<List<OnDutyAssignment>> getAssignmentsForEmployee({
    required int employeeId,
    String? date,
  }) async {
    final db = await database;
    final whereClause = date == null || date.isEmpty
        ? 'employee_id = ?'
        : 'employee_id = ? AND date = ?';
    final whereArgs = date == null || date.isEmpty
        ? [employeeId]
        : [employeeId, date];

    final rows = await db.query(
      'on_duty_assignments',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
    return rows.map(OnDutyAssignment.fromMap).toList();
  }

  @override
  Future<List<OnDutyAssignment>> getAllAssignments({
    String? date,
    String? statusFilter,
    int? employeeId,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (date != null && date.isNotEmpty) {
      conditions.add('date = ?');
      args.add(date);
    }
    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'All') {
      conditions.add('status = ?');
      args.add(statusFilter.toLowerCase());
    }
    if (employeeId != null && employeeId != 0) {
      conditions.add('employee_id = ?');
      args.add(employeeId);
    }

    final whereStr = conditions.isEmpty ? null : conditions.join(' AND ');
    final rows = await db.query(
      'on_duty_assignments',
      where: whereStr,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
    );
    return rows.map(OnDutyAssignment.fromMap).toList();
  }

  @override
  Future<OnDutyAssignment?> getActiveAssignmentForEmployee(int employeeId) async {
    final db = await database;
    final rows = await db.query(
      'on_duty_assignments',
      where: 'employee_id = ? AND (status = ? OR status = ?)',
      whereArgs: [employeeId, 'active', 'assigned'],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return OnDutyAssignment.fromMap(rows.first);
  }

  @override
  Future<OnDutyAssignment?> getAssignmentById(int id) async {
    final db = await database;
    final rows = await db.query(
      'on_duty_assignments',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return OnDutyAssignment.fromMap(rows.first);
  }

  @override
  Future<int> createAssignment(OnDutyAssignment assignment) async {
    final db = await database;
    return await db.insert(
      'on_duty_assignments',
      assignment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateAssignment(OnDutyAssignment assignment) async {
    final db = await database;
    await db.update(
      'on_duty_assignments',
      assignment.toMap(),
      where: 'id = ?',
      whereArgs: [assignment.id],
    );
  }

  @override
  Future<void> updateAssignmentStatus({
    required int id,
    required String status,
    String? startedTime,
    String? completedTime,
    int? durationMinutes,
  }) async {
    final db = await database;
    final updates = <String, dynamic>{
      'status': status,
    };
    if (startedTime != null) updates['started_time'] = startedTime;
    if (completedTime != null) updates['completed_time'] = completedTime;
    if (durationMinutes != null) updates['duration_minutes'] = durationMinutes;

    await db.update(
      'on_duty_assignments',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> deleteAssignment(int id) async {
    final db = await database;
    await db.delete(
      'on_duty_assignments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
