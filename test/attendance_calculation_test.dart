import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_record.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_session.dart';

void main() {
  group('Attendance Calculation Tests', () {
    test('Sums all completed sessions including Office, Lunch, Tea Break, Meeting, and OD without deducting breaks', () {
      final sessions = [
        const AttendanceSession(
          id: 's1',
          type: 'office',
          checkInTime: '09:00:00 AM',
          checkOutTime: '01:00:00 PM',
          durationHours: 4.0,
          durationMinutes: 240,
        ),
        const AttendanceSession(
          id: 's2',
          type: 'LUNCH_BREAK',
          checkInTime: '01:00:00 PM',
          checkOutTime: '02:00:00 PM',
          durationHours: 1.0,
          durationMinutes: 60,
        ),
        const AttendanceSession(
          id: 's3',
          type: 'MEETING',
          checkInTime: '02:00:00 PM',
          checkOutTime: '03:30:00 PM',
          durationHours: 1.5,
          durationMinutes: 90,
        ),
        const AttendanceSession(
          id: 's4',
          type: 'TEA_BREAK',
          checkInTime: '03:30:00 PM',
          checkOutTime: '04:00:00 PM',
          durationHours: 0.5,
          durationMinutes: 30,
        ),
        const AttendanceSession(
          id: 's5',
          type: 'od',
          checkInTime: '04:00:00 PM',
          checkOutTime: '06:00:00 PM',
          durationHours: 2.0,
          durationMinutes: 120,
        ),
      ];

      final record = AttendanceRecord(
        id: 1,
        employeeId: 101,
        employeeName: 'Alice',
        date: '18-09-2026',
        time: '09:00:00 AM',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        checkInTime: '09:00:00 AM',
        checkOutTime: '06:00:00 PM',
        sessions: sessions,
      );

      // Total working hours must be 4.0 + 1.0 + 1.5 + 0.5 + 2.0 = 9.0 hours
      expect(record.computedTotalHours, 9.0);
      expect(record.formattedTotalHours, '9hr');
    });

    test('Shortfall is 0 when totalHours is equal to requiredWorkingHours', () {
      const requiredHours = 9.0;
      const totalHours = 9.0;

      final shortfallHours = (requiredHours - totalHours).clamp(0, requiredHours);
      final shortfallMins = (shortfallHours * 60).ceil();

      expect(shortfallHours, 0.0);
      expect(shortfallMins, 0);
    });

    test('Shortfall is 0 when totalHours is greater than requiredWorkingHours (no overtime)', () {
      const requiredHours = 9.0;
      const totalHours = 10.5;

      final shortfallHours = (requiredHours - totalHours).clamp(0, requiredHours);
      final shortfallMins = (shortfallHours * 60).ceil();

      expect(shortfallHours, 0.0);
      expect(shortfallMins, 0);
    });

    test('Shortfall is correctly computed when totalHours is less than requiredWorkingHours', () {
      const requiredHours = 9.0;
      const totalHours = 7.5; // 1.5 hours short = 90 mins

      final shortfallHours = (requiredHours - totalHours).clamp(0, requiredHours);
      final shortfallMins = (shortfallHours * 60).ceil();

      expect(shortfallHours, 1.5);
      expect(shortfallMins, 90);
    });

    test('Legacy record without sessions falls back to top-level check-in and check-out', () {
      final legacyRecord = const AttendanceRecord(
        id: 2,
        employeeId: 102,
        employeeName: 'Bob',
        date: '18-09-2026',
        time: '09:00:00 AM',
        checkInTime: '09:00:00 AM',
        checkOutTime: '06:00:00 PM',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        sessions: [],
      );

      expect(legacyRecord.computedTotalHours, 9.0);
      expect(legacyRecord.formattedTotalHours, '9hr');
    });

    test('Active sessions that are not yet completed are excluded from total hours', () {
      final sessions = [
        const AttendanceSession(
          id: 's1',
          type: 'office',
          checkInTime: '09:00:00 AM',
          checkOutTime: '01:00:00 PM',
          durationHours: 4.0,
          durationMinutes: 240,
        ),
        const AttendanceSession(
          id: 's2',
          type: 'office',
          checkInTime: '02:00:00 PM',
          checkOutTime: '', // Active session
          durationHours: 0.0,
          durationMinutes: 0,
        ),
      ];

      final record = AttendanceRecord(
        id: 3,
        employeeId: 103,
        employeeName: 'Charlie',
        date: '18-09-2026',
        time: '09:00:00 AM',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        sessions: sessions,
      );

      expect(record.computedTotalHours, 4.0);
      expect(record.formattedTotalHours, '4hr');
    });

    test('Status calculation logic with permission authorization', () {
      const requiredHours = 9.0;
      const totalHours = 7.5; // Shortfall = 1.5 hrs (90 mins)

      final shortfallHours = (requiredHours - totalHours).clamp(0, requiredHours);
      final shortfallMins = (shortfallHours * 60).ceil();

      // Case 1: Approved permission of 90 minutes covers shortfall -> Completed
      const approvedPermissionMins1 = 90;
      final bool covered1 = approvedPermissionMins1 >= shortfallMins;
      expect(covered1, isTrue);

      // Case 2: Approved permission of 30 minutes does not cover shortfall -> Insufficient hours
      const approvedPermissionMins2 = 30;
      final bool covered2 = approvedPermissionMins2 >= shortfallMins;
      expect(covered2, isFalse);
    });
  });

  group('Dynamic Session Hours & Activity Categorization (Strict Rule Tests)', () {
    // 1. General Work -> Office
    test('1. General Work session maps to Office Hours', () {
      final session = const AttendanceSession(
        id: 's1',
        type: 'General Work',
        checkInTime: '09:00:00 AM',
        checkOutTime: '12:30:00 PM', // 3h 30m = 3.5h
      );
      expect(session.isOffice, isTrue);
      expect(session.effectiveDurationHours, 3.5);
      expect(session.effectiveDurationMinutes, 210);

      final record = AttendanceRecord(
        id: 1,
        employeeId: 101,
        employeeName: 'Test',
        date: '19-09-2026',
        time: '09:00:00 AM',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        sessions: [session],
      );
      expect(record.computedOfficeHours, 3.5);
      expect(record.computedTotalHours, 3.5);
    });

    // 2. Work -> Office
    test('2. Work session maps to Office Hours', () {
      final session = const AttendanceSession(
        id: 's1',
        type: 'Work',
        checkInTime: '09:00:00 AM',
        checkOutTime: '01:00:00 PM', // 4.0h
      );
      expect(session.isOffice, isTrue);
      expect(session.effectiveDurationHours, 4.0);

      final record = AttendanceRecord(
        id: 1,
        employeeId: 101,
        employeeName: 'Test',
        date: '19-09-2026',
        time: '09:00:00 AM',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        sessions: [session],
      );
      expect(record.computedOfficeHours, 4.0);
      expect(record.computedTotalHours, 4.0);
    });

    // 3. Lunch -> actual Lunch duration
    test('3. Lunch maps to actual dynamic Lunch duration (no fixed 1 hour)', () {
      // 1:00 PM to 1:35 PM = 35 mins
      final session1 = const AttendanceSession(
        id: 's1',
        type: 'Lunch',
        checkInTime: '01:00:00 PM',
        checkOutTime: '01:35:00 PM',
      );
      expect(session1.isLunch, isTrue);
      expect(session1.effectiveDurationMinutes, 35);

      // 1:00 PM to 2:10 PM = 70 mins (1h 10m)
      final session2 = const AttendanceSession(
        id: 's2',
        type: 'Lunch',
        checkInTime: '01:00:00 PM',
        checkOutTime: '02:10:00 PM',
      );
      expect(session2.effectiveDurationMinutes, 70);

      final record = AttendanceRecord(
        id: 1,
        employeeId: 101,
        employeeName: 'Test',
        date: '19-09-2026',
        time: '01:00:00 PM',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        sessions: [session1],
      );
      expect(record.computedLunchHours, closeTo(35 / 60.0, 0.01));
      expect(record.formattedLunchHours, '35min');
    });

    // 4. Tea / Coffee Break -> actual Tea duration
    test('4. Tea / Coffee Break maps to actual Tea duration (no fixed 15 mins)', () {
      // 4:10 PM to 4:25 PM = 15 mins
      final session1 = const AttendanceSession(
        id: 's1',
        type: 'Tea / Coffee Break',
        checkInTime: '04:10:00 PM',
        checkOutTime: '04:25:00 PM',
      );
      expect(session1.isTeaBreak, isTrue);
      expect(session1.effectiveDurationMinutes, 15);

      // 4:00 PM to 4:20 PM = 20 mins
      final session2 = const AttendanceSession(
        id: 's2',
        type: 'Tea Break',
        checkInTime: '04:00:00 PM',
        checkOutTime: '04:20:00 PM',
      );
      expect(session2.effectiveDurationMinutes, 20);

      final record = AttendanceRecord(
        id: 1,
        employeeId: 101,
        employeeName: 'Test',
        date: '19-09-2026',
        time: '04:10:00 PM',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        sessions: [session1],
      );
      expect(record.computedTeaBreakHours, 0.25);
      expect(record.formattedTeaBreakHours, '15min');
    });

    // 5. Meeting -> Meeting/Other
    test('5. Meeting maps to Meeting/Other Hours', () {
      // 10:30 AM to 11:45 AM = 75 mins (1h 15m = 1.25h)
      final session = const AttendanceSession(
        id: 's1',
        type: 'Meeting',
        checkInTime: '10:30:00 AM',
        checkOutTime: '11:45:00 AM',
      );
      expect(session.isMeetingOrOther, isTrue);
      expect(session.effectiveDurationMinutes, 75);
      expect(session.effectiveDurationHours, 1.25);

      final record = AttendanceRecord(
        id: 1,
        employeeId: 101,
        employeeName: 'Test',
        date: '19-09-2026',
        time: '10:30:00 AM',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        sessions: [session],
      );
      expect(record.computedMeetingOtherHours, 1.25);
      expect(record.formattedMeetingOtherHours, '1hr 15min');
    });

    // 6. Other -> Meeting/Other
    test('6. Other maps to Meeting/Other Hours', () {
      final session = const AttendanceSession(
        id: 's1',
        type: 'Other',
        checkInTime: '02:00:00 PM',
        checkOutTime: '02:30:00 PM', // 30 mins = 0.5h
      );
      expect(session.isMeetingOrOther, isTrue);
      expect(session.effectiveDurationMinutes, 30);
      expect(session.effectiveDurationHours, 0.5);

      final record = AttendanceRecord(
        id: 1,
        employeeId: 101,
        employeeName: 'Test',
        date: '19-09-2026',
        time: '02:00:00 PM',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        sessions: [session],
      );
      expect(record.computedMeetingOtherHours, 0.5);
      expect(record.formattedMeetingOtherHours, '30min');
    });

    // 7. OD -> OD duration
    test('7. OD / On-Duty maps to OD Hours', () {
      final session = const AttendanceSession(
        id: 's1',
        type: 'On-Duty',
        checkInTime: '10:00:00 AM',
        checkOutTime: '12:00:00 PM', // 2.0h
      );
      expect(session.isOd, isTrue);
      expect(session.effectiveDurationHours, 2.0);

      final record = AttendanceRecord(
        id: 1,
        employeeId: 101,
        employeeName: 'Test',
        date: '19-09-2026',
        time: '10:00:00 AM',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        sessions: [session],
      );
      expect(record.computedOdHours, 2.0);
      expect(record.formattedOdHours, '2hr');
    });

    // 8. Multiple sessions -> exact total
    test('8. Sums Office + OD + Lunch + Tea + Meeting + Other to exact total (10h 30m example)', () {
      final sessions = [
        const AttendanceSession(
          id: 's1',
          type: 'Office',
          checkInTime: '09:00:00 AM',
          checkOutTime: '02:20:00 PM', // 5h 20m = 320m
        ),
        const AttendanceSession(
          id: 's2',
          type: 'OD',
          checkInTime: '02:20:00 PM',
          checkOutTime: '04:20:00 PM', // 2h 00m = 120m
        ),
        const AttendanceSession(
          id: 's3',
          type: 'Lunch',
          checkInTime: '01:00:00 PM',
          checkOutTime: '02:10:00 PM', // 1h 10m = 70m
        ),
        const AttendanceSession(
          id: 's4',
          type: 'Tea / Coffee Break',
          checkInTime: '04:10:00 PM',
          checkOutTime: '04:25:00 PM', // 0h 15m = 15m
        ),
        const AttendanceSession(
          id: 's5',
          type: 'Meeting',
          checkInTime: '10:30:00 AM',
          checkOutTime: '11:45:00 AM', // 1h 15m = 75m
        ),
        const AttendanceSession(
          id: 's6',
          type: 'Other',
          checkInTime: '05:00:00 PM',
          checkOutTime: '05:30:00 PM', // 0h 30m = 30m
        ),
      ];

      final record = AttendanceRecord(
        id: 1,
        employeeId: 101,
        employeeName: 'Test',
        date: '19-09-2026',
        time: '09:00:00 AM',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        sessions: sessions,
      );

      // Total minutes = 320 + 120 + 70 + 15 + 75 + 30 = 630 mins = 10h 30m = 10.5h
      expect(record.computedTotalHours, 10.5);
      expect(record.formattedTotalHours, '10hr 30min');
      expect(record.formattedOfficeHours, '5hr 20min');
      expect(record.formattedOdHours, '2hr');
      expect(record.formattedLunchHours, '1hr 10min');
      expect(record.formattedTeaBreakHours, '15min');
      expect(record.formattedMeetingOtherHours, '1hr 45min'); // 75m Meeting + 30m Other = 105m = 1h 45m
    });

    // 9. Active/unclosed session -> not counted as completed hours
    test('9. Active / unclosed session does NOT contribute to completed hours', () {
      final sessions = [
        const AttendanceSession(
          id: 's1',
          type: 'Office',
          checkInTime: '09:00:00 AM',
          checkOutTime: '01:00:00 PM', // Completed 4.0h
        ),
        const AttendanceSession(
          id: 's2',
          type: 'Lunch',
          checkInTime: '01:00:00 PM',
          checkOutTime: '', // Active unclosed
        ),
      ];

      final record = AttendanceRecord(
        id: 1,
        employeeId: 101,
        employeeName: 'Test',
        date: '19-09-2026',
        time: '09:00:00 AM',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        sessions: sessions,
      );

      expect(sessions[1].isActive, isTrue);
      expect(sessions[1].effectiveDurationHours, 0.0);
      expect(sessions[1].effectiveDurationMinutes, 0);

      expect(record.computedTotalHours, 4.0);
      expect(record.computedLunchHours, 0.0);
      expect(record.formattedTotalHours, '4hr');
    });

    // 10. No fixed Lunch/Tea duration
    test('10. Different lunch and tea durations are computed dynamically without fixed fallback', () {
      final lunchSession = const AttendanceSession(
        id: 's1',
        type: 'Lunch',
        checkInTime: '12:45:00 PM',
        checkOutTime: '01:05:00 PM', // 20 mins
      );
      final teaSession = const AttendanceSession(
        id: 's2',
        type: 'Tea Break',
        checkInTime: '03:40:00 PM',
        checkOutTime: '03:48:00 PM', // 8 mins
      );

      expect(lunchSession.effectiveDurationMinutes, 20);
      expect(teaSession.effectiveDurationMinutes, 8);

      final record = AttendanceRecord(
        id: 1,
        employeeId: 101,
        employeeName: 'Test',
        date: '19-09-2026',
        time: '12:45:00 PM',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        sessions: [lunchSession, teaSession],
      );

      expect(record.formattedLunchHours, '20min');
      expect(record.formattedTeaBreakHours, '8min');
      expect(record.formattedTotalHours, '28min');
    });

    // 11. Total hours >= Required Hours -> Shortfall remains 0
    test('11. Total hours >= Required Hours -> Shortfall is 0 (No Overtime)', () {
      final recordEqual = AttendanceRecord(
        id: 1,
        employeeId: 101,
        employeeName: 'Test',
        date: '19-09-2026',
        time: '09:00:00 AM',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        totalHours: 9.0,
      );
      expect(recordEqual.calculateShortfall(9.0), 0.0);
      expect(recordEqual.formattedShortfall(9.0), '0hr');

      final recordOver = AttendanceRecord(
        id: 2,
        employeeId: 101,
        employeeName: 'Test',
        date: '19-09-2026',
        time: '09:00:00 AM',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        totalHours: 11.5,
      );
      expect(recordOver.calculateShortfall(9.0), 0.0);
      expect(recordOver.formattedShortfall(9.0), '0hr');
    });

    // 12. Total hours < Required Hours -> correct Shortfall
    test('12. Total hours < Required Hours -> correct Shortfall computed', () {
      final recordShort = AttendanceRecord(
        id: 1,
        employeeId: 101,
        employeeName: 'Test',
        date: '19-09-2026',
        time: '09:00:00 AM',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        totalHours: 7.25, // 1.75h short = 1h 45m
      );
      expect(recordShort.calculateShortfall(9.0), 1.75);
      expect(recordShort.formattedShortfall(9.0), '1hr 45min');
    });
  });
}
