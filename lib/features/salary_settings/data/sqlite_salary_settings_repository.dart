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
      'pf_percentage REAL NOT NULL, '
      'tax_percentage REAL NOT NULL, '
      'professional_tax_percentage REAL NOT NULL)',
    );
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
