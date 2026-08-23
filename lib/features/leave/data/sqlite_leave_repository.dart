import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/leave_request.dart';
import '../domain/permission_allowance.dart';
import '../domain/leave_repository.dart';
import '../domain/leave_balance.dart';
import '../domain/leave_monthly_balance.dart';
import '../domain/leave_type.dart';
import '../domain/salary_calculation.dart';
import '../../employee/domain/employee.dart';

class SqliteLeaveRepository implements LeaveRepository {
  static Database? _database;
  static Future<Database>? _initDbFuture;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _initDbFuture ??= _initDatabase();
    _database = await _initDbFuture!;
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
        lop_dates TEXT,
        is_emergency INTEGER DEFAULT 0,
        attachment_url TEXT,
        rejection_reason TEXT,
        is_half_day INTEGER DEFAULT 0,
        half_day_period TEXT
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
      CREATE TABLE IF NOT EXISTS leave_monthly_balances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER,
        leave_type TEXT,
        period_year INTEGER,
        period_month INTEGER,
        allowed_days REAL,
        used_paid_days REAL,
        lop_days REAL,
        remaining_days REAL,
        UNIQUE(employee_id, leave_type, period_year, period_month)
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

    // Delete legacy non-leave-type items from leave_types table
    await db.delete(
      'leave_types',
      where: "name IN ('As Needed', 'Manual Allocation', 'No Leave', 'Monthly Leave')",
    );

