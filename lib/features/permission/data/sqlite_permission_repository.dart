import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/permission_balance.dart';
import '../domain/permission_enums.dart';
import '../domain/permission_policy.dart';
import '../domain/permission_repository.dart';
import '../domain/permission_request.dart';

class SqlitePermissionRepository implements PermissionRepository {
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
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async => _createTables(db),
      onOpen: (db) async => _createTables(db),
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS permission_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        daily_limit_hours REAL DEFAULT 1.0,
        monthly_limit_hours REAL DEFAULT 3.0,
        require_approval INTEGER DEFAULT 1,
        allow_emergency INTEGER DEFAULT 1,
        emergency_requires_approval INTEGER DEFAULT 1,
        allow_multiple_per_day INTEGER DEFAULT 0,
        allow_post_date_emergency INTEGER DEFAULT 0
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS permission_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL,
        employee_name TEXT NOT NULL,
        employee_code TEXT NOT NULL,
        department TEXT NOT NULL,
        date TEXT NOT NULL,
        from_time TEXT NOT NULL,
        to_time TEXT NOT NULL,
        duration_minutes INTEGER NOT NULL,
        permission_type TEXT NOT NULL,
        reason TEXT NOT NULL,
        status TEXT NOT NULL,
        is_emergency INTEGER DEFAULT 0,
        emergency_reason TEXT,
        attachment_url TEXT,
        submitted_at TEXT NOT NULL,
        reviewed_by TEXT,
        reviewed_at TEXT,
        admin_comment TEXT,
        payroll_treatment TEXT DEFAULT 'unspecified',
        paid_duration_minutes INTEGER DEFAULT 0,
        lop_duration_minutes INTEGER DEFAULT 0
      );
    ''');

    // Ensure default settings record exists
    final settingsCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM permission_settings'),
    );
    if (settingsCount == null || settingsCount == 0) {
      await db.insert('permission_settings', const PermissionPolicy().toMap());
    }
  }

  @override
  Future<PermissionPolicy> getPermissionPolicy() async {
    final db = await database;
    final res = await db.query('permission_settings', limit: 1);
    if (res.isNotEmpty) {
      return PermissionPolicy.fromMap(res.first);
    }
    return const PermissionPolicy();
  }

  @override
  Future<void> updatePermissionPolicy(PermissionPolicy policy) async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM permission_settings'),
    );
    if (count != null && count > 0) {
      await db.update('permission_settings', policy.toMap(), where: 'id = 1');
    } else {
      await db.insert('permission_settings', policy.toMap());
    }
  }

  @override
  Future<PermissionBalance> getPermissionBalance(int employeeId, DateTime date) async {
    final db = await database;
    final policy = await getPermissionPolicy();

    double dailyLimitHours = policy.dailyLimitHours;
    double monthlyLimitHours = policy.monthlyLimitHours;

    try {
      final empRows = await db.query(
        'employees',
        columns: ['daily_permission_limit_hours', 'monthly_permission_limit_hours'],
        where: 'id = ?',
        whereArgs: [employeeId],
      );
      if (empRows.isNotEmpty) {
        final empDaily = (empRows.first['daily_permission_limit_hours'] as num?)?.toDouble();
        final empMonthly = (empRows.first['monthly_permission_limit_hours'] as num?)?.toDouble();
        if (empDaily != null && empDaily > 0) dailyLimitHours = empDaily;
        if (empMonthly != null && empMonthly > 0) monthlyLimitHours = empMonthly;
      }
    } catch (_) {
      // Fallback to global policy if employees table is not populated
    }

    final dateStr = date.toIso8601String().split('T').first;
    final yearMonthStr = '${date.year}-${date.month.toString().padLeft(2, '0')}';

    // Calculate today's used minutes (approved or emergency approved paid/lop)
    final todayRows = await db.query(
      'permission_requests',
      where: 'employee_id = ? AND date = ? AND status != ? AND status != ?',
      whereArgs: [employeeId, dateStr, 'rejected', 'cancelled'],
    );
    int todayUsed = 0;
    for (final row in todayRows) {
      todayUsed += (row['duration_minutes'] as int? ?? 0);
    }

    // Calculate monthly used minutes
    final monthRows = await db.query(
      'permission_requests',
      where: 'employee_id = ? AND date LIKE ? AND status != ? AND status != ?',
      whereArgs: [employeeId, '$yearMonthStr%', 'rejected', 'cancelled'],
    );
    int monthlyUsed = 0;
    for (final row in monthRows) {
      monthlyUsed += (row['duration_minutes'] as int? ?? 0);
    }

    return PermissionBalance(
      employeeId: employeeId,
      month: date,
      monthlyLimitMinutes: (monthlyLimitHours * 60).round(),
      monthlyUsedMinutes: monthlyUsed,
      todayLimitMinutes: (dailyLimitHours * 60).round(),
      todayUsedMinutes: todayUsed,
    );
  }

  @override
  Future<List<PermissionRequest>> getEmployeeRequests(int employeeId) async {
    final db = await database;
    final rows = await db.query(
      'permission_requests',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      orderBy: 'submitted_at DESC',
    );
    return rows.map((r) => PermissionRequest.fromMap(r)).toList();
  }

  @override
  Future<PermissionRequest?> getRequestById(int id) async {
    final db = await database;
    final rows = await db.query('permission_requests', where: 'id = ?', whereArgs: [id]);
    if (rows.isNotEmpty) {
      return PermissionRequest.fromMap(rows.first);
    }
    return null;
  }

  @override
  Future<void> submitRequest(PermissionRequest request) async {
    final db = await database;
    await db.insert('permission_requests', request.toMap());
  }

  @override
  Future<void> submitEmergencyRequest(PermissionRequest request) async {
    final db = await database;
    final emergencyReq = request.copyWith(
      isEmergency: true,
      status: PermissionStatus.emergencyPending,
      payrollTreatment: PayrollTreatment.unspecified,
    );
    await db.insert('permission_requests', emergencyReq.toMap());
  }

  @override
  Future<void> cancelRequest(int id, String cancelledBy) async {
    final db = await database;
    await db.update(
      'permission_requests',
      {
        'status': PermissionStatus.cancelled.name,
        'admin_comment': 'Cancelled by $cancelledBy',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<PermissionRequest>> getAllRequests({
    int? employeeId,
    String? department,
    PermissionStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (employeeId != null) {
      whereClauses.add('employee_id = ?');
      whereArgs.add(employeeId);
    }

    if (department != null && department.isNotEmpty && department != 'All Departments') {
      whereClauses.add('department = ?');
      whereArgs.add(department);
    }

    if (status != null) {
      whereClauses.add('status = ?');
      whereArgs.add(status.name);
    }

    if (startDate != null) {
      whereClauses.add('date >= ?');
      whereArgs.add(startDate.toIso8601String().split('T').first);
    }

    if (endDate != null) {
      whereClauses.add('date <= ?');
      whereArgs.add(endDate.toIso8601String().split('T').first);
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final rows = await db.query(
      'permission_requests',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'submitted_at DESC',
    );

    return rows.map((r) => PermissionRequest.fromMap(r)).toList();
  }

  @override
  Future<void> approveNormalRequest(int id, String adminName, {String? comment}) async {
    final db = await database;
    final req = await getRequestById(id);
    if (req == null) return;

    await db.update(
      'permission_requests',
      {
        'status': PermissionStatus.approved.name,
        'reviewed_by': adminName,
        'reviewed_at': DateTime.now().toIso8601String(),
        'admin_comment': comment ?? 'Approved',
        'payroll_treatment': PayrollTreatment.paid.name,
        'paid_duration_minutes': req.durationMinutes,
        'lop_duration_minutes': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> rejectRequest(int id, String adminName, String reason) async {
    final db = await database;
    await db.update(
      'permission_requests',
      {
        'status': PermissionStatus.rejected.name,
        'reviewed_by': adminName,
        'reviewed_at': DateTime.now().toIso8601String(),
        'admin_comment': reason,
        'payroll_treatment': PayrollTreatment.unspecified.name,
        'paid_duration_minutes': 0,
        'lop_duration_minutes': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> reviewEmergencyRequest(
    int id,
    String adminName, {
    required PayrollTreatment decision,
    String? comment,
  }) async {
    final db = await database;
    final req = await getRequestById(id);
    if (req == null) return;

    final isPaid = decision == PayrollTreatment.paid;

    await db.update(
      'permission_requests',
      {
        'status': PermissionStatus.approved.name,
        'reviewed_by': adminName,
        'reviewed_at': DateTime.now().toIso8601String(),
        'admin_comment': comment ?? (isPaid ? 'Approved as Paid Emergency' : 'Approved as LOP Emergency'),
        'payroll_treatment': decision.name,
        'paid_duration_minutes': isPaid ? req.durationMinutes : 0,
        'lop_duration_minutes': isPaid ? 0 : req.durationMinutes,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<PermissionBalance>> getAllEmployeeUsage(DateTime month) async {
    final db = await database;
    final employees = await db.rawQuery('SELECT DISTINCT employee_id FROM permission_requests');
    final result = <PermissionBalance>[];
    for (final emp in employees) {
      final empId = emp['employee_id'] as int?;
      if (empId != null) {
        final bal = await getPermissionBalance(empId, month);
        result.add(bal);
      }
    }
    return result;
  }
}
