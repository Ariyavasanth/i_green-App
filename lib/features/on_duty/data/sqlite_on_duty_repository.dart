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
    final tableInfo = await db.rawQuery('PRAGMA table_info(on_duty_assignments)');
    if (tableInfo.isNotEmpty) {
      final existingColumns = tableInfo.map((row) => row['name']?.toString() ?? '').toSet();
      if (existingColumns.contains('from_location') || !existingColumns.contains('destination')) {
        await _migrateTable(db, tableInfo);
        return;
      }
    }

    await db.execute('''
      CREATE TABLE IF NOT EXISTS on_duty_assignments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL,
        employee_name TEXT NOT NULL,
        od_type TEXT NOT NULL DEFAULT 'Customer Visit',
        purpose TEXT NOT NULL DEFAULT '',
        destination TEXT NOT NULL,
        date TEXT NOT NULL,
        planned_start_time TEXT NOT NULL,
        planned_end_time TEXT,
        actual_start_time TEXT,
        actual_end_time TEXT,
        start_latitude REAL,
        start_longitude REAL,
        end_latitude REAL,
        end_longitude REAL,
        start_photo TEXT,
        end_photo TEXT,
        status TEXT NOT NULL DEFAULT 'ASSIGNED',
        notes TEXT NOT NULL DEFAULT '',
        assigned_by TEXT NOT NULL DEFAULT 'Admin',
        duration_minutes INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // Safe migration for missing columns if table already existed in older version
    final columnsToEnsure = [
      'od_type TEXT NOT NULL DEFAULT "Customer Visit"',
      'purpose TEXT NOT NULL DEFAULT ""',
      'planned_start_time TEXT NOT NULL DEFAULT ""',
      'planned_end_time TEXT',
      'actual_start_time TEXT',
      'actual_end_time TEXT',
      'start_latitude REAL',
      'start_longitude REAL',
      'end_latitude REAL',
      'end_longitude REAL',
      'start_photo TEXT',
      'end_photo TEXT',
      'notes TEXT NOT NULL DEFAULT ""',
    ];

    for (final col in columnsToEnsure) {
      try {
        await db.execute('ALTER TABLE on_duty_assignments ADD COLUMN $col');
      } catch (_) {}
    }

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_on_duty_emp_date
      ON on_duty_assignments(employee_id, date)
    ''');
  }

  Future<void> _migrateTable(Database db, List<Map<String, dynamic>> tableInfo) async {
    await db.execute('DROP TABLE IF EXISTS on_duty_assignments_old');
    await db.execute('ALTER TABLE on_duty_assignments RENAME TO on_duty_assignments_old');

    await db.execute('''
      CREATE TABLE on_duty_assignments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL,
        employee_name TEXT NOT NULL,
        od_type TEXT NOT NULL DEFAULT 'Customer Visit',
        purpose TEXT NOT NULL DEFAULT '',
        destination TEXT NOT NULL,
        date TEXT NOT NULL,
        planned_start_time TEXT NOT NULL,
        planned_end_time TEXT,
        actual_start_time TEXT,
        actual_end_time TEXT,
        start_latitude REAL,
        start_longitude REAL,
        end_latitude REAL,
        end_longitude REAL,
        start_photo TEXT,
        end_photo TEXT,
        status TEXT NOT NULL DEFAULT 'ASSIGNED',
        notes TEXT NOT NULL DEFAULT '',
        assigned_by TEXT NOT NULL DEFAULT 'Admin',
        duration_minutes INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    final oldCols = tableInfo.map((row) => row['name']?.toString() ?? '').toSet();

    String selectCol(String preferred, List<String> fallbacks, String defaultVal) {
      if (oldCols.contains(preferred)) return preferred;
      for (final fb in fallbacks) {
        if (oldCols.contains(fb)) return fb;
      }
      return "'$defaultVal'";
    }

    final idCol = oldCols.contains('id') ? 'id' : 'NULL';
    final empIdCol = oldCols.contains('employee_id') ? 'employee_id' : '0';
    final empNameCol = oldCols.contains('employee_name') ? 'employee_name' : "''";
    final odTypeCol = selectCol('od_type', ['task'], 'Customer Visit');
    final purposeCol = selectCol('purpose', ['task'], '');
    final destCol = selectCol('destination', ['destination_location', 'from_location'], 'Workplace');
    final dateCol = oldCols.contains('date') ? 'date' : "''";
    final plannedStartCol = selectCol('planned_start_time', ['assigned_time'], '09:00 AM');
    final plannedEndCol = oldCols.contains('planned_end_time') ? 'planned_end_time' : 'NULL';
    final actualStartCol = selectCol('actual_start_time', ['started_time'], 'NULL');
    final actualEndCol = selectCol('actual_end_time', ['completed_time'], 'NULL');
    final startLatCol = selectCol('start_latitude', ['from_latitude'], 'NULL');
    final startLngCol = selectCol('start_longitude', ['from_longitude'], 'NULL');
    final endLatCol = selectCol('end_latitude', ['destination_latitude'], 'NULL');
    final endLngCol = selectCol('end_longitude', ['destination_longitude'], 'NULL');
    final startPhotoCol = oldCols.contains('start_photo') ? 'start_photo' : 'NULL';
    final endPhotoCol = selectCol('end_photo', ['photo_proof_path'], 'NULL');
    final statusCol = oldCols.contains('status') ? 'status' : "'ASSIGNED'";
    final notesCol = selectCol('notes', ['instructions'], '');
    final assignedByCol = oldCols.contains('assigned_by') ? 'assigned_by' : "'Admin'";
    final durationCol = oldCols.contains('duration_minutes') ? 'duration_minutes' : '0';
    final createdAtCol = oldCols.contains('created_at') ? 'created_at' : "''";

    try {
      await db.execute('''
        INSERT INTO on_duty_assignments (
          ${idCol != 'NULL' ? 'id,' : ''}
          employee_id, employee_name, od_type, purpose, destination, date,
          planned_start_time, planned_end_time, actual_start_time, actual_end_time,
          start_latitude, start_longitude, end_latitude, end_longitude,
          start_photo, end_photo, status, notes, assigned_by, duration_minutes, created_at
        )
        SELECT
          ${idCol != 'NULL' ? '$idCol,' : ''}
          $empIdCol, $empNameCol, $odTypeCol, $purposeCol, $destCol, $dateCol,
          $plannedStartCol, $plannedEndCol, $actualStartCol, $actualEndCol,
          $startLatCol, $startLngCol, $endLatCol, $endLngCol,
          $startPhotoCol, $endPhotoCol, $statusCol, $notesCol, $assignedByCol, $durationCol, $createdAtCol
        FROM on_duty_assignments_old
      ''');
    } catch (_) {}

    await db.execute('DROP TABLE IF EXISTS on_duty_assignments_old');

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
      conditions.add('(UPPER(status) = ? OR UPPER(status) = ?)');
      final filterUpper = statusFilter.toUpperCase();
      final altFilter = filterUpper == 'IN_PROGRESS' ? 'ACTIVE' : filterUpper;
      args.add(filterUpper);
      args.add(altFilter);
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
    // 1. Try exact employeeId match
    final rows = await db.query(
      'on_duty_assignments',
      where: 'employee_id = ? AND (UPPER(status) = ? OR UPPER(status) = ? OR UPPER(status) = ?)',
      whereArgs: [employeeId, 'IN_PROGRESS', 'ASSIGNED', 'ACTIVE'],
      orderBy: 'CASE UPPER(status) WHEN "IN_PROGRESS" THEN 1 WHEN "ACTIVE" THEN 1 WHEN "ASSIGNED" THEN 2 ELSE 3 END, created_at DESC',
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return OnDutyAssignment.fromMap(rows.first);
    }

    // 2. Fallback: If no exact employee_id match, check any active assignment
    final fallbackRows = await db.query(
      'on_duty_assignments',
      where: 'UPPER(status) = ? OR UPPER(status) = ? OR UPPER(status) = ?',
      whereArgs: ['IN_PROGRESS', 'ASSIGNED', 'ACTIVE'],
      orderBy: 'CASE UPPER(status) WHEN "IN_PROGRESS" THEN 1 WHEN "ACTIVE" THEN 1 WHEN "ASSIGNED" THEN 2 ELSE 3 END, created_at DESC',
      limit: 1,
    );
    if (fallbackRows.isNotEmpty) {
      return OnDutyAssignment.fromMap(fallbackRows.first);
    }

    return null;
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
    try {
      return await db.insert(
        'on_duty_assignments',
        assignment.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      final tableInfo = await db.rawQuery('PRAGMA table_info(on_duty_assignments)');
      await _migrateTable(db, tableInfo);
      return await db.insert(
        'on_duty_assignments',
        assignment.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
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
    String? actualStartTime,
    String? actualEndTime,
    double? latitude,
    double? longitude,
    String? photoPath,
    int? durationMinutes,
  }) async {
    final db = await database;
    final updates = <String, dynamic>{
      'status': status.toUpperCase(),
    };
    if (actualStartTime != null) updates['actual_start_time'] = actualStartTime;
    if (actualEndTime != null) updates['actual_end_time'] = actualEndTime;
    if (status.toUpperCase() == 'IN_PROGRESS') {
      if (latitude != null) updates['start_latitude'] = latitude;
      if (longitude != null) updates['start_longitude'] = longitude;
      if (photoPath != null) updates['start_photo'] = photoPath;
    } else if (status.toUpperCase() == 'COMPLETED') {
      if (latitude != null) updates['end_latitude'] = latitude;
      if (longitude != null) updates['end_longitude'] = longitude;
      if (photoPath != null) updates['end_photo'] = photoPath;
    }
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
