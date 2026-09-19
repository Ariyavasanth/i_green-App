import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_record.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_session.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_status_helper.dart';
import 'package:flutter_application_1/features/attendance/domain/monthly_attendance_result.dart';
import 'package:flutter_application_1/features/employee/domain/employee.dart';
import 'package:flutter_application_1/features/leave/domain/leave_request.dart';
import 'package:flutter_application_1/features/on_duty/domain/on_duty_assignment.dart';

void main() {
  group('Phase 2C — Monthly Attendance Result & Calculation Tests', () {
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

    test('1. Monthly summary aggregates all 30 days in September 2026 with correct status counts', () {
      // In September 2026:
      // Sept 1 = Tuesday, Sept 30 = Wednesday (30 days total)
      // Sundays in Sept 2026: Sept 6, 13, 20, 27 (4 Sundays -> 4 Weekly Offs)
      // Working days = 30 - 4 = 26 working days (assuming no holidays)

      final records = <AttendanceRecord>[];

      // Day 1 to 10: On-time Present (9 hrs each = 90 hrs)
      for (int d = 1; d <= 10; d++) {
        if (d == 6) continue; // Sunday
        records.add(AttendanceRecord(
          id: d,
          employeeId: 101,
          employeeCode: 'EMP-101',
          employeeName: 'Vikram Sharma',
          date: '${d.toString().padLeft(2, '0')}-09-2026',
          time: '09:00 AM',
          checkInTime: '09:00 AM',
          checkOutTime: '06:00 PM',
          status: 'Present',
          verificationStatus: 'Verified',
          similarityScore: 1.0,
          totalHours: 9.0,
        ));
      }

      // Day 11: Late check-in (8.5 hrs)
      records.add(const AttendanceRecord(
        id: 11,
        employeeId: 101,
        employeeCode: 'EMP-101',
        employeeName: 'Vikram Sharma',
        date: '11-09-2026',
        time: '09:30 AM',
        checkInTime: '09:30 AM',
        checkOutTime: '06:00 PM',
        status: 'Late',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        totalHours: 8.5,
        notes: 'Late = 20 minutes',
      ));

      // Day 12: Missing Check-Out (checked in at 09:00 AM, no check out)
      records.add(const AttendanceRecord(
        id: 12,
        employeeId: 101,
        employeeCode: 'EMP-101',
        employeeName: 'Vikram Sharma',
        date: '12-09-2026',
        time: '09:00 AM',
        checkInTime: '09:00 AM',
        checkOutTime: '',
        status: 'Missing Check-Out',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        totalHours: 0.0,
      ));

      // Day 14 & 15: Approved Leave (Casual Leave)
      const leave = LeaveRequest(
        id: 1,
        employeeId: 101,
        employeeName: 'Vikram Sharma',
        employeeCustomId: 'EMP-101',
        leaveType: 'Casual Leave',
        fromDate: '14-09-2026',
        toDate: '15-09-2026',
        reason: 'Personal leave',
        status: 'Approved',
        numDays: 2.0,
        createdAt: '2026-09-10T10:00:00.000',
      );

      // Day 16: Approved On-Duty (OD)
      const od = OnDutyAssignment(
        id: 1,
        employeeId: 101,
        employeeName: 'Vikram Sharma',
        odType: 'Client Visit',
        purpose: 'Site Inspection',
        destination: 'Project Alpha',
        date: '16-09-2026',
        status: 'APPROVED',
        assignedBy: 'Manager',
        createdAt: '2026-09-10T10:00:00.000',
      );

      // Holiday: Sept 17 (Ganesh Chaturthi / Festival)
      final holidays = ['17-09-2026'];

      // Day 18: Insufficient Hours (worked 4.0 hrs)
      records.add(const AttendanceRecord(
        id: 18,
        employeeId: 101,
        employeeCode: 'EMP-101',
        employeeName: 'Vikram Sharma',
        date: '18-09-2026',
        time: '09:00 AM',
        checkInTime: '09:00 AM',
        checkOutTime: '01:00 PM',
        status: 'Insufficient Hours',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        totalHours: 4.0,
      ));

      // Calculate Monthly Attendance Result for completed September 2026
      final result = MonthlyAttendanceCalculator.calculate(
        employee: testEmployee,
        year: 2026,
        month: 9,
        records: records,
        leaves: const [leave],
        onDutyAssignments: const [od],
        holidays: holidays,
        referenceDate: DateTime(2026, 10, 1),
      );

      expect(result.totalDaysInMonth, equals(30));
      expect(result.monthYear, equals('09-2026'));

      // Verify Weekly Offs (Sundays: 6, 13, 20, 27 = 4 days)
      expect(result.weeklyOffCount, equals(4));

      // Verify Holiday (17th = 1 day)
      expect(result.holidayCount, equals(1));

      // Total Working Days = 30 - 4 (WO) - 1 (H) = 25 working days
      expect(result.totalWorkingDays, equals(25));

      // Present Count: Days 1, 2, 3, 4, 5, 7, 8, 9, 10 = 9 days
      expect(result.presentCount, equals(9));

      // Late Count: Day 11 = 1 day
      expect(result.lateCount, equals(1));

      // Missing Checkout: Day 12 = 1 day
      expect(result.missingCheckoutCount, equals(1));

      // On Leave: Days 14 & 15 = 2 days
      expect(result.onLeaveCount, equals(2));

      // On Duty: Day 16 = 1 day
      expect(result.onDutyCount, equals(1));

      // Insufficient Hours: Day 18 = 1 day
      expect(result.insufficientHoursCount, equals(1));

      // Absent Days: Days without records/leave/OD/holiday on past working days
      // Remaining working days in month = 25 - 9(P) - 1(L) - 1(MC) - 2(OL) - 1(OD) - 1(IH) = 10 absent days
      expect(result.absentCount, equals(10));

      // Verify Total Required Hours = 25 working days * 9.0 = 225.0 hrs
      expect(result.totalRequiredHours, equals(225.0));

      // Verify Total Working Hours = 9 * 9.0 + 8.5 (Late) + 0.0 (MC) + 4.0 (IH) = 81.0 + 8.5 + 4.0 = 93.5 hrs
      expect(result.totalWorkingHours, equals(93.5));

      // Verify Total Shortfall = 225.0 - 93.5 = 131.5 hrs
      expect(result.totalShortfallHours, equals(131.5));
    });

    test('2. Weekly Off and Holiday are strictly excluded from required working hours', () {
      final holidays = ['01-09-2026', '02-09-2026']; // 2 holidays
      // 30 days in Sept 2026, 4 Sundays (6, 13, 20, 27)
      // Working days = 30 - 4 - 2 = 24

      final result = MonthlyAttendanceCalculator.calculate(
        employee: testEmployee,
        year: 2026,
        month: 9,
        records: const [],
        holidays: holidays,
      );

      expect(result.weeklyOffCount, equals(4));
      expect(result.holidayCount, equals(2));
      expect(result.totalWorkingDays, equals(24));
      expect(result.totalRequiredHours, equals(24 * 9.0)); // 216.0 hrs
    });

    test('3. Shortfall rule: max(0, Required Hours - Working Hours) — No Overtime added', () {
      final records = <AttendanceRecord>[];

      // Employee works 10 hours every working day for 26 working days (Sundays off)
      for (int d = 1; d <= 30; d++) {
        final date = DateTime(2026, 9, d);
        if (date.weekday == DateTime.sunday) continue;
        records.add(AttendanceRecord(
          id: d,
          employeeId: 101,
          employeeCode: 'EMP-101',
          employeeName: 'Vikram Sharma',
          date: '${d.toString().padLeft(2, '0')}-09-2026',
          time: '08:00 AM',
          checkInTime: '08:00 AM',
          checkOutTime: '06:00 PM',
          status: 'Present',
          verificationStatus: 'Verified',
          similarityScore: 1.0,
          totalHours: 10.0,
        ));
      }

      final result = MonthlyAttendanceCalculator.calculate(
        employee: testEmployee,
        year: 2026,
        month: 9,
        records: records,
      );

      expect(result.totalWorkingDays, equals(26));
      expect(result.totalRequiredHours, equals(26 * 9.0)); // 234.0 hrs
      expect(result.totalWorkingHours, equals(26 * 10.0)); // 260.0 hrs

      // Working hours > Required hours -> Shortfall is strictly 0.0 (No Overtime)
      expect(result.totalShortfallHours, equals(0.0));
      expect(result.formattedShortfallHours, equals('0hr'));
    });

    test('4. Date key normalization: supports records saved in ISO format (2026-09-01) without missing daily matches', () {
      final recordIso = AttendanceRecord(
        id: 1,
        employeeId: 101,
        employeeCode: 'EMP-101',
        employeeName: 'Vikram Sharma',
        date: '2026-09-01', // ISO format
        time: '09:00 AM',
        checkInTime: '09:00 AM',
        checkOutTime: '06:00 PM',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        totalHours: 9.0,
      );

      final result = MonthlyAttendanceCalculator.calculate(
        employee: testEmployee,
        year: 2026,
        month: 9,
        records: [recordIso],
      );

      // Day 1 must match and resolve to Present
      final day1 = result.dailyResults.firstWhere((d) => d.dateStr == '01-09-2026');
      expect(day1.statusInfo, equals(AttendanceStatusInfo.present));
      expect(day1.workingHours, equals(9.0));
      expect(result.presentCount, equals(1));
    });

    test('5. Dynamic multi-session hours properly sum into monthly totalWorkingHours', () {
      final multiSessionRecord = AttendanceRecord(
        id: 1,
        employeeId: 101,
        employeeCode: 'EMP-101',
        employeeName: 'Vikram Sharma',
        date: '01-09-2026',
        time: '09:00 AM',
        checkInTime: '09:00 AM',
        checkOutTime: '06:00 PM',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        totalHours: 9.0,
        sessions: const [
          AttendanceSession(
            id: 's1',
            type: 'Office',
            checkInTime: '09:00 AM',
            checkOutTime: '01:00 PM',
            durationHours: 4.0,
            durationMinutes: 240,
          ),
          AttendanceSession(
            id: 's2',
            type: 'Lunch Break',
            checkInTime: '01:00 PM',
            checkOutTime: '01:45 PM',
            durationHours: 0.75,
            durationMinutes: 45,
          ),
          AttendanceSession(
            id: 's3',
            type: 'OD',
            checkInTime: '01:45 PM',
            checkOutTime: '05:00 PM',
            durationHours: 3.25,
            durationMinutes: 195,
          ),
          AttendanceSession(
            id: 's4',
            type: 'Tea Break',
            checkInTime: '05:00 PM',
            checkOutTime: '05:15 PM',
            durationHours: 0.25,
            durationMinutes: 15,
          ),
          AttendanceSession(
            id: 's5',
            type: 'Client Meeting',
            checkInTime: '05:15 PM',
            checkOutTime: '06:00 PM',
            durationHours: 0.75,
            durationMinutes: 45,
          ),
        ],
      );

      final result = MonthlyAttendanceCalculator.calculate(
        employee: testEmployee,
        year: 2026,
        month: 9,
        records: [multiSessionRecord],
      );

      // Sum of sessions = 4.0 + 0.75 + 3.25 + 0.25 + 0.75 = 9.0 hrs
      final day1 = result.dailyResults.firstWhere((d) => d.dateStr == '01-09-2026');
      expect(day1.workingHours, equals(9.0));
      expect(result.totalWorkingHours, equals(9.0));
    });

    test('6. Mid-Month ongoing calculation: past unrecorded working days are Absent while future days in month are pending', () {
      final records = [
        AttendanceRecord(
          id: 1,
          employeeId: 101,
          employeeCode: 'EMP-101',
          employeeName: 'Vikram Sharma',
          date: '01-09-2026',
          time: '09:00 AM',
          checkInTime: '09:00 AM',
          checkOutTime: '06:00 PM',
          status: 'Present',
          verificationStatus: 'Verified',
          similarityScore: 1.0,
          totalHours: 9.0,
        ),
      ];

      // Evaluating as of September 10, 2026
      // Past working days in month: Sept 1 (Present), Sept 2, 3, 4, 5 (Absent), Sept 6 (Weekly Off), Sept 7, 8, 9 (Absent)
      // Future days: Sept 10..30
      final result = MonthlyAttendanceCalculator.calculate(
        employee: testEmployee,
        year: 2026,
        month: 9,
        records: records,
        referenceDate: DateTime(2026, 9, 10),
      );

      expect(result.presentCount, equals(1));
      expect(result.weeklyOffCount, equals(4)); // all 4 Sundays categorized
      // Past unrecorded working days: Sept 2, 3, 4, 5, 7, 8, 9 = 7 absent days
      expect(result.absentCount, equals(7));

      // Day 15 (future) statusInfo is null / Pending
      final day15 = result.dailyResults.firstWhere((d) => d.dateStr == '15-09-2026');
      expect(day15.statusInfo, isNull);
      expect(day15.statusLabel, equals('Pending'));
    });
  });
}
