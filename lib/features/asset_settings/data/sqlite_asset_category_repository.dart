import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/asset_category.dart';
import '../domain/asset_category_repository.dart';

class SqliteAssetCategoryRepository implements AssetCategoryRepository {
  Database? _database;

  Future<Database> get _db async {
    if (_database != null) return _database!;
    _database = await openDatabase(
      p.join(await getDatabasesPath(), 'igreen_assets.db'),
      version: 2,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _createTables(db);
      },
    );
    await _ensureTablesAndSeed(_database!);
    return _database!;
  }

  static Future<void> _createTables(Database db) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS asset_types('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'name TEXT NOT NULL, '
      'description TEXT, '
      'category TEXT, '
      'status TEXT NOT NULL, '
      'created_at TEXT)',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS asset_categories('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'name TEXT NOT NULL, '
      'description TEXT, '
      'created_at TEXT)',
    );
  }

  static Future<void> _ensureTablesAndSeed(Database db) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS asset_categories('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'name TEXT NOT NULL, '
      'description TEXT, '
      'created_at TEXT)',
    );

    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM asset_categories'),
    );

    if (count == 0) {
      await _seed(db);
    }
  }

  static Future<void> _seed(Database db) async {
    final nowStr = DateTime.now().toIso8601String();
    const defaultCategories = [
      ['Hardware', 'Physical equipment and devices'],
      ['Peripheral', 'External devices and accessories'],
      ['Software', 'Software licenses and applications'],
      ['Network', 'Network devices and components'],
      ['Other', 'Other tools and equipment'],
    ];

    for (final row in defaultCategories) {
      await db.insert('asset_categories', {
        'name': row[0],
        'description': row[1],
        'created_at': nowStr,
      });
    }
  }

  @override
  Future<List<AssetCategory>> getAssetCategories() async {
    final db = await _db;
    final rows = await db.query('asset_categories', orderBy: 'id ASC');
    return rows.map((row) => AssetCategory.fromMap(row)).toList();
  }

  @override
  Future<AssetCategory> addAssetCategory(AssetCategory category) async {
    final db = await _db;
    final createdAt = category.createdAt ?? DateTime.now().toIso8601String();
    final id = await db.insert('asset_categories', {
      'name': category.name,
      'description': category.description,
      'created_at': createdAt,
    });
    return category.copyWith(id: id, createdAt: createdAt);
  }

  @override
  Future<void> updateAssetCategory(AssetCategory category) async {
    final db = await _db;
    await db.update(
      'asset_categories',
      {
        'name': category.name,
        'description': category.description,
      },
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  @override
  Future<void> deleteAssetCategory(int id) async {
    final db = await _db;
    await db.delete('asset_categories', where: 'id = ?', whereArgs: [id]);
  }
}
