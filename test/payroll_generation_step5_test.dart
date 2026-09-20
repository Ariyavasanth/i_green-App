import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/employee/domain/employee.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_record.dart';
import 'package:flutter_application_1/features/attendance/domain/monthly_attendance_result.dart';
import 'package:flutter_application_1/features/leave/domain/leave_request.dart';
import 'package:flutter_application_1/features/payroll/domain/payroll.dart';

void main() {
  final sampleEmployee = Employee(
    id: 101,
    employeeId: 'EMP101',
    firstName: 'Ariya',
    lastName: 'Vasanth',
    emailAddress: 'ariya@example.com',
    phoneNumber: '9876543210',
    department: 'Product Development',
    designation: 'Senior Flutter Engineer',
    dob: '01-01-1995',
    employmentType: 'Full-Time',
    gender: 'Male',
    joiningDate: '01-01-2025',
    organizationName: 'IGreen',
    status: 'Active',
    salaryBasic: 50000,
    salaryHra: 20000,
    salarySpecialAllowance: 10000,
    requiredWorkingHours: 9.0,
    weeklyOffDay: 'Sunday',
  );

  const settings = PayrollSettings();

  group('Payroll Integration Step 5 — Generate Payroll & Phase 2C Attendance Tests', () {
    test('A. September 2026 Payroll Period bounds (20 Aug 2026 -> 20 Sep 2026 exclusive)', () {
      final period = settings.getPayrollPeriod(2026, 9);
      expect(period.startDate, DateTime(2026, 8, 20));
      expect(period.endDateExclusive, DateTime(2026, 9, 20));
      expect(period.processingDate, DateTime(2026, 9, 21));
      expect(period.paymentDate, DateTime(2026, 9, 21));
    });

    test('B. Boundary attendance: 19 Aug & 20 Sep excluded, 20 Aug & 19 Sep included', () {
      final period = settings.getPayrollPeriod(2026, 9);

      final records = [
        // Before period (19 Aug) - Present
        const AttendanceRecord(
          id: 1,
          employeeId: 101,
          employeeCode: 'EMP101',
          employeeName: 'Ariya Vasanth',
          date: '19-08-2026',
          time: '09:00 AM',
          checkInTime: '09:00 AM',
          checkOutTime: '06:00 PM',
          status: 'Present',
          verificationStatus: 'Verified',
          similarityScore: 1.0,
          totalHours: 9.0,
        ),
        // Start boundary (20 Aug) - Present
        const AttendanceRecord(
          id: 2,
          employeeId: 101,
          employeeCode: 'EMP101',
          employeeName: 'Ariya Vasanth',
          date: '20-08-2026',
          time: '09:00 AM',
          checkInTime: '09:00 AM',
          checkOutTime: '06:00 PM',
          status: 'Present',
          verificationStatus: 'Verified',
          similarityScore: 1.0,
          totalHours: 9.0,
        ),
        // End boundary inside (19 Sep) - Present
        const AttendanceRecord(
          id: 3,
          employeeId: 101,
          employeeCode: 'EMP101',
          employeeName: 'Ariya Vasanth',
          date: '19-09-2026',
          time: '09:00 AM',
          checkInTime: '09:00 AM',
          checkOutTime: '06:00 PM',
          status: 'Present',
          verificationStatus: 'Verified',
          similarityScore: 1.0,
          totalHours: 9.0,
        ),
        // Exclusive end boundary (20 Sep) - Present (must be excluded from Sep payroll)
        const AttendanceRecord(
          id: 4,
          employeeId: 101,
          employeeCode: 'EMP101',
          employeeName: 'Ariya Vasanth',
          date: '20-09-2026',
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
        employee: sampleEmployee,
        year: 2026,
        month: 9,
        records: records,
        startDate: period.startDate,
        endDateExclusive: period.endDateExclusive,
        referenceDate: period.endDateExclusive,
      );

      // Verify total days in 20 Aug -> 20 Sep range = 31 days
      expect(result.totalDaysInMonth, 31);

      // Verify dailyResults contains dates from 20-08-2026 to 19-09-2026
      final dates = result.dailyResults.map((d) => d.dateStr).toList();
      expect(dates.contains('19-08-2026'), isFalse, reason: '19 Aug must be excluded');
      expect(dates.contains('20-08-2026'), isTrue, reason: '20 Aug must be included');
      expect(dates.contains('19-09-2026'), isTrue, reason: '19 Sep must be included');
      expect(dates.contains('20-09-2026'), isFalse, reason: '20 Sep must be excluded');

      // Check Present count inside the boundary = 2 (20 Aug and 19 Sep)
      expect(result.presentCount, 2);
    });

    test('C & D. PayrollRecord receives all Phase 2C metrics from MonthlyAttendanceCalculator', () {
      final period = settings.getPayrollPeriod(2026, 9);

      final records = [
        const AttendanceRecord(
          id: 1,
          employeeId: 101,
          employeeCode: 'EMP101',
          employeeName: 'Ariya Vasanth',
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
          employeeCode: 'EMP101',
          employeeName: 'Ariya Vasanth',
          date: '21-08-2026',
          time: '10:00 AM',
          checkInTime: '10:00 AM',
          checkOutTime: '06:00 PM',
          status: 'Late',
          verificationStatus: 'Verified',
          similarityScore: 1.0,
          totalHours: 8.0,
        ),
      ];

      final leaves = [
        const LeaveRequest(
          id: 10,
          employeeId: 101,
          employeeName: 'Ariya Vasanth',
          employeeCustomId: 'EMP101',
          leaveType: 'Casual Leave',
          fromDate: '22-08-2026',
          toDate: '22-08-2026',
          reason: 'Personal',
          status: 'Approved',
          numDays: 1.0,
          createdAt: '2026-08-15T10:00:00.000',
        ),
      ];

      final attendanceResult = MonthlyAttendanceCalculator.calculate(
        employee: sampleEmployee,
        year: 2026,
        month: 9,
        records: records,
        leaves: leaves,
        startDate: period.startDate,
        endDateExclusive: period.endDateExclusive,
        referenceDate: period.endDateExclusive,
      );

      // Create standard record and attach attendanceResult via copyWithAttendanceResult
      final baseRecord = PayrollRecord(
        id: 1,
        employeeId: 101,
        employeeName: 'Ariya Vasanth',
        month: 'September 2026',
        presentDays: 0,
        lateDays: 0,
        absentDays: 0,
        leaveDays: 0,
        basicPay: 50000,
        hra: 20000,
        educationAllowance: 0,
        specialAllowance: 10000,
        pf: 1800,
        tax: 0,
        netSalary: 78200,
        status: 'Processed',
        periodStartDate: period.startDateFormatted,
        periodEndDate: period.endDateFormatted,
        processingDate: period.processingDateFormatted,
        paymentDate: period.paymentDateFormatted,
      );

      final payrollRecord = baseRecord.copyWithAttendanceResult(attendanceResult);

      // Verify exact 1-to-1 match with Phase 2C MonthlyAttendanceResult
      expect(payrollRecord.presentDays, attendanceResult.presentCount);
      expect(payrollRecord.presentCount, attendanceResult.presentCount);
      expect(payrollRecord.lateDays, attendanceResult.lateCount);
      expect(payrollRecord.lateCount, attendanceResult.lateCount);
      expect(payrollRecord.absentDays, attendanceResult.absentCount);
      expect(payrollRecord.absentCount, attendanceResult.absentCount);
      expect(payrollRecord.leaveDays, attendanceResult.onLeaveCount);
      expect(payrollRecord.onLeaveCount, attendanceResult.onLeaveCount);
      expect(payrollRecord.onDutyCount, attendanceResult.onDutyCount);
      expect(payrollRecord.weeklyOffCount, attendanceResult.weeklyOffCount);
      expect(payrollRecord.holidayCount, attendanceResult.holidayCount);
      expect(payrollRecord.missingCheckoutCount, attendanceResult.missingCheckoutCount);
      expect(payrollRecord.insufficientHoursCount, attendanceResult.insufficientHoursCount);
      expect(payrollRecord.totalWorkingDays, attendanceResult.totalWorkingDays);
      expect(payrollRecord.totalRequiredHours, attendanceResult.totalRequiredHours);
      expect(payrollRecord.totalWorkingHours, attendanceResult.totalWorkingHours);
      expect(payrollRecord.totalShortfallHours, attendanceResult.totalShortfallHours);
    });

    test('E & F. Approved leave remains On Leave and does not create absence LOP', () {
      final period = settings.getPayrollPeriod(2026, 9);

      final leaves = [
        const LeaveRequest(
          id: 11,
          employeeId: 101,
          employeeName: 'Ariya Vasanth',
          employeeCustomId: 'EMP101',
          leaveType: 'Earned Leave',
          fromDate: '24-08-2026',
          toDate: '25-08-2026',
          reason: 'Vacation',
          status: 'Approved',
          numDays: 2.0,
          createdAt: '2026-08-15T10:00:00.000',
        ),
      ];

      final result = MonthlyAttendanceCalculator.calculate(
        employee: sampleEmployee,
        year: 2026,
        month: 9,
        records: const [],
        leaves: leaves,
        startDate: period.startDate,
        endDateExclusive: period.endDateExclusive,
        referenceDate: period.endDateExclusive,
      );

      expect(result.onLeaveCount, 2);

      // Verify days 24 Aug and 25 Aug have status code 'OL'
      final day24 = result.dailyResults.firstWhere((d) => d.dateStr == '24-08-2026');
      final day25 = result.dailyResults.firstWhere((d) => d.dateStr == '25-08-2026');
      expect(day24.statusCode, 'OL');
      expect(day25.statusCode, 'OL');
    });

    test('G & H. Weekly Off and Holidays are stored correctly without becoming absence LOP', () {
      final period = settings.getPayrollPeriod(2026, 9);
      final holidays = ['25-08-2026']; // 1 Holiday

      final result = MonthlyAttendanceCalculator.calculate(
        employee: sampleEmployee,
        year: 2026,
        month: 9,
        records: const [],
        holidays: holidays,
        startDate: period.startDate,
        endDateExclusive: period.endDateExclusive,
        referenceDate: period.endDateExclusive,
      );

      expect(result.holidayCount, 1);
      expect(result.weeklyOffCount, greaterThan(0));

      final holidayDay = result.dailyResults.firstWhere((d) => d.dateStr == '25-08-2026');
      expect(holidayDay.statusCode, 'H');
      expect(holidayDay.isWorkingDay, isFalse);
    });
  });
}
