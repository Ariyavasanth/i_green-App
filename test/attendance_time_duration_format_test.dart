import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/utils/time_formatter.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_record.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_settings.dart';
import 'package:flutter_application_1/features/employee/domain/employee.dart';
import 'package:flutter_application_1/features/attendance/presentation/attendance_page.dart';
import 'package:flutter_application_1/features/attendance/providers/attendance_providers.dart';
import 'package:flutter_application_1/features/leave/domain/leave_request.dart';
import 'package:flutter_application_1/features/leave/providers/leave_providers.dart';
import 'package:flutter_application_1/features/permission/domain/permission_request.dart';
import 'package:flutter_application_1/features/permission/providers/permission_providers.dart';
import 'package:flutter_application_1/features/on_duty/on_duty.dart';
import 'package:flutter_application_1/features/attendance_settings/providers/attendance_settings_providers.dart';

void main() {
  group('TimeFormatter 24-Hour & HH:mm:ss Duration Format Tests', () {
    test('Expected Example 1: 12:44 AM converts to 00:44:00', () {
      expect(TimeFormatter.formatTo24HourTime('12:44 AM'), '00:44:00');
      expect(TimeFormatter.formatTo24HourTime('12:44:00 AM'), '00:44:00');
      expect(TimeFormatter.formatTo24HourTime('12:44 am'), '00:44:00');
    });

    test('Expected Example 2: 12:58 PM converts to 12:58:00', () {
      expect(TimeFormatter.formatTo24HourTime('12:58 PM'), '12:58:00');
      expect(TimeFormatter.formatTo24HourTime('12:58:00 PM'), '12:58:00');
      expect(TimeFormatter.formatTo24HourTime('12:58 pm'), '12:58:00');
    });

    test('Expected Example 3: 0h 14m duration converts to 00:14:00', () {
      const minutes = 14;
      expect(TimeFormatter.formatMinutesToHHmmss(minutes), '00:14:00');
      expect(TimeFormatter.formatSecondsToHHmmss(minutes * 60), '00:14:00');
    });

    test('Other 24-hour time conversions', () {
      expect(TimeFormatter.formatTo24HourTime('12:00 AM'), '00:00:00');
      expect(TimeFormatter.formatTo24HourTime('12:00 PM'), '12:00:00');
      expect(TimeFormatter.formatTo24HourTime('1:15 AM'), '01:15:00');
      expect(TimeFormatter.formatTo24HourTime('01:15 AM'), '01:15:00');
      expect(TimeFormatter.formatTo24HourTime('1:15 PM'), '13:15:00');
      expect(TimeFormatter.formatTo24HourTime('01:15 PM'), '13:15:00');
      expect(TimeFormatter.formatTo24HourTime('9:30 AM'), '09:30:00');
      expect(TimeFormatter.formatTo24HourTime('09:30:45 AM'), '09:30:45');
      expect(TimeFormatter.formatTo24HourTime('18:25'), '18:25:00');
      expect(TimeFormatter.formatTo24HourTime('18:25:35'), '18:25:35');
      expect(TimeFormatter.formatTo24HourTime('--:--'), '--:--');
      expect(TimeFormatter.formatTo24HourTime('Active'), 'Active');
    });

    test('Elapsed seconds calculation handles timestamps with seconds and wrap-around', () {
      expect(TimeFormatter.calculateElapsedSeconds('12:44 AM', '12:58 AM'), 840);
      expect(TimeFormatter.calculateElapsedSeconds('12:44:10 AM', '12:58:30 AM'), 860);
      expect(TimeFormatter.calculateElapsedSeconds('11:50 PM', '12:10 AM'), 1200);
    });

    test('formatDuration formats Duration correctly', () {
      expect(TimeFormatter.formatDuration(const Duration(minutes: 14)), '00:14:00');
      expect(TimeFormatter.formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)), '01:02:03');
      expect(TimeFormatter.formatDuration(const Duration(seconds: -10)), '00:00:00');
    });
  });

  group('AttendanceSession & AttendanceRecord Duration Calculation Tests', () {
    test('AttendanceSession calculates effective duration in seconds accurately', () {
      const session = AttendanceSession(
        checkInTime: '12:44 AM',
        checkOutTime: '12:58 AM',
        durationMinutes: 14,
      );
      expect(session.effectiveDurationSeconds, 840);
      expect(TimeFormatter.formatSecondsToHHmmss(session.effectiveDurationSeconds), '00:14:00');
    });

    test('AttendanceRecord calculates total work duration in seconds across sessions', () {
      const session1 = AttendanceSession(
        checkInTime: '12:44 AM',
        checkOutTime: '12:58 AM',
        durationMinutes: 14,
      );
      const record = AttendanceRecord(
        id: 1,
        employeeId: 101,
        employeeName: 'Jane Doe',
        date: '2026-10-23',
        time: '12:44 AM',
        status: 'Completed',
        verificationStatus: 'Verified',
        similarityScore: 0.95,
        checkInTime: '12:44 AM',
        checkOutTime: '12:58 PM',
        sessions: [session1],
      );

      expect(record.totalWorkDurationSeconds, 840);
      expect(TimeFormatter.formatSecondsToHHmmss(record.totalWorkDurationSeconds), '00:14:00');
    });
  });

  group('Attendance UI Formatting in HH:mm:ss Verification', () {
    testWidgets('Attendance Page displays HH:mm:ss for Shift completed, Time cards, and Sessions', (tester) async {
      const testEmp = Employee(
        id: 101,
        employeeId: 'EMP-101',
        firstName: 'Jane',
        lastName: 'Doe',
        emailAddress: 'jane@example.com',
        phoneNumber: '9876543210',
        gender: 'Female',
        dob: '01-01-1995',
        organizationName: 'IGreen',
        department: 'Engineering',
        designation: 'Engineer',
        employmentType: 'Full-Time',
        joiningDate: '01-01-2025',
        status: 'Active',
        inTime: '09:00 AM',
        outTime: '06:00 PM',
      );

      const session1 = AttendanceSession(
        id: 'sess-1',
        checkInTime: '12:44 AM',
        checkOutTime: '12:58 PM',
        durationMinutes: 14,
        type: 'office',
      );

      final testRecord = AttendanceRecord(
        id: 1,
        employeeId: 101,
        employeeName: 'Jane Doe',
        date: '2026-10-23',
        time: '12:44 AM',
        status: 'Completed',
        verificationStatus: 'Verified',
        similarityScore: 0.95,
        checkInTime: '12:44 AM',
        checkOutTime: '12:58 PM',
        sessions: [session1],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentEmployeeProvider.overrideWithValue(testEmp),
            todayAttendanceRecordProvider(101).overrideWith((ref) => Future.value(testRecord)),
            attendanceRecordsProvider(101).overrideWith((ref) => Future.value([testRecord])),
            attendanceLeaveRequestsProvider(101).overrideWith((ref) => Future.value(<LeaveRequest>[])),
            leaveRequestsProvider(101).overrideWith((ref) => Future.value(<LeaveRequest>[])),
            myPermissionRequestsProvider(101).overrideWith((ref) => Future.value(<PermissionRequest>[])),
            activeOnDutyAssignmentProvider(101).overrideWith((ref) => Future.value(null)),
            attendanceSettingsProvider.overrideWith((ref) => Future.value(AttendanceSettings.defaults())),
          ],
          child: const MaterialApp(
            home: AttendancePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Today's Status — Shift completed start and end times in HH:mm:ss
      expect(find.text('Shift completed: 00:44:00 – 12:58:00'), findsOneWidget);

      // 2. Check In and Check Out time cards
      expect(find.text('00:44:00'), findsAtLeastNWidgets(1));
      expect(find.text('12:58:00'), findsAtLeastNWidgets(1));

      // 3. Work Hrs time card
      expect(find.text('00:14:00'), findsAtLeastNWidgets(1));

      // 4. Today's Work Sessions — header total
      expect(find.text('Total 00:14:00'), findsOneWidget);

      // 5. Today's Work Sessions — session start and end times
      expect(find.text('00:44:00 → 12:58:00'), findsOneWidget);

      // 6. Today's Work Sessions — individual session duration
      expect(find.text('00:14:00'), findsAtLeastNWidgets(2)); // in Work Hrs chip and session chip
    });

    testWidgets('Active flexible check-in with empty sessions list displays Today\'s Work Sessions card and Live Clock', (tester) async {
      const flexibleEmp = Employee(
        id: 102,
        employeeId: 'EMP-102',
        firstName: 'Sam',
        lastName: 'J',
        emailAddress: 'sam@example.com',
        phoneNumber: '9876543211',
        gender: 'Male',
        dob: '01-01-1995',
        organizationName: 'IGreen',
        department: 'Operations',
        designation: 'Field Executive',
        employmentType: 'Full-Time',
        joiningDate: '01-01-2025',
        status: 'Active',
        workScheduleType: 'Flexible Schedule',
        inTime: '',
        outTime: '',
      );

      final activeRecord = AttendanceRecord(
        id: 2,
        employeeId: 102,
        employeeName: 'Sam J',
        date: '2026-10-23',
        time: '01:30:00 AM',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        checkInTime: '01:30:00 AM',
        checkOutTime: '',
        sessions: const [], // Empty sessions list as in user's image
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentEmployeeProvider.overrideWithValue(flexibleEmp),
            todayAttendanceRecordProvider(102).overrideWith((ref) => Future.value(activeRecord)),
            attendanceRecordsProvider(102).overrideWith((ref) => Future.value([activeRecord])),
            attendanceLeaveRequestsProvider(102).overrideWith((ref) => Future.value(<LeaveRequest>[])),
            leaveRequestsProvider(102).overrideWith((ref) => Future.value(<LeaveRequest>[])),
            myPermissionRequestsProvider(102).overrideWith((ref) => Future.value(<PermissionRequest>[])),
            activeOnDutyAssignmentProvider(102).overrideWith((ref) => Future.value(null)),
            attendanceSettingsProvider.overrideWith((ref) => Future.value(AttendanceSettings.defaults())),
          ],
          child: const MaterialApp(
            home: AttendancePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Today's Status
      expect(find.textContaining('Checked in at 01:30:00 • Target: 9 Working Hours'), findsOneWidget);

      // Check In card
      expect(find.text('01:30:00'), findsAtLeastNWidgets(1));

      // Check Out card is unset
      expect(find.text('--:--:--'), findsAtLeastNWidgets(1));

      // Live Clock card is active
      expect(find.text('Live Clock'), findsOneWidget);

      // Today's Work Sessions card is rendered!
      expect(find.text("Today's Work Sessions"), findsOneWidget);
      expect(find.text('01:30:00 → Active'), findsOneWidget);
      expect(find.text('Active'), findsAtLeastNWidgets(1));
    });
  });
}
