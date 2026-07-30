import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../attendance/domain/attendance_settings.dart';
import '../domain/attendance_settings_repository.dart';

class SqliteAttendanceSettingsRepository implements AttendanceSettingsRepository {
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
    return openDatabase(path, version: 3, onCreate: (db, _) async => _createTables(db), onOpen: (db) async => _createTables(db));
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attendance_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        grace_period_minutes INTEGER NOT NULL,
        late_limit_minutes INTEGER NOT NULL,
        absent_threshold_minutes INTEGER NOT NULL
      )
    ''');
    await db.insert(
      'attendance_settings',
      {'id': 1, ...AttendanceSettings.defaults().toMap()},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  @override
  Future<AttendanceSettings> getAttendanceSettings() async {
    final db = await database;
    final rows = await db.query('attendance_settings', where: 'id = 1', limit: 1);
    if (rows.isEmpty) return AttendanceSettings.defaults();
    return AttendanceSettings.fromMap(rows.first);
  }

  @override
  Future<void> saveAttendanceSettings(AttendanceSettings settings) async {
    final db = await database;
    await db.insert(
      'attendance_settings',
      {'id': 1, ...settings.toMap()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
