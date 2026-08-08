import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/asset_assignment.dart';
import '../domain/asset_assignment_repository.dart';

class SqliteAssetAssignmentRepository implements AssetAssignmentRepository {
  Database? _database;

  Future<Database> get _db async => _database ??= await openDatabase(
        p.join(await getDatabasesPath(), 'igreen_assets.db'),
        version: 4,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS asset_assignments('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'employee_id INTEGER NOT NULL, '
            'employee_name TEXT NOT NULL, '
            'employee_code TEXT, '
            'asset_type_id INTEGER NOT NULL, '
            'asset_type_name TEXT NOT NULL, '
            'asset_name TEXT, '
            'serial_number TEXT, '
            'assigned_date TEXT NOT NULL, '
            'description TEXT NOT NULL, '
            'status TEXT NOT NULL, '
            'maintenance_address TEXT, '
            'maintenance_contact TEXT, '
            'maintenance_given_date TEXT, '
            'maintenance_return_date TEXT, '
            'created_at TEXT)',
          );
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('ALTER TABLE asset_assignments ADD COLUMN maintenance_address TEXT');
            await db.execute('ALTER TABLE asset_assignments ADD COLUMN maintenance_contact TEXT');
            await db.execute('ALTER TABLE asset_assignments ADD COLUMN maintenance_given_date TEXT');
            await db.execute('ALTER TABLE asset_assignments ADD COLUMN maintenance_return_date TEXT');
          }
          if (oldVersion < 3) {
            await db.execute('ALTER TABLE asset_assignments ADD COLUMN serial_number TEXT');
          }
          if (oldVersion < 4) {
            await db.execute('ALTER TABLE asset_assignments ADD COLUMN asset_name TEXT');
          }
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
      'asset_name': assignment.assetName,
      'serial_number': assignment.serialNumber,
      'assigned_date': assignment.assignedDate,
      'description': assignment.description,
      'status': assignment.status,
      'maintenance_address': assignment.maintenanceAddress,
      'maintenance_contact': assignment.maintenanceContact,
      'maintenance_given_date': assignment.maintenanceGivenDate,
      'maintenance_return_date': assignment.maintenanceReturnDate,
      'created_at': createdAt,
    });
    return assignment.copyWith(id: id, createdAt: createdAt);
  }

  @override
  Future<void> addAssignments(List<AssetAssignment> assignments) async {
    if (assignments.isEmpty) return;
    final db = await _db;
    final batch = db.batch();
    final nowStr = DateTime.now().toIso8601String();
    for (final assignment in assignments) {
      batch.insert('asset_assignments', {
        'employee_id': assignment.employeeId,
        'employee_name': assignment.employeeName,
        'employee_code': assignment.employeeCode,
        'asset_type_id': assignment.assetTypeId,
        'asset_type_name': assignment.assetTypeName,
        'asset_name': assignment.assetName,
        'serial_number': assignment.serialNumber,
        'assigned_date': assignment.assignedDate,
        'description': assignment.description,
        'status': assignment.status,
        'maintenance_address': assignment.maintenanceAddress,
        'maintenance_contact': assignment.maintenanceContact,
        'maintenance_given_date': assignment.maintenanceGivenDate,
        'maintenance_return_date': assignment.maintenanceReturnDate,
        'created_at': assignment.createdAt ?? nowStr,
      });
    }
    await batch.commit(noResult: true);
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
        'asset_name': assignment.assetName,
        'serial_number': assignment.serialNumber,
        'assigned_date': assignment.assignedDate,
        'description': assignment.description,
        'status': assignment.status,
        'maintenance_address': assignment.maintenanceAddress,
        'maintenance_contact': assignment.maintenanceContact,
        'maintenance_given_date': assignment.maintenanceGivenDate,
        'maintenance_return_date': assignment.maintenanceReturnDate,
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
