import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/asset_assignment.dart';
import '../domain/asset_assignment_repository.dart';

class SqliteAssetAssignmentRepository implements AssetAssignmentRepository {
  Database? _database;

  Future<Database> get _db async => _database ??= await openDatabase(
        p.join(await getDatabasesPath(), 'igreen_assets.db'),
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS asset_assignments('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'employee_id INTEGER NOT NULL, '
            'employee_name TEXT NOT NULL, '
            'employee_code TEXT, '
            'asset_type_id INTEGER NOT NULL, '
            'asset_type_name TEXT NOT NULL, '
            'assigned_date TEXT NOT NULL, '
            'description TEXT NOT NULL, '
            'status TEXT NOT NULL, '
            'created_at TEXT)',
          );
        },
      );

  @override
  Future<List<AssetAssignment>> getAssignments() async {
    final db = await _db;
    final rows = await db.query('asset_assignments', orderBy: 'id DESC');
    return rows.map((row) => AssetAssignment.fromMap(row)).toList();
  }

  @override
  Future<AssetAssignment> addAssignment(AssetAssignment assignment) async {
    final db = await _db;
    final createdAt = assignment.createdAt ?? DateTime.now().toIso8601String();
    final id = await db.insert('asset_assignments', {
      'employee_id': assignment.employeeId,
      'employee_name': assignment.employeeName,
      'employee_code': assignment.employeeCode,
      'asset_type_id': assignment.assetTypeId,
      'asset_type_name': assignment.assetTypeName,
      'assigned_date': assignment.assignedDate,
      'description': assignment.description,
      'status': assignment.status,
      'created_at': createdAt,
    });
    return assignment.copyWith(id: id, createdAt: createdAt);
  }

  @override
  Future<void> updateAssignment(AssetAssignment assignment) async {
    final db = await _db;
    await db.update(
      'asset_assignments',
      {
        'employee_id': assignment.employeeId,
        'employee_name': assignment.employeeName,
        'employee_code': assignment.employeeCode,
        'asset_type_id': assignment.assetTypeId,
        'asset_type_name': assignment.assetTypeName,
        'assigned_date': assignment.assignedDate,
        'description': assignment.description,
        'status': assignment.status,
      },
      where: 'id = ?',
      whereArgs: [assignment.id],
    );
  }

  @override
  Future<void> deleteAssignment(int id) async {
    final db = await _db;
    await db.delete('asset_assignments', where: 'id = ?', whereArgs: [id]);
  }
}