    // Seed default leave types if empty
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM leave_types'),
    );
    if (count == 0) {
      await db.insert('leave_types', {
        'name': 'Sick Leave',
        'description': 'Medical leave allowance.',
        'annual_allocation': 10.0,
        'carry_forward': 'Not allowed',
        'color_hex': '#14B8A6',
        'is_active': 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await db.insert('leave_types', {
        'name': 'Casual Leave',
        'description': 'Standard casual leave allowance.',
        'annual_allocation': 12.0,
        'carry_forward': 'Up to 3 days',
        'color_hex': '#6366F1',
        'is_active': 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await db.insert('leave_types', {
        'name': 'Annual Leave',
        'description': 'Paid annual leave allowance.',
        'annual_allocation': 15.0,
        'carry_forward': 'Up to 10 days',
        'color_hex': '#22C55E',
        'is_active': 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await db.insert('leave_types', {
        'name': 'Optional Leave',
        'description': 'Optional / Floating holiday leave.',
        'annual_allocation': 3.0,
        'carry_forward': 'Not allowed',
        'color_hex': '#F59E0B',
        'is_active': 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await db.insert('leave_types', {
        'name': 'Emergency Leave',
        'description': 'Urgent emergency leave allowance.',
        'annual_allocation': 5.0,
        'carry_forward': 'Not allowed',
        'color_hex': '#F43F5E',
        'is_active': 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await db.insert('leave_types', {
        'name': 'Work From Home',
        'description': 'Remote work allocation.',
        'annual_allocation': 12.0,
        'carry_forward': 'Not allowed',
        'color_hex': '#3B82F6',
        'is_active': 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await db.insert('leave_types', {
        'name': 'Comp Off',
        'description': 'Compensatory off for extra work.',
        'annual_allocation': 5.0,
        'carry_forward': 'Not allowed',
        'color_hex': '#8B5CF6',
        'is_active': 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
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
      'is_emergency': 'INTEGER DEFAULT 0',
      'attachment_url': 'TEXT',
      'rejection_reason': 'TEXT',
      'is_half_day': 'INTEGER DEFAULT 0',
      'half_day_period': 'TEXT',
      'is_override': 'INTEGER DEFAULT 0',
      'override_reason': 'TEXT',
      'approved_by': 'TEXT',
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
    if (request.id != 0) {
      throw StateError('Leave dates cannot be changed after submission.');
    }
    if (request.leaveType.toLowerCase().startsWith('permission')) {
      await _validatePermissionRequest(request);
    }
    final db = await database;
    await db.insert('leave_requests', request.toMap());
  }

  @override
  Future<void> updateLeaveRequest(LeaveRequest request) async {
    final db = await database;
    await db.update(
      'leave_requests',
      request.toMap(),
      where: 'id = ?',
      whereArgs: [request.id],
    );
  }

  Future<void> _validatePermissionRequest(LeaveRequest request) async {
    final requestedHours = request.numDays * 8;
    if (requestedHours <= 0 || requestedHours > 1.0001) {
      throw Exception('Only up to 1 hour of permission can be taken per day.');
    }
    final requestDate = _parsePermissionDate(request.fromDate);
    final allowance = await getPermissionAllowance(request.employeeId, requestDate);
    if (requestedHours <= 0 || requestedHours > allowance.dailyLimitHours + 0.0001) {
      throw Exception('Only up to ${allowance.dailyLimitHours.toStringAsFixed(0)} hour(s) of permission can be taken per day.');
    }
    final requests = await getLeaveRequests(request.employeeId);
    final active = requests.where((item) =>
        item.leaveType.toLowerCase().startsWith('permission') &&
        (item.status == 'Pending' || item.status == 'Approved'));
    final usedToday = active
        .where((item) => item.fromDate == request.fromDate)
        .fold<double>(0, (sum, item) => sum + item.numDays * 8);
    if (usedToday + requestedHours > allowance.dailyLimitHours + 0.0001) {
      throw Exception('The ${allowance.dailyLimitHours.toStringAsFixed(0)}-hour permission limit for this day has already been used.');
    }
    if (allowance.usedHours + requestedHours > allowance.monthlyLimitHours + 0.0001) {
      throw Exception('Only ${allowance.monthlyLimitHours.toStringAsFixed(0)} hours of permission are available per month.');
    }
  }

  DateTime _parsePermissionDate(String value) {
    final parts = value.split('-');
    if (parts.length == 3) {
      return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
    }
    return DateTime.now();
  }

  @override
  Future<PermissionAllowance> getPermissionAllowance(int employeeId, DateTime month) async {
    double monthlyLimit = 3.0;
    double dailyLimit = 1.0;
    try {
      final db = await database;
      final maps = await db.query('employees', where: 'id = ?', whereArgs: [employeeId], limit: 1);
      if (maps.isNotEmpty) {
        final emp = Employee.fromMap(maps.first);
        monthlyLimit = emp.monthlyPermissionLimitHours;
        dailyLimit = emp.dailyPermissionLimitHours;
      }
    } catch (_) {}

    final requests = await getLeaveRequests(employeeId);
    final used = requests.where((item) {
      if (!item.leaveType.toLowerCase().startsWith('permission') ||
          (item.status != 'Pending' && item.status != 'Approved')) {
        return false;
      }
      final date = _parsePermissionDate(item.fromDate);
      return date.year == month.year && date.month == month.month;
    }).fold<double>(0, (sum, item) => sum + item.numDays * 8);
    return PermissionAllowance(
      monthlyLimitHours: monthlyLimit,
      dailyLimitHours: dailyLimit,
      usedHours: used,
    );
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
  Future<void> _revertPreviousApprovalEffects(Database db, LeaveRequest req) async {
    if (req.status != 'Approved') return;

    // 1. Delete previous LOP records for this request
    await db.delete(
      'loss_of_pay_records',
      where: 'leave_request_id = ?',
      whereArgs: [req.id],
    );

    // 2. Restore leave balance if paid leave days were previously approved
    if (req.approvedDates.isNotEmpty) {
      final requestLeaveType = req.leaveType.startsWith('Permission') ? 'Permission' : req.leaveType;
      final balance = await getLeaveBalance(req.employeeId, requestLeaveType);
      final double restoredCount = req.approvedDates.length.toDouble();
      final double newUsed = (balance.usedLeaves - restoredCount).clamp(0.0, double.infinity);
      final double newAvailable = (balance.availableLeaves + restoredCount).clamp(0.0, balance.allowedLeaves);

      await db.update(
        'leave_balances',
        {
          'used_leaves': newUsed,
          'available_leaves': newAvailable,
        },
        where: 'id = ?',
        whereArgs: [balance.id],
      );
    }
  }

  @override
  Future<void> approveLeaveRequest(
    int id,
    String adminName, {
    String approvalMode = 'as_calculated',
    String? overrideReason,
  }) async {
    final db = await database;

    // 1. Fetch leave request
    final reqMaps = await db.query('leave_requests', where: 'id = ?', whereArgs: [id]);
    if (reqMaps.isEmpty) return;
    var req = LeaveRequest.fromMap(reqMaps.first);

    // Revert previous approval effects if re-evaluating an already approved request
    await _revertPreviousApprovalEffects(db, req);

    // 2. Fetch employee details for leave policy and salary
    final empMaps = await db.query('employees', where: 'id = ?', whereArgs: [req.employeeId]);
    double grossSalary = 0.0;
    String employeePolicy = 'As Needed';
    if (empMaps.isNotEmpty) {
      grossSalary = (empMaps.first['salary_total_ctc'] as num?)?.toDouble() ?? 0.0;
      final rawPolicy = empMaps.first['leave_type'] as String?;
      if (rawPolicy != null && rawPolicy.isNotEmpty) {
        employeePolicy = rawPolicy;
      }
    }
    final double perDaySalary = grossSalary / 26.0;

    final allDates = _getDatesBetween(req.fromDate, req.toDate);
    final List<String> approvedDates = [];
    final List<String> lopDates = [];

    bool isOverride = (approvalMode == 'all_paid' && (employeePolicy == 'Manual Allocation' || employeePolicy == 'No Leave'));

    final batch = db.batch();

    if (employeePolicy == 'As Needed') {
      // 1. As Needed: No quota restriction. All approved days are Paid Leave.
      approvedDates.addAll(allDates);
    } else if (employeePolicy == 'No Leave') {
      // 2. No Leave: Super Admin decides whether it is LOP or Paid Leave Override
      if (approvalMode == 'all_paid') {
        approvedDates.addAll(allDates);
        isOverride = true;
      } else {
        lopDates.addAll(allDates);
        for (final d in lopDates) {
          batch.insert('loss_of_pay_records', {
            'employee_id': req.employeeId,
            'leave_request_id': req.id,
            'date': d,
            'amount': perDaySalary,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }
    } else {
      // 3. Manual Allocation: Quota-based tracking
      final requestLeaveType = req.leaveType.startsWith('Permission') ? 'Permission' : req.leaveType;
      final balance = await getLeaveBalance(req.employeeId, requestLeaveType);

      if (approvalMode == 'all_paid') {
        // Super Admin Override: Approve all requested days as Paid Leave
        approvedDates.addAll(allDates);
        isOverride = true;
        
        final double newUsed = balance.usedLeaves + allDates.length;
        final double newAvailable = (balance.availableLeaves - allDates.length).clamp(0.0, balance.allowedLeaves);
        batch.update(
          'leave_balances',
          {
            'used_leaves': newUsed,
            'available_leaves': newAvailable,
          },
          where: 'id = ?',
          whereArgs: [balance.id],
        );
      } else if (approvalMode == 'all_lop') {
        // Super Admin decision: Approve all requested days as LOP
        lopDates.addAll(allDates);
        for (final d in lopDates) {
          batch.insert('loss_of_pay_records', {
            'employee_id': req.employeeId,
            'leave_request_id': req.id,
            'date': d,
            'amount': perDaySalary,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      } else {
        // Default / 'as_calculated': Days within quota are Paid, excess days are LOP
        double currentAvailable = balance.availableLeaves;
        double currentUsed = balance.usedLeaves;

        for (final d in allDates) {
          if (currentAvailable >= 1.0) {
            currentAvailable -= 1.0;
            currentUsed += 1.0;
            approvedDates.add(d);
          } else {
            lopDates.add(d);
            batch.insert('loss_of_pay_records', {
              'employee_id': req.employeeId,
              'leave_request_id': req.id,
              'date': d,
              'amount': perDaySalary,
              'created_at': DateTime.now().toIso8601String(),
            });
          }
        }

        batch.update(
          'leave_balances',
          {
            'used_leaves': currentUsed,
            'available_leaves': currentAvailable,
          },
          where: 'id = ?',
          whereArgs: [balance.id],
        );
      }
    }

    // Create/update attendance records for approved leave dates with status 'On Leave'
    for (final d in approvedDates) {
      batch.insert(
        'attendance_records',
        {
          'employee_id': req.employeeId,
          'employee_name': req.employeeName,
          'date': d,
          'time': '',
          'status': 'On Leave',
          'verification_status': 'Approved Leave',
          'similarity_score': 1.0,
          'check_in_time': '',
          'check_out_time': '',
          'check_in_verification_status': 'Approved Leave',
          'check_out_verification_status': '',
          'check_in_similarity_score': 1.0,
          'check_out_similarity_score': 0.0,
          'total_hours': 0.0,
          'notes': 'Approved Leave (${req.leaveType})',
          'marked_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // Update Leave Request Status
    batch.update(
      'leave_requests',
      {
        'status': 'Approved',
        'approved_dates': jsonEncode(approvedDates),
        'lop_dates': jsonEncode(lopDates),
        'is_override': isOverride ? 1 : 0,
        'override_reason': overrideReason,
        'approved_by': adminName,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    // Insert Audit Log
    final detailText = isOverride
        ? 'Approved all ${allDates.length} day(s) as Paid Leave via Super Admin Override. Reason: ${overrideReason ?? "N/A"}'
        : 'Approved ${allDates.length} day(s): ${approvedDates.length} Paid Leave, ${lopDates.length} LOP.';

    batch.insert('leave_audit_logs', {
      'leave_request_id': id,
      'action': 'Approved',
      'performed_by': adminName,
      'timestamp': DateTime.now().toIso8601String(),
      'details': detailText,
    });

    await batch.commit(noResult: true);
  }

  @override
  Future<void> denyLeaveRequest(int id, String adminName, {String? reason}) async {
    final db = await database;

    final reqMaps = await db.query('leave_requests', where: 'id = ?', whereArgs: [id]);
    if (reqMaps.isNotEmpty) {
      var req = LeaveRequest.fromMap(reqMaps.first);
      await _revertPreviousApprovalEffects(db, req);
    }

    final batch = db.batch();
    batch.update(
      'leave_requests',
      {
        'status': 'Denied',
        'approved_dates': jsonEncode([]),
        'lop_dates': jsonEncode([]),
        if (reason != null && reason.isNotEmpty) 'rejection_reason': reason,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    batch.insert('leave_audit_logs', {
      'leave_request_id': id,
      'action': 'Denied',
      'performed_by': adminName,
      'timestamp': DateTime.now().toIso8601String(),
      'details': reason != null && reason.isNotEmpty ? 'Denied: $reason' : 'Leave request denied.',
    });

    await batch.commit(noResult: true);
  }

  @override
  Future<void> cancelLeaveRequest(int id, String employeeName) async {
    final db = await database;

    final batch = db.batch();
    batch.update(
      'leave_requests',
      {'status': 'Cancelled'},
      where: 'id = ?',
      whereArgs: [id],
    );

    batch.insert('leave_audit_logs', {
      'leave_request_id': id,
      'action': 'Cancelled',
      'performed_by': employeeName,
      'timestamp': DateTime.now().toIso8601String(),
      'details': 'Leave request cancelled by employee.',
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

  Future<LeaveMonthlyBalance> getMonthlyLeaveBalance(
    int employeeId,
    String leaveType,
    int year,
    int month,
  ) async {
    final db = await database;
    final maps = await db.query(
      'leave_monthly_balances',
      where: 'employee_id = ? AND leave_type = ? AND period_year = ? AND period_month = ?',
      whereArgs: [employeeId, leaveType, year, month],
    );

    if (maps.isNotEmpty) {
      return LeaveMonthlyBalance.fromMap(maps.first);
    }

    double allowedDays = 3.0;
    try {
      final empMaps = await db.query('employees', where: 'id = ?', whereArgs: [employeeId]);
      if (empMaps.isNotEmpty) {
        final emp = Employee.fromMap(empMaps.first);
        final pol = emp.leavePolicy;
        if (pol == 'As Needed') {
          allowedDays = 999.0;
        } else if (pol == 'No Leave') {
          allowedDays = 0.0;
        } else {
          allowedDays = emp.monthlyLeaveAllowanceVal;
        }
      }
    } catch (_) {}

    final monthlyBal = LeaveMonthlyBalance(
      id: 0,
      employeeId: employeeId,
      leaveType: leaveType,
      periodYear: year,
      periodMonth: month,
      allowedDays: allowedDays,
      usedPaidDays: 0.0,
      lopDays: 0.0,
      remainingDays: allowedDays,
    );

    final id = await db.insert(
      'leave_monthly_balances',
      monthlyBal.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return monthlyBal.copyWith(id: id);
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

    // 1. Check for employee override first
    final overrideMaps = await db.query(
      'leave_employee_overrides',
      where: 'employee_id = ? AND leave_type = ?',
      whereArgs: [employeeId, leaveType],
    );

    double allowed = 12.0;
    String freq = 'Monthly';
    String effDate = '';

    if (overrideMaps.isNotEmpty) {
      allowed = (overrideMaps.first['override_days'] as num?)?.toDouble() ?? 12.0;
    } else {
      // 2. Check leave_types table allocation
      final typeMaps = await db.query(
        'leave_types',
        where: 'name = ?',
        whereArgs: [leaveType],
      );
      if (typeMaps.isNotEmpty) {
        allowed = (typeMaps.first['annual_allocation'] as num?)?.toDouble() ?? 12.0;
      } else {
        final empMaps = await db.query('employees', where: 'id = ?', whereArgs: [employeeId]);
        if (empMaps.isNotEmpty) {
          final empMap = empMaps.first;
          allowed = (empMap['allowed_leaves'] as num?)?.toDouble() ?? 12.0;
          freq = empMap['leave_allocation_frequency'] as String? ?? 'Monthly';
          effDate = empMap['effective_date'] as String? ?? '';
        }
      }
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

    final id = await db.insert(
      'leave_balances',
      balance.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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

    double totalLopDays = 0;

    final lopMaps = await db.query(
      'loss_of_pay_records',
      where: 'employee_id = ? AND date LIKE ?',
      whereArgs: [employeeId, suffix],
    );
    totalLopDays += lopMaps.length.toDouble();

    // Unauthorized Late Attendance records (0.5 LOP day each)
    try {
      final lateMaps = await db.query(
        'attendance_records',
        where: 'employee_id = ? AND status = ? AND date LIKE ?',
        whereArgs: [employeeId, 'Late', suffix],
      );
      totalLopDays += (lateMaps.length * 0.5);
    } catch (_) {}

    // Emergency Exception Permission Requests with LOP decision
    try {
      final permMaps = await db.query(
        'permission_requests',
        where: '(employee_id = ? OR employee_id = 0) AND LOWER(payroll_treatment) = ? AND date LIKE ?',
        whereArgs: [employeeId, 'lop', suffix],
      );
      totalLopDays += permMaps.length.toDouble();
    } catch (_) {}

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
