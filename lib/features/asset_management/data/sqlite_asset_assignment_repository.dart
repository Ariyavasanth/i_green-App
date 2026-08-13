import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/asset_assignment.dart';
import '../domain/asset_assignment_repository.dart';
import '../domain/asset_transfer_request.dart';

class SqliteAssetAssignmentRepository implements AssetAssignmentRepository {
  Database? _database;

  Future<Database> get _db async => _database ??= await openDatabase(
        p.join(await getDatabasesPath(), 'igreen_assets.db'),
        version: 6,
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
            'transferred_from TEXT, '
            'transfer_date TEXT, '
            'created_at TEXT)',
          );
          await _createTransferRequestsTable(db);
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
          if (oldVersion < 5) {
            await db.execute('ALTER TABLE asset_assignments ADD COLUMN transferred_from TEXT');
            await db.execute('ALTER TABLE asset_assignments ADD COLUMN transfer_date TEXT');
          }
          if (oldVersion < 6) await _createTransferRequestsTable(db);
        },
      );

  static Future<void> _createTransferRequestsTable(Database db) => db.execute(
        'CREATE TABLE IF NOT EXISTS asset_transfer_requests('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, asset_assignment_id INTEGER NOT NULL, '
        'asset_name TEXT NOT NULL, asset_type_name TEXT NOT NULL, serial_number TEXT, '
        'from_employee_id INTEGER NOT NULL, from_employee_name TEXT NOT NULL, from_employee_code TEXT, '
        'to_employee_id INTEGER NOT NULL, to_employee_name TEXT NOT NULL, to_employee_code TEXT, '
        'transfer_date TEXT NOT NULL, reason TEXT NOT NULL, status TEXT NOT NULL, '
        'created_at TEXT, responded_at TEXT)',
      );

  Future<void> _seedDefaultAssignments(Database db) async {
    final nowStr = DateTime.now().toIso8601String();
    final defaultItems = [
      {
        'employee_id': 1,
        'employee_name': 'Alex Morgan',
        'employee_code': 'EMP001',
        'asset_type_id': 1,
        'asset_type_name': 'Laptop',
        'asset_name': 'MacBook Pro M2 Max 16"',
        'serial_number': 'C02G1234MD6R',
        'assigned_date': '2026-01-15',
        'description': 'Assigned for primary development & engineering work',
        'status': 'Assigned',
        'created_at': nowStr,
      },
      {
        'employee_id': 1,
        'employee_name': 'Alex Morgan',
        'employee_code': 'EMP001',
        'asset_type_id': 2,
        'asset_type_name': 'Mobile',
        'asset_name': 'iPhone 14 Pro 256GB',
        'serial_number': 'DX3K8892PL01',
        'assigned_date': '2026-02-01',
        'description': 'Assigned for mobile app testing and client communications',
        'status': 'Assigned',
        'created_at': nowStr,
      },
      {
        'employee_id': 1,
        'employee_name': 'Alex Morgan',
        'employee_code': 'EMP001',
        'asset_type_id': 3,
        'asset_type_name': 'Monitor',
        'asset_name': 'Dell UltraSharp 27" 4K Monitor',
        'serial_number': 'CN088321459',
        'assigned_date': '2026-01-15',
        'description': 'Dual screen workstation setup',
        'status': 'Assigned',
        'created_at': nowStr,
      },
      {
        'employee_id': 1,
        'employee_name': 'Alex Morgan',
        'employee_code': 'EMP001',
        'asset_type_id': 4,
        'asset_type_name': 'Headset',
        'asset_name': 'Bose QuietComfort 45 Noise Cancelling',
        'serial_number': 'SN-982314-QC',
        'assigned_date': '2026-03-10',
        'description': 'Audio headset for meetings - sent for battery checkup',
        'status': 'Maintenance',
        'maintenance_address': 'Bose Tech Service Center, MG Road',
        'maintenance_contact': '+91 98765 43210 (Tech Support)',
        'maintenance_given_date': '2026-08-01',
        'maintenance_return_date': '2026-08-12',
        'created_at': nowStr,
      },
      {
        'employee_id': 1,
        'employee_name': 'Alex Morgan',
        'employee_code': 'EMP001',
        'asset_type_id': 5,
        'asset_type_name': 'Security Badge',
        'asset_name': 'Smart Access Card & Server Key Fob',
        'serial_number': 'ACC-2026-0089',
        'assigned_date': '2026-01-10',
        'description': 'Building & Server Room security pass',
        'status': 'Assigned',
        'created_at': nowStr,
      },
    ];

    final batch = db.batch();
    for (final item in defaultItems) {
      batch.insert('asset_assignments', item);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<AssetAssignment>> getAssignments() async {
    final db = await _db;
    await db.execute("UPDATE asset_assignments SET employee_name = 'Alex Morgan' WHERE employee_name = 'Developer / Employee' OR employee_name IS NULL OR TRIM(employee_name) = ''");
    var rows = await db.query('asset_assignments', orderBy: 'id DESC');
    if (rows.isEmpty) {
      await _seedDefaultAssignments(db);
      rows = await db.query('asset_assignments', orderBy: 'id DESC');
    }
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
      'transferred_from': assignment.transferredFrom,
      'transfer_date': assignment.transferDate,
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
        'transferred_from': assignment.transferredFrom,
        'transfer_date': assignment.transferDate,
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
        'transferred_from': assignment.transferredFrom,
        'transfer_date': assignment.transferDate,
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

  @override
  Future<List<AssetTransferRequest>> getTransferRequests() async {
    final db = await _db;
    final rows = await db.query('asset_transfer_requests', orderBy: 'id DESC');
    return rows.map(AssetTransferRequest.fromMap).toList();
  }

  @override
  Future<AssetTransferRequest> createTransferRequest(AssetTransferRequest request) async {
    final db = await _db;
    final data = request.toMap()..remove('id');
    data['created_at'] ??= DateTime.now().toIso8601String();
    final id = await db.insert('asset_transfer_requests', data);
    return request.copyWith(id: id, createdAt: data['created_at'] as String?);
  }

  @override
  Future<void> respondToTransferRequest(AssetTransferRequest request, {required bool approve}) async {
    final db = await _db;
    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      if (approve) {
        await txn.update('asset_assignments', {
          'employee_id': request.toEmployeeId,
          'employee_name': request.toEmployeeName,
          'employee_code': request.toEmployeeCode,
          'assigned_date': request.transferDate,
          'description': request.reason,
          'status': 'Assigned',
          'transferred_from': '${request.fromEmployeeName}${request.fromEmployeeCode.isEmpty ? '' : ' (${request.fromEmployeeCode})'}',
          'transfer_date': request.transferDate,
          'maintenance_address': null,
          'maintenance_contact': null,
          'maintenance_given_date': null,
          'maintenance_return_date': null,
        }, where: 'id = ?', whereArgs: [request.assetAssignmentId]);
      }
      await txn.update('asset_transfer_requests', {
        'status': approve ? 'Approved' : 'Rejected',
        'responded_at': now,
      }, where: 'id = ? AND status = ?', whereArgs: [request.id, 'Pending']);
    });
  }
}
