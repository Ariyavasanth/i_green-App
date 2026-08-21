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
        office_latitude REAL NOT NULL,
        office_longitude REAL NOT NULL,
        allowed_attendance_radius_meters INTEGER NOT NULL,
        require_gps_verification INTEGER NOT NULL
      )
    ''');
    final columns = await db.rawQuery('PRAGMA table_info(attendance_settings)');
    final columnNames = columns.map((row) => row['name'] as String? ?? '').toSet();
    if (!columnNames.contains('office_latitude')) {
      await db.execute('ALTER TABLE attendance_settings ADD COLUMN office_latitude REAL NOT NULL DEFAULT 0');
    }
    if (!columnNames.contains('office_longitude')) {
      await db.execute('ALTER TABLE attendance_settings ADD COLUMN office_longitude REAL NOT NULL DEFAULT 0');
    }
    if (!columnNames.contains('allowed_attendance_radius_meters')) {
      await db.execute('ALTER TABLE attendance_settings ADD COLUMN allowed_attendance_radius_meters INTEGER NOT NULL DEFAULT 15');
    }
    if (!columnNames.contains('require_gps_verification')) {
      await db.execute('ALTER TABLE attendance_settings ADD COLUMN require_gps_verification INTEGER NOT NULL DEFAULT 1');
    }
    await db.insert(
      'attendance_settings',
      {
        'id': 1,
        'grace_period_minutes': AttendanceSettings.defaults().gracePeriodMinutes,
        'late_limit_minutes': AttendanceSettings.defaults().lateLimitMinutes,
        'office_latitude': AttendanceSettings.defaults().officeLatitude,
        'office_longitude': AttendanceSettings.defaults().officeLongitude,
        'allowed_attendance_radius_meters': AttendanceSettings.defaults().allowedAttendanceRadiusMeters,
        'require_gps_verification': AttendanceSettings.defaults().requireGpsVerification ? 1 : 0,
      },
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
      {
        'id': 1,
        'grace_period_minutes': settings.gracePeriodMinutes,
        'late_limit_minutes': settings.lateLimitMinutes,
        'office_latitude': settings.officeLatitude,
        'office_longitude': settings.officeLongitude,
        'allowed_attendance_radius_meters': settings.allowedAttendanceRadiusMeters,
        'require_gps_verification': settings.requireGpsVerification ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
