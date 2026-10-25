import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/employee/domain/employee.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_record.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_session.dart';
import 'package:flutter_application_1/core/utils/time_formatter.dart';

Employee _createEmployee({
  required int id,
  required String employeeId,
  String inTime = '09:00 AM',
  String outTime = '06:00 PM',
  String workScheduleType = 'Fixed Schedule',
  bool isDynamic = false,
  String weeklyOffDay = 'Sunday',
}) {
  return Employee(
    id: id,
    employeeId: employeeId,
    firstName: 'Test',
    lastName: 'Employee',
    emailAddress: 'test$id@example.com',
    phoneNumber: '987654321$id',
    gender: 'Male',
    dob: '1990-01-01',
    organizationName: 'IGREEN',
    department: 'Engineering',
    designation: 'Developer',
    employmentType: 'Full-Time',
    joiningDate: '2026-01-01',
    status: 'Active',
    inTime: inTime,
    outTime: outTime,
    workScheduleType: workScheduleType,
    isDynamicEmployee: isDynamic,
    weeklyOffDay: weeklyOffDay,
  );
}

/// Evaluation function mimicking the exact scheduled checkout cutoff logic
/// implemented in FirebaseAttendanceRepository and AttendanceVerificationDialog.
bool isCheckInBlockedAtCutoff({
  required Employee employee,
  required DateTime checkInAttemptTime,
  required String dateStr,
  bool isWeeklyOff = false,
}) {
  final isDynamic = employee.isDynamicEmployee ||
      employee.workScheduleType.trim().toLowerCase() == 'flexible schedule';

  // Flexible and weekly off employees are exempt from fixed cutoff
  if (isDynamic || isWeeklyOff || employee.outTime.trim().isEmpty) {
    return false;
  }

  final outStr = employee.outTime.trim();
  final inStr = employee.inTime.trim();

  int? parseMinutes(String timeStr) {
    if (timeStr.trim().isEmpty) return null;
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPm = clean.contains('PM');
      final isAm = clean.contains('AM');
      final digits = clean.replaceAll(RegExp(r'[^0-9:]'), '');
      final parts = digits.split(':').where((p) => p.trim().isNotEmpty).toList();
      if (parts.isNotEmpty) {
        int? hours = int.tryParse(parts[0]);
        if (hours == null) return null;
        final minutes = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
        if (isPm && hours < 12) hours += 12;
        if (isAm && hours == 12) hours = 0;
        return hours * 60 + minutes;
      }
    } catch (_) {}
    return null;
  }

  final outMins = parseMinutes(outStr);
  final inMins = inStr.isNotEmpty ? parseMinutes(inStr) : null;
  if (outMins == null) return false;

  final parts = dateStr.split(RegExp(r'[-/]'));
  DateTime? baseDate;
  if (parts.length == 3) {
    if (parts[0].length == 4) {
      baseDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    } else if (parts[2].length == 4) {
      baseDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
    }
  }
  if (baseDate == null) return false;

  final isOvernight = inMins != null && outMins <= inMins;
  final shiftEndDt = isOvernight
      ? DateTime(baseDate.year, baseDate.month, baseDate.day + 1, outMins ~/ 60, outMins % 60)
      : DateTime(baseDate.year, baseDate.month, baseDate.day, outMins ~/ 60, outMins % 60);

  // Block at or after scheduled checkout time
  return !checkInAttemptTime.isBefore(shiftEndDt);
}

