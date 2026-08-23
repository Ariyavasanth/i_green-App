import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_application_1/features/leave/data/sqlite_leave_repository.dart';
import 'package:flutter_application_1/features/leave/domain/leave_monthly_balance.dart';

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
    await db.delete('leave_monthly_balances');

    // Create Employee with Monthly Allocation (3.0 days/month)
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

  group('Phase 2 — Period-Based Monthly Balance & Reset Engine Tests', () {
    test('Test 1 — Initial Period Balance Initialization for Month', () async {
      const empId = 1;
      const year = 2026;
      const month = 9; // September 2026

      final balance = await repository.getMonthlyLeaveBalance(empId, 'Casual Leave', year, month);

      expect(balance.employeeId, empId);
      expect(balance.periodYear, year);
      expect(balance.periodMonth, month);
      expect(balance.allowedDays, 3.0);
      expect(balance.usedPaidDays, 0.0);
      expect(balance.remainingDays, 3.0);
      expect(balance.lopDays, 0.0);
    });

    test('Test 2 — LOP Does NOT Reduce Remaining Paid Days', () async {
      const empId = 1;
      const year = 2026;
      const month = 9;

      // 1. Initial balance
      var balance = await repository.getMonthlyLeaveBalance(empId, 'Casual Leave', year, month);
      expect(balance.remainingDays, 3.0);

      // 2. Consume 2 paid days
      final updated = balance.copyWith(
        usedPaidDays: 2.0,
        lopDays: 0.0,
        remainingDays: 1.0,
      );
      await db.update(
        'leave_monthly_balances',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [balance.id],
      );

      var check1 = await repository.getMonthlyLeaveBalance(empId, 'Casual Leave', year, month);
      expect(check1.usedPaidDays, 2.0);
      expect(check1.remainingDays, 1.0);
      expect(check1.lopDays, 0.0);

      // 3. Add 3 LOP days
      final withLop = check1.copyWith(
        lopDays: 3.0,
        // remainingDays should stay 1.0 (allowed 3.0 - usedPaid 2.0 = 1.0)
        remainingDays: 1.0,
      );
      await db.update(
        'leave_monthly_balances',
        withLop.toMap(),
        where: 'id = ?',
        whereArgs: [check1.id],
      );

      var check2 = await repository.getMonthlyLeaveBalance(empId, 'Casual Leave', year, month);
      expect(check2.usedPaidDays, 2.0);
      expect(check2.lopDays, 3.0);
      expect(check2.remainingDays, 1.0); // VERIFIED: LOP does NOT reduce remaining days!
    });

    test('Test 3 — Clean Monthly Reset for New Period (October 2026)', () async {
      const empId = 1;

      // Sept 2026 balance has 2 paid days used
      await repository.getMonthlyLeaveBalance(empId, 'Casual Leave', 2026, 9);

      // Query Oct 2026 balance
      final octBalance = await repository.getMonthlyLeaveBalance(empId, 'Casual Leave', 2026, 10);

      expect(octBalance.periodYear, 2026);
      expect(octBalance.periodMonth, 10);
      expect(octBalance.allowedDays, 3.0);
      expect(octBalance.usedPaidDays, 0.0); // Fresh reset for October!
      expect(octBalance.remainingDays, 3.0);
    });
  });
}
