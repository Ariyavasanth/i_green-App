import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import '../domain/clock_entry.dart';
import '../domain/clocking_repository.dart';

class SqliteClockingRepository implements ClockingRepository {
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
      CREATE TABLE IF NOT EXISTS time_clockings (
        id TEXT PRIMARY KEY,
        employee_id TEXT,
        entry_type TEXT,
        start_time TEXT,
        end_time TEXT,
        notes TEXT
      )
    ''');
    await _seedDataIfEmpty(db);
  }

  static Future<void> _seedDataIfEmpty(Database db) async {
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM time_clockings'));
    if (count == 0) {
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      
      final seeds = [
        {
          'id': 'CLK-101',
          'employee_id': 'EMP-001',
          'entry_type': 'General Work',
          'start_time': '${todayStr}T09:00:00',
          'end_time': '${todayStr}T10:00:00',
          'notes': 'Morning tasks & email triage',
        },
        {
          'id': 'CLK-102',
          'employee_id': 'EMP-001',
          'entry_type': 'Meeting',
          'start_time': '${todayStr}T10:00:00',
          'end_time': '${todayStr}T11:00:00',
          'notes': 'Sprint planning & status update',
        },
        {
          'id': 'CLK-103',
          'employee_id': 'EMP-001',
          'entry_type': 'Lunch Break',
          'start_time': '${todayStr}T12:00:00',
          'end_time': '${todayStr}T13:00:00',
          'notes': 'Cafeteria lunch',
        },
        {
          'id': 'CLK-104',
          'employee_id': 'EMP-001',
          'entry_type': 'Client Website Task',
          'start_time': '${todayStr}T13:15:00',
          'end_time': null,
          'notes': 'Frontend layout optimization',
        },
        {
          'id': 'CLK-105',
          'employee_id': 'EMP-002',
          'entry_type': 'General Work',
          'start_time': '${todayStr}T09:30:00',
          'end_time': '${todayStr}T10:30:00',
          'notes': 'Documentation update',
        },
        {
          'id': 'CLK-106',
          'employee_id': 'EMP-002',
          'entry_type': 'Tea Break',
          'start_time': '${todayStr}T11:00:00',
          'end_time': '${todayStr}T11:15:00',
          'notes': 'Morning tea',
        },
        {
          'id': 'CLK-107',
          'employee_id': 'EMP-002',
          'entry_type': 'Meeting',
          'start_time': '${todayStr}T11:30:00',
          'end_time': null,
          'notes': 'Client review call',
        },
        {
          'id': 'CLK-108',
          'employee_id': 'EMP-003',
          'entry_type': 'Lunch Break',
          'start_time': '${todayStr}T12:30:00',
          'end_time': null,
          'notes': 'Lunch hour',
        },
      ];

      for (final s in seeds) {
        await db.insert('time_clockings', s, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
  }

  @override
  Future<List<ClockEntry>> getClockEntries({
    String? employeeId,
    DateTime? date,
  }) async {
    final db = await database;
    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (employeeId != null && employeeId.isNotEmpty) {
      if (employeeId == 'EMP-001' || employeeId == 'EMP-0001') {
        whereClause += " AND (employee_id = 'EMP-001' OR employee_id = 'EMP-0001')";
      } else {
        whereClause += ' AND employee_id = ?';
        whereArgs.add(employeeId);
      }
    }

    final maps = await db.query(
      'time_clockings',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'start_time DESC',
    );

    final entries = maps.map(ClockEntry.fromMap).toList();

    if (date != null) {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      return entries.where((e) => DateFormat('yyyy-MM-dd').format(e.startTime) == dateStr).toList();
    }

    return entries;
  }

  @override
  Future<ClockEntry?> getActiveEntry(String employeeId) async {
    final db = await database;
    final maps = await db.query(
      'time_clockings',
      where: 'employee_id = ? AND end_time IS NULL',
      whereArgs: [employeeId],
      orderBy: 'start_time DESC',
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return ClockEntry.fromMap(maps.first);
  }

  @override
  Future<List<ClockEntry>> getAllActiveEntries() async {
    final db = await database;
    final maps = await db.query(
      'time_clockings',
      where: 'end_time IS NULL',
      orderBy: 'start_time DESC',
    );
    return maps.map(ClockEntry.fromMap).toList();
  }

  @override
  Future<void> startClockEntry(ClockEntry entry) async {
    final db = await database;
    // First auto clock out any active entry for this employee
    await clockOutActiveEntry(entry.employeeId, time: entry.startTime);

    await db.insert(
      'time_clockings',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> clockOutActiveEntry(String employeeId, {DateTime? time}) async {
    final db = await database;
    final clockOutTime = (time ?? DateTime.now()).toIso8601String();
    await db.update(
      'time_clockings',
      {'end_time': clockOutTime},
      where: 'employee_id = ? AND end_time IS NULL',
      whereArgs: [employeeId],
    );
  }

  @override
  Future<void> adminClockOutEntry(String id, DateTime endTime) async {
    final db = await database;
    final clockOutTime = endTime.toIso8601String();
    await db.update(
      'time_clockings',
      {'end_time': clockOutTime},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<double> getTotalWorkHours(String employeeId, DateTime date) async {
    final entries = await getClockEntries(employeeId: employeeId, date: date);
    double workHours = 0.0;
    for (final e in entries) {
      if (!e.isBreak) {
        workHours += e.durationInHours;
      }
    }
    return workHours;
  }

  @override
  Future<double> getTotalBreakHours(String employeeId, DateTime date) async {
    final entries = await getClockEntries(employeeId: employeeId, date: date);
    double breakHours = 0.0;
    for (final e in entries) {
      if (e.isBreak) {
        breakHours += e.durationInHours;
      }
    }
    return breakHours;
  }
}
