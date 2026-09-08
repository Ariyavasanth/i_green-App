import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_record.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_session.dart';

void main() {
  group('Steps 10–14: On-Duty (OD) Sessions, Multi-Transitions & Lifecycle Tests', () {
    // Helper to simulate office check-in
    AttendanceRecord simulateOfficeCheckIn({
      AttendanceRecord? existingRecord,
      required int employeeId,
      required String employeeName,
      required String date,
      required String checkInTime,
      String status = 'Present',
    }) {
      if (existingRecord != null) {
        final hasActive = existingRecord.sessions.any((s) => s.isActive);
        if (hasActive) {
          final active = existingRecord.sessions.firstWhere((s) => s.isActive);
          if (active.isOd) {
            throw StateError('You have an active On-Duty session. Please complete On-Duty before checking in at the office.');
          }
          throw StateError('You already have an active check-in session.');
        }
      }

      final newIndex = (existingRecord?.sessions.length ?? 0) + 1;
      final newSession = AttendanceSession(
        id: 'session_$newIndex',
        type: 'office',
        checkInTime: checkInTime,
        checkOutTime: '',
        checkInVerificationStatus: 'Verified',
        createdAt: '2026-09-06T$checkInTime:00',
      );

      List<AttendanceSession> updatedSessions = [];
      if (existingRecord != null) {
        updatedSessions = List<AttendanceSession>.from(existingRecord.sessions);
        updatedSessions.add(newSession);

        return existingRecord.copyWith(
          checkInTime: existingRecord.checkInTime.isNotEmpty ? existingRecord.checkInTime : checkInTime,
          checkOutTime: existingRecord.checkOutTime,
          sessions: updatedSessions,
        );
      } else {
        updatedSessions.add(newSession);
        return AttendanceRecord(
          id: 101,
          employeeId: employeeId,
          employeeName: employeeName,
          date: date,
          time: checkInTime,
          checkInTime: checkInTime,
          checkOutTime: '',
          status: status,
          verificationStatus: 'Verified',
          similarityScore: 1.0,
          totalHours: 0.0,
          sessions: updatedSessions,
        );
      }
    }

    // Helper to simulate office checkout
    AttendanceRecord simulateOfficeCheckOut({
      required AttendanceRecord record,
      required String checkOutTime,
    }) {
      List<AttendanceSession> updatedSessions = List<AttendanceSession>.from(record.sessions);
      int activeIndex = updatedSessions.indexWhere((s) => s.isActive);

      if (activeIndex == -1) {
        throw StateError('No active check-in session found.');
      }

      final activeSession = updatedSessions[activeIndex];
      if (activeSession.isOd) {
        throw StateError('The active session is an On-Duty session. Please complete On-Duty from the OD card.');
      }

      final inParts = activeSession.checkInTime.split(':');
      final outParts = checkOutTime.split(':');
      final inMin = int.parse(inParts[0]) * 60 + int.parse(inParts[1]);
      final outMin = int.parse(outParts[0]) * 60 + int.parse(outParts[1]);
      final durationMins = (outMin >= inMin) ? (outMin - inMin) : 0;
      final durationHrs = double.parse((durationMins / 60.0).toStringAsFixed(2));

      final completedSession = activeSession.copyWith(
        checkOutTime: checkOutTime,
        checkOutVerificationStatus: 'Verified',
        durationHours: durationHrs,
        durationMinutes: durationMins,
      );
      updatedSessions[activeIndex] = completedSession;

      double totalDailyHours = 0.0;
      for (final s in updatedSessions) {
        if (s.isCompleted) {
          totalDailyHours += s.effectiveDurationHours;
        }
      }
      totalDailyHours = double.parse(totalDailyHours.toStringAsFixed(2));

      return record.copyWith(
        checkOutTime: checkOutTime,
        totalHours: totalDailyHours,
        sessions: updatedSessions,
      );
    }

    // Helper to simulate starting OD
    AttendanceRecord simulateStartOd({
      AttendanceRecord? existingRecord,
      required int employeeId,
      required String employeeName,
      required String date,
      required String startTime,
      required int assignmentId,
      required String purpose,
      required String destination,
      String assignmentStatus = 'ASSIGNED',
    }) {
      if (assignmentStatus == 'CANCELLED' || assignmentStatus == 'REJECTED') {
        throw StateError('This On-Duty assignment has been cancelled or rejected.');
      }

      if (existingRecord != null) {
        final hasActive = existingRecord.sessions.any((s) => s.isActive);
        if (hasActive) {
          final active = existingRecord.sessions.firstWhere((s) => s.isActive);
          if (active.isOffice) {
            throw StateError('You are currently checked in at the office. Please check out before starting On-Duty.');
          }
          throw StateError('You already have an active On-Duty session in progress.');
        }
      }

      final newIndex = (existingRecord?.sessions.length ?? 0) + 1;
      final newSession = AttendanceSession(
        id: 'session_$newIndex',
        type: 'od',
        assignmentId: assignmentId,
        purpose: purpose,
        destination: destination,
        checkInTime: startTime,
        checkOutTime: '',
        checkInVerificationStatus: 'OD Verified',
        checkInMethod: 'OD GPS + Photo',
        notes: 'On Duty: $purpose ($destination)',
        createdAt: '2026-09-06T$startTime:00',
      );

      List<AttendanceSession> updatedSessions = [];
      if (existingRecord != null) {
        updatedSessions = List<AttendanceSession>.from(existingRecord.sessions);
        updatedSessions.add(newSession);

        return existingRecord.copyWith(
          time: existingRecord.time.isNotEmpty ? existingRecord.time : startTime,
          checkInTime: existingRecord.checkInTime.isNotEmpty ? existingRecord.checkInTime : startTime,
          checkOutTime: existingRecord.checkOutTime,
          sessions: updatedSessions,
        );
      } else {
        updatedSessions.add(newSession);
        return AttendanceRecord(
          id: 101,
          employeeId: employeeId,
          employeeName: employeeName,
          date: date,
          time: startTime,
          checkInTime: startTime,
          checkOutTime: '',
          status: 'Present',
          verificationStatus: 'OD Verified',
          similarityScore: 1.0,
          totalHours: 0.0,
          notes: 'On Duty: $purpose ($destination)',
          sessions: updatedSessions,
        );
      }
    }

    // Helper to simulate completing OD
    AttendanceRecord simulateCompleteOd({
      required AttendanceRecord record,
      required String endTime,
      required int assignmentId,
      String afterCompletionOption = 'RETURN_TO_OFFICE',
    }) {
      List<AttendanceSession> updatedSessions = List<AttendanceSession>.from(record.sessions);
      int activeIndex = updatedSessions.indexWhere((s) => s.isActive && s.isOd);

      if (activeIndex == -1) {
        throw StateError('No active On-Duty session found.');
      }

      final activeSession = updatedSessions[activeIndex];
      final inParts = activeSession.checkInTime.split(':');
      final outParts = endTime.split(':');
      final inMin = int.parse(inParts[0]) * 60 + int.parse(inParts[1]);
      final outMin = int.parse(outParts[0]) * 60 + int.parse(outParts[1]);
      final durationMins = (outMin >= inMin) ? (outMin - inMin) : 0;
      final durationHrs = double.parse((durationMins / 60.0).toStringAsFixed(2));

      final completedSession = activeSession.copyWith(
        checkOutTime: endTime,
        checkOutVerificationStatus: 'OD Completed',
        checkOutMethod: 'OD GPS Capture',
        durationHours: durationHrs,
        durationMinutes: durationMins,
      );
      updatedSessions[activeIndex] = completedSession;

      double totalDailyHours = 0.0;
      for (final s in updatedSessions) {
        if (s.isCompleted) {
          totalDailyHours += s.effectiveDurationHours;
        }
      }
      totalDailyHours = double.parse(totalDailyHours.toStringAsFixed(2));

      final isCheckoutFromOd = afterCompletionOption == 'CHECKOUT_FROM_OD';

      return record.copyWith(
        checkOutTime: isCheckoutFromOd ? endTime : record.checkOutTime,
        checkOutVerificationStatus: isCheckoutFromOd ? 'OD Location Verified' : record.checkOutVerificationStatus,
        totalHours: totalDailyHours,
        sessions: updatedSessions,
      );
    }

    test('Step 11: Multi-Transition Flow: Office (4h) -> OD (3h) -> Office (1h) = Total 8h', () {
      // 1. Office Check-In 1: 09:00
      final r1 = simulateOfficeCheckIn(
        employeeId: 1,
        employeeName: 'Transition Employee',
        date: '2026-09-06',
        checkInTime: '09:00',
      );
      expect(r1.sessions.length, 1);
      expect(r1.sessions[0].isOffice, isTrue);
      expect(r1.sessions[0].isActive, isTrue);

      // 2. Office Check-Out 1: 13:00 (Duration: 4h)
      final r2 = simulateOfficeCheckOut(record: r1, checkOutTime: '13:00');
      expect(r2.sessions[0].isCompleted, isTrue);
      expect(r2.sessions[0].durationHours, 4.0);
      expect(r2.totalHours, 4.0);

      // 3. OD Start: 14:00 (Assignment #501)
      final r3 = simulateStartOd(
        existingRecord: r2,
        employeeId: 1,
        employeeName: 'Transition Employee',
        date: '2026-09-06',
        startTime: '14:00',
        assignmentId: 501,
        purpose: 'Client Demo',
        destination: 'Tech Park Zone B',
      );
      expect(r3.sessions.length, 2);
      expect(r3.sessions[1].isOd, isTrue);
      expect(r3.sessions[1].isActive, isTrue);
      expect(r3.sessions[1].assignmentId, 501);
      expect(r3.sessions[1].purpose, 'Client Demo');

      // 4. OD Complete: 17:00 (Duration: 3h, Return to Office)
      final r4 = simulateCompleteOd(
        record: r3,
        endTime: '17:00',
        assignmentId: 501,
        afterCompletionOption: 'RETURN_TO_OFFICE',
      );
      expect(r4.sessions[1].isCompleted, isTrue);
      expect(r4.sessions[1].durationHours, 3.0);
      expect(r4.totalHours, 7.0); // 4h + 3h = 7h

      // 5. Office Check-In 2: 17:30
      final r5 = simulateOfficeCheckIn(
        existingRecord: r4,
        employeeId: 1,
        employeeName: 'Transition Employee',
        date: '2026-09-06',
        checkInTime: '17:30',
      );
      expect(r5.sessions.length, 3);
      expect(r5.sessions[2].isOffice, isTrue);
      expect(r5.sessions[2].isActive, isTrue);
      expect(r5.totalHours, 7.0); // active session does not add uncompleted time

      // 6. Office Check-Out 2: 18:30 (Duration: 1h)
      final r6 = simulateOfficeCheckOut(record: r5, checkOutTime: '18:30');
      expect(r6.sessions.length, 3);
      expect(r6.sessions[2].isCompleted, isTrue);
      expect(r6.sessions[2].durationHours, 1.0);

      // Verify Total Aggregated Working Hours: 4h + 3h + 1h = 8h (480 mins)
      expect(r6.totalHours, 8.0);
      final totalMinutes = r6.sessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);
      expect(totalMinutes, 480);
      expect(r6.sessions.every((s) => s.isCompleted), isTrue);
    });

    test('Step 12: OD Approval Guard: Starting OD with Cancelled or Rejected assignment is blocked', () {
      expect(
        () => simulateStartOd(
          employeeId: 1,
          employeeName: 'Guard Employee',
          date: '2026-09-06',
          startTime: '10:00',
          assignmentId: 502,
          purpose: 'Site Audit',
          destination: 'Site 4',
          assignmentStatus: 'CANCELLED',
        ),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('cancelled or rejected'))),
      );
    });

    test('Step 14: Mutual Exclusion 1: Starting OD while Office session is active is blocked', () {
      final activeOffice = simulateOfficeCheckIn(
        employeeId: 1,
        employeeName: 'Mutual Exclusion Employee',
        date: '2026-09-06',
        checkInTime: '09:00',
      );

      expect(
        () => simulateStartOd(
          existingRecord: activeOffice,
          employeeId: 1,
          employeeName: 'Mutual Exclusion Employee',
          date: '2026-09-06',
          startTime: '11:00',
          assignmentId: 503,
          purpose: 'Meeting',
          destination: 'Client HQ',
        ),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('currently checked in at the office'))),
      );
    });

    test('Step 14: Mutual Exclusion 2: Checking in to Office while OD session is active is blocked', () {
      final activeOd = simulateStartOd(
        employeeId: 1,
        employeeName: 'Mutual Exclusion Employee',
        date: '2026-09-06',
        startTime: '09:00',
        assignmentId: 504,
        purpose: 'Field Work',
        destination: 'Solar Park',
      );

      expect(
        () => simulateOfficeCheckIn(
          existingRecord: activeOd,
          employeeId: 1,
          employeeName: 'Mutual Exclusion Employee',
          date: '2026-09-06',
          checkInTime: '11:00',
        ),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('active On-Duty session'))),
      );
    });

    test('Step 14: Mutual Exclusion 3: Starting a second OD session while an OD is active is blocked', () {
      final activeOd = simulateStartOd(
        employeeId: 1,
        employeeName: 'Mutual Exclusion Employee',
        date: '2026-09-06',
        startTime: '09:00',
        assignmentId: 505,
        purpose: 'Site Inspection',
        destination: 'Site A',
      );

      expect(
        () => simulateStartOd(
          existingRecord: activeOd,
          employeeId: 1,
          employeeName: 'Mutual Exclusion Employee',
          date: '2026-09-06',
          startTime: '10:00',
          assignmentId: 506,
          purpose: 'Site Inspection 2',
          destination: 'Site B',
        ),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('active On-Duty session in progress'))),
      );
    });

    test('Step 10 Scenario B: Direct Morning OD (3.5h) -> Afternoon Office (4.5h) = Total 8.0h', () {
      // 1. Employee starts morning directly on field (09:00 -> 12:30)
      final r1 = simulateStartOd(
        employeeId: 2,
        employeeName: 'Morning OD Employee',
        date: '2026-09-06',
        startTime: '09:00',
        assignmentId: 507,
        purpose: 'Client Morning Consultation',
        destination: 'Client Factory',
      );
      expect(r1.status, 'Present');
      expect(r1.sessions.length, 1);
      expect(r1.sessions[0].isOd, isTrue);

      final r2 = simulateCompleteOd(
        record: r1,
        endTime: '12:30',
        assignmentId: 507,
        afterCompletionOption: 'RETURN_TO_OFFICE',
      );
      expect(r2.sessions[0].durationHours, 3.5);
      expect(r2.totalHours, 3.5);

      // 2. Afternoon Office Session (13:30 -> 18:00)
      final r3 = simulateOfficeCheckIn(
        existingRecord: r2,
        employeeId: 2,
        employeeName: 'Morning OD Employee',
        date: '2026-09-06',
        checkInTime: '13:30',
      );
      final r4 = simulateOfficeCheckOut(record: r3, checkOutTime: '18:00');
      expect(r4.sessions.length, 2);
      expect(r4.sessions[1].isOffice, isTrue);
      expect(r4.sessions[1].durationHours, 4.5);

      // Total = 3.5h + 4.5h = 8.0h
      expect(r4.totalHours, 8.0);
    });

    test('Step 10 Scenario C: Full Day OD (8h) with Direct Checkout from OD location', () {
      final r1 = simulateStartOd(
        employeeId: 3,
        employeeName: 'Full Day OD Employee',
        date: '2026-09-06',
        startTime: '09:30',
        assignmentId: 508,
        purpose: 'Full Day Gov Inspection',
        destination: 'Govt Department',
      );

      final r2 = simulateCompleteOd(
        record: r1,
        endTime: '17:30',
        assignmentId: 508,
        afterCompletionOption: 'CHECKOUT_FROM_OD',
      );

      expect(r2.sessions.length, 1);
      expect(r2.sessions[0].isOd, isTrue);
      expect(r2.sessions[0].durationHours, 8.0);
      expect(r2.totalHours, 8.0);
      expect(r2.checkOutTime, '17:30');
      expect(r2.checkOutVerificationStatus, 'OD Location Verified');
    });

    test('Serialization: AttendanceSession toMap and fromMap round-trip preserves all OD fields', () {
      const session = AttendanceSession(
        id: 'session_od_101',
        type: 'od',
        checkInTime: '14:00',
        checkOutTime: '17:00',
        checkInVerificationStatus: 'OD Verified',
        checkOutVerificationStatus: 'OD Completed',
        checkInMethod: 'OD GPS + Photo',
        checkOutMethod: 'OD GPS Capture',
        assignmentId: 888,
        purpose: 'Vendor Meet',
        destination: 'North Hub',
        durationHours: 3.0,
        durationMinutes: 180,
        notes: 'Important client meeting',
        createdAt: '2026-09-06T14:00:00',
      );

      final map = session.toMap();
      final deserialized = AttendanceSession.fromMap(map);

      expect(deserialized.id, 'session_od_101');
      expect(deserialized.type, 'od');
      expect(deserialized.isOd, isTrue);
      expect(deserialized.isOffice, isFalse);
      expect(deserialized.assignmentId, 888);
      expect(deserialized.purpose, 'Vendor Meet');
      expect(deserialized.destination, 'North Hub');
      expect(deserialized.checkInTime, '14:00');
      expect(deserialized.checkOutTime, '17:00');
      expect(deserialized.durationHours, 3.0);
      expect(deserialized.durationMinutes, 180);
      expect(deserialized.notes, 'Important client meeting');
    });
  });
}
