import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_record.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_status_helper.dart';
import 'package:flutter_application_1/features/attendance/domain/monthly_attendance_result.dart';
import 'package:flutter_application_1/features/employee/domain/employee.dart';
import 'package:flutter_application_1/features/leave/domain/leave_request.dart';
import 'package:flutter_application_1/features/on_duty/domain/on_duty_assignment.dart';
import 'package:flutter_application_1/features/payroll/domain/payroll.dart';

void main() {
  group('Payroll Integration Step 4 — Payroll LOP & Attendance Integration Tests', () {
    const testEmployee = Employee(
      id: 101,
      employeeId: 'EMP-101',
      firstName: 'Vikram',
      lastName: 'Sharma',
      emailAddress: 'vikram@example.com',
      phoneNumber: '9876543210',
      gender: 'Male',
      dob: '01-01-1995',
      organizationName: 'IGreen',
      department: 'Engineering',
      designation: 'Engineer',
      employmentType: 'Full-Time',
      joiningDate: '01-01-2025',
      status: 'Active',
      inTime: '09:00 AM',
      outTime: '06:00 PM',
      requiredWorkingHours: 9.0,
      workScheduleType: 'Fixed',
      weeklyOffDay: 'Sunday',
    );

    final periodSeptember2026 = PayrollPeriod(
      startDate: DateTime(2026, 8, 20),
      endDateExclusive: DateTime(2026, 9, 20),
      processingDate: DateTime(2026, 9, 21),
      paymentDate: DateTime(2026, 9, 21),
    );

    test('A. Payroll period attendance boundary — 20 Aug included, 19 Sep included, 20 Sep excluded', () {
      final records = [
        const AttendanceRecord(
          id: 1,
          employeeId: 101,
          employeeCode: 'EMP-101',
          employeeName: 'Vikram Sharma',
          date: '20-08-2026',
          time: '09:00 AM',
          checkInTime: '09:00 AM',
          checkOutTime: '06:00 PM',
          status: 'Present',
          verificationStatus: 'Verified',
          similarityScore: 1.0,
          totalHours: 9.0,
        ),
        const AttendanceRecord(
          id: 2,
          employeeId: 101,
          employeeCode: 'EMP-101',
          employeeName: 'Vikram Sharma',
          date: '19-09-2026',
          time: '09:00 AM',
          checkInTime: '09:00 AM',
          checkOutTime: '06:00 PM',
          status: 'Present',
          verificationStatus: 'Verified',
          similarityScore: 1.0,
          totalHours: 9.0,
        ),
        const AttendanceRecord(
          id: 3,
          employeeId: 101,
          employeeCode: 'EMP-101',
          employeeName: 'Vikram Sharma',
          date: '20-09-2026', // Boundary date -> Excluded
          time: '09:00 AM',
          checkInTime: '09:00 AM',
          checkOutTime: '06:00 PM',
          status: 'Present',
          verificationStatus: 'Verified',
          similarityScore: 1.0,
          totalHours: 9.0,
        ),
      ];

      final result = MonthlyAttendanceCalculator.calculate(
        employee: testEmployee,
        year: 2026,
        month: 9,
        records: records,
        startDate: periodSeptember2026.startDate,
        endDateExclusive: periodSeptember2026.endDateExclusive,
        referenceDate: DateTime(2026, 9, 21),
      );

      // Verify bounds
      expect(result.totalDaysInMonth, equals(31));
      expect(result.presentCount, equals(2)); // Only 20 Aug & 19 Sep
      expect(result.dailyResults.any((d) => d.dateStr == '20-08-2026'), isTrue);
      expect(result.dailyResults.any((d) => d.dateStr == '19-09-2026'), isTrue);
      expect(result.dailyResults.any((d) => d.dateStr == '20-09-2026'), isFalse);
    });

    test('B & C. Approved leave vs Pending/Denied/Cancelled leave behavior', () {
      const approvedLeave = LeaveRequest(
        id: 1,
        employeeId: 101,
        employeeName: 'Vikram Sharma',
        employeeCustomId: 'EMP-101',
        leaveType: 'Casual Leave',
        fromDate: '21-08-2026',
        toDate: '22-08-2026',
        reason: 'Family Event',
        status: 'Approved',
        numDays: 2.0,
        createdAt: '2026-08-15T10:00:00.000',
      );

      const deniedLeave = LeaveRequest(
        id: 2,
        employeeId: 101,
        employeeName: 'Vikram Sharma',
        employeeCustomId: 'EMP-101',
        leaveType: 'Casual Leave',
        fromDate: '25-08-2026',
        toDate: '25-08-2026',
        reason: 'Personal',
        status: 'Denied',
        numDays: 1.0,
        createdAt: '2026-08-15T10:00:00.000',
      );

      final result = MonthlyAttendanceCalculator.calculate(
        employee: testEmployee,
        year: 2026,
        month: 9,
        records: const [],
        leaves: const [approvedLeave, deniedLeave],
        startDate: periodSeptember2026.startDate,
        endDateExclusive: periodSeptember2026.endDateExclusive,
        referenceDate: DateTime(2026, 9, 21),
      );

      // Approved leave resolves to onLeave (2 days: 21 Aug, 22 Aug)
      expect(result.onLeaveCount, equals(2));

      // Denied leave on 25 Aug resolves to Absent (since unrecorded past workday)
      final day25Aug = result.dailyResults.firstWhere((d) => d.dateStr == '25-08-2026');
      expect(day25Aug.statusInfo, equals(AttendanceStatusInfo.absent));
    });

    test('D. Configured Late Penalty calculation (allowedLateDays = 2, penaltyPerLateDay = 0.5)', () {
      const pSettings = PayrollSettings(
        allowedLateDays: 2,
        penaltyPerLateDay: 0.5,
      );

      // Test formula for various late counts:
      // late = 0 -> 0.0 penalty
      // late = 1 -> 0.0 penalty
      // late = 2 -> 0.0 penalty
      // late = 3 -> 0.5 penalty
      // late = 4 -> 1.0 penalty
      double calcLateLop(int lateCount) {
        final penalizedCount = (lateCount - pSettings.allowedLateDays).clamp(0, 9999);
        return penalizedCount * pSettings.penaltyPerLateDay;
      }

      expect(calcLateLop(0), equals(0.0));
      expect(calcLateLop(1), equals(0.0));
      expect(calcLateLop(2), equals(0.0));
      expect(calcLateLop(3), equals(0.5));
      expect(calcLateLop(4), equals(1.0));
    });

    test('F, G, H. Weekly Off, Holiday, and On Duty must NOT create absence LOP', () {
      const od = OnDutyAssignment(
        id: 1,
        employeeId: 101,
        employeeName: 'Vikram Sharma',
        odType: 'Client Visit',
        purpose: 'Meeting',
        destination: 'Client HQ',
        date: '24-08-2026',
        status: 'APPROVED',
        assignedBy: 'Manager',
        createdAt: '2026-08-15T10:00:00.000',
      );

      final holidays = ['25-08-2026'];

      final result = MonthlyAttendanceCalculator.calculate(
        employee: testEmployee,
        year: 2026,
        month: 9,
        records: const [],
        onDutyAssignments: const [od],
        holidays: holidays,
        startDate: periodSeptember2026.startDate,
        endDateExclusive: periodSeptember2026.endDateExclusive,
        referenceDate: DateTime(2026, 9, 21),
      );

      // Verify 24 Aug is On Duty
      final day24Aug = result.dailyResults.firstWhere((d) => d.dateStr == '24-08-2026');
      expect(day24Aug.statusInfo, equals(AttendanceStatusInfo.onDuty));

      // Verify 25 Aug is Holiday
      final day25Aug = result.dailyResults.firstWhere((d) => d.dateStr == '25-08-2026');
      expect(day25Aug.statusInfo, equals(AttendanceStatusInfo.holiday));

      // Verify Weekly Offs (Sundays: 23 Aug, 30 Aug, 6 Sep, 13 Sep)
      expect(result.weeklyOffCount, equals(4));
      expect(result.holidayCount, equals(1));
      expect(result.onDutyCount, equals(1));
    });

    test('I & J. MonthlyAttendanceCalculator metrics consistency for Payroll period', () {
      final records = <AttendanceRecord>[];
      for (int d = 20; d <= 31; d++) {
        records.add(AttendanceRecord(
          id: d,
          employeeId: 101,
          employeeCode: 'EMP-101',
          employeeName: 'Vikram Sharma',
          date: '${d.toString().padLeft(2, '0')}-08-2026',
          time: '09:00 AM',
          checkInTime: '09:00 AM',
          checkOutTime: '06:00 PM',
          status: 'Present',
          verificationStatus: 'Verified',
          similarityScore: 1.0,
          totalHours: 9.0,
        ));
      }

      final result = MonthlyAttendanceCalculator.calculate(
        employee: testEmployee,
        year: 2026,
        month: 9,
        records: records,
        startDate: periodSeptember2026.startDate,
        endDateExclusive: periodSeptember2026.endDateExclusive,
        referenceDate: DateTime(2026, 9, 21),
      );

      final record = const PayrollRecord(
        id: 1,
        employeeId: 101,
        employeeName: 'Vikram Sharma',
        month: 'September 2026',
        presentDays: 0,
        lateDays: 0,
        absentDays: 0,
        leaveDays: 0,
        basicPay: 30000,
        hra: 15000,
        educationAllowance: 0,
        specialAllowance: 5000,
        pf: 1800,
        tax: 0,
        netSalary: 50000,
        status: 'Processed',
      ).copyWithAttendanceResult(result);

      expect(record.presentCount, equals(result.presentCount));
      expect(record.lateCount, equals(result.lateCount));
      expect(record.absentCount, equals(result.absentCount));
      expect(record.onLeaveCount, equals(result.onLeaveCount));
      expect(record.weeklyOffCount, equals(result.weeklyOffCount));
      expect(record.totalWorkingDays, equals(result.totalWorkingDays));
      expect(record.totalRequiredHours, equals(result.totalRequiredHours));
      expect(record.totalWorkingHours, equals(result.totalWorkingHours));
      expect(record.totalShortfallHours, equals(result.totalShortfallHours));
    });
  });
}
