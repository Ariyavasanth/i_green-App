import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/attendance/domain/monthly_attendance_result.dart';
import 'package:flutter_application_1/features/payroll/domain/payroll.dart';

void main() {
  group('Payroll Integration Step 3 — PayrollRecord & Phase 2C Attendance Integration Tests', () {
    const sampleRecord = PayrollRecord(
      id: 1,
      employeeId: 101,
      employeeName: 'Vikram Sharma',
      month: 'September 2026',
      presentDays: 20,
      lateDays: 2,
      absentDays: 1,
      leaveDays: 2,
      onDutyCount: 1,
      weeklyOffCount: 4,
      holidayCount: 1,
      missingCheckoutCount: 1,
      insufficientHoursCount: 1,
      totalWorkingDays: 26,
      totalRequiredHours: 234.0,
      totalWorkingHours: 195.5,
      totalShortfallHours: 38.5,
      basicPay: 40000.0,
      hra: 20000.0,
      educationAllowance: 0.0,
      specialAllowance: 10000.0,
      pf: 1800.0,
      tax: 2500.0,
      netSalary: 65700.0,
      status: 'Processed',
    );

    test('A & G. PayrollRecord can store all Phase 2C attendance metrics and preserve numeric precision', () {
      expect(sampleRecord.presentCount, equals(20));
      expect(sampleRecord.presentDays, equals(20));
      expect(sampleRecord.lateCount, equals(2));
      expect(sampleRecord.lateDays, equals(2));
      expect(sampleRecord.absentCount, equals(1));
      expect(sampleRecord.absentDays, equals(1));
      expect(sampleRecord.onLeaveCount, equals(2));
      expect(sampleRecord.leaveDays, equals(2));

      expect(sampleRecord.onDutyCount, equals(1));
      expect(sampleRecord.weeklyOffCount, equals(4));
      expect(sampleRecord.holidayCount, equals(1));
      expect(sampleRecord.missingCheckoutCount, equals(1));
      expect(sampleRecord.insufficientHoursCount, equals(1));
      expect(sampleRecord.totalWorkingDays, equals(26));

      expect(sampleRecord.totalRequiredHours, equals(234.0));
      expect(sampleRecord.totalWorkingHours, equals(195.5));
      expect(sampleRecord.totalShortfallHours, equals(38.5));
    });

    test('B. toMap() correctly serializes all Phase 2C attendance fields', () {
      final map = sampleRecord.toMap();

      expect(map['present_days'], equals(20));
      expect(map['present_count'], equals(20));
      expect(map['late_days'], equals(2));
      expect(map['late_count'], equals(2));
      expect(map['absent_days'], equals(1));
      expect(map['absent_count'], equals(1));
      expect(map['leave_days'], equals(2));
      expect(map['on_leave_count'], equals(2));

      expect(map['on_duty_count'], equals(1));
      expect(map['weekly_off_count'], equals(4));
      expect(map['holiday_count'], equals(1));
      expect(map['missing_checkout_count'], equals(1));
      expect(map['insufficient_hours_count'], equals(1));
      expect(map['total_working_days'], equals(26));

      expect(map['total_required_hours'], equals(234.0));
      expect(map['total_working_hours'], equals(195.5));
      expect(map['total_shortfall_hours'], equals(38.5));
    });

    test('C. fromMap() correctly restores all Phase 2C attendance fields', () {
      final map = sampleRecord.toMap();
      final restored = PayrollRecord.fromMap(map);

      expect(restored.presentCount, equals(20));
      expect(restored.lateCount, equals(2));
      expect(restored.absentCount, equals(1));
      expect(restored.onLeaveCount, equals(2));

      expect(restored.onDutyCount, equals(1));
      expect(restored.weeklyOffCount, equals(4));
      expect(restored.holidayCount, equals(1));
      expect(restored.missingCheckoutCount, equals(1));
      expect(restored.insufficientHoursCount, equals(1));
      expect(restored.totalWorkingDays, equals(26));

      expect(restored.totalRequiredHours, equals(234.0));
      expect(restored.totalWorkingHours, equals(195.5));
      expect(restored.totalShortfallHours, equals(38.5));
    });

    test('D. copyWith() preserves and updates Phase 2C attendance fields', () {
      final updated = sampleRecord.copyWith(
        onDutyCount: 3,
        totalWorkingHours: 210.0,
        totalShortfallHours: 24.0,
      );

      expect(updated.onDutyCount, equals(3));
      expect(updated.totalWorkingHours, equals(210.0));
      expect(updated.totalShortfallHours, equals(24.0));

      // Unchanged fields remain preserved
      expect(updated.presentCount, equals(20));
      expect(updated.weeklyOffCount, equals(4));
      expect(updated.totalRequiredHours, equals(234.0));
    });

    test('E. Backward Compatibility: Legacy PayrollRecord data without Phase 2C fields loads safely with defaults', () {
      final legacyMap = <String, dynamic>{
        'id': 99,
        'employee_id': 101,
        'employee_name': 'Legacy Employee',
        'month': 'June 2026',
        'present_days': 22,
        'late_days': 1,
        'absent_days': 2,
        'leave_days': 5,
        'basic_pay': 30000.0,
        'hra': 15000.0,
        'education_allowance': 0.0,
        'special_allowance': 5000.0,
        'pf': 1800.0,
        'tax': 0.0,
        'netSalary': 48200.0,
        'status': 'Paid',
      };

      final legacyRecord = PayrollRecord.fromMap(legacyMap);

      expect(legacyRecord.presentDays, equals(22));
      expect(legacyRecord.presentCount, equals(22));
      expect(legacyRecord.lateDays, equals(1));
      expect(legacyRecord.absentDays, equals(2));
      expect(legacyRecord.leaveDays, equals(5));

      // Defaults for missing Phase 2C metrics
      expect(legacyRecord.onDutyCount, equals(0));
      expect(legacyRecord.weeklyOffCount, equals(0));
      expect(legacyRecord.holidayCount, equals(0));
      expect(legacyRecord.missingCheckoutCount, equals(0));
      expect(legacyRecord.insufficientHoursCount, equals(0));
      expect(legacyRecord.totalWorkingDays, equals(0));
      expect(legacyRecord.totalRequiredHours, equals(0.0));
      expect(legacyRecord.totalWorkingHours, equals(0.0));
      expect(legacyRecord.totalShortfallHours, equals(0.0));
    });

    test('H. copyWithAttendanceResult directly maps MonthlyAttendanceResult to PayrollRecord accurately', () {
      const attendanceResult = MonthlyAttendanceResult(
        employeeId: 101,
        employeeCode: 'EMP-101',
        employeeName: 'Vikram Sharma',
        year: 2026,
        month: 9,
        monthYear: '09-2026',
        totalDaysInMonth: 31,
        presentCount: 22,
        lateCount: 3,
        absentCount: 1,
        onLeaveCount: 2,
        onDutyCount: 1,
        weeklyOffCount: 4,
        holidayCount: 1,
        missingCheckoutCount: 1,
        insufficientHoursCount: 1,
        totalWorkingDays: 26,
        totalRequiredHours: 234.0,
        totalWorkingHours: 212.5,
        totalShortfallHours: 21.5,
        dailyResults: [],
      );

      const baseRecord = PayrollRecord(
        id: 10,
        employeeId: 101,
        employeeName: 'Vikram Sharma',
        month: 'September 2026',
        presentDays: 0,
        lateDays: 0,
        absentDays: 0,
        leaveDays: 0,
        basicPay: 40000.0,
        hra: 20000.0,
        educationAllowance: 0.0,
        specialAllowance: 10000.0,
        pf: 1800.0,
        tax: 2500.0,
        netSalary: 65700.0,
        status: 'Draft',
      );

      final updatedRecord = baseRecord.copyWithAttendanceResult(attendanceResult);

      expect(updatedRecord.presentCount, equals(22));
      expect(updatedRecord.presentDays, equals(22));
      expect(updatedRecord.lateCount, equals(3));
      expect(updatedRecord.absentCount, equals(1));
      expect(updatedRecord.onLeaveCount, equals(2));
      expect(updatedRecord.onDutyCount, equals(1));
      expect(updatedRecord.weeklyOffCount, equals(4));
      expect(updatedRecord.holidayCount, equals(1));
      expect(updatedRecord.missingCheckoutCount, equals(1));
      expect(updatedRecord.insufficientHoursCount, equals(1));
      expect(updatedRecord.totalWorkingDays, equals(26));
      expect(updatedRecord.totalRequiredHours, equals(234.0));
      expect(updatedRecord.totalWorkingHours, equals(212.5));
      expect(updatedRecord.totalShortfallHours, equals(21.5));
    });
  });
}
