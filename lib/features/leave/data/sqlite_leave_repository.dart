import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/leave_request.dart';
import '../domain/leave_repository.dart';
import '../domain/leave_balance.dart';
import '../domain/leave_type.dart';
import '../domain/salary_calculation.dart';

class SqliteLeaveRepository implements LeaveRepository {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    await _createTables(_database!);
    await _ensureColumnsExist(_database!);
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
        await _ensureColumnsExist(db);
      },
    );

    return db;
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS leave_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER,
        employee_name TEXT,
        employee_custom_id TEXT,
        leave_type TEXT,
        from_date TEXT,
        to_date TEXT,
        num_days REAL,
        reason TEXT,
        status TEXT,
        created_at TEXT,
        approved_dates TEXT,
        lop_dates TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS leave_balances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER,
        leave_type TEXT,
        allowed_leaves REAL,
        used_leaves REAL,
        available_leaves REAL,
        effective_date TEXT,
        allocation_frequency TEXT,
        UNIQUE(employee_id, leave_type)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS leave_types (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE,
        description TEXT,
        annual_allocation REAL DEFAULT 12.0,
        carry_forward TEXT DEFAULT 'Not allowed',
        color_hex TEXT DEFAULT '#6366F1',
        is_active INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS leave_employee_overrides (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER,
        employee_name TEXT,
        employee_custom_id TEXT,
        leave_type TEXT,
        override_days REAL,
        reason TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS loss_of_pay_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER,
        leave_request_id INTEGER,
        date TEXT,
        amount REAL,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS leave_audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        leave_request_id INTEGER,
        action TEXT,
        performed_by TEXT,
        timestamp TEXT,
        details TEXT
      )
    ''');

    // Seed default leave types if empty
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM leave_types'),
    );
    if (count == 0) {
      await db.insert('leave_types', {
        'name': 'Casual Leave',
        'description': 'Standard casual leave allowance.',
        'annual_allocation': 12.0,
        'carry_forward': 'Up to 3 days',
        'color_hex': '#6366F1',
        'is_active': 1,
      });
      await db.insert('leave_types', {
        'name': 'Sick Leave',
        'description': 'Medical leave allowance.',
        'annual_allocation': 10.0,
        'carry_forward': 'Not allowed',
        'color_hex': '#14B8A6',
        'is_active': 1,
      });
      await db.insert('leave_types', {
        'name': 'Earned Leave',
        'description': 'Paid annual leave accumulated through service.',
        'annual_allocation': 15.0,
        'carry_forward': 'Up to 10 days',
        'color_hex': '#22C55E',
        'is_active': 1,
      });
      await db.insert('leave_types', {
        'name': 'As Needed',
        'description': 'Flexible leave allowed on special request.',
        'annual_allocation': 8.0,
        'carry_forward': 'Not allowed',
        'color_hex': '#F59E0B',
        'is_active': 1,
      });
    }

    // Clear legacy sample leave balances and leave requests
    await db.delete(
      'leave_requests',
      where: "employee_custom_id IN ('EMP-0001', 'EMP-0002', 'EMP-0003', 'EMP-3006') OR employee_name IN ('Saravanan G S', 'John Doe', 'Jane Smith', 'Ariya vasanth', 'guna S')",
    );
    await db.delete('leave_balances');
  }

  Future<void> _ensureColumnsExist(Database db) async {
    final tableInfo = await db.rawQuery('PRAGMA table_info(leave_requests)');
    final existingColumns = tableInfo.map((row) => row['name'] as String).toSet();

    final requiredColumns = {
      'employee_name': 'TEXT',
      'employee_custom_id': 'TEXT',
      'leave_type': 'TEXT',
      'from_date': 'TEXT',
      'to_date': 'TEXT',
      'num_days': 'REAL',
      'approved_dates': 'TEXT',
      'lop_dates': 'TEXT',
      'is_emergency': 'INTEGER',
    };

    for (final entry in requiredColumns.entries) {
      if (!existingColumns.contains(entry.key)) {
        await db.execute('ALTER TABLE leave_requests ADD COLUMN ${entry.key} ${entry.value}');
      }
    }

    final typeTableInfo = await db.rawQuery('PRAGMA table_info(leave_types)');
    final existingTypeCols = typeTableInfo.map((row) => row['name'] as String).toSet();
    final requiredTypeCols = {
      'annual_allocation': 'REAL DEFAULT 12.0',
      'carry_forward': "TEXT DEFAULT 'Not allowed'",
      'color_hex': "TEXT DEFAULT '#6366F1'",
      'is_active': 'INTEGER DEFAULT 1',
    };

    for (final entry in requiredTypeCols.entries) {
      if (!existingTypeCols.contains(entry.key)) {
        await db.execute('ALTER TABLE leave_types ADD COLUMN ${entry.key} ${entry.value}');
      }
    }
  }

  @override
  Future<List<LeaveRequest>> getLeaveRequests(int employeeId) async {
    final db = await database;
    final maps = await db.query(
      'leave_requests',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      orderBy: 'id DESC',
    );
    return maps.map((map) => LeaveRequest.fromMap(map)).toList();
  }

  @override
  Future<List<LeaveRequest>> getAllLeaveRequests() async {
    final db = await database;
    final maps = await db.query(
      'leave_requests',
      orderBy: 'id DESC',
    );
    return maps.map((map) => LeaveRequest.fromMap(map)).toList();
  }

  @override
  Future<void> submitLeaveRequest(LeaveRequest request) async {
    final db = await database;
    await db.insert('leave_requests', request.toMap());
  }

  List<String> _getDatesBetween(String fromStr, String toStr) {
    try {
      final fromParts = fromStr.split('-');
      final toParts = toStr.split('-');
      if (fromParts.length != 3 || toParts.length != 3) return [fromStr];
      final from = DateTime(int.parse(fromParts[2]), int.parse(fromParts[1]), int.parse(fromParts[0]));
      final to = DateTime(int.parse(toParts[2]), int.parse(toParts[1]), int.parse(toParts[0]));
      final List<String> list = [];
      var curr = from;
      while (curr.isBefore(to) || curr.isAtSameMomentAs(to)) {
        final d = curr.day.toString().padLeft(2, '0');
        final m = curr.month.toString().padLeft(2, '0');
        list.add('$d-$m-${curr.year}');
        curr = curr.add(const Duration(days: 1));
      }
      return list;
    } catch (_) {
      return [fromStr];
    }
  }

  @override
  Future<void> approveLeaveRequest(int id, String adminName) async {
    final db = await database;

    // 1. Fetch leave request
    final reqMaps = await db.query('leave_requests', where: 'id = ?', whereArgs: [id]);
    if (reqMaps.isEmpty) return;
    var req = LeaveRequest.fromMap(reqMaps.first);
    if (req.status != 'Pending') return;

    // 2. Fetch employee details for balance lookup and LOP deduction calculations
    final empMaps = await db.query('employees', where: 'id = ?', whereArgs: [req.employeeId]);
    double grossSalary = 0.0;
    String employeeLeavePermissionType = 'As Needed';
    if (empMaps.isNotEmpty) {
      grossSalary = (empMaps.first['salary_total_ctc'] as num?)?.toDouble() ?? 0.0;
      employeeLeavePermissionType = empMaps.first['leave_type'] as String? ?? 'As Needed';
    }
    final double perDaySalary = grossSalary / 26.0;

    // 3. Fetch leave balance using the employee's leave permission type (not the request category)
    final balance = await getLeaveBalance(req.employeeId, employeeLeavePermissionType);

    // 4. Determine approved vs. LOP dates
    final allDates = _getDatesBetween(req.fromDate, req.toDate);
    final List<String> approvedDates = [];
    final List<String> lopDates = [];

    double currentAvailable = balance.availableLeaves;
    double currentUsed = balance.usedLeaves;

    final batch = db.batch();

    for (final d in allDates) {
      if (currentAvailable >= 1.0) {
        currentAvailable -= 1.0;
        currentUsed += 1.0;
        approvedDates.add(d);
      } else {
        lopDates.add(d);
        // Insert Loss of Pay record
        batch.insert('loss_of_pay_records', {
          'employee_id': req.employeeId,
          'leave_request_id': req.id,
          'date': d,
          'amount': perDaySalary,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    }

    // 5. Update Leave Balance
    batch.update(
      'leave_balances',
      {
        'used_leaves': currentUsed,
        'available_leaves': currentAvailable,
      },
      where: 'id = ?',
      whereArgs: [balance.id],
    );

    // 6. Update Leave Request Status
    batch.update(
      'leave_requests',
      {
        'status': 'Approved',
        'approved_dates': jsonEncode(approvedDates),
        'lop_dates': jsonEncode(lopDates),
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    // 7. Insert Audit Log
    batch.insert('leave_audit_logs', {
      'leave_request_id': id,
      'action': 'Approved',
      'performed_by': adminName,
      'timestamp': DateTime.now().toIso8601String(),
      'details': 'Approved ${allDates.length} days: ${approvedDates.length} Paid Leave, ${lopDates.length} Loss of Pay (LOP)',
    });

    await batch.commit(noResult: true);
  }

  @override
  Future<void> denyLeaveRequest(int id, String adminName) async {
    final db = await database;

    final batch = db.batch();
    batch.update(
      'leave_requests',
      {'status': 'Denied'},
      where: 'id = ?',
      whereArgs: [id],
    );

    batch.insert('leave_audit_logs', {
      'leave_request_id': id,
      'action': 'Denied',
      'performed_by': adminName,
      'timestamp': DateTime.now().toIso8601String(),
      'details': 'Leave request denied.',
    });

    await batch.commit(noResult: true);
  }

  @override
  Future<List<LeaveRequest>> getLeaveRequestsForCalendar() async {
    final db = await database;
    final maps = await db.query('leave_requests');
    return maps.map((map) => LeaveRequest.fromMap(map)).toList();
  }

  @override
  Future<List<LeaveBalance>> getLeaveBalances(int employeeId) async {
    final db = await database;
    final maps = await db.query(
      'leave_balances',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
    );
    return maps.map((map) => LeaveBalance.fromMap(map)).toList();
  }

  @override
  Future<LeaveBalance> getLeaveBalance(int employeeId, String leaveType) async {
    final db = await database;

    final maps = await db.query(
      'leave_balances',
      where: 'employee_id = ? AND leave_type = ?',
      whereArgs: [employeeId, leaveType],
    );

    if (maps.isNotEmpty) {
      return LeaveBalance.fromMap(maps.first);
    }

    // Initialize from employee settings
    final empMaps = await db.query('employees', where: 'id = ?', whereArgs: [employeeId]);
    double allowed = 1.0;
    String freq = 'Monthly';
    String effDate = '';

    if (empMaps.isNotEmpty) {
      final empMap = empMaps.first;
      allowed = (empMap['allowed_leaves'] as num?)?.toDouble() ?? 1.0;
      freq = empMap['leave_allocation_frequency'] as String? ?? 'Monthly';
      effDate = empMap['effective_date'] as String? ?? '';
    }

    final balance = LeaveBalance(
      id: 0,
      employeeId: employeeId,
      leaveType: leaveType,
      allowedLeaves: allowed,
      usedLeaves: 0.0,
      availableLeaves: allowed, // Initially all allowed leaves are available
      effectiveDate: effDate,
      allocationFrequency: freq,
    );

    final id = await db.insert('leave_balances', balance.toMap());
    return balance.copyWith(id: id);
  }

  @override
  Future<List<LeaveType>> getLeaveTypes() async {
    final db = await database;
    final maps = await db.query('leave_types');
    return maps.map((map) => LeaveType.fromMap(map)).toList();
  }

  @override
  Future<void> addLeaveType(LeaveType leaveType) async {
    final db = await database;
    await db.insert('leave_types', leaveType.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> updateLeaveType(LeaveType leaveType) async {
    final db = await database;
    await db.update(
      'leave_types',
      leaveType.toMap(),
      where: 'id = ?',
      whereArgs: [leaveType.id],
    );
  }

  @override
  Future<void> deleteLeaveType(int id) async {
    final db = await database;
    await db.delete('leave_types', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<Map<String, dynamic>>> getEmployeeOverrides() async {
    final db = await database;
    return await db.query('leave_employee_overrides', orderBy: 'id DESC');
  }

  @override
  Future<void> addEmployeeOverride(Map<String, dynamic> override) async {
    final db = await database;
    await db.insert('leave_employee_overrides', override, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteEmployeeOverride(int id) async {
    final db = await database;
    await db.delete('leave_employee_overrides', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<SalaryCalculation> calculateSalaryAndLop(
    int employeeId,
    int year,
    int month, {
    int workingDays = 26,
  }) async {
    final db = await database;

    // Fetch employee details
    final empMaps = await db.query('employees', where: 'id = ?', whereArgs: [employeeId]);
    double grossSalary = 0.0;
    if (empMaps.isNotEmpty) {
      grossSalary = (empMaps.first['salary_total_ctc'] as num?)?.toDouble() ?? 0.0;
    }

    final double perDaySalary = workingDays > 0 ? (grossSalary / workingDays) : 0.0;

    // Query LOP records in selected month/year
    final monthStr = month.toString().padLeft(2, '0');
    final suffix = '%-$monthStr-$year';
    
    final lopMaps = await db.query(
      'loss_of_pay_records',
      where: 'employee_id = ? AND date LIKE ?',
      whereArgs: [employeeId, suffix],
    );
    final double totalLopDays = lopMaps.length.toDouble();

    // Query all approved leave requests and count approved dates in selected month/year
    final leaveMaps = await db.query(
      'leave_requests',
      where: 'employee_id = ? AND status = ?',
      whereArgs: [employeeId, 'Approved'],
    );
    
    double approvedDaysCount = 0;
    for (final map in leaveMaps) {
      final req = LeaveRequest.fromMap(map);
      for (final date in req.approvedDates) {
        if (date.endsWith('-$monthStr-$year')) {
          approvedDaysCount++;
        }
      }
    }

    final double lopDeduction = perDaySalary * totalLopDays;
    final double payableSalary = grossSalary - lopDeduction;

    return SalaryCalculation(
      grossMonthlySalary: grossSalary,
      totalWorkingDays: workingDays,
      perDaySalary: perDaySalary,
      totalApprovedLeaveDays: approvedDaysCount,
      totalLopDays: totalLopDays,
      lopDeductionAmount: lopDeduction,
      finalPayableSalary: payableSalary,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getAuditLogs(int leaveRequestId) async {
    final db = await database;
    return await db.query(
      'leave_audit_logs',
      where: 'leave_request_id = ?',
      whereArgs: [leaveRequestId],
      orderBy: 'id DESC',
    );
  }
}
