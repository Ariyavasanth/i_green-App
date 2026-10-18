import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/employee/domain/employee.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_record.dart';
import 'package:flutter_application_1/features/attendance/domain/monthly_attendance_result.dart';
import 'package:flutter_application_1/features/payroll/domain/payroll.dart';

void main() {
  group('Employee 5406 (Nithya Sri J) Attendance & LOP Calculation Tests', () {
    final employee5406 = Employee(
      id: 5406,
      employeeId: 'EMP-5406',
      firstName: 'Nithya Sri',
      lastName: 'J',
      emailAddress: 'nithya@igreen.com',
      phoneNumber: '9876543216',
      gender: 'Female',
      dob: '1998-04-12',
      organizationName: 'IGREEN TECHNOLOGIES',
      department: 'Execution',
      designation: 'Junior Engineer',
      employmentType: 'Full Time',
      joiningDate: '20-08-2026',
      status: 'Active',
      userType: 'EMPLOYEE',
      salaryType: 'Monthly',
      salaryBasic: 30000.0,
      salaryHra: 15000.0,
      salarySpecialAllowance: 15000.0,
      salaryTotalCtc: 60000.0,
      salaryPf: 1800.0,
      requiredWorkingHours: 9.0,
      weeklyOffDay: 'Sunday',
      inTime: '09:00',
      outTime: '18:00',
    );

    const settings = PayrollSettings(
      id: 1,
      payrollStartDay: 21,
      payrollEndDay: 20,
      workingDaysInMonth: 26.0,
      standardDailyWorkingHours: 9.0,
      penaltyPerLateDay: 0.5,
      allowedLateDays: 3,
    );

    test('Evaluates exact attendance and LOP hours for Employee 5406 in September cycle', () {
      final period = settings.getPayrollPeriod(2026, 9); // 21-08-2026 to 20-09-2026

      final records = <AttendanceRecord>[
        // 2 Absent days (0.0 hrs, 9 hrs shortfall each = 18 hrs)
        const AttendanceRecord(
          id: 1,
          employeeId: 5406,
          employeeCode: 'EMP-5406',
          employeeName: 'Nithya Sri J',
          date: '28-08-2026',
          time: '',
          status: 'Absent',
          verificationStatus: 'Unverified',
          similarityScore: 0.0,
          totalHours: 0.0,
        ),
        const AttendanceRecord(
          id: 2,
          employeeId: 5406,
          employeeCode: 'EMP-5406',
          employeeName: 'Nithya Sri J',
          date: '08-09-2026',
          time: '',
          status: 'Absent',
          verificationStatus: 'Unverified',
          similarityScore: 0.0,
          totalHours: 0.0,
        ),

        // 2 Insufficient hours days (5.5 hrs worked, 3.5 hrs shortfall each = 7 hrs)
        const AttendanceRecord(
          id: 3,
          employeeId: 5406,
          employeeCode: 'EMP-5406',
          employeeName: 'Nithya Sri J',
          date: '02-09-2026',
          time: '09:00:00',
          checkInTime: '09:00:00',
          checkOutTime: '14:30:00',
          status: 'Insufficient Hours',
          verificationStatus: 'Verified',
          similarityScore: 0.95,
          totalHours: 5.5,
        ),
        const AttendanceRecord(
          id: 4,
          employeeId: 5406,
          employeeCode: 'EMP-5406',
          employeeName: 'Nithya Sri J',
          date: '15-09-2026',
          time: '09:00:00',
          checkInTime: '09:00:00',
          checkOutTime: '14:30:00',
          status: 'Insufficient Hours',
          verificationStatus: 'Verified',
          similarityScore: 0.95,
          totalHours: 5.5,
        ),

        // 2 Late arrivals (8.4 hrs worked)
        const AttendanceRecord(
          id: 5,
          employeeId: 5406,
          employeeCode: 'EMP-5406',
          employeeName: 'Nithya Sri J',
          date: '25-08-2026',
          time: '09:35:00',
          checkInTime: '09:35:00',
          checkOutTime: '18:00:00',
          status: 'Late',
          verificationStatus: 'Verified',
          similarityScore: 0.96,
          totalHours: 8.42,
        ),
        const AttendanceRecord(
          id: 6,
          employeeId: 5406,
          employeeCode: 'EMP-5406',
          employeeName: 'Nithya Sri J',
          date: '11-09-2026',
          time: '09:40:00',
          checkInTime: '09:40:00',
          checkOutTime: '18:00:00',
          status: 'Late',
          verificationStatus: 'Verified',
          similarityScore: 0.96,
          totalHours: 8.33,
        ),

        // Regular Present Days (9 hrs full)
        for (final d in [
          '21-08-2026', '22-08-2026', '24-08-2026', '26-08-2026', '27-08-2026', '29-08-2026', '31-08-2026',
          '01-09-2026', '03-09-2026', '04-09-2026', '05-09-2026', '07-09-2026', '09-09-2026', '10-09-2026',
          '12-09-2026', '14-09-2026', '16-09-2026', '17-09-2026', '18-09-2026', '19-09-2026',
        ])
          AttendanceRecord(
            id: 100,
            employeeId: 5406,
            employeeCode: 'EMP-5406',
            employeeName: 'Nithya Sri J',
            date: d,
            time: '09:00:00',
            checkInTime: '09:00:00',
            checkOutTime: '18:00:00',
            status: 'Present',
            verificationStatus: 'Verified',
            similarityScore: 0.97,
            totalHours: 9.0,
          ),
      ];

      final result = MonthlyAttendanceCalculator.calculate(
        employee: employee5406,
        year: 2026,
        month: 9,
        records: records,
        startDate: period.startDate,
        endDateExclusive: period.endDateExclusive,
      );

      // Verify attendance counts
      expect(result.presentCount, 20);
      expect(result.lateCount, 2);
      expect(result.absentCount, 2);
      expect(result.insufficientHoursCount, 2);
      expect(result.weeklyOffCount, 5); // 5 Sundays in 21-Aug to 20-Sep
      expect(result.totalWorkingDays, 26);

      // Verify shortfall hours: 2 absent days * 9h (18h) + 2 insufficient days * 3.5h (7h) + late diffs = 26.25 hrs
      expect(result.totalShortfallHours, greaterThanOrEqualTo(25.0));

      // Calculate LOP deduction at hourly rate
      final scheduledHours = 26.0 * 9.0; // 234 hours
      final hourlyRate = 60000.0 / scheduledHours; // 256.41
      final lopAmount = result.totalShortfallHours * hourlyRate;

      expect(lopAmount, greaterThan(6400.0));
      expect(lopAmount, lessThan(6800.0));
    });
  });
}
