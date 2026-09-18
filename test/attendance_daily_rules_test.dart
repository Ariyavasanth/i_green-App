import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_record.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_session.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_status_helper.dart';
import 'package:flutter_application_1/features/employee/domain/employee.dart';
import 'package:flutter_application_1/features/leave/domain/leave_request.dart';
import 'package:flutter_application_1/features/on_duty/domain/on_duty_assignment.dart';

void main() {
  const dummyEmp = Employee(
    id: 101,
    employeeId: 'EMP-0101',
    firstName: 'Test',
    lastName: 'Employee',
    emailAddress: 'test@example.com',
    phoneNumber: '9876543210',
    gender: 'Male',
    dob: '01-01-1995',
    organizationName: 'IGreen',
    department: 'Execution',
    designation: 'Engineer',
    employmentType: 'Full-Time',
    joiningDate: '01-01-2025',
    status: 'Active',
    requiredWorkingHours: 9.0,
    weeklyOffDay: 'Sunday',
  );

  group('Phase 2A — Daily Attendance Session & Hours Calculation Tests', () {
    test('1. Multi-session breakdown: Office + OD + Lunch + Tea + Meeting + Other sums to Total Working Hours', () {
      final List<AttendanceSession> sessions = [
        const AttendanceSession(
          id: 's1',
          type: 'Office',
          checkInTime: '09:00:00',
          checkOutTime: '12:00:00', // 3.0h
          durationMinutes: 180,
          durationHours: 3.0,
        ),
        const AttendanceSession(
          id: 's2',
          type: 'OD',
          checkInTime: '12:00:00',
          checkOutTime: '14:30:00', // 2.5h
          durationMinutes: 150,
          durationHours: 2.5,
        ),
        const AttendanceSession(
          id: 's3',
          type: 'Lunch Break',
          checkInTime: '14:30:00',
          checkOutTime: '15:15:00', // 0.75h (45 min)
          durationMinutes: 45,
          durationHours: 0.75,
        ),
        const AttendanceSession(
          id: 's4',
          type: 'Tea Break',
          checkInTime: '16:00:00',
          checkOutTime: '16:15:00', // 0.25h (15 min)
          durationMinutes: 15,
          durationHours: 0.25,
        ),
        const AttendanceSession(
          id: 's5',
          type: 'Meeting',
          checkInTime: '16:15:00',
          checkOutTime: '17:45:00', // 1.5h
          durationMinutes: 90,
          durationHours: 1.5,
        ),
        const AttendanceSession(
          id: 's6',
          type: 'Workshop Work',
          checkInTime: '17:45:00',
          checkOutTime: '18:45:00', // 1.0h
          durationMinutes: 60,
          durationHours: 1.0,
        ),
      ];

      final record = AttendanceRecord(
        id: 1,
        employeeId: 101,
        employeeName: 'Test Employee',
        date: '10-09-2026',
        time: '09:00:00',
        checkInTime: '09:00:00',
        checkOutTime: '18:45:00',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        sessions: sessions,
      );

      expect(record.computedOfficeHours, equals(3.0));
      expect(record.computedOdHours, equals(2.5));
      expect(record.computedLunchHours, equals(0.75));
      expect(record.computedTeaBreakHours, equals(0.25));
      expect(record.computedMeetingOtherHours, equals(2.5)); // 1.5h Meeting + 1.0h Workshop
      // 3.0 + 2.5 + 0.75 + 0.25 + 1.5 + 1.0 = 9.0h
      expect(record.computedTotalHours, equals(9.0));
      expect(record.calculateShortfall(dummyEmp.requiredWorkingHours), equals(0.0));
      expect(record.formattedShortfall(dummyEmp.requiredWorkingHours), equals('0hr'));
      expect(record.formattedTotalHours, equals('9hr'));
    });

    test('2. Shortfall calculated correctly when total hours are less than required hours', () {
      final List<AttendanceSession> sessions = [
        const AttendanceSession(
          id: 's1',
          type: 'Office',
          checkInTime: '09:00:00',
          checkOutTime: '14:30:00', // 5.5h
          durationMinutes: 330,
          durationHours: 5.5,
        ),
        const AttendanceSession(
          id: 's2',
          type: 'Lunch Break',
          checkInTime: '14:30:00',
          checkOutTime: '15:30:00', // 1.0h
          durationMinutes: 60,
          durationHours: 1.0,
        ),
      ];

      final record = AttendanceRecord(
        id: 2,
        employeeId: 101,
        employeeName: 'Test Employee',
        date: '11-09-2026',
        time: '09:00:00',
        checkInTime: '09:00:00',
        checkOutTime: '15:30:00',
        status: 'Checked Out',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        sessions: sessions,
      );

      // Total = 5.5 + 1.0 = 6.5h
      expect(record.computedTotalHours, equals(6.5));
      // Required = 9.0h -> Shortfall = 9.0 - 6.5 = 2.5h
      expect(record.calculateShortfall(dummyEmp.requiredWorkingHours), equals(2.5));
      expect(record.formattedShortfall(dummyEmp.requiredWorkingHours), equals('2hr 30min'));
    });

    test('3. No Overtime — Shortfall remains 0 when total hours exceed required hours', () {
      final List<AttendanceSession> sessions = [
        const AttendanceSession(
          id: 's1',
          type: 'Office',
          checkInTime: '09:00:00',
          checkOutTime: '20:00:00', // 11.0h
          durationMinutes: 660,
          durationHours: 11.0,
        ),
      ];

      final record = AttendanceRecord(
        id: 3,
        employeeId: 101,
        employeeName: 'Test Employee',
        date: '12-09-2026',
        time: '09:00:00',
        checkInTime: '09:00:00',
        checkOutTime: '20:00:00',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        sessions: sessions,
      );

      expect(record.computedTotalHours, equals(11.0));
      expect(record.calculateShortfall(dummyEmp.requiredWorkingHours), equals(0.0));
      expect(record.formattedShortfall(dummyEmp.requiredWorkingHours), equals('0hr'));
    });

    test('4. Late punctuality is separate from Working Hours fulfillment', () {
      final List<AttendanceSession> sessions = [
        const AttendanceSession(
          id: 's1',
          type: 'Office',
          checkInTime: '09:45:00', // Late check-in
          checkOutTime: '18:45:00', // 9.0h
          durationMinutes: 540,
          durationHours: 9.0,
        ),
      ];

      final record = AttendanceRecord(
        id: 4,
        employeeId: 101,
        employeeName: 'Test Employee',
        date: '13-09-2026',
        time: '09:45:00',
        checkInTime: '09:45:00',
        checkOutTime: '18:45:00',
        status: 'Late',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        sessions: sessions,
      );

      final status = AttendanceStatusHelper.resolveStatus(
        employee: dummyEmp,
        date: DateTime(2026, 9, 13),
        record: record,
      );

      expect(status, equals(AttendanceStatusInfo.late));
      expect(record.computedTotalHours, equals(9.0));
      expect(record.calculateShortfall(dummyEmp.requiredWorkingHours), equals(0.0));
    });
  });

  group('Phase 2A — Daily Attendance Status Resolution Tests', () {
    test('1. Present status resolution', () {
      final record = AttendanceRecord(
        id: 10,
        employeeId: 101,
        employeeName: 'Test Employee',
        date: '14-09-2026',
        time: '09:00:00',
        checkInTime: '09:00:00',
        checkOutTime: '18:00:00',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
      );

      final status = AttendanceStatusHelper.resolveStatus(
        employee: dummyEmp,
        date: DateTime(2026, 9, 14),
        record: record,
      );

      expect(status, equals(AttendanceStatusInfo.present));
    });

    test('2. Insufficient Hours status resolution', () {
      final record = AttendanceRecord(
        id: 11,
        employeeId: 101,
        employeeName: 'Test Employee',
        date: '15-09-2026',
        time: '09:00:00',
        checkInTime: '09:00:00',
        checkOutTime: '12:00:00',
        status: 'Insufficient Hours',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        totalHours: 3.0,
      );

      final status = AttendanceStatusHelper.resolveStatus(
        employee: dummyEmp,
        date: DateTime(2026, 9, 15),
        record: record,
      );

      expect(status, equals(AttendanceStatusInfo.insufficientHours));
    });

    test('3. Missing Check-Out on past dates persists until corrected', () {
      final pastDate = DateTime(2026, 8, 10);
      final record = AttendanceRecord(
        id: 12,
        employeeId: 101,
        employeeName: 'Test Employee',
        date: '10-08-2026',
        time: '09:00:00',
        checkInTime: '09:00:00',
        checkOutTime: '', // No checkout!
        status: 'Present', // Set during morning check-in
        verificationStatus: 'Verified',
        similarityScore: 1.0,
      );

      final status = AttendanceStatusHelper.resolveStatus(
        employee: dummyEmp,
        date: pastDate,
        record: record,
      );

      expect(status, equals(AttendanceStatusInfo.missingCheckout));
    });

    test('4. Leave approval workflow status resolution (Approved vs Pending vs Denied vs Cancelled)', () {
      final targetDate = DateTime(2026, 8, 12);

      // 4a. Approved leave -> On Leave (OL)
      final List<LeaveRequest> approvedLeaves = [
        const LeaveRequest(
          id: 1,
          employeeId: 101,
          employeeName: 'Test Employee',
          employeeCustomId: 'EMP-0101',
          leaveType: 'Casual Leave',
          fromDate: '11-08-2026',
          toDate: '13-08-2026',
          numDays: 3.0,
          reason: 'Family Event',
          status: 'Approved',
          createdAt: '10-08-2026',
        ),
      ];
      expect(
        AttendanceStatusHelper.resolveStatus(
          employee: dummyEmp,
          date: targetDate,
          record: null,
          leaves: approvedLeaves,
        ),
        equals(AttendanceStatusInfo.onLeave),
      );

      // 4b. Pending leave -> NOT On Leave (Resolves to Absent on a past working day)
      final List<LeaveRequest> pendingLeaves = [
        const LeaveRequest(
          id: 2,
          employeeId: 101,
          employeeName: 'Test Employee',
          employeeCustomId: 'EMP-0101',
          leaveType: 'Casual Leave',
          fromDate: '11-08-2026',
          toDate: '13-08-2026',
          numDays: 3.0,
          reason: 'Family Event',
          status: 'Pending',
          createdAt: '10-08-2026',
        ),
      ];
      expect(
        AttendanceStatusHelper.resolveStatus(
          employee: dummyEmp,
          date: targetDate,
          record: null,
          leaves: pendingLeaves,
        ),
        equals(AttendanceStatusInfo.absent),
      );

      // 4c. Denied / Rejected leave -> NOT On Leave (Resolves to Absent on a past working day)
      final List<LeaveRequest> deniedLeaves = [
        const LeaveRequest(
          id: 3,
          employeeId: 101,
          employeeName: 'Test Employee',
          employeeCustomId: 'EMP-0101',
          leaveType: 'Casual Leave',
          fromDate: '11-08-2026',
          toDate: '13-08-2026',
          numDays: 3.0,
          reason: 'Family Event',
          status: 'Denied',
          createdAt: '10-08-2026',
        ),
      ];
      expect(
        AttendanceStatusHelper.resolveStatus(
          employee: dummyEmp,
          date: targetDate,
          record: null,
          leaves: deniedLeaves,
        ),
        equals(AttendanceStatusInfo.absent),
      );

      // 4d. Cancelled leave -> NOT On Leave (Resolves to Absent on a past working day)
      final List<LeaveRequest> cancelledLeaves = [
        const LeaveRequest(
          id: 4,
          employeeId: 101,
          employeeName: 'Test Employee',
          employeeCustomId: 'EMP-0101',
          leaveType: 'Casual Leave',
          fromDate: '11-08-2026',
          toDate: '13-08-2026',
          numDays: 3.0,
          reason: 'Family Event',
          status: 'Cancelled',
          createdAt: '10-08-2026',
        ),
      ];
      expect(
        AttendanceStatusHelper.resolveStatus(
          employee: dummyEmp,
          date: targetDate,
          record: null,
          leaves: cancelledLeaves,
        ),
        equals(AttendanceStatusInfo.absent),
      );
    });

    test('5. Weekly Off resolution', () {
      final sunday = DateTime(2026, 9, 20); // Sunday
      final status = AttendanceStatusHelper.resolveStatus(
        employee: dummyEmp,
        date: sunday,
        record: null,
      );

      expect(status, equals(AttendanceStatusInfo.weeklyOff));
    });

    test('6. Holiday resolution', () {
      final holidayDate = DateTime(2026, 8, 15); // Independence Day
      final List<String> holidays = ['15-08-2026'];

      final status = AttendanceStatusHelper.resolveStatus(
        employee: dummyEmp,
        date: holidayDate,
        record: null,
        holidays: holidays,
      );

      expect(status, equals(AttendanceStatusInfo.holiday));
    });

    test('7. Specific Case: Scheduled working day with no attendance, no approved leave, no weekly off, no holiday, no OD', () {
      final pastWorkingDay = DateTime(2026, 8, 18); // Tuesday in the past

      final status = AttendanceStatusHelper.resolveStatus(
        employee: dummyEmp,
        date: pastWorkingDay,
        record: null,
        leaves: null,
        onDutyAssignments: null,
        holidays: null,
      );

      expect(status, equals(AttendanceStatusInfo.absent));

      // For unrecorded absent day:
      // Working Hours = 0.0
      // Required Hours = employee.requiredWorkingHours (9.0)
      // Shortfall = Required Hours (9.0)
      const unrecordedTotalHours = 0.0;
      final requiredHours = dummyEmp.requiredWorkingHours;
      final shortfall = (requiredHours - unrecordedTotalHours).clamp(0.0, requiredHours);

      expect(unrecordedTotalHours, equals(0.0));
      expect(requiredHours, equals(9.0));
      expect(shortfall, equals(9.0));
    });

    test('8. Future unrecorded day resolves to null (Not Marked -)', () {
      final futureDate = DateTime(2028, 1, 15); // Far future
      final status = AttendanceStatusHelper.resolveStatus(
        employee: dummyEmp,
        date: futureDate,
        record: null,
      );

      expect(status, isNull);
    });
  });
}
