import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_record.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_session.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_settings.dart';

void main() {
  group('Step 8 — Attendance Rules & AttendanceSession Lifecycle Verification', () {
    // Helper to evaluate attendance status exactly following FirebaseAttendanceRepository logic
    ({String status, String notes}) evaluateAttendanceStatus({
      required String scheduledCheckInTime,
      required String actualCheckInTime,
      required AttendanceSettings settings,
      bool isDynamic = false,
      List<Map<String, dynamic>> approvedPermissions = const [],
    }) {
      if (isDynamic || scheduledCheckInTime.trim().isEmpty) {
        return (status: 'Present', notes: 'Flexible schedule');
      }

      int? parseMinutes(String timeStr) {
        final trimmed = timeStr.trim();
        if (trimmed.isEmpty) return null;
        final parts = trimmed.split(':');
        if (parts.length >= 2) {
          final h = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          if (h != null && m != null) {
            return h * 60 + m;
          }
        }
        return null;
      }

      final scheduledMinutes = parseMinutes(scheduledCheckInTime);
      final actualMinutes = parseMinutes(actualCheckInTime);

      if (scheduledMinutes == null || actualMinutes == null) {
        return (status: 'Present', notes: 'On time');
      }

      int maxApprovedToMinutes = -1;
      int totalApprovedMins = 0;
      for (final p in approvedPermissions) {
        final toStr = (p['to_time'] ?? '').toString();
        final dur = (p['duration_minutes'] as num?)?.toInt() ?? 0;
        totalApprovedMins += dur;
        final toMins = parseMinutes(toStr);
        if (toMins != null && toMins > maxApprovedToMinutes) {
          maxApprovedToMinutes = toMins;
        }
      }

      int effectiveAllowedMinutes = scheduledMinutes + settings.gracePeriodMinutes;
      if (maxApprovedToMinutes > 0) {
        if (maxApprovedToMinutes + settings.gracePeriodMinutes > effectiveAllowedMinutes) {
          effectiveAllowedMinutes = maxApprovedToMinutes + settings.gracePeriodMinutes;
        }
      } else if (totalApprovedMins > 0) {
        effectiveAllowedMinutes = scheduledMinutes + totalApprovedMins + settings.gracePeriodMinutes;
      }

      final netUnauthorizedDelay = actualMinutes - effectiveAllowedMinutes;

      if (netUnauthorizedDelay <= 0) {
        final notes = (totalApprovedMins > 0 || maxApprovedToMinutes > 0)
            ? 'Present (Authorized Permission)'
            : 'On time';
        return (status: 'Present', notes: notes);
      } else if (netUnauthorizedDelay <= settings.lateLimitMinutes) {
        final notes = (totalApprovedMins > 0 || maxApprovedToMinutes > 0)
            ? 'Late = $netUnauthorizedDelay mins unauthorized after permission'
            : 'Late = $netUnauthorizedDelay minutes';
        return (status: 'Late', notes: notes);
      } else {
        final notes = (totalApprovedMins > 0 || maxApprovedToMinutes > 0)
            ? 'Absent (Exceeds late limit cutoff after permission)'
            : 'Absent (Exceeds late limit cutoff of ${settings.lateLimitMinutes} mins)';
        return (status: 'Absent', notes: notes);
      }
    }

    // Helper to simulate office check-in with session
    AttendanceRecord processOfficeCheckIn({
      AttendanceRecord? existingRecord,
      required int employeeId,
      required String employeeName,
      required String date,
      required String checkInTime,
      required String status,
      required String notes,
      String verificationStatus = 'Verified',
      double similarityScore = 1.0,
      double lat = 13.0827,
      double lng = 80.2707,
    }) {
      if (existingRecord != null) {
        final bool hasActiveSession = existingRecord.sessions.any((s) => s.isActive);
        final bool hasLegacyActiveSession = existingRecord.sessions.isEmpty &&
            existingRecord.checkInTime.isNotEmpty &&
            existingRecord.checkOutTime.isEmpty;

        if (hasActiveSession || hasLegacyActiveSession) {
          throw StateError('You already have an active check-in session.');
        }
      }

      final newSessionIndex = (existingRecord?.sessions.length ?? 0) + 1;
      final newSession = AttendanceSession(
        id: 'session_$newSessionIndex',
        checkInTime: checkInTime,
        checkOutTime: '',
        checkInVerificationStatus: verificationStatus,
        checkOutVerificationStatus: '',
        checkInSimilarityScore: similarityScore,
        checkOutSimilarityScore: 0.0,
        checkInLatitude: lat,
        checkInLongitude: lng,
        checkInMethod: 'Face + Geofence',
        durationHours: 0.0,
        durationMinutes: 0,
        notes: notes,
        createdAt: '2026-09-06T$checkInTime:00',
      );

      List<AttendanceSession> updatedSessions = [];
      if (existingRecord != null) {
        updatedSessions = List<AttendanceSession>.from(existingRecord.sessions);
        updatedSessions.add(newSession);

        return existingRecord.copyWith(
          time: existingRecord.time.isNotEmpty ? existingRecord.time : checkInTime,
          checkInTime: existingRecord.checkInTime.isNotEmpty ? existingRecord.checkInTime : checkInTime,
          checkOutTime: existingRecord.checkOutTime,
          status: (existingRecord.status == 'Absent' || existingRecord.status == 'Late')
              ? existingRecord.status
              : status,
          notes: existingRecord.notes.isNotEmpty ? existingRecord.notes : notes,
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
          verificationStatus: verificationStatus,
          similarityScore: similarityScore,
          checkInVerificationStatus: verificationStatus,
          checkInSimilarityScore: similarityScore,
          totalHours: 0.0,
          notes: notes,
          markedAt: '2026-09-06T$checkInTime:00',
          sessions: updatedSessions,
        );
      }
    }

    // Helper to simulate office check-out with session completion
    AttendanceRecord processOfficeCheckOut({
      required AttendanceRecord record,
      required String checkOutTime,
      String verificationStatus = 'Verified',
      double similarityScore = 1.0,
      double lat = 13.0827,
      double lng = 80.2707,
    }) {
      List<AttendanceSession> updatedSessions = List<AttendanceSession>.from(record.sessions);
      int activeIndex = updatedSessions.indexWhere((s) => s.isActive);

      if (activeIndex == -1) {
        throw StateError('No active check-in session found.');
      }

      final activeSession = updatedSessions[activeIndex];
      final inParts = activeSession.checkInTime.split(':');
      final outParts = checkOutTime.split(':');
      final inMin = int.parse(inParts[0]) * 60 + int.parse(inParts[1]);
      final outMin = int.parse(outParts[0]) * 60 + int.parse(outParts[1]);
      final durationMins = (outMin >= inMin) ? (outMin - inMin) : 0;
      final durationHrs = double.parse((durationMins / 60.0).toStringAsFixed(2));

      final completedSession = activeSession.copyWith(
        checkOutTime: checkOutTime,
        checkOutVerificationStatus: verificationStatus,
        checkOutSimilarityScore: similarityScore,
        checkOutLatitude: lat,
        checkOutLongitude: lng,
        checkOutMethod: 'Face + Geofence',
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
        checkOutVerificationStatus: verificationStatus,
        checkOutSimilarityScore: similarityScore,
        totalHours: totalDailyHours,
        sessions: updatedSessions,
      );
    }

    const defaultSettings = AttendanceSettings(
      officeLatitude: 13.0827,
      officeLongitude: 80.2707,
      allowedAttendanceRadiusMeters: 200,
      requireGpsVerification: true,
      gracePeriodMinutes: 10,
      lateLimitMinutes: 30,
    );

    test('1. Grace Period: 09:00 expected, 10 min grace, 09:08 check-in -> Present, active session starts at 09:08', () {
      final evaluation = evaluateAttendanceStatus(
        scheduledCheckInTime: '09:00',
        actualCheckInTime: '09:08',
        settings: defaultSettings,
      );

      expect(evaluation.status, 'Present');
      expect(evaluation.notes, 'On time');

      final record = processOfficeCheckIn(
        employeeId: 1,
        employeeName: 'Grace Employee',
        date: '2026-09-06',
        checkInTime: '09:08',
        status: evaluation.status,
        notes: evaluation.notes,
      );

      expect(record.status, 'Present');
      expect(record.notes, 'On time');
      expect(record.sessions.length, 1);
      expect(record.sessions[0].checkInTime, '09:08');
      expect(record.sessions[0].isActive, isTrue);
      expect(record.sessions[0].isCompleted, isFalse);
    });

    test('2. Late: 09:00 expected, 10 min grace, 09:25 check-in -> Late (15 mins), active session starts at 09:25', () {
      final evaluation = evaluateAttendanceStatus(
        scheduledCheckInTime: '09:00',
        actualCheckInTime: '09:25',
        settings: defaultSettings,
      );

      expect(evaluation.status, 'Late');
      expect(evaluation.notes, 'Late = 15 minutes');

      final record = processOfficeCheckIn(
        employeeId: 2,
        employeeName: 'Late Employee',
        date: '2026-09-06',
        checkInTime: '09:25',
        status: evaluation.status,
        notes: evaluation.notes,
      );

      expect(record.status, 'Late');
      expect(record.notes, 'Late = 15 minutes');
      expect(record.sessions.length, 1);
      expect(record.sessions[0].checkInTime, '09:25');
      expect(record.sessions[0].isActive, isTrue);
    });

    test('3. Absent: 09:00 expected, 10 min grace, 30 min cutoff -> 09:45 check-in -> Absent, active session starts at 09:45', () {
      final evaluation = evaluateAttendanceStatus(
        scheduledCheckInTime: '09:00',
        actualCheckInTime: '09:45',
        settings: defaultSettings,
      );

      expect(evaluation.status, 'Absent');
      expect(evaluation.notes, contains('Absent (Exceeds late limit cutoff of 30 mins)'));

      final record = processOfficeCheckIn(
        employeeId: 3,
        employeeName: 'Absent Employee',
        date: '2026-09-06',
        checkInTime: '09:45',
        status: evaluation.status,
        notes: evaluation.notes,
      );

      expect(record.status, 'Absent');
      expect(record.sessions.length, 1);
      expect(record.sessions[0].checkInTime, '09:45');
      expect(record.sessions[0].isActive, isTrue);
    });

    test('4. Permission: 09:00 expected, 10 min grace, Permission 09:10->09:30, check-in 09:30 -> Present, session starts at 09:30', () {
      final evaluation = evaluateAttendanceStatus(
        scheduledCheckInTime: '09:00',
        actualCheckInTime: '09:30',
        settings: defaultSettings,
        approvedPermissions: [
          {
            'from_time': '09:10',
            'to_time': '09:30',
            'duration_minutes': 20,
            'status': 'Approved',
          }
        ],
      );

      expect(evaluation.status, 'Present');
      expect(evaluation.notes, 'Present (Authorized Permission)');

      final record = processOfficeCheckIn(
        employeeId: 4,
        employeeName: 'Permission Employee',
        date: '2026-09-06',
        checkInTime: '09:30',
        status: evaluation.status,
        notes: evaluation.notes,
      );

      expect(record.status, 'Present');
      expect(record.notes, 'Present (Authorized Permission)');
      expect(record.sessions.length, 1);
      expect(record.sessions[0].checkInTime, '09:30');
      expect(record.sessions[0].isActive, isTrue);
      expect(record.sessions[0].checkOutTime, isEmpty);
    });

    test('5. Multiple sessions + attendance status: 09:20 In, 13:00 Out, 14:00 In, 17:30 Out -> Status Late, Total Hours 7.17h (7h 10m)', () {
      // First check-in at 09:20 (Late by 10 mins over 10 min grace)
      final eval1 = evaluateAttendanceStatus(
        scheduledCheckInTime: '09:00',
        actualCheckInTime: '09:20',
        settings: defaultSettings,
      );
      expect(eval1.status, 'Late');
      expect(eval1.notes, 'Late = 10 minutes');

      // 1. Check in at 09:20
      final r1 = processOfficeCheckIn(
        employeeId: 5,
        employeeName: 'Multi Session Employee',
        date: '2026-09-06',
        checkInTime: '09:20',
        status: eval1.status,
        notes: eval1.notes,
      );
      expect(r1.status, 'Late');
      expect(r1.sessions.length, 1);
      expect(r1.sessions[0].checkInTime, '09:20');
      expect(r1.sessions[0].isActive, isTrue);

      // 2. Check out at 13:00 (Session 1: 09:20 -> 13:00 = 220 mins / 3h 40m = 3.67h)
      final r2 = processOfficeCheckOut(record: r1, checkOutTime: '13:00');
      expect(r2.status, 'Late'); // Daily status remains Late
      expect(r2.sessions.length, 1);
      expect(r2.sessions[0].isCompleted, isTrue);
      expect(r2.sessions[0].durationMinutes, 220); // 3h 40m
      expect(r2.sessions[0].durationHours, 3.67);
      expect(r2.totalHours, 3.67);

      // 3. Second Check in at 14:00 (Session 2 starts)
      final r3 = processOfficeCheckIn(
        existingRecord: r2,
        employeeId: 5,
        employeeName: 'Multi Session Employee',
        date: '2026-09-06',
        checkInTime: '14:00',
        status: 'Present', // New evaluation on afternoon checkin should not overwrite 'Late'
        notes: 'Afternoon session',
      );
      expect(r3.status, 'Late'); // Verifies 'Late' is preserved and NOT overwritten
      expect(r3.sessions.length, 2);
      expect(r3.sessions[0].isCompleted, isTrue);
      expect(r3.sessions[1].checkInTime, '14:00');
      expect(r3.sessions[1].isActive, isTrue);
      expect(r3.totalHours, 3.67); // Active session doesn't add incomplete hours yet

      // 4. Second Check out at 17:30 (Session 2: 14:00 -> 17:30 = 210 mins / 3h 30m = 3.5h)
      final r4 = processOfficeCheckOut(record: r3, checkOutTime: '17:30');
      expect(r4.status, 'Late'); // Status still Late
      expect(r4.sessions.length, 2);
      expect(r4.sessions[1].isCompleted, isTrue);
      expect(r4.sessions[1].durationMinutes, 210); // 3h 30m
      expect(r4.sessions[1].durationHours, 3.5);

      // Total daily hours: 220 mins (3h 40m) + 210 mins (3h 30m) = 430 mins = 7h 10m = 7.17h
      final totalMinutes = r4.sessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);
      expect(totalMinutes, 430); // 7h 10m
      final totalHoursDisplay = '${totalMinutes ~/ 60}h ${totalMinutes % 60}m';
      expect(totalHoursDisplay, '7h 10m');
      expect(r4.totalHours, 7.17);

      // Verify Separation: Attendance status (Late) ≠ Session duration (7h 10m / 2 sessions)
      expect(r4.status, 'Late');
      expect(r4.sessions.length, 2);
    });
  });
}
