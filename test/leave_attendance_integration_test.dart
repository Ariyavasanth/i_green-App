import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_application_1/features/attendance/data/sqlite_attendance_repository.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_record.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late SqliteAttendanceRepository repository;
  late Database db;

  setUp(() async {
    repository = SqliteAttendanceRepository();
    db = await repository.database;

    await db.delete('attendance_records');
    await db.delete('attendance_attempts');
    await db.execute('DROP TABLE IF EXISTS employees');
    await db.execute('CREATE TABLE employees (id INTEGER PRIMARY KEY AUTOINCREMENT, employee_code TEXT, required_working_hours REAL, is_dynamic_employee INTEGER)');
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

    await db.insert('employees', {
      'id': 1,
      'employee_code': 'EMP-001',
      'required_working_hours': 9.0,
      'is_dynamic_employee': 0,
    });
  });

  group('Phase 6 — Case 2 Half-Day Work & Attendance Integration Tests', () {
    test('Test 6 — Half-Day Leave + Complete Remaining Work (9:00-1:30 Leave, 1:30 Check-In, 6:00 Check-Out)', () async {
      const empId = 1;
      const date = '2026-09-20';

      // Approved First-Half Leave
      await db.insert('leave_requests', {
        'id': 20,
        'employee_id': empId,
        'employee_name': 'John Doe',
        'employee_custom_id': 'EMP-001',
        'leave_type': 'Casual Leave',
        'from_date': date,
        'to_date': date,
        'num_days': 0.5,
        'requested_days': 0.5,
        'paid_days': 0.5,
        'status': 'Approved',
        'approved_dates': '["$date"]',
        'is_half_day': 1,
        'half_day_period': 'first_half',
        'reason': 'Medical checkup',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Check-In at 13:30 (1:30 PM), Check-Out at 18:00 (6:00 PM)
      await repository.markAttendance(
        employeeId: empId,
        employeeName: 'John Doe',
        date: date,
        time: '13:30',
        verificationStatus: 'Verified',
        similarityScore: 0.98,
        status: 'Present',
        notes: 'Half-Day check-in',
      );

      await repository.checkOut(
        employeeId: empId,
        date: date,
        checkOutTime: '18:00',
        verificationStatus: 'Verified',
        similarityScore: 0.98,
      );

      final record = await repository.getAttendanceRecordForDate(empId, date);

      expect(record, isNotNull);
      expect(record!.checkInTime, '13:30');
      expect(record.checkOutTime, '18:00');
      expect(record.totalHours, 4.5);
      expect(record.status, isNot(equals('Absent')));
      expect(record.status, isNot(equals('Missing Check-Out')));
    });

    test('Test 7 — Half-Day Leave + Late Check-In to Remaining Work (Check-In at 2:00 PM)', () async {
      const empId = 1;
      const date = '2026-09-21';

      // Approved First-Half Leave (expected work starts at 1:30 PM)
      await db.insert('leave_requests', {
        'id': 21,
        'employee_id': empId,
        'employee_name': 'John Doe',
        'employee_custom_id': 'EMP-001',
        'leave_type': 'Casual Leave',
        'from_date': date,
        'to_date': date,
        'num_days': 0.5,
        'requested_days': 0.5,
        'paid_days': 0.5,
        'status': 'Approved',
        'approved_dates': '["$date"]',
        'is_half_day': 1,
        'half_day_period': 'first_half',
        'reason': 'Medical checkup',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Employee arrives late at 14:00 (2:00 PM) instead of 13:30 (1:30 PM)
      await repository.markAttendance(
        employeeId: empId,
        employeeName: 'John Doe',
        date: date,
        time: '14:00',
        verificationStatus: 'Verified',
        similarityScore: 0.98,
        status: 'Present',
        notes: 'Late for remaining shift',
      );

      await repository.checkOut(
        employeeId: empId,
        date: date,
        checkOutTime: '18:00',
        verificationStatus: 'Verified',
        similarityScore: 0.98,
      );

      final record = await repository.getAttendanceRecordForDate(empId, date);

      expect(record, isNotNull);
      expect(record!.checkInTime, '14:00');
      expect(record.checkOutTime, '18:00');
      expect(record.totalHours, 4.0);
    });

    test('Test 8 — Half-Day Leave + Early Check-Out from Remaining Work (Check-Out at 5:00 PM)', () async {
      const empId = 1;
      const date = '2026-09-22';

      // Approved First-Half Leave
      await db.insert('leave_requests', {
        'id': 22,
        'employee_id': empId,
        'employee_name': 'John Doe',
        'employee_custom_id': 'EMP-001',
        'leave_type': 'Casual Leave',
        'from_date': date,
        'to_date': date,
        'num_days': 0.5,
        'requested_days': 0.5,
        'paid_days': 0.5,
        'status': 'Approved',
        'approved_dates': '["$date"]',
        'is_half_day': 1,
        'half_day_period': 'first_half',
        'reason': 'Medical checkup',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Check-in on time at 13:30 (1:30 PM), check-out early at 17:00 (5:00 PM)
      await repository.markAttendance(
        employeeId: empId,
        employeeName: 'John Doe',
        date: date,
        time: '13:30',
        verificationStatus: 'Verified',
        similarityScore: 0.98,
        status: 'Present',
        notes: 'Check-in on time',
      );

      await repository.checkOut(
        employeeId: empId,
        date: date,
        checkOutTime: '17:00',
        verificationStatus: 'Verified',
        similarityScore: 0.98,
      );

      final record = await repository.getAttendanceRecordForDate(empId, date);

      expect(record, isNotNull);
      expect(record!.checkInTime, '13:30');
      expect(record.checkOutTime, '17:00');
      expect(record.totalHours, 3.5);
    });
  });
}
