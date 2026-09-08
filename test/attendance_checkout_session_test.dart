import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_record.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_session.dart';

void main() {
  group('Office Employee Multi-Session Attendance Lifecycle Audit', () {
    // Helper function to simulate session checkout calculation like FirebaseAttendanceRepository
    AttendanceRecord processSessionCheckOut({
      required AttendanceRecord record,
      required String checkOutTime,
      String verificationStatus = 'Verified',
      double similarityScore = 1.0,
      double? lat,
      double? lng,
    }) {
      List<AttendanceSession> updatedSessions = List<AttendanceSession>.from(record.sessions);
      int activeIndex = updatedSessions.indexWhere((s) => s.isActive);

      // Legacy fallback
      if (activeIndex == -1 &&
          updatedSessions.isEmpty &&
          record.checkInTime.isNotEmpty &&
          record.checkOutTime.isEmpty) {
        final legacySession = AttendanceSession(
          id: 'session_legacy_1',
          checkInTime: record.checkInTime,
          checkOutTime: '',
          checkInVerificationStatus: record.checkInVerificationStatus.isNotEmpty
              ? record.checkInVerificationStatus
              : record.verificationStatus,
          checkOutVerificationStatus: '',
          checkInSimilarityScore: record.checkInSimilarityScore > 0
              ? record.checkInSimilarityScore
              : record.similarityScore,
          checkOutSimilarityScore: 0.0,
          durationHours: 0.0,
          durationMinutes: 0,
          notes: record.notes,
          createdAt: record.markedAt,
        );
        updatedSessions.add(legacySession);
        activeIndex = 0;
      }

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

    // Helper function to simulate session check-in like FirebaseAttendanceRepository
    AttendanceRecord processSessionCheckIn({
      AttendanceRecord? existingRecord,
      required int employeeId,
      required String employeeName,
      required String date,
      required String checkInTime,
      String verificationStatus = 'Verified',
      double similarityScore = 1.0,
      String status = 'Present',
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
        checkInMethod: 'Face + Geofence',
        durationHours: 0.0,
        durationMinutes: 0,
        createdAt: '2026-09-06T$checkInTime:00',
      );

      List<AttendanceSession> updatedSessions = [];
      if (existingRecord != null) {
        updatedSessions = List<AttendanceSession>.from(existingRecord.sessions);
        if (updatedSessions.isEmpty &&
            existingRecord.checkInTime.isNotEmpty &&
            existingRecord.checkOutTime.isNotEmpty) {
          updatedSessions.add(AttendanceSession(
            id: 'session_legacy_1',
            checkInTime: existingRecord.checkInTime,
            checkOutTime: existingRecord.checkOutTime,
            checkInVerificationStatus: existingRecord.checkInVerificationStatus.isNotEmpty
                ? existingRecord.checkInVerificationStatus
                : existingRecord.verificationStatus,
            checkOutVerificationStatus: existingRecord.checkOutVerificationStatus,
            checkInSimilarityScore: existingRecord.checkInSimilarityScore > 0
                ? existingRecord.checkInSimilarityScore
                : existingRecord.similarityScore,
            checkOutSimilarityScore: existingRecord.checkOutSimilarityScore,
            durationHours: existingRecord.totalHours,
            durationMinutes: (existingRecord.totalHours * 60).round(),
            notes: existingRecord.notes,
            createdAt: existingRecord.markedAt,
          ));
        }
        updatedSessions.add(newSession);

        return existingRecord.copyWith(
          time: existingRecord.time.isNotEmpty ? existingRecord.time : checkInTime,
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
          verificationStatus: verificationStatus,
          similarityScore: similarityScore,
          checkInVerificationStatus: verificationStatus,
          checkInSimilarityScore: similarityScore,
          totalHours: 0.0,
          markedAt: '2026-09-06T$checkInTime:00',
          sessions: updatedSessions,
        );
      }
    }

    test('Scenario 1: First Office session check-in creates active session without losing completed sessions', () {
      final record = processSessionCheckIn(
        employeeId: 1,
        employeeName: 'Office Employee',
        date: '2026-09-06',
        checkInTime: '09:00',
      );

      expect(record.sessions.length, 1);
      expect(record.sessions[0].id, 'session_1');
      expect(record.sessions[0].checkInTime, '09:00');
      expect(record.sessions[0].checkOutTime, isEmpty);
      expect(record.sessions[0].isActive, isTrue);
      expect(record.sessions[0].isCompleted, isFalse);
      expect(record.checkInTime, '09:00');
      expect(record.checkOutTime, isEmpty);
      expect(record.totalHours, 0.0);
    });

    test('Scenario 2: First checkout completes session 1 with 4.0h duration and totalHours = 4.0', () {
      final initialRecord = processSessionCheckIn(
        employeeId: 1,
        employeeName: 'Office Employee',
        date: '2026-09-06',
        checkInTime: '09:00',
      );

      final checkedOutRecord = processSessionCheckOut(
        record: initialRecord,
        checkOutTime: '13:00',
      );

      expect(checkedOutRecord.sessions.length, 1);
      final s1 = checkedOutRecord.sessions[0];
      expect(s1.checkInTime, '09:00');
      expect(s1.checkOutTime, '13:00');
      expect(s1.isActive, isFalse);
      expect(s1.isCompleted, isTrue);
      expect(s1.durationMinutes, 240);
      expect(s1.durationHours, 4.0);
      expect(s1.effectiveDurationHours, 4.0);
      expect(checkedOutRecord.totalHours, 4.0);
      expect(checkedOutRecord.checkOutTime, '13:00');
    });

    test('Scenario 3: Second Office check-in at 14:00 creates session 2 active, keeps session 1, gap not counted', () {
      final initialRecord = processSessionCheckIn(
        employeeId: 1,
        employeeName: 'Office Employee',
        date: '2026-09-06',
        checkInTime: '09:00',
      );
      final afterFirstCheckout = processSessionCheckOut(
        record: initialRecord,
        checkOutTime: '13:00',
      );

      final afterSecondCheckIn = processSessionCheckIn(
        existingRecord: afterFirstCheckout,
        employeeId: 1,
        employeeName: 'Office Employee',
        date: '2026-09-06',
        checkInTime: '14:00',
      );

      expect(afterSecondCheckIn.sessions.length, 2);
      
      // Session 1 remains completed
      final s1 = afterSecondCheckIn.sessions[0];
      expect(s1.isCompleted, isTrue);
      expect(s1.checkInTime, '09:00');
      expect(s1.checkOutTime, '13:00');
      expect(s1.effectiveDurationHours, 4.0);

      // Session 2 is active
      final s2 = afterSecondCheckIn.sessions[1];
      expect(s2.isActive, isTrue);
      expect(s2.isCompleted, isFalse);
      expect(s2.checkInTime, '14:00');
      expect(s2.checkOutTime, isEmpty);

      // totalHours still represents completed sessions (4.0 hours)
      expect(afterSecondCheckIn.totalHours, 4.0);
      
      // Gap from 13:00 to 14:00 is not counted in total completed hours
      final completedHours = afterSecondCheckIn.sessions
          .where((s) => s.isCompleted)
          .fold<double>(0.0, (acc, s) => acc + s.effectiveDurationHours);
      expect(completedHours, 4.0);
    });

    test('Scenario 4: Second checkout at 17:30 completes session 2 (3.5h) and totalHours = 7.5h', () {
      final r1 = processSessionCheckIn(
        employeeId: 1,
        employeeName: 'Office Employee',
        date: '2026-09-06',
        checkInTime: '09:00',
      );
      final r2 = processSessionCheckOut(record: r1, checkOutTime: '13:00');
      final r3 = processSessionCheckIn(
        existingRecord: r2,
        employeeId: 1,
        employeeName: 'Office Employee',
        date: '2026-09-06',
        checkInTime: '14:00',
      );
      final finalRecord = processSessionCheckOut(record: r3, checkOutTime: '17:30');

      expect(finalRecord.sessions.length, 2);
      
      final s1 = finalRecord.sessions[0];
      expect(s1.checkInTime, '09:00');
      expect(s1.checkOutTime, '13:00');
      expect(s1.isCompleted, isTrue);
      expect(s1.durationHours, 4.0);
      expect(s1.effectiveDurationHours, 4.0);

      final s2 = finalRecord.sessions[1];
      expect(s2.checkInTime, '14:00');
      expect(s2.checkOutTime, '17:30');
      expect(s2.isCompleted, isTrue);
      expect(s2.durationMinutes, 210);
      expect(s2.durationHours, 3.5);
      expect(s2.effectiveDurationHours, 3.5);

      expect(finalRecord.checkInTime, '09:00');
      expect(finalRecord.checkOutTime, '17:30');
      expect(finalRecord.totalHours, 7.5);
      expect(finalRecord.sessions.any((s) => s.isActive), isFalse);
    });

    test('Scenario 5: Duplicate Office check-in while a session is active is rejected', () {
      final activeRecord = processSessionCheckIn(
        employeeId: 1,
        employeeName: 'Office Employee',
        date: '2026-09-06',
        checkInTime: '09:00',
      );

      expect(
        () => processSessionCheckIn(
          existingRecord: activeRecord,
          employeeId: 1,
          employeeName: 'Office Employee',
          date: '2026-09-06',
          checkInTime: '09:30',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('already have an active check-in session'),
        )),
      );

      // Verify no extra session was added
      expect(activeRecord.sessions.length, 1);
      expect(activeRecord.sessions[0].checkInTime, '09:00');
    });

    test('Scenario 6: Duplicate Office checkout when no active session is rejected and completed sessions unchanged', () {
      final r1 = processSessionCheckIn(
        employeeId: 1,
        employeeName: 'Office Employee',
        date: '2026-09-06',
        checkInTime: '09:00',
      );
      final completedRecord = processSessionCheckOut(record: r1, checkOutTime: '13:00');

      expect(
        () => processSessionCheckOut(
          record: completedRecord,
          checkOutTime: '13:30',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('No active check-in session found'),
        )),
      );

      // Verify completed session remains unchanged
      expect(completedRecord.sessions.length, 1);
      expect(completedRecord.sessions[0].checkInTime, '09:00');
      expect(completedRecord.sessions[0].checkOutTime, '13:00');
      expect(completedRecord.totalHours, 4.0);
    });

    test('Scenario 7: Legacy compatibility handles legacy AttendanceRecord seamlessly', () {
      // 7a. Legacy active check-in (checkInTime present, checkOutTime empty, sessions empty)
      const legacyActiveRecord = AttendanceRecord(
        id: 201,
        employeeId: 2,
        employeeName: 'Legacy Employee',
        date: '2026-09-06',
        time: '09:00',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        checkInTime: '09:00',
        checkOutTime: '',
        totalHours: 0.0,
        sessions: [],
      );

      final checkedOutLegacy = processSessionCheckOut(
        record: legacyActiveRecord,
        checkOutTime: '13:00',
      );

      expect(checkedOutLegacy.sessions.length, 1);
      expect(checkedOutLegacy.sessions[0].checkInTime, '09:00');
      expect(checkedOutLegacy.sessions[0].checkOutTime, '13:00');
      expect(checkedOutLegacy.sessions[0].isCompleted, isTrue);
      expect(checkedOutLegacy.totalHours, 4.0);

      // 7b. Legacy completed record receives second check-in
      const legacyCompletedRecord = AttendanceRecord(
        id: 202,
        employeeId: 2,
        employeeName: 'Legacy Employee',
        date: '2026-09-06',
        time: '09:00',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        checkInTime: '09:00',
        checkOutTime: '13:00',
        totalHours: 4.0,
        sessions: [],
      );

      final secondCheckInFromLegacy = processSessionCheckIn(
        existingRecord: legacyCompletedRecord,
        employeeId: 2,
        employeeName: 'Legacy Employee',
        date: '2026-09-06',
        checkInTime: '14:00',
      );

      expect(secondCheckInFromLegacy.sessions.length, 2);
      expect(secondCheckInFromLegacy.sessions[0].checkInTime, '09:00');
      expect(secondCheckInFromLegacy.sessions[0].checkOutTime, '13:00');
      expect(secondCheckInFromLegacy.sessions[0].effectiveDurationHours, 4.0);
      expect(secondCheckInFromLegacy.sessions[1].checkInTime, '14:00');
      expect(secondCheckInFromLegacy.sessions[1].isActive, isTrue);

      // 7c. fromMap parses legacy Firestore document without sessions map
      final legacyMap = {
        'id': 203,
        'employee_id': 2,
        'employee_name': 'Legacy Employee',
        'date': '2026-09-06',
        'time': '09:00',
        'status': 'Present',
        'verification_status': 'Verified',
        'similarity_score': 1.0,
        'check_in_time': '09:00',
        'check_out_time': '17:00',
        'total_hours': 8.0,
      };

      final parsedLegacy = AttendanceRecord.fromMap(legacyMap);
      expect(parsedLegacy.sessions, isEmpty);
      expect(parsedLegacy.checkInTime, '09:00');
      expect(parsedLegacy.checkOutTime, '17:00');
      expect(parsedLegacy.totalHours, 8.0);
    });

    test('Scenario 8: Site/Dynamic Employee continuous single-session regression check', () {
      // Dynamic employees do not use multiple session segments; duration is continuous
      const dynamicIn = '09:00';
      const dynamicOut = '17:30';

      final inParts = dynamicIn.split(':');
      final outParts = dynamicOut.split(':');
      final inMin = int.parse(inParts[0]) * 60 + int.parse(inParts[1]);
      final outMin = int.parse(outParts[0]) * 60 + int.parse(outParts[1]);
      final hours = double.parse(((outMin - inMin) / 60.0).toStringAsFixed(2));

      final dynamicRecord = AttendanceRecord(
        id: 301,
        employeeId: 3,
        employeeName: 'Site/Dynamic Employee',
        date: '2026-09-06',
        time: dynamicIn,
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        checkInTime: dynamicIn,
        checkOutTime: dynamicOut,
        totalHours: hours,
        sessions: const [], // Site employees have no session splitting
      );

      expect(dynamicRecord.totalHours, 8.5);
      expect(dynamicRecord.sessions, isEmpty);
      expect(dynamicRecord.checkInTime, '09:00');
      expect(dynamicRecord.checkOutTime, '17:30');
    });
  });
}