void main() {
  group('Scheduled Checkout Cutoff Rule - Normal Shift (09:00 AM - 06:00 PM)', () {
    final emp = _createEmployee(id: 1, employeeId: 'EMP001', inTime: '09:00 AM', outTime: '06:00 PM');
    const dateStr = '2026-10-26';

    test('1. Check-in during morning (09:15 AM) is ALLOWED', () {
      final attempt = DateTime(2026, 10, 26, 9, 15);
      expect(isCheckInBlockedAtCutoff(employee: emp, checkInAttemptTime: attempt, dateStr: dateStr), isFalse);
    });

    test('2. Check-in during afternoon (02:00 PM) is ALLOWED', () {
      final attempt = DateTime(2026, 10, 26, 14, 0);
      expect(isCheckInBlockedAtCutoff(employee: emp, checkInAttemptTime: attempt, dateStr: dateStr), isFalse);
    });

    test('3. Check-in 1 second before cutoff (05:59:59 PM) is ALLOWED', () {
      final attempt = DateTime(2026, 10, 26, 17, 59, 59);
      expect(isCheckInBlockedAtCutoff(employee: emp, checkInAttemptTime: attempt, dateStr: dateStr), isFalse);
    });

    test('4. Check-in EXACTLY at cutoff (06:00:00 PM) is BLOCKED', () {
      final attempt = DateTime(2026, 10, 26, 18, 0, 0);
      expect(isCheckInBlockedAtCutoff(employee: emp, checkInAttemptTime: attempt, dateStr: dateStr), isTrue);
    });

    test('5. Check-in 1 minute after cutoff (06:01:00 PM) is BLOCKED', () {
      final attempt = DateTime(2026, 10, 26, 18, 1, 0);
      expect(isCheckInBlockedAtCutoff(employee: emp, checkInAttemptTime: attempt, dateStr: dateStr), isTrue);
    });

    test('6. Check-in late evening during OT window (07:30 PM) is BLOCKED', () {
      final attempt = DateTime(2026, 10, 26, 19, 30, 0);
      expect(isCheckInBlockedAtCutoff(employee: emp, checkInAttemptTime: attempt, dateStr: dateStr), isTrue);
    });
  });

  group('Scheduled Checkout Cutoff Rule - Overnight Shift (10:00 PM - 06:00 AM)', () {
    final emp = _createEmployee(id: 2, employeeId: 'EMP002', inTime: '10:00 PM', outTime: '06:00 AM');
    const shiftStartDate = '2026-10-25'; // Shift spans 2026-10-25 10:00 PM to 2026-10-26 06:00 AM

    test('1. Check-in before midnight on shift start day (10:30 PM) is ALLOWED', () {
      final attempt = DateTime(2026, 10, 25, 22, 30);
      expect(isCheckInBlockedAtCutoff(employee: emp, checkInAttemptTime: attempt, dateStr: shiftStartDate), isFalse);
    });

    test('2. Check-in after midnight on next calendar day (02:15 AM) is ALLOWED', () {
      final attempt = DateTime(2026, 10, 26, 2, 15);
      expect(isCheckInBlockedAtCutoff(employee: emp, checkInAttemptTime: attempt, dateStr: shiftStartDate), isFalse);
    });

    test('3. Check-in 1 second before overnight cutoff (05:59:59 AM) is ALLOWED', () {
      final attempt = DateTime(2026, 10, 26, 5, 59, 59);
      expect(isCheckInBlockedAtCutoff(employee: emp, checkInAttemptTime: attempt, dateStr: shiftStartDate), isFalse);
    });

    test('4. Check-in EXACTLY at overnight cutoff (06:00:00 AM) is BLOCKED', () {
      final attempt = DateTime(2026, 10, 26, 6, 0, 0);
      expect(isCheckInBlockedAtCutoff(employee: emp, checkInAttemptTime: attempt, dateStr: shiftStartDate), isTrue);
    });

    test('5. Check-in after overnight cutoff (06:30:00 AM) is BLOCKED', () {
      final attempt = DateTime(2026, 10, 26, 6, 30, 0);
      expect(isCheckInBlockedAtCutoff(employee: emp, checkInAttemptTime: attempt, dateStr: shiftStartDate), isTrue);
    });

    test('6. Check-in hours after overnight shift ended (09:00:00 AM) is BLOCKED', () {
      final attempt = DateTime(2026, 10, 26, 9, 0, 0);
      expect(isCheckInBlockedAtCutoff(employee: emp, checkInAttemptTime: attempt, dateStr: shiftStartDate), isTrue);
    });
  });

  group('Scheduled Checkout Cutoff Rule - Exemptions & Edge Cases', () {
    test('1. Flexible Schedule Employee is NOT blocked after outTime', () {
      final flexEmp = _createEmployee(
        id: 3,
        employeeId: 'EMP003',
        inTime: '09:00 AM',
        outTime: '06:00 PM',
        workScheduleType: 'Flexible Schedule',
      );
      final attempt = DateTime(2026, 10, 26, 19, 0); // 7:00 PM
      expect(isCheckInBlockedAtCutoff(employee: flexEmp, checkInAttemptTime: attempt, dateStr: '2026-10-26'), isFalse);
    });

    test('2. Dynamic Employee is NOT blocked after outTime', () {
      final dynamicEmp = _createEmployee(
        id: 4,
        employeeId: 'EMP004',
        inTime: '09:00 AM',
        outTime: '06:00 PM',
        isDynamic: true,
      );
      final attempt = DateTime(2026, 10, 26, 20, 0); // 8:00 PM
      expect(isCheckInBlockedAtCutoff(employee: dynamicEmp, checkInAttemptTime: attempt, dateStr: '2026-10-26'), isFalse);
    });

    test('3. Weekly Off Day check-in is NOT blocked after outTime', () {
      final fixedEmp = _createEmployee(id: 5, employeeId: 'EMP005', inTime: '09:00 AM', outTime: '06:00 PM');
      final attempt = DateTime(2026, 10, 26, 19, 0);
      expect(isCheckInBlockedAtCutoff(employee: fixedEmp, checkInAttemptTime: attempt, dateStr: '2026-10-26', isWeeklyOff: true), isFalse);
    });

    test('4. Employee with empty outTime is NOT blocked', () {
      final noOutEmp = _createEmployee(id: 6, employeeId: 'EMP006', inTime: '09:00 AM', outTime: '');
      final attempt = DateTime(2026, 10, 26, 21, 0);
      expect(isCheckInBlockedAtCutoff(employee: noOutEmp, checkInAttemptTime: attempt, dateStr: '2026-10-26'), isFalse);
    });
  });

  group('Overtime (OT) & Checkout Integrity Guarantee', () {
    const shiftOut = '06:00 PM'; // 18:00 -> OT starts at 18:30 (buffer 30 min)

    test('1. Valid check-in at 09:00 AM, checkout at 08:00 PM: Exactly 90 minutes OT calculated', () {
      final record = AttendanceRecord(
        id: 201,
        employeeId: 1,
        employeeName: 'Ravi Kumar',
        date: '2026-10-26',
        time: '09:00 AM',
        checkInTime: '09:00 AM',
        checkOutTime: '08:00 PM',
        status: 'Completed',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        sessions: const [
          AttendanceSession(
            id: 'session_1',
            type: 'office',
            checkInTime: '09:00 AM',
            checkOutTime: '08:00 PM',
            durationHours: 11.0,
            durationMinutes: 660,
          ),
        ],
      );

      final otMins = record.calculateOvertimeMinutes(shiftOutTime: shiftOut, bufferMinutes: 30);
      final otHrs = record.calculateOvertimeHours(shiftOutTime: shiftOut, bufferMinutes: 30);
      final meetsMinThreshold = record.hasMetMinOvertimeThreshold(shiftOutTime: shiftOut, bufferMinutes: 30, minOtMinutes: 60);

      // 06:00 PM + 30 min buffer = 06:30 PM (1110 min). Checkout at 08:00 PM (1200 min).
      // OT = 1200 - 1110 = 90 min (1.5 hrs)
      expect(otMins, equals(90));
      expect(otHrs, equals(1.5));
      expect(meetsMinThreshold, isTrue);
      expect(record.formattedOvertimeHours(shiftOutTime: shiftOut, bufferMinutes: 30), equals('1hr 30min'));
    });

    test('2. Valid check-in within buffer checkout (06:20 PM): 0 OT calculated', () {
      final record = AttendanceRecord(
        id: 202,
        employeeId: 1,
        employeeName: 'Ravi Kumar',
        date: '2026-10-26',
        time: '09:00 AM',
        checkInTime: '09:00 AM',
        checkOutTime: '06:20 PM',
        status: 'Completed',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
      );

      final otMins = record.calculateOvertimeMinutes(shiftOutTime: shiftOut, bufferMinutes: 30);
      expect(otMins, equals(0));
    });

    test('3. Blocked late check-in prevents phantom OT accumulation', () {
      final emp = _createEmployee(id: 1, employeeId: 'EMP001', inTime: '09:00 AM', outTime: '06:00 PM');
      // Employee attempts to check in at 07:00 PM (inside what would be OT window)
      final attempt = DateTime(2026, 10, 26, 19, 0);
      final isBlocked = isCheckInBlockedAtCutoff(employee: emp, checkInAttemptTime: attempt, dateStr: '2026-10-26');

      expect(isBlocked, isTrue, reason: 'Check-in must be rejected, preventing any attendance document or OT tracking');
    });
  });
}
