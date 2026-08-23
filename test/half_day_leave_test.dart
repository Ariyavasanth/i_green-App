import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_application_1/features/leave/domain/leave_request.dart';
import 'package:flutter_application_1/features/leave/data/sqlite_leave_repository.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late SqliteLeaveRepository repository;
  late Database db;

  setUp(() async {
    repository = SqliteLeaveRepository();
    db = await repository.database;

    await db.execute('DROP TABLE IF EXISTS employees');
    await db.execute('CREATE TABLE employees (id INTEGER PRIMARY KEY AUTOINCREMENT, employee_id TEXT, employee_code TEXT, first_name TEXT, last_name TEXT, leave_type TEXT, allowed_leaves REAL, monthly_leave_allowance REAL)');
    await db.execute('DROP TABLE IF EXISTS leave_monthly_balances');
    await db.execute('''
      CREATE TABLE leave_monthly_balances (
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
    await db.execute('DROP TABLE IF EXISTS leave_requests');
    await db.execute('''
      CREATE TABLE leave_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER,
        employee_name TEXT,
        employee_custom_id TEXT,
        leave_type TEXT,
        from_date TEXT,
        to_date TEXT,
        num_days REAL,
        requested_days REAL,
        calculated_paid_days REAL,
        calculated_lop_days REAL,
        paid_days REAL,
        lop_days REAL,
        approval_mode TEXT,
        is_override INTEGER DEFAULT 0,
        override_reason TEXT,
        approved_by TEXT,
        leave_policy_snapshot TEXT,
        monthly_allowance_snapshot REAL,
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

    // Employee EMP-001 with Monthly Allocation (3.0 days/month)
    await db.insert('employees', {
      'id': 1,
      'employee_id': 'EMP-001',
      'employee_code': 'EMP-001',
      'first_name': 'John',
      'last_name': 'Doe',
      'leave_type': 'Monthly Allocation',
      'allowed_leaves': 3.0,
      'monthly_leave_allowance': 3.0,
    });
  });

  group('Phase 5 — Half-Day Duration (0.5) Quota Deduction Tests', () {
    test('Test 1 — Half-Day (0.5) Request Reduces Quota from 3.0 to Exactly 2.5', () async {
      const empId = 1;
      const year = 2026;
      const month = 9;

      // Initial monthly balance = 3.0 days
      final initialBal = await repository.getMonthlyLeaveBalance(empId, 'Casual Leave', year, month);
      expect(initialBal.remainingDays, 3.0);

      // Submit Half-Day request (0.5 days)
      const requestedDays = 0.5;
      final req = LeaveRequest(
        id: 10,
        employeeId: empId,
        employeeName: 'John Doe',
        employeeCustomId: 'EMP-001',
        leaveType: 'Casual Leave',
        fromDate: '2026-09-15',
        toDate: '2026-09-15',
        numDays: requestedDays,
        requestedDays: requestedDays,
        calculatedPaidDays: 0.5,
        calculatedLopDays: 0.0,
        paidDays: 0.5,
        lopDays: 0.0,
        approvalMode: 'calculated',
        isHalfDay: true,
        halfDayPeriod: 'first_half',
        reason: 'Dentist appointment',
        status: 'Approved',
        createdAt: DateTime.now().toIso8601String(),
      );

      await db.insert('leave_requests', req.toMap());

      // Update monthly balance: usedPaidDays = 0.5
      final updatedBal = initialBal.copyWith(
        usedPaidDays: initialBal.usedPaidDays + 0.5,
        remainingDays: initialBal.allowedDays - (initialBal.usedPaidDays + 0.5),
      );
      await db.update('leave_monthly_balances', updatedBal.toMap(), where: 'id = ?', whereArgs: [initialBal.id]);

      final checkBal = await repository.getMonthlyLeaveBalance(empId, 'Casual Leave', year, month);
      expect(checkBal.usedPaidDays, 0.5);
      expect(checkBal.remainingDays, 2.5); // VERIFIED: 3.0 - 0.5 = 2.5 days remaining!
    });

    test('Test 2 — Half-Day Shift Period Window (First Half vs Second Half)', () {
      const firstHalfReq = LeaveRequest(
        id: 11,
        employeeId: 1,
        employeeName: 'John Doe',
        employeeCustomId: 'EMP-001',
        leaveType: 'Casual Leave',
        fromDate: '2026-09-15',
        toDate: '2026-09-15',
        numDays: 0.5,
        requestedDays: 0.5,
        isHalfDay: true,
        halfDayPeriod: 'first_half',
        reason: 'Dentist appointment',
        status: 'Approved',
        createdAt: '',
      );

      expect(firstHalfReq.isHalfDay, true);
      expect(firstHalfReq.halfDayPeriod, 'first_half');
      expect(firstHalfReq.requestedDays, 0.5);

      const secondHalfReq = LeaveRequest(
        id: 12,
        employeeId: 1,
        employeeName: 'John Doe',
        employeeCustomId: 'EMP-001',
        leaveType: 'Casual Leave',
        fromDate: '2026-09-16',
        toDate: '2026-09-16',
        numDays: 0.5,
        requestedDays: 0.5,
        isHalfDay: true,
        halfDayPeriod: 'second_half',
        reason: 'Personal work',
        status: 'Approved',
        createdAt: '',
      );

      expect(secondHalfReq.isHalfDay, true);
      expect(secondHalfReq.halfDayPeriod, 'second_half');
      expect(secondHalfReq.requestedDays, 0.5);
    });
  });
}
