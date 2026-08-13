import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../domain/incentive_repository.dart';
import '../domain/incentive_request.dart';
import '../domain/incentive_settings.dart';

class SqliteIncentiveRepository implements IncentiveRepository {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    await _createTables(_database!);
    await _seedDefaultRequests(_database!);
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app_database.db');

    final db = await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onOpen: (db) async {
        await _createTables(db);
      },
    );

    return db;
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS incentive_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        request_id TEXT,
        employee_id INTEGER,
        employee_name TEXT,
        designation TEXT,
        site TEXT,
        product_name TEXT,
        meters REAL,
        rate REAL,
        amount REAL,
        verified_meters REAL,
        approved_amount REAL,
        status TEXT,
        remarks TEXT,
        evidence_image TEXT,
        created_at TEXT
      )
    ''');

    final columns = await db.rawQuery('PRAGMA table_info(incentive_requests)');
    if (!columns.any((column) => column['name'] == 'evidence_image')) {
      await db.execute('ALTER TABLE incentive_requests ADD COLUMN evidence_image TEXT');
    }

    await db.execute('''
      CREATE TABLE IF NOT EXISTS incentive_settings (
        id INTEGER PRIMARY KEY DEFAULT 1,
        is_lock_active INTEGER DEFAULT 0,
        lock_from_date TEXT DEFAULT '',
        lock_to_date TEXT DEFAULT ''
      )
    ''');
  }

  Future<void> _seedDefaultRequests(Database db) async {
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM incentive_requests'),
    );

    if (count == null || count == 0) {
      final now = DateTime.now().toIso8601String();
      final initialRequests = [
        IncentiveRequest(
          requestId: 'INC-1001',
          employeeId: 1,
          employeeName: 'Ramesh',
          designation: 'Operator',
          site: 'Site A',
          productName: 'Underground Cable Pipeline',
          meters: 50,
          rate: 10,
          amount: 500,
          verifiedMeters: 50,
          approvedAmount: 500,
          status: 'Pending',
          remarks: '-',
          createdAt: now,
        ),
        IncentiveRequest(
          requestId: 'INC-1002',
          employeeId: 2,
          employeeName: 'Suresh',
          designation: 'Tracker',
          site: 'Site B',
          productName: 'Underground Cable Pipeline',
          meters: 80,
          rate: 10,
          amount: 800,
          verifiedMeters: 80,
          approvedAmount: 800,
          status: 'Pending',
          remarks: 'Completed ahead of schedule',
          createdAt: now,
        ),
        IncentiveRequest(
          requestId: 'INC-1003',
          employeeId: 3,
          employeeName: 'Kumar',
          designation: 'Supervisor',
          site: 'Site C',
          productName: 'Underground Cable Pipeline',
          meters: 120,
          rate: 10,
          amount: 1200,
          verifiedMeters: 120,
          approvedAmount: 1200,
          status: 'Pending',
          remarks: '-',
          createdAt: now,
        ),
        IncentiveRequest(
          requestId: 'INC-1004',
          employeeId: 1,
          employeeName: 'Ramesh',
          designation: 'Operator',
          site: 'Site A',
          productName: 'Duct',
          meters: 100,
          rate: 4,
          amount: 400,
          verifiedMeters: 100,
          approvedAmount: 400,
          status: 'Approved',
          remarks: 'Verified by Site Incharge',
          createdAt: now,
        ),
        IncentiveRequest(
          requestId: 'INC-1005',
          employeeId: 4,
          employeeName: 'Anil',
          designation: 'Tracker',
          site: 'Site B',
          productName: 'HDPE 110',
          meters: 40,
          rate: 25,
          amount: 1000,
          verifiedMeters: 40,
          approvedAmount: 1000,
          status: 'Approved',
          remarks: '-',
          createdAt: now,
        ),
        IncentiveRequest(
          requestId: 'INC-1006',
          employeeId: 5,
          employeeName: 'Priya',
          designation: 'Operator',
          site: 'Site C',
          productName: 'EB Cable 11kv 120sqmm',
          meters: 60,
          rate: 6,
          amount: 360,
          verifiedMeters: 60,
          approvedAmount: 360,
          status: 'Approved',
          remarks: '-',
          createdAt: now,
        ),
        IncentiveRequest(
          requestId: 'INC-1007',
          employeeId: 2,
          employeeName: 'Suresh',
          designation: 'Tracker',
          site: 'Site A',
          productName: 'MSPIPE EB /TWAD',
          meters: 10,
          rate: 125,
          amount: 1250,
          verifiedMeters: 10,
          approvedAmount: 1250,
          status: 'Approved',
          remarks: 'Target met',
          createdAt: now,
        ),
        IncentiveRequest(
          requestId: 'INC-1008',
          employeeId: 3,
          employeeName: 'Kumar',
          designation: 'Supervisor',
          site: 'Site B',
          productName: 'GAS Pipeline 100mm-250mm',
          meters: 50,
          rate: 20,
          amount: 1000,
          verifiedMeters: 50,
          approvedAmount: 1000,
          status: 'Approved',
          remarks: '-',
          createdAt: now,
        ),
        IncentiveRequest(
          requestId: 'INC-1009',
          employeeId: 6,
          employeeName: 'Vikas',
          designation: 'Operator',
          site: 'Site C',
          productName: 'Eb LT cable 240 sqmm',
          meters: 30,
          rate: 0,
          amount: 0,
          status: 'Rejected',
          remarks: 'Duplicate request',
          createdAt: now,
        ),
        IncentiveRequest(
          requestId: 'INC-1010',
          employeeId: 1,
          employeeName: 'Ramesh',
          designation: 'Operator',
          site: 'Site B',
          productName: 'GAS Pipeline above 500mm',
          meters: 15,
          rate: 125,
          amount: 1875,
          status: 'Rejected',
          remarks: 'Incorrect site code',
          createdAt: now,
        ),
      ];

      for (final req in initialRequests) {
        await db.insert('incentive_requests', req.toMap());
      }
    }
  }

  @override
  Future<List<IncentiveRequest>> getAllRequests() async {
    final db = await database;
    final maps = await db.query('incentive_requests', orderBy: 'id DESC');
    return maps.map((m) => IncentiveRequest.fromMap(m)).toList();
  }

  @override
  Future<List<IncentiveRequest>> getRequestsByEmployeeName(String employeeName) async {
    final db = await database;
    final maps = await db.query(
      'incentive_requests',
      where: 'LOWER(employee_name) = LOWER(?)',
      whereArgs: [employeeName],
      orderBy: 'id DESC',
    );
    return maps.map((m) => IncentiveRequest.fromMap(m)).toList();
  }

  @override
  Future<IncentiveRequest?> getRequestById(int id) async {
    final db = await database;
    final maps = await db.query(
      'incentive_requests',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return IncentiveRequest.fromMap(maps.first);
    }
    return null;
  }

  @override
  Future<void> createRequest(IncentiveRequest request) async {
    final db = await database;
    await db.insert('incentive_requests', request.toMap());
  }

  @override
  Future<void> cancelRequest(int id) async {
    final db = await database;
    await db.update(
      'incentive_requests',
      {'status': 'Cancelled'},
      where: 'id = ? AND status = ?',
      whereArgs: [id, 'Pending'],
    );
  }

  @override
  Future<void> updateRequest(IncentiveRequest request) async {
    if (request.id == null) return;
    final db = await database;
    await db.update(
      'incentive_requests',
      request.toMap(),
      where: 'id = ? AND status = ?',
      whereArgs: [request.id, 'Pending'],
    );
  }

  @override
  Future<void> updateRequestStatus(
    int id,
    String status, {
    double? verifiedMeters,
    double? approvedAmount,
  }) async {
    final db = await database;
    final updates = <String, dynamic>{
      'status': status,
    };
    if (verifiedMeters != null) updates['verified_meters'] = verifiedMeters;
    if (approvedAmount != null) updates['approved_amount'] = approvedAmount;

    await db.update(
      'incentive_requests',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<IncentiveSettings> getIncentiveSettings() async {
    final db = await database;
    final maps = await db.query('incentive_settings', where: 'id = 1');
    if (maps.isNotEmpty) {
      return IncentiveSettings.fromMap(maps.first);
    }
    return const IncentiveSettings();
  }

  @override
  Future<void> updateIncentiveSettings(IncentiveSettings settings) async {
    final db = await database;
    final map = settings.toMap();
    map['id'] = 1;
    await db.insert(
      'incentive_settings',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
