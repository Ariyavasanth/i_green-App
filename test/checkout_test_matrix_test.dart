import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_application_1/features/attendance/data/sqlite_attendance_repository.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_record.dart';

void main() {
  // Initialize FFI for SQLite tests in Flutter test environment
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late SqliteAttendanceRepository repository;
  late Database db;

  setUp(() async {
    repository = SqliteAttendanceRepository();
    db = await repository.database;
    // Clear attendance_records, attendance_attempts, permission_requests, employees before each test
    await db.delete('attendance_records');
    await db.delete('attendance_attempts');
    await db.execute('CREATE TABLE IF NOT EXISTS permission_requests (id INTEGER PRIMARY KEY AUTOINCREMENT, employee_id INTEGER, employee_code TEXT, date TEXT, duration_minutes INTEGER, status TEXT)');
    await db.delete('permission_requests');
    await db.execute('CREATE TABLE IF NOT EXISTS leave_requests (id INTEGER PRIMARY KEY AUTOINCREMENT, employee_id INTEGER, employee_name TEXT, employee_custom_id TEXT, leave_type TEXT, from_date TEXT, to_date TEXT, num_days REAL, reason TEXT, status TEXT, created_at TEXT, approved_dates TEXT, lop_dates TEXT, is_emergency INTEGER DEFAULT 0, attachment_url TEXT, rejection_reason TEXT, is_half_day INTEGER DEFAULT 0, half_day_period TEXT)');
    await db.delete('leave_requests');
    await db.execute('CREATE TABLE IF NOT EXISTS employees (id INTEGER PRIMARY KEY AUTOINCREMENT, employee_code TEXT, required_working_hours REAL, is_dynamic_employee INTEGER)');
    await db.delete('employees');

    // Create standard employee EMP-001 with 9 required working hours
    await db.insert('employees', {
      'id': 1,
      'employee_code': 'EMP-001',
      'required_working_hours': 9.0,
      'is_dynamic_employee': 0,
    });
  });

  group('Complete Checkout Test Matrix', () {
    test('Scenario 1 — 9:00 -> 6:00 -> Expected: Normal Present', () async {
      const empId = 1;
      const date = '2026-08-17';

      // 1. Mark Check-in at 09:00
      await repository.markAttendance(
        employeeId: empId,
        employeeName: 'John Doe',
        date: date,
        time: '09:00',
        verificationStatus: 'Verified',
        similarityScore: 0.98,
        status: 'Present',
        notes: 'On time',
      );

      // 2. Check-out at 18:00 (6:00 PM)
      await repository.checkOut(
        employeeId: empId,
        date: date,
        checkOutTime: '18:00',
        verificationStatus: 'Verified',
        similarityScore: 0.98,
      );

      final record = await repository.getAttendanceRecordForDate(empId, date);
      expect(record, isNotNull);
      expect(record!.checkInTime, '09:00');
      expect(record.checkOutTime, '18:00');
      expect(record.totalHours, 9.0);
      expect(record.status, 'Completed');
      expect(record.notes, contains('Completed shift'));
    });

    test('Scenario 2 — 9:00 -> 5:00, no permission -> Expected: Early + unauthorized', () async {
      const empId = 1;
      const date = '2026-08-17';

      await repository.markAttendance(
        employeeId: empId,
        employeeName: 'John Doe',
        date: date,
        time: '09:00',
        verificationStatus: 'Verified',
        similarityScore: 0.98,
        status: 'Present',
        notes: 'On time',
      );

      // Check-out at 17:00 (5:00 PM) without permission
      await repository.checkOut(
        employeeId: empId,
        date: date,
        checkOutTime: '17:00',
        verificationStatus: 'Verified',
        similarityScore: 0.98,
      );

      final record = await repository.getAttendanceRecordForDate(empId, date);
      expect(record, isNotNull);
      expect(record!.totalHours, 8.0);
      expect(record.status, 'Insufficient hours');
      expect(record.notes, contains('60 mins unauthorized'));
    });

    test('Scenario 3 — 9:00 -> 5:00, 5-6 permission -> Expected: Early + authorized', () async {
      const empId = 1;
      const date = '2026-08-17';

      // Insert approved permission request for 5:00 - 6:00 (60 mins)
      await db.insert('permission_requests', {
        'employee_id': empId,
        'employee_code': 'EMP-001',
        'date': date,
        'duration_minutes': 60,
        'status': 'Approved',
      });

      await repository.markAttendance(
        employeeId: empId,
        employeeName: 'John Doe',
        date: date,
        time: '09:00',
        verificationStatus: 'Verified',
        similarityScore: 0.98,
        status: 'Present',
        notes: 'On time',
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
      expect(record!.totalHours, 8.0);
      expect(record.status, 'Completed');
      expect(record.notes, contains('Authorized early checkout (covers 60 mins)'));
    });

    test('Scenario 4 — 9:00 -> 5:00, 5-5:30 permission -> Expected: Partially authorized', () async {
      const empId = 1;
      const date = '2026-08-17';

      // Insert approved permission request for 5:00 - 5:30 (30 mins)
      await db.insert('permission_requests', {
        'employee_id': empId,
        'employee_code': 'EMP-001',
        'date': date,
        'duration_minutes': 30,
        'status': 'Approved',
      });

      await repository.markAttendance(
        employeeId: empId,
        employeeName: 'John Doe',
        date: date,
        time: '09:00',
        verificationStatus: 'Verified',
        similarityScore: 0.98,
        status: 'Present',
        notes: 'On time',
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
      expect(record!.totalHours, 8.0);
      expect(record.status, 'Insufficient hours');
      expect(record.notes, contains('Partially authorized: 30 mins authorized, 30 mins unauthorized'));
    });

    test('Scenario 5 — 9:00 -> 6:30 -> Expected: Late Checkout', () async {
      const empId = 1;
      const date = '2026-08-17';

      await repository.markAttendance(
        employeeId: empId,
        employeeName: 'John Doe',
        date: date,
        time: '09:00',
        verificationStatus: 'Verified',
        similarityScore: 0.98,
        status: 'Present',
        notes: 'On time',
      );

      // Check-out at 18:30 (6:30 PM) after standard shift end (18:00)
      await repository.checkOut(
        employeeId: empId,
        date: date,
        checkOutTime: '18:30',
        verificationStatus: 'Verified',
        similarityScore: 0.98,
      );

      final record = await repository.getAttendanceRecordForDate(empId, date);
      expect(record, isNotNull);
      expect(record!.totalHours, 9.5);
      expect(record.status, 'Completed');
      expect(record.notes, contains('Late Checkout'));
    });

    test('Scenario 6 — 9:00 -> no checkout -> Expected: Missing Checkout', () async {
      const empId = 1;
      const day1 = '2020-01-01'; // Past date to trigger auto-resolve

      await repository.markAttendance(
        employeeId: empId,
        employeeName: 'John Doe',
        date: day1,
        time: '09:00',
        verificationStatus: 'Verified',
        similarityScore: 0.98,
        status: 'Present',
        notes: 'On time',
      );

      // Run auto-resolution for missing check-outs
      await repository.autoResolveMissingCheckOuts(employeeId: empId);

      final record = await repository.getAttendanceRecordForDate(empId, day1);
      expect(record, isNotNull);
      expect(record!.checkOutTime, isEmpty);
      expect(record.status, 'Missing Check-Out');
      expect(record.totalHours, 0.0);
    });

    test('Scenario 7 — Day 1 missing -> Day 2 check-in -> Expected: Day 2 allowed', () async {
      const empId = 1;
      const day1 = '2020-01-01';
      final now = DateTime.now();
      final day2 = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // Day 1 check-in, missing checkout
      await repository.markAttendance(
        employeeId: empId,
        employeeName: 'John Doe',
        date: day1,
        time: '09:00',
        verificationStatus: 'Verified',
        similarityScore: 0.98,
        status: 'Present',
        notes: 'On time',
      );
      await repository.autoResolveMissingCheckOuts(employeeId: empId);

      final day1Record = await repository.getAttendanceRecordForDate(empId, day1);
      expect(day1Record?.status, 'Missing Check-Out');

      // Check if attendance exists for Day 2 before check-in
      final hasDay2Attendance = await repository.hasAttendanceForDate(empId, day2);
      expect(hasDay2Attendance, isFalse);

      // Mark check-in on Day 2
      await repository.markAttendance(
        employeeId: empId,
        employeeName: 'John Doe',
        date: day2,
        time: '09:00',
        verificationStatus: 'Verified',
        similarityScore: 0.98,
        status: 'Present',
        notes: 'On time',
      );

      final day2Record = await repository.getAttendanceRecordForDate(empId, day2);
      expect(day2Record, isNotNull);
      expect(day2Record!.status, 'Present');
      expect(day2Record.date, day2);
    });

    test('Scenario 8 — Admin corrects Day 1 -> Expected: Recalculate', () async {
      const empId = 1;
      const day1 = '2020-01-01';

      // Day 1 missing checkout state
      await repository.markAttendance(
        employeeId: empId,
        employeeName: 'John Doe',
        date: day1,
        time: '09:00',
        verificationStatus: 'Verified',
        similarityScore: 0.98,
        status: 'Present',
        notes: 'On time',
      );
      await repository.autoResolveMissingCheckOuts(employeeId: empId);

      final missingRecord = await repository.getAttendanceRecordForDate(empId, day1);
      expect(missingRecord?.status, 'Missing Check-Out');
      expect(missingRecord?.totalHours, 0.0);

      // Admin corrects Day 1 by adding checkout time 18:00
      final correctedRecord = missingRecord!.copyWith(
        checkOutTime: '18:00',
      );

      await repository.adminSaveAttendance(correctedRecord);

      final updatedRecord = await repository.getAttendanceRecordForDate(empId, day1);
      expect(updatedRecord, isNotNull);
      expect(updatedRecord!.checkOutTime, '18:00');
      expect(updatedRecord.totalHours, 9.0);
      expect(updatedRecord.status, 'Completed');
      expect(updatedRecord.notes, contains('Completed shift'));
    });

    test('Leave + Attendance Case 1 — Full-day approved leave (No Check-In, No Check-Out)', () async {
      const empId = 1;
      const leaveDate = '2020-01-05';

      // 1. Insert approved full-day leave request for employee
      await db.insert('leave_requests', {
        'id': 101,
        'employee_id': empId,
        'employee_name': 'John Doe',
        'employee_custom_id': 'EMP-001',
        'leave_type': 'Casual Leave',
        'from_date': leaveDate,
        'to_date': leaveDate,
        'num_days': 1.0,
        'reason': 'Personal work',
        'status': 'Approved',
        'created_at': DateTime.now().toIso8601String(),
        'approved_dates': '["$leaveDate"]',
        'lop_dates': '[]',
        'is_half_day': 0,
      });

      // 2. Run auto-resolution for missing check-outs
      await repository.autoResolveMissingCheckOuts(employeeId: empId);

      // 3. Retrieve attendance record for the leave date
      final record = await repository.getAttendanceRecordForDate(empId, leaveDate);

      expect(record, isNotNull);
      expect(record!.status, 'On Leave');
      expect(record.status, isNot(equals('Absent')));
      expect(record.status, isNot(equals('Missing Check-Out')));
      expect(record.checkInTime, isEmpty);
      expect(record.checkOutTime, isEmpty);
    });
  });
}
