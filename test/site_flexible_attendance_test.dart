import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/employee/domain/employee.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_record.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_session.dart';
import 'package:flutter_application_1/features/attendance/domain/monthly_attendance_result.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_status_helper.dart';

void main() {
  group('Flexible / Site Employee Attendance Tests', () {
    final flexibleEmployee = Employee(
      id: 101,
      employeeId: 'SITE001',
      firstName: 'Site',
      lastName: 'Worker',
      emailAddress: 'site@example.com',
      phoneNumber: '9876543210',
      gender: 'Male',
      dob: '1990-01-01',
      organizationName: 'I-Green',
      department: 'Site Operations',
      designation: 'Site Engineer',
      employmentType: 'Full Time',
      joiningDate: '01-01-2026',
      status: 'Active',
      workScheduleType: 'Flexible Schedule',
      isDynamicEmployee: true,
      isStaticEmployee: false,
      requiredWorkingHours: 9.0,
      siteLatitude: 12.9716,
      siteLongitude: 77.5946,
      siteAllowedRadiusMeters: 50,
      siteRequireGpsVerification: true,
    );

    test('1. Daytime 9:00 AM -> 6:00 PM yields 9 hours completed with no OT', () {
      final session = AttendanceSession(
        checkInTime: '09:00:00 AM',
        checkOutTime: '06:00:00 PM',
      );
      expect(session.effectiveDurationHours, 9.0);

      final record = AttendanceRecord(
        id: 1,
        employeeId: flexibleEmployee.id,
        employeeCode: flexibleEmployee.employeeId,
        employeeName: flexibleEmployee.fullName,
        date: '03-10-2026',
        time: '09:00:00 AM',
        checkInTime: '09:00:00 AM',
        checkOutTime: '06:00:00 PM',
        status: 'Completed',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        sessions: [session],
        requiredHours: 9.0,
      );

      expect(record.computedTotalHours, 9.0);
      expect(record.calculateShortfall(9.0), 0.0);

      final monthlyResult = MonthlyAttendanceCalculator.calculate(
        employee: flexibleEmployee,
        year: 2026,
        month: 10,
        records: [record],
        referenceDate: DateTime(2026, 10, 4),
      );

      expect(monthlyResult.totalWorkingHours, 9.0);
      expect(monthlyResult.totalOvertimeHours, 0.0);
      final oct3Result = monthlyResult.dailyResults.firstWhere((d) => d.dateStr == '03-10-2026');
      expect(oct3Result.shortfallHours, 0.0);
      expect(oct3Result.overtimeHours, 0.0);
    });

    test('2. Afternoon to Night 2:00 PM -> 11:00 PM yields 9 hours completed with no OT', () {
      final session = AttendanceSession(
        checkInTime: '02:00:00 PM',
        checkOutTime: '11:00:00 PM',
      );
      expect(session.effectiveDurationHours, 9.0);

      final record = AttendanceRecord(
        id: 2,
        employeeId: flexibleEmployee.id,
        employeeCode: flexibleEmployee.employeeId,
        employeeName: flexibleEmployee.fullName,
        date: '03-10-2026',
        time: '02:00:00 PM',
        checkInTime: '02:00:00 PM',
        checkOutTime: '11:00:00 PM',
        status: 'Completed',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        sessions: [session],
        requiredHours: 9.0,
      );

      expect(record.computedTotalHours, 9.0);
      expect(record.calculateShortfall(9.0), 0.0);
    });

    test('3. Overnight 9:00 PM -> 6:00 AM next day yields 9 hours completed with no OT', () {
      final session = AttendanceSession(
        checkInTime: '09:00:00 PM',
        checkOutTime: '06:00:00 AM',
      );
      expect(session.effectiveDurationHours, 9.0);
      expect(session.effectiveDurationMinutes, 540);

      final record = AttendanceRecord(
        id: 3,
        employeeId: flexibleEmployee.id,
        employeeCode: flexibleEmployee.employeeId,
        employeeName: flexibleEmployee.fullName,
        date: '03-10-2026',
        time: '09:00:00 PM',
        checkInTime: '09:00:00 PM',
        checkOutTime: '06:00:00 AM',
        status: 'Completed',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        sessions: [session],
        requiredHours: 9.0,
      );

      expect(record.computedTotalHours, 9.0);
      expect(record.calculateShortfall(9.0), 0.0);

      final monthlyResult = MonthlyAttendanceCalculator.calculate(
        employee: flexibleEmployee,
        year: 2026,
        month: 10,
        records: [record],
        referenceDate: DateTime(2026, 10, 4),
      );

      expect(monthlyResult.totalWorkingHours, 9.0);
      expect(monthlyResult.totalOvertimeHours, 0.0);
    });

    test('4. Overnight 10:00 PM -> 7:00 AM next day yields 9 hours', () {
      final session = AttendanceSession(
        checkInTime: '10:00:00 PM',
        checkOutTime: '07:00:00 AM',
      );
      expect(session.effectiveDurationHours, 9.0);
    });

    test('5. Overnight 11:00 PM -> 8:00 AM next day yields 9 hours', () {
      final session = AttendanceSession(
        checkInTime: '11:00:00 PM',
        checkOutTime: '08:00:00 AM',
      );
      expect(session.effectiveDurationHours, 9.0);
    });

    test('6. Overnight 8:00 PM -> 5:00 AM next day yields 9 hours', () {
      final session = AttendanceSession(
        checkInTime: '08:00:00 PM',
        checkOutTime: '05:00:00 AM',
      );
      expect(session.effectiveDurationHours, 9.0);
    });

    test('7. Overnight 9:00 PM -> 5:00 AM next day yields 8 hours (1 hour shortfall)', () {
      final session = AttendanceSession(
        checkInTime: '09:00:00 PM',
        checkOutTime: '05:00:00 AM',
      );
      expect(session.effectiveDurationHours, 8.0);

      final record = AttendanceRecord(
        id: 7,
        employeeId: flexibleEmployee.id,
        employeeCode: flexibleEmployee.employeeId,
        employeeName: flexibleEmployee.fullName,
        date: '03-10-2026',
        time: '09:00:00 PM',
        checkInTime: '09:00:00 PM',
        checkOutTime: '05:00:00 AM',
        status: 'Insufficient hours',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        sessions: [session],
        requiredHours: 9.0,
      );

      expect(record.computedTotalHours, 8.0);
      expect(record.calculateShortfall(9.0), 1.0);
    });

    test('8. Overnight 9:00 PM -> 7:00 AM next day yields 10 hours (Completed, Strictly NO OT)', () {
      final session = AttendanceSession(
        checkInTime: '09:00:00 PM',
        checkOutTime: '07:00:00 AM',
      );
      expect(session.effectiveDurationHours, 10.0);

      final record = AttendanceRecord(
        id: 8,
        employeeId: flexibleEmployee.id,
        employeeCode: flexibleEmployee.employeeId,
        employeeName: flexibleEmployee.fullName,
        date: '03-10-2026',
        time: '09:00:00 PM',
        checkInTime: '09:00:00 PM',
        checkOutTime: '07:00:00 AM',
        status: 'Completed',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        sessions: [session],
        requiredHours: 9.0,
      );

      expect(record.computedTotalHours, 10.0);
      expect(record.calculateShortfall(9.0), 0.0);

      final monthlyResult = MonthlyAttendanceCalculator.calculate(
        employee: flexibleEmployee,
        year: 2026,
        month: 10,
        records: [record],
        referenceDate: DateTime(2026, 10, 4),
      );

      expect(monthlyResult.totalWorkingHours, 10.0);
      // Strictly NO overtime generated for flexible/site employee
      expect(monthlyResult.totalOvertimeHours, 0.0);
    });

    test('9. Overnight 11:00 PM -> 6:00 AM next day yields 7 hours (2 hours shortfall)', () {
      final session = AttendanceSession(
        checkInTime: '11:00:00 PM',
        checkOutTime: '06:00:00 AM',
      );
      expect(session.effectiveDurationHours, 7.0);

      final record = AttendanceRecord(
        id: 9,
        employeeId: flexibleEmployee.id,
        employeeCode: flexibleEmployee.employeeId,
        employeeName: flexibleEmployee.fullName,
        date: '03-10-2026',
        time: '11:00:00 PM',
        checkInTime: '11:00:00 PM',
        checkOutTime: '06:00:00 AM',
        status: 'Insufficient hours',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        sessions: [session],
        requiredHours: 9.0,
      );

      expect(record.calculateShortfall(9.0), 2.0);
    });

    test('10. Multiple sessions 9:00 AM-1:00 PM (4h) + 2:00 PM-7:00 PM (5h) = 9 hours', () {
      final s1 = AttendanceSession(
        id: 's1',
        checkInTime: '09:00:00 AM',
        checkOutTime: '01:00:00 PM',
      );
      final s2 = AttendanceSession(
        id: 's2',
        checkInTime: '02:00:00 PM',
        checkOutTime: '07:00:00 PM',
      );

      final record = AttendanceRecord(
        id: 10,
        employeeId: flexibleEmployee.id,
        employeeCode: flexibleEmployee.employeeId,
        employeeName: flexibleEmployee.fullName,
        date: '03-10-2026',
        time: '09:00:00 AM',
        checkInTime: '09:00:00 AM',
        checkOutTime: '07:00:00 PM',
        status: 'Completed',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        sessions: [s1, s2],
        requiredHours: 9.0,
      );

      expect(record.computedTotalHours, 9.0);
      expect(record.calculateShortfall(9.0), 0.0);
    });
    test('11. Active overnight session at 5:00 AM next day appears In Progress under check-in date without Missing Check-Out', () {
      final activeRecord = AttendanceRecord(
        id: 11,
        employeeId: flexibleEmployee.id,
        employeeCode: flexibleEmployee.employeeId,
        employeeName: flexibleEmployee.fullName,
        date: '07-10-2026',
        time: '09:00:00 PM',
        checkInTime: '09:00:00 PM',
        checkOutTime: '',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        sessions: [
          AttendanceSession(
            checkInTime: '09:00:00 PM',
            checkOutTime: '',
          ),
        ],
      );

      // Viewed at 08-Oct-2026 05:00 AM (8 hours after 9 PM check-in, Thursday morning)
      final referenceTime = DateTime(2026, 10, 8, 5, 0);

      // Check 07-Oct cell status
      final oct7Status = AttendanceStatusHelper.resolveStatus(
        employee: flexibleEmployee,
        date: DateTime(2026, 10, 7),
        record: activeRecord,
        referenceDate: referenceTime,
      );

      // Status must be Present (In Progress) and NOT Missing Checkout
      expect(oct7Status, AttendanceStatusInfo.present);
      expect(oct7Status != AttendanceStatusInfo.missingCheckout, true);

      // Check 08-Oct cell status (No record on 08-Oct)
      final oct8Status = AttendanceStatusHelper.resolveStatus(
        employee: flexibleEmployee,
        date: DateTime(2026, 10, 8),
        record: null,
        referenceDate: referenceTime,
      );

      // 08-Oct has no record, so it remains empty / not marked
      expect(oct8Status, null);
    });

    test('12. Completed overnight session owns check-in date (03-Oct: 9h, 04-Oct: empty)', () {
      final completedRecord = AttendanceRecord(
        id: 12,
        employeeId: flexibleEmployee.id,
        employeeCode: flexibleEmployee.employeeId,
        employeeName: flexibleEmployee.fullName,
        date: '03-10-2026',
        time: '09:00:00 PM',
        checkInTime: '09:00:00 PM',
        checkOutTime: '06:00:00 AM',
        status: 'Completed',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        sessions: [
          AttendanceSession(
            checkInTime: '09:00:00 PM',
            checkOutTime: '06:00:00 AM',
          ),
        ],
        requiredHours: 9.0,
      );

      expect(completedRecord.computedTotalHours, 9.0);
      expect(completedRecord.formattedTotalHours, '9hr');
      expect(completedRecord.calculateShortfall(9.0), 0.0);

      // Matrix calculation for October 2026
      final monthlyResult = MonthlyAttendanceCalculator.calculate(
        employee: flexibleEmployee,
        year: 2026,
        month: 10,
        records: [completedRecord],
        referenceDate: DateTime(2026, 10, 5),
      );

      final oct3Day = monthlyResult.dailyResults.firstWhere((d) => d.dateStr == '03-10-2026');
      expect(oct3Day.workingHours, 9.0);
      expect(oct3Day.statusLabel, 'Present');
      expect(oct3Day.overtimeHours, 0.0);

      final oct4Day = monthlyResult.dailyResults.firstWhere((d) => d.dateStr == '04-10-2026');
      expect(oct4Day.workingHours, 0.0);
    });
  });

  group('Fixed Schedule Employee Attendance Tests (Preserved 100%)', () {
    final fixedEmployee = Employee(
      id: 201,
      employeeId: 'FIXED001',
      firstName: 'Office',
      lastName: 'Staff',
      emailAddress: 'office@example.com',
      phoneNumber: '9876543211',
      gender: 'Female',
      dob: '1992-05-15',
      organizationName: 'I-Green',
      department: 'Finance',
      designation: 'Accountant',
      employmentType: 'Full Time',
      joiningDate: '01-01-2026',
      status: 'Active',
      workScheduleType: 'Fixed Schedule',
      isDynamicEmployee: false,
      isStaticEmployee: true,
      inTime: '09:00 AM',
      outTime: '06:00 PM',
      requiredWorkingHours: 9.0,
    );

    test('10. Fixed Schedule normal attendance (09:00 AM -> 06:00 PM = Present/Completed)', () {
      final record = AttendanceRecord(
        id: 20,
        employeeId: fixedEmployee.id,
        employeeCode: fixedEmployee.employeeId,
        employeeName: fixedEmployee.fullName,
        date: '03-10-2026',
        time: '09:00:00 AM',
        checkInTime: '09:00:00 AM',
        checkOutTime: '06:00:00 PM',
        status: 'Completed',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        scheduledInTime: '09:00 AM',
        scheduledOutTime: '06:00 PM',
        requiredHours: 9.0,
      );

      final statusInfo = AttendanceStatusHelper.resolveStatus(
        employee: fixedEmployee,
        date: DateTime(2026, 10, 3),
        record: record,
      );

      expect(statusInfo, AttendanceStatusInfo.present);
      expect(record.computedTotalHours, 9.0);
    });

    test('11. Fixed Schedule late attendance (09:45 AM -> 06:00 PM = Late)', () {
      final record = AttendanceRecord(
        id: 21,
        employeeId: fixedEmployee.id,
        employeeCode: fixedEmployee.employeeId,
        employeeName: fixedEmployee.fullName,
        date: '03-10-2026',
        time: '09:45:00 AM',
        checkInTime: '09:45:00 AM',
        checkOutTime: '06:00:00 PM',
        status: 'Late',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        scheduledInTime: '09:00 AM',
        scheduledOutTime: '06:00 PM',
      );

      final statusInfo = AttendanceStatusHelper.resolveStatus(
        employee: fixedEmployee,
        date: DateTime(2026, 10, 3),
        record: record,
      );

      expect(statusInfo, AttendanceStatusInfo.late);
    });

    test('12. Fixed Schedule early checkout (09:00 AM -> 04:30 PM = Insufficient Hours)', () {
      final record = AttendanceRecord(
        id: 23,
        employeeId: fixedEmployee.id,
        employeeCode: fixedEmployee.employeeId,
        employeeName: fixedEmployee.fullName,
        date: '03-10-2026',
        time: '09:00:00 AM',
        checkInTime: '09:00:00 AM',
        checkOutTime: '04:30:00 PM',
        status: 'Insufficient Hours',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        scheduledInTime: '09:00 AM',
        scheduledOutTime: '06:00 PM',
        requiredHours: 9.0,
      );

      final statusInfo = AttendanceStatusHelper.resolveStatus(
        employee: fixedEmployee,
        date: DateTime(2026, 10, 3),
        record: record,
      );

      expect(statusInfo, AttendanceStatusInfo.insufficientHours);
      expect(record.computedTotalHours, 7.5);
      expect(record.calculateShortfall(9.0), 1.5);
    });

    test('Fixed shift Overtime calculation works for office staff working late', () {
      final record = AttendanceRecord(
        id: 22,
        employeeId: fixedEmployee.id,
        employeeCode: fixedEmployee.employeeId,
        employeeName: fixedEmployee.fullName,
        date: '03-10-2026',
        time: '09:00:00 AM',
        checkInTime: '09:00:00 AM',
        checkOutTime: '07:45:00 PM',
        status: 'Completed',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        scheduledInTime: '09:00 AM',
        scheduledOutTime: '06:00 PM',
        totalHours: 10.75,
      );

      final otMinutes = record.calculateOvertimeMinutes(shiftOutTime: '06:00 PM');
      expect(otMinutes, 75);

      final monthlyResult = MonthlyAttendanceCalculator.calculate(
        employee: fixedEmployee,
        year: 2026,
        month: 10,
        records: [record],
        referenceDate: DateTime(2026, 10, 4),
      );

      expect(monthlyResult.totalOvertimeHours, 1.25);
    });
  });
}
