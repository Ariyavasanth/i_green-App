import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../domain/exit_model.dart';
import '../domain/exit_repository.dart';

class SqliteExitRepository implements ExitRepository {
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

    final db = await openDatabase(
      path,
      version: 1,
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
      CREATE TABLE IF NOT EXISTS exit_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id TEXT,
        employee_name TEXT,
        department TEXT,
        designation TEXT,
        applied_date TEXT,
        reason TEXT,
        notice_start_date TEXT,
        notice_end_date TEXT,
        days_completed INTEGER,
        total_notice_days INTEGER,
        last_working_day TEXT,
        status TEXT,
        policy_accepted INTEGER,
        employee_signature TEXT,
        leave_taken_count INTEGER,
        manager_approval_status TEXT,
        hr_approval_status TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS exit_clearances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        exit_request_id INTEGER,
        department TEXT,
        status TEXT,
        checklist_json TEXT,
        comments TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS exit_interviews (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        exit_request_id INTEGER,
        reason_category TEXT,
        feedback TEXT,
        recommend_company INTEGER,
        submitted_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS exit_settlements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        exit_request_id INTEGER,
        gross_salary REAL,
        notice_pay REAL,
        insurance_deduction REAL,
        uniform_deduction REAL,
        shoes_deduction REAL,
        id_card_deduction REAL,
        loan_deduction REAL,
        notice_shortfall_deduction REAL,
        other_deductions REAL,
        total_deductions REAL,
        net_settlement REAL,
        status TEXT,
        payout_date TEXT,
        notes TEXT
      )
    ''');
  }

  @override
  Future<List<ExitRequest>> getAllExitRequests() async {
    final db = await database;
    final maps = await db.query('exit_requests', orderBy: 'id DESC');
    return maps.map((m) => ExitRequest.fromMap(m)).toList();
  }

  @override
  Future<ExitRequest?> getExitRequestByEmployeeId(String employeeId) async {
    final db = await database;
    final maps = await db.query(
      'exit_requests',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ExitRequest.fromMap(maps.first);
  }

  @override
  Future<ExitRequest?> getExitRequestById(int id) async {
    final db = await database;
    final maps = await db.query(
      'exit_requests',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ExitRequest.fromMap(maps.first);
  }

  @override
  Future<int> submitExitRequest(ExitRequest request) async {
    final db = await database;
    final id = await db.insert('exit_requests', request.toMap());

    // Initialize default clearances for standard departments
    final nowStr = DateTime.now().toIso8601String();
    final defaultDepts = [
      {
        'dept': 'IT',
        'items': {'Laptop Returned': false, 'ID Card Returned': false, 'Email Disabled': false}
      },
      {
        'dept': 'HR',
        'items': {'Exit Interview': false, 'Documents Collected': false}
      },
      {
        'dept': 'Admin',
        'items': {'Uniform Returned': false, 'Shoes Returned': false, 'Locker Returned': false}
      },
      {
        'dept': 'Accounts',
        'items': {'Loan Closed': false, 'Final Settlement': false}
      },
      {
        'dept': 'Manager',
        'items': {'Knowledge Transfer': false, 'Project Handover': false}
      },
    ];

    for (var item in defaultDepts) {
      final clearance = DepartmentClearance(
        exitRequestId: id,
        department: item['dept'] as String,
        status: 'Pending',
        checklist: item['items'] as Map<String, bool>,
        updatedAt: nowStr,
      );
      await db.insert('exit_clearances', clearance.toMap());
    }

    return id;
  }

  @override
  Future<void> updateExitRequestStatus(int id, String status) async {
    final db = await database;
    await db.update(
      'exit_requests',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> updateExitRequestDetails(ExitRequest request) async {
    final db = await database;
    if (request.id == null) return;
    await db.update(
      'exit_requests',
      request.toMap(),
      where: 'id = ?',
      whereArgs: [request.id],
    );
  }

  @override
  Future<List<DepartmentClearance>> getClearancesForExit(int exitRequestId) async {
    final db = await database;
    final maps = await db.query(
      'exit_clearances',
      where: 'exit_request_id = ?',
      whereArgs: [exitRequestId],
    );
    return maps.map((m) => DepartmentClearance.fromMap(m)).toList();
  }

  @override
  Future<void> saveOrUpdateClearance(DepartmentClearance clearance) async {
    final db = await database;
    if (clearance.id != null) {
      await db.update(
        'exit_clearances',
        clearance.toMap(),
        where: 'id = ?',
        whereArgs: [clearance.id],
      );
    } else {
      await db.insert('exit_clearances', clearance.toMap());
    }
  }

  @override
  Future<ExitInterview?> getExitInterview(int exitRequestId) async {
    final db = await database;
    final maps = await db.query(
      'exit_interviews',
      where: 'exit_request_id = ?',
      whereArgs: [exitRequestId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ExitInterview.fromMap(maps.first);
  }

  @override
  Future<void> submitExitInterview(ExitInterview interview) async {
    final db = await database;
    final existing = await getExitInterview(interview.exitRequestId);
    if (existing != null) {
      await db.update(
        'exit_interviews',
        interview.toMap(),
        where: 'id = ?',
        whereArgs: [existing.id],
      );
    } else {
      await db.insert('exit_interviews', interview.toMap());
    }
  }

  @override
  Future<ExitSettlement?> getExitSettlement(int exitRequestId) async {
    final db = await database;
    final maps = await db.query(
      'exit_settlements',
      where: 'exit_request_id = ?',
      whereArgs: [exitRequestId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ExitSettlement.fromMap(maps.first);
  }

  @override
  Future<void> saveOrUpdateSettlement(ExitSettlement settlement) async {
    final db = await database;
    final existing = await getExitSettlement(settlement.exitRequestId);
    if (existing != null) {
      await db.update(
        'exit_settlements',
        settlement.toMap(),
        where: 'id = ?',
        whereArgs: [existing.id],
      );
    } else {
      await db.insert('exit_settlements', settlement.toMap());
    }
  }
}
