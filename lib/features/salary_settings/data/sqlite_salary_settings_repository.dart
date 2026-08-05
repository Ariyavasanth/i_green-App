import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/salary_settings.dart';
import '../domain/salary_settings_repository.dart';

class SqliteSalarySettingsRepository implements SalarySettingsRepository {
  Database? _database;

  Future<Database> get _db async => _database ??= await openDatabase(
        p.join(await getDatabasesPath(), 'igreen_assets.db'),
        version: 1,
        onCreate: (db, _) async {
          await _createTable(db);
        },
      );

  static Future<void> _createTable(Database db) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS salary_settings_structure('
      'id INTEGER PRIMARY KEY DEFAULT 1, '
      'hra_percentage REAL NOT NULL, '
      'special_allowance_percentage REAL NOT NULL, '
      'education_allowance_percentage REAL NOT NULL, '
      'travel_allowance_percentage REAL NOT NULL, '
      'other_allowance_percentage REAL NOT NULL DEFAULT 0.0, '
      'pf_percentage REAL NOT NULL, '
      'esi_percentage REAL NOT NULL DEFAULT 0.0, '
      'tax_percentage REAL NOT NULL, '
      'professional_tax_percentage REAL NOT NULL)',
    );
    await _ensureColumnsExist(db);
  }

  static Future<void> _ensureColumnsExist(Database db) async {
    final tableInfo = await db.rawQuery('PRAGMA table_info(salary_settings_structure)');
    final existingColumns = tableInfo.map((row) => row['name'] as String).toSet();

    if (!existingColumns.contains('other_allowance_percentage')) {
      await db.execute('ALTER TABLE salary_settings_structure ADD COLUMN other_allowance_percentage REAL DEFAULT 0.0');
    }
    if (!existingColumns.contains('esi_percentage')) {
      await db.execute('ALTER TABLE salary_settings_structure ADD COLUMN esi_percentage REAL DEFAULT 0.0');
    }
  }

  @override
  Future<SalarySettings> getSalarySettings() async {
    final db = await _db;
    await _createTable(db);
    final rows = await db.query('salary_settings_structure', where: 'id = 1');
    if (rows.isEmpty) {
      const defaultSettings = SalarySettings();
      await db.insert('salary_settings_structure', {
        'id': 1,
        ...defaultSettings.toMap(),
      });
      return defaultSettings;
    }
    return SalarySettings.fromMap(rows.first);
  }

  @override
  Future<void> saveSalarySettings(SalarySettings settings) async {
    final db = await _db;
    await _createTable(db);
    final count = await db.update(
      'salary_settings_structure',
      settings.toMap(),
      where: 'id = 1',
    );
    if (count == 0) {
      await db.insert('salary_settings_structure', {
        'id': 1,
        ...settings.toMap(),
      });
    }
  }
}
