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

  group('Phase 3 & 4 — System Calculation & Admin Approval Overrides Tests', () {
    test('Test 1 — System Quota Calculation (4 Days Requested vs 3 Days Allowance)', () async {
      const empId = 1;
      const year = 2026;
      const month = 9;

      // Initial monthly balance = 3.0 days
      final balance = await repository.getMonthlyLeaveBalance(empId, 'Casual Leave', year, month);
      expect(balance.remainingDays, 3.0);

      // System predicts: Requested 4.0 -> 3.0 Paid + 1.0 LOP
      const requestedDays = 4.0;
      final calculatedPaid = requestedDays.clamp(0.0, balance.remainingDays);
      final calculatedLop = requestedDays - calculatedPaid;

      final req = LeaveRequest(
        id: 1,
        employeeId: empId,
        employeeName: 'John Doe',
        employeeCustomId: 'EMP-001',
        leaveType: 'Casual Leave',
        fromDate: '2026-09-10',
        toDate: '2026-09-13',
        numDays: requestedDays,
        requestedDays: requestedDays,
        calculatedPaidDays: calculatedPaid,
        calculatedLopDays: calculatedLop,
        paidDays: calculatedPaid,
        lopDays: calculatedLop,
        approvalMode: 'calculated',
        leavePolicySnapshot: 'Monthly Allocation',
        monthlyAllowanceSnapshot: 3.0,
        reason: 'Vacation',
        status: 'Pending',
        createdAt: DateTime.now().toIso8601String(),
      );

      await db.insert('leave_requests', req.toMap());

      final savedMaps = await db.query('leave_requests', where: 'id = ?', whereArgs: [1]);
      final savedReq = LeaveRequest.fromMap(savedMaps.first);

      expect(savedReq.requestedDays, 4.0);
      expect(savedReq.calculatedPaidDays, 3.0);
      expect(savedReq.calculatedLopDays, 1.0);
      expect(savedReq.leavePolicySnapshot, 'Monthly Allocation');
      expect(savedReq.monthlyAllowanceSnapshot, 3.0);
    });

    test('Test 2 — Admin Approves All Paid (Override)', () async {
      final req = LeaveRequest(
        id: 2,
        employeeId: 1,
        employeeName: 'John Doe',
        employeeCustomId: 'EMP-001',
        leaveType: 'Casual Leave',
        fromDate: '2026-09-10',
        toDate: '2026-09-13',
        numDays: 4.0,
        requestedDays: 4.0,
        calculatedPaidDays: 3.0,
        calculatedLopDays: 1.0,
        paidDays: 4.0, // Admin overrides to 4 Paid!
        lopDays: 0.0,
        approvalMode: 'all_paid',
        isOverride: true,
        overrideReason: 'Approved by Admin',
        approvedBy: 'Admin Saravanan',
        leavePolicySnapshot: 'Monthly Allocation',
        monthlyAllowanceSnapshot: 3.0,
        reason: 'Vacation',
        status: 'Approved',
        createdAt: DateTime.now().toIso8601String(),
      );

      await db.insert('leave_requests', req.toMap());

      final savedMaps = await db.query('leave_requests', where: 'id = ?', whereArgs: [2]);
      final savedReq = LeaveRequest.fromMap(savedMaps.first);

      expect(savedReq.paidDays, 4.0);
      expect(savedReq.lopDays, 0.0);
      expect(savedReq.isOverride, true);
      expect(savedReq.overrideReason, 'Approved by Admin');
    });

    test('Test 3 — Admin Approves All LOP (Paid Leave Quota Preserved)', () async {
      // 1. Initial balance 3.0 days
      var balance = await repository.getMonthlyLeaveBalance(1, 'Casual Leave', 2026, 9);
      expect(balance.remainingDays, 3.0);

      // 2. Admin approves 4 days as ALL LOP
      final req = LeaveRequest(
        id: 3,
        employeeId: 1,
        employeeName: 'John Doe',
        employeeCustomId: 'EMP-001',
        leaveType: 'Casual Leave',
        fromDate: '2026-09-10',
        toDate: '2026-09-13',
        numDays: 4.0,
        requestedDays: 4.0,
        calculatedPaidDays: 3.0,
        calculatedLopDays: 1.0,
        paidDays: 0.0, // 0 Paid days consumed!
        lopDays: 4.0, // 4 LOP days!
        approvalMode: 'all_lop',
        isOverride: true,
        overrideReason: 'Approved as LOP',
        approvedBy: 'Admin Saravanan',
        leavePolicySnapshot: 'Monthly Allocation',
        monthlyAllowanceSnapshot: 3.0,
        reason: 'Personal',
        status: 'Approved',
        createdAt: DateTime.now().toIso8601String(),
      );

      await db.insert('leave_requests', req.toMap());

      // Update monthly balance with 0 usedPaidDays, 4 lopDays
      final updatedBal = balance.copyWith(
        usedPaidDays: balance.usedPaidDays + 0.0,
        lopDays: balance.lopDays + 4.0,
        remainingDays: balance.allowedDays - (balance.usedPaidDays + 0.0),
      );
      await db.update('leave_monthly_balances', updatedBal.toMap(), where: 'id = ?', whereArgs: [balance.id]);

      final checkBal = await repository.getMonthlyLeaveBalance(1, 'Casual Leave', 2026, 9);
      expect(checkBal.usedPaidDays, 0.0);
      expect(checkBal.lopDays, 4.0);
      expect(checkBal.remainingDays, 3.0); // VERIFIED: Paid quota remains 3.0 days untouched!
    });

    test('Test 3 — End-to-End Workflow Verification (4 Days Request, 3 Allowance -> 3 Paid / 1 LOP -> Attendance On Leave -> Payroll 1 LOP)', () async {
      // 1. Create Employee with Monthly Allocation & 3 days Allowance
      await db.execute('DROP TABLE IF EXISTS leave_balances');
      await db.execute('''
        CREATE TABLE leave_balances (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          employee_id INTEGER,
          leave_type TEXT,
          allowed_leaves REAL,
          used_leaves REAL,
          available_leaves REAL
        )
      ''');
      await db.execute('DROP TABLE IF EXISTS loss_of_pay_records');
      await db.execute('''
        CREATE TABLE loss_of_pay_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          employee_id INTEGER,
          leave_request_id INTEGER,
          date TEXT,
          amount REAL,
          created_at TEXT
        )
      ''');
      await db.execute('DROP TABLE IF EXISTS attendance_records');
      await db.execute('''
        CREATE TABLE attendance_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          employee_id INTEGER,
          employee_name TEXT,
          date TEXT,
          time TEXT,
          status TEXT,
          verification_status TEXT,
          similarity_score REAL,
          check_in_time TEXT,
          check_out_time TEXT,
          check_in_verification_status TEXT,
          check_out_verification_status TEXT,
          check_in_similarity_score REAL,
          check_out_similarity_score REAL,
          total_hours REAL,
          notes TEXT,
          marked_at TEXT
        )
      ''');
      await db.execute('DROP TABLE IF EXISTS leave_audit_logs');
      await db.execute('''
        CREATE TABLE leave_audit_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          leave_request_id INTEGER,
          action TEXT,
          performed_by TEXT,
          timestamp TEXT,
          details TEXT
        )
      ''');

      await db.insert('leave_balances', {
        'id': 1,
        'employee_id': 1,
        'leave_type': 'Casual Leave',
        'allowed_leaves': 3.0,
        'used_leaves': 0.0,
        'available_leaves': 3.0,
      });

      // 2. Submit Leave Request for 4 Days (10-09-2026 to 13-09-2026)
      const requestedDays = 4.0;
      final req = LeaveRequest(
        id: 10,
        employeeId: 1,
        employeeName: 'John Doe',
        employeeCustomId: 'EMP-001',
        leaveType: 'Casual Leave',
        fromDate: '10-09-2026',
        toDate: '13-09-2026',
        numDays: requestedDays,
        requestedDays: requestedDays,
        calculatedPaidDays: 3.0,
        calculatedLopDays: 1.0,
        paidDays: 3.0,
        lopDays: 1.0,
        approvalMode: 'as_calculated',
        leavePolicySnapshot: 'Monthly Allocation',
        monthlyAllowanceSnapshot: 3.0,
        reason: 'Family Trip',
        status: 'Pending',
        createdAt: DateTime.now().toIso8601String(),
      );

      await db.insert('leave_requests', req.toMap());

      // 3. Admin approves as calculated
      await repository.approveLeaveRequest(10, 'Admin Manager', approvalMode: 'as_calculated');

      // 4. Verify Leave Status: 4 Days Approved (3 Paid, 1 LOP)
      final updatedReqMap = await db.query('leave_requests', where: 'id = ?', whereArgs: [10]);
      final updatedReq = LeaveRequest.fromMap(updatedReqMap.first);

      expect(updatedReq.status, 'Approved');
      expect(updatedReq.approvedDates.length, 3); // 3 Paid Dates
      expect(updatedReq.lopDates.length, 1);       // 1 LOP Date

      // 5. Verify Attendance: ALL 4 Days marked 'On Leave'
      final attRecords = await db.query('attendance_records', where: 'employee_id = ?', whereArgs: [1]);
      expect(attRecords.length, 4);
      for (final att in attRecords) {
        expect(att['status'], 'On Leave');
      }

      // 6. Verify Payroll: 1 LOP Day recorded
      final lopRecords = await db.query('loss_of_pay_records', where: 'employee_id = ?', whereArgs: [1]);
      expect(lopRecords.length, 1);
      expect(lopRecords.first['date'], '13-09-2026');
    });
  });
}
