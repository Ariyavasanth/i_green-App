import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/asset_type.dart';
import '../domain/asset_type_repository.dart';

class SqliteAssetTypeRepository implements AssetTypeRepository {
  Database? _database;

  Future<Database> get _db async => _database ??= await openDatabase(
        p.join(await getDatabasesPath(), 'igreen_assets.db'),
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE asset_types('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'name TEXT NOT NULL, '
            'description TEXT, '
            'category TEXT, '
            'status TEXT NOT NULL, '
            'created_at TEXT)',
          );
          await _seed(db);
        },
      );

  static Future<void> _seed(Database db) async {
    final nowStr = DateTime.now().toIso8601String();
    const defaultTypes = [
      ['Laptop', 'Company assigned laptop computer', 'Hardware', 'Active'],
      ['Mobile Phone', 'Company mobile smartphone or SIM card', 'Hardware', 'Active'],
      ['Monitor', 'Desktop display monitor screen', 'Peripheral', 'Active'],
      ['Keyboard', 'Mechanical or ergonomic desktop keyboard', 'Peripheral', 'Active'],
      ['Headset', 'Audio headset or noise cancelling headphones', 'Peripheral', 'Active'],
      ['Other Equipment', 'General tools, accessories or devices', 'Other', 'Active'],
    ];

    for (final row in defaultTypes) {
      await db.insert('asset_types', {
        'name': row[0],
        'description': row[1],
        'category': row[2],
        'status': row[3],
        'created_at': nowStr,
      });
    }
  }

  @override
  Future<List<AssetType>> getAssetTypes() async {
    final db = await _db;
    final rows = await db.query('asset_types', orderBy: 'id ASC');
    return rows.map((row) => AssetType.fromMap(row)).toList();
  }

  @override
  Future<AssetType> addAssetType(AssetType type) async {
    final db = await _db;
    final createdAt = type.createdAt ?? DateTime.now().toIso8601String();
    final id = await db.insert('asset_types', {
      'name': type.name,
      'description': type.description,
      'category': type.category,
      'status': type.status,
      'created_at': createdAt,
    });
    return type.copyWith(id: id, createdAt: createdAt);
  }

  @override
  Future<void> updateAssetType(AssetType type) async {
    final db = await _db;
    await db.update(
      'asset_types',
      {
        'name': type.name,
        'description': type.description,
        'category': type.category,
        'status': type.status,
      },
      where: 'id = ?',
      whereArgs: [type.id],
    );
  }

  @override
  Future<void> deleteAssetType(int id) async {
    final db = await _db;
    await db.delete('asset_types', where: 'id = ?', whereArgs: [id]);
  }
}
