import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../domain/task_item.dart';
import '../domain/task_repository.dart';

class SqliteTaskRepository implements TaskRepository {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app_database.db');
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onOpen: (db) async {
        await _createTables(db);
      },
    );
    return _database!;
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tasks (
        id TEXT PRIMARY KEY,
        title TEXT,
        project_or_office_code TEXT,
        assigned_by TEXT,
        assigned_to TEXT,
        start_time TEXT,
        end_time TEXT,
        status TEXT
      )
    ''');

    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM tasks'));
    if (count == null || count == 0) {
      final now = DateTime.now();
      await db.insert('tasks', {
        'id': '101',
        'title': 'Client Website',
        'project_or_office_code': 'PRJ-101',
        'assigned_by': 'Manager',
        'assigned_to': 'EMP-001',
        'start_time': now.toIso8601String(),
        'end_time': null,
        'status': 'TODO',
      });
      await db.insert('tasks', {
        'id': '205',
        'title': 'Employee Report',
        'project_or_office_code': 'OFF-205',
        'assigned_by': 'Manager',
        'assigned_to': 'EMP-001',
        'start_time': now.toIso8601String(),
        'end_time': null,
        'status': 'TODO',
      });
    }
  }

  @override
  Future<List<TaskItem>> getTasks({
    String? assignedTo,
    String? projectOrOfficeCode,
    String? status,
  }) async {
    final db = await database;
    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (assignedTo != null && assignedTo.isNotEmpty) {
      whereClause += ' AND assigned_to = ?';
      whereArgs.add(assignedTo);
    }
    if (projectOrOfficeCode != null && projectOrOfficeCode.isNotEmpty && projectOrOfficeCode != 'All') {
      whereClause += ' AND project_or_office_code = ?';
      whereArgs.add(projectOrOfficeCode);
    }
    if (status != null && status.isNotEmpty && status != 'All') {
      whereClause += ' AND status = ?';
      whereArgs.add(status);
    }

    final maps = await db.query(
      'tasks',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'start_time DESC',
    );

    return maps.map(TaskItem.fromMap).toList();
  }

  @override
  Future<TaskItem?> getTaskById(String id) async {
    final db = await database;
    final maps = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return TaskItem.fromMap(maps.first);
  }

  @override
  Future<void> createTask(TaskItem task) async {
    final db = await database;
    await db.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateTask(TaskItem task) async {
    final db = await database;
    await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  @override
  Future<void> deleteTask(String id) async {
    final db = await database;
    await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<Map<String, double>> getHoursByProject({String? assignedTo}) async {
    final tasks = await getTasks(assignedTo: assignedTo);
    final Map<String, double> result = {};
    for (final task in tasks) {
      final code = task.projectOrOfficeCode;
      result[code] = (result[code] ?? 0.0) + task.durationInHours;
    }
    return result;
  }
}
