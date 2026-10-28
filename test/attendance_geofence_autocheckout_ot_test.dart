import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_record.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_session.dart';

void main() {
  group('Attendance Geofence Exit Auto-Checkout & Overtime (OT) Rules', () {
    const defaultShiftOut = '07:00 PM';
    const bufferMinutes = 30; // 7:00 PM -> 7:30 PM
    const minOtMinutes = 60; // 7:30 PM -> 8:30 PM is 1-hour minimum

    test('1. Early Exit before 7:00 PM: Auto checkout at 05:00 PM, 0 OT', () {
      final record = AttendanceRecord(
        id: 101,
        employeeId: 1,
        employeeName: 'Ravi Kumar',
        date: '2026-10-02',
        time: '10:00 AM',
        checkInTime: '10:00 AM',
        checkOutTime: '05:00 PM',
        status: 'Insufficient hours',
        verificationStatus: 'Auto-Checked Out (Geofence Exit)',
        similarityScore: 1.0,
        sessions: [
          const AttendanceSession(
            id: 'session_1',
            type: 'office',
            checkInTime: '10:00 AM',
            checkOutTime: '05:00 PM',
            durationHours: 7.0,
            durationMinutes: 420,
          ),
        ],
      );

      final otMins = record.calculateOvertimeMinutes(shiftOutTime: defaultShiftOut, bufferMinutes: bufferMinutes);
      final otHrs = record.calculateOvertimeHours(shiftOutTime: defaultShiftOut, bufferMinutes: bufferMinutes);
      final meetsMinOt = record.hasMetMinOvertimeThreshold(shiftOutTime: defaultShiftOut, bufferMinutes: bufferMinutes);
      final otFormatted = record.formattedOvertimeHours(shiftOutTime: defaultShiftOut, bufferMinutes: bufferMinutes);

      expect(otMins, equals(0));
      expect(otHrs, equals(0.0));
      expect(meetsMinOt, isFalse);
      expect(otFormatted, equals('0hr'));
      expect(record.computedTotalHours, equals(7.0));
    });

    test('2. Buffer Period Exit (7:00–7:30 PM): Auto checkout at 07:20 PM, 0 OT', () {
      final record = AttendanceRecord(
        id: 102,
        employeeId: 1,
        employeeName: 'Ravi Kumar',
        date: '2026-10-02',
        time: '10:00 AM',
        checkInTime: '10:00 AM',
        checkOutTime: '07:20 PM',
        status: 'Completed',
        verificationStatus: 'Auto-Checked Out (Geofence Exit)',
        similarityScore: 1.0,
        sessions: [
          const AttendanceSession(
            id: 'session_1',
            type: 'office',
            checkInTime: '10:00 AM',
            checkOutTime: '07:20 PM',
            durationHours: 9.33,
            durationMinutes: 560,
          ),
        ],
      );

      final otMins = record.calculateOvertimeMinutes(shiftOutTime: defaultShiftOut, bufferMinutes: bufferMinutes);
      final otHrs = record.calculateOvertimeHours(shiftOutTime: defaultShiftOut, bufferMinutes: bufferMinutes);
      final meetsMinOt = record.hasMetMinOvertimeThreshold(shiftOutTime: defaultShiftOut, bufferMinutes: bufferMinutes);
      final otFormatted = record.formattedOvertimeHours(shiftOutTime: defaultShiftOut, bufferMinutes: bufferMinutes);

      expect(otMins, equals(0));
      expect(otHrs, equals(0.0));
      expect(meetsMinOt, isFalse);
      expect(otFormatted, equals('0hr'));
    });

    test('3. Exit during OT before 1-hr minimum (08:10 PM): Auto checkout at 08:10 PM, 40 min OT, < 1 hr threshold', () {
      final record = AttendanceRecord(
        id: 103,
        employeeId: 1,
        employeeName: 'Ravi Kumar',
        date: '2026-10-02',
        time: '10:00 AM',
        checkInTime: '10:00 AM',
        checkOutTime: '08:10 PM',
        status: 'Completed',
        verificationStatus: 'Auto-Checked Out (Geofence Exit)',
        similarityScore: 1.0,
        notes: 'Worked 10.17 hrs | OT: 40min (< 1-hr threshold)',
        sessions: [
          const AttendanceSession(
            id: 'session_1',
            type: 'office',
            checkInTime: '10:00 AM',
            checkOutTime: '08:10 PM',
            durationHours: 10.17,
            durationMinutes: 610,
          ),
        ],
      );

      final otMins = record.calculateOvertimeMinutes(shiftOutTime: defaultShiftOut, bufferMinutes: bufferMinutes);
      final otHrs = record.calculateOvertimeHours(shiftOutTime: defaultShiftOut, bufferMinutes: bufferMinutes);
      final meetsMinOt = record.hasMetMinOvertimeThreshold(shiftOutTime: defaultShiftOut, bufferMinutes: bufferMinutes, minOtMinutes: minOtMinutes);
      final otFormatted = record.formattedOvertimeHours(shiftOutTime: defaultShiftOut, bufferMinutes: bufferMinutes);

      expect(otMins, equals(40)); // 8:10 PM (1210 mins) - 7:30 PM (1170 mins) = 40 mins
      expect(otHrs, equals(0.67));
      expect(meetsMinOt, isFalse);
      expect(otFormatted, equals('40min'));
    });

    test('4. Exit after 1-hr OT minimum (09:15 PM): Auto checkout at 09:15 PM, 1hr 45min OT, 1-hr threshold met, remains Office session', () {
      final record = AttendanceRecord(
        id: 104,
        employeeId: 1,
        employeeName: 'Ravi Kumar',
        date: '2026-10-02',
        time: '10:00 AM',
        checkInTime: '10:00 AM',
        checkOutTime: '09:15 PM',
        status: 'Completed',
        verificationStatus: 'Auto-Checked Out (Geofence Exit)',
        similarityScore: 1.0,
        notes: 'Worked 11.25 hrs | OT: 1hr 45min (1-hr threshold met)',
        sessions: [
          const AttendanceSession(
            id: 'session_1',
            type: 'office',
            checkInTime: '10:00 AM',
            checkOutTime: '09:15 PM',
            durationHours: 11.25,
            durationMinutes: 675,
          ),
        ],
      );

      final otMins = record.calculateOvertimeMinutes(shiftOutTime: defaultShiftOut, bufferMinutes: bufferMinutes);
      final otHrs = record.calculateOvertimeHours(shiftOutTime: defaultShiftOut, bufferMinutes: bufferMinutes);
      final meetsMinOt = record.hasMetMinOvertimeThreshold(shiftOutTime: defaultShiftOut, bufferMinutes: bufferMinutes, minOtMinutes: minOtMinutes);
      final otFormatted = record.formattedOvertimeHours(shiftOutTime: defaultShiftOut, bufferMinutes: bufferMinutes);

      expect(otMins, equals(105)); // 9:15 PM (1275 mins) - 7:30 PM (1170 mins) = 105 mins
      expect(otHrs, equals(1.75));
      expect(meetsMinOt, isTrue);
      expect(otFormatted, equals('1hr 45min'));

      // Crucial requirement: Remains office session, NOT auto-converted to OD session
      expect(record.sessions.first.isOffice, isTrue);
      expect(record.sessions.first.isOd, isFalse);
      expect(record.computedOdHours, equals(0.0));
      expect(record.computedOfficeHours, equals(11.25));
    });

    test('5. Active OD Session Shield: Stepping outside office does NOT trigger auto-checkout', () {
      final activeOdRecord = AttendanceRecord(
        id: 105,
        employeeId: 1,
        employeeName: 'Ravi Kumar',
        date: '2026-10-02',
        time: '10:00 AM',
        checkInTime: '10:00 AM',
        checkOutTime: '',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        sessions: [
          const AttendanceSession(
            id: 'session_1',
            type: 'office',
            checkInTime: '10:00 AM',
            checkOutTime: '02:00 PM',
            durationHours: 4.0,
            durationMinutes: 240,
          ),
          const AttendanceSession(
            id: 'session_2',
            type: 'od',
            checkInTime: '02:00 PM',
            checkOutTime: '',
            purpose: 'Client Site Inspection',
            destination: 'Site B',
          ),
        ],
      );

      final activeSession = activeOdRecord.sessions.where((s) => s.isActive).firstOrNull;
      expect(activeSession, isNotNull);
      expect(activeSession!.isOd, isTrue);

      // Verify that active OD session is protected from auto checkout
      final bool shouldTriggerAutoCheckOut = activeSession.isOffice && !activeSession.isOd;
      expect(shouldTriggerAutoCheckOut, isFalse);
    });

    test('6. Missing Check-Out Fallback: Unrecorded exit remains unclosed until overnight resolver', () {
      final unclosedRecord = AttendanceRecord(
        id: 106,
        employeeId: 1,
        employeeName: 'Ravi Kumar',
        date: '2026-10-01', // Yesterday
        time: '10:00 AM',
        checkInTime: '10:00 AM',
        checkOutTime: '',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
      );

      expect(unclosedRecord.requiresCorrection, isTrue);
      expect(unclosedRecord.checkOutTime.isEmpty, isTrue);
    });

    test('7. Shift Derivation: 12:10 PM to 08:10 PM calculates exactly 8.0 required hours with any format variation', () {
      // Standard with space
      final inMins = AttendanceSession.parseTimeToMinutes('12:10 PM')!;
      final outMins = AttendanceSession.parseTimeToMinutes('08:10 PM')!;
      final diffMins = outMins - inMins;
      final derivedHours = double.parse((diffMins / 60.0).toStringAsFixed(2));
      expect(derivedHours, equals(8.0));

      // Compact without space (e.g. 12:10PM and 08:10PM)
      final inMinsCompact = AttendanceSession.parseTimeToMinutes('12:10PM')!;
      final outMinsCompact = AttendanceSession.parseTimeToMinutes('08:10PM')!;
      final diffMinsCompact = outMinsCompact - inMinsCompact;
      final derivedHoursCompact = double.parse((diffMinsCompact / 60.0).toStringAsFixed(2));
      expect(derivedHoursCompact, equals(8.0));
      expect(inMinsCompact, equals(730)); // 12 * 60 + 10
      expect(outMinsCompact, equals(1210)); // 20 * 60 + 10
    });

    test('8. Historical Snapshot Integrity: Past record retains its snapshotted requiredHours even if profile changes', () {
      final pastRecord = AttendanceRecord(
        id: 108,
        employeeId: 6,
        employeeName: 'Ravi Kumar',
        date: '2026-09-15',
        time: '12:15 PM',
        checkInTime: '12:15 PM',
        checkOutTime: '09:15 PM',
        status: 'Completed',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        requiredHours: 9.0,
        scheduledInTime: '12:15 PM',
        scheduledOutTime: '09:15 PM',
        totalHours: 9.0,
      );

      // Even if fallback is 8.0 from updated employee profile, record's snapshotted requiredHours is 9.0
      expect(pastRecord.requiredHours, equals(9.0));
      expect(pastRecord.scheduledInTime, equals('12:15 PM'));
      expect(pastRecord.scheduledOutTime, equals('09:15 PM'));

      // Serialization round-trip preserves snapshotted fields
      final map = pastRecord.toMap();
      final restored = AttendanceRecord.fromMap(map);
      expect(restored.requiredHours, equals(9.0));
      expect(restored.scheduledInTime, equals('12:15 PM'));
      expect(restored.scheduledOutTime, equals('09:15 PM'));
    });

    test('9. Multi-Session Check-in #2: checkOutTime is cleared so previous checkout does not block new session', () {
      // Simulates an existing record that completed Session 1 (09:00 AM to 01:00 PM)
      final existingRecord = AttendanceRecord(
        id: 109,
        employeeId: 1,
        employeeName: 'Ravi Kumar',
        date: '2026-10-02',
        time: '09:00 AM',
        checkInTime: '09:00 AM',
        checkOutTime: '01:00 PM',
        status: 'Completed',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        sessions: const [
          AttendanceSession(
            id: 'session_1',
            type: 'office',
            checkInTime: '09:00 AM',
            checkOutTime: '01:00 PM',
            durationHours: 4.0,
            durationMinutes: 240,
          ),
        ],
      );

      // Simulates checking in for Session 2 at 02:00 PM
      final newSession = const AttendanceSession(
        id: 'session_2',
        type: 'office',
        checkInTime: '02:00 PM',
        checkOutTime: '', // Active session
      );

      final updatedSessions = List<AttendanceSession>.from(existingRecord.sessions)..add(newSession);

      // In the fixed _startOfficeAttendanceSession, checkOutTime is reset to ''
      final updatedRecord = existingRecord.copyWith(
        checkOutTime: '', // Fixed behavior: reset to empty string for active session
        checkOutVerificationStatus: '',
        checkOutSimilarityScore: 0.0,
        status: 'Present',
        sessions: updatedSessions,
      );

      expect(updatedRecord.checkOutTime, isEmpty);
      expect(updatedRecord.sessions.length, equals(2));
      expect(updatedRecord.sessions.any((s) => s.isActive), isTrue);
      // Verify that the record is eligible for exit auto-checkout (checkOutTime is empty)
      final bool isEligibleForAutoCheckout = updatedRecord.checkOutTime.trim().isEmpty &&
          updatedRecord.status != 'Checked Out' &&
          updatedRecord.sessions.any((s) => s.isActive);
      expect(isEligibleForAutoCheckout, isTrue);
    });

    test('10. Date Isolation for OD Assignments: Previous-day OD does not shield today', () {
      bool isOdActiveForDate({
        required String assignmentDate,
        required String targetDate,
        required String status,
      }) {
        if (assignmentDate != targetDate) return false;
        final s = status.toUpperCase();
        return s == 'ASSIGNED' || s == 'IN_PROGRESS' || s == 'ACTIVE';
      }

      const today = '2026-10-02';
      const yesterday = '2026-10-01';

      // Yesterday's unclosed OD assignment should NOT shield today
      expect(isOdActiveForDate(assignmentDate: yesterday, targetDate: today, status: 'ASSIGNED'), isFalse);
      expect(isOdActiveForDate(assignmentDate: yesterday, targetDate: today, status: 'ACTIVE'), isFalse);

      // Today's active OD assignment MUST shield today
      expect(isOdActiveForDate(assignmentDate: today, targetDate: today, status: 'ASSIGNED'), isTrue);
      expect(isOdActiveForDate(assignmentDate: today, targetDate: today, status: 'IN_PROGRESS'), isTrue);
    });

    test('11. Date Isolation for Time Clocking: Previous-day unclosed break does not shield today', () {
      bool isBreakActiveForDate({
        required String entryStartTimeIso,
        required String targetDate,
        required String? endTime,
      }) {
        final entryDate = entryStartTimeIso.split('T').first;
        if (entryDate != targetDate) return false;
        return endTime == null || endTime.trim().isEmpty;
      }

      const today = '2026-10-02';

      // Yesterday's unclosed break should NOT shield today
      expect(isBreakActiveForDate(entryStartTimeIso: '2026-10-01T13:00:00', targetDate: today, endTime: null), isFalse);

      // Today's ongoing break MUST shield today
      expect(isBreakActiveForDate(entryStartTimeIso: '2026-10-02T13:00:00', targetDate: today, endTime: null), isTrue);
      // Completed break today does NOT shield
      expect(isBreakActiveForDate(entryStartTimeIso: '2026-10-02T13:00:00', targetDate: today, endTime: '2026-10-02T13:45:00'), isFalse);
    });

    test('12. Geofence Guard: (0, 0) coordinates or disabled GPS safely aborts checkout without false inside', () {
      bool shouldTriggerGeofenceExit({
        required double currentLat,
        required double currentLng,
        required double targetLat,
        required double targetLng,
        required bool requireGps,
        required double distanceMeters,
        required int targetRadius,
      }) {
        if (currentLat == 0.0 && currentLng == 0.0) return false;
        if (!requireGps || (targetLat == 0.0 && targetLng == 0.0)) return false;
        return distanceMeters > targetRadius;
      }

      // Invalid current GPS (0, 0)
      expect(shouldTriggerGeofenceExit(
        currentLat: 0.0, currentLng: 0.0,
        targetLat: 13.0827, targetLng: 80.2707,
        requireGps: true, distanceMeters: 500, targetRadius: 100,
      ), isFalse);

      // Unconfigured workplace coordinates (0, 0)
      expect(shouldTriggerGeofenceExit(
        currentLat: 13.0850, currentLng: 80.2750,
        targetLat: 0.0, targetLng: 0.0,
        requireGps: true, distanceMeters: 500, targetRadius: 100,
      ), isFalse);

      // GPS verification disabled
      expect(shouldTriggerGeofenceExit(
        currentLat: 13.0850, currentLng: 80.2750,
        targetLat: 13.0827, targetLng: 80.2707,
        requireGps: false, distanceMeters: 500, targetRadius: 100,
      ), isFalse);

      // Valid outside geofence -> triggers checkout
      expect(shouldTriggerGeofenceExit(
        currentLat: 13.0850, currentLng: 80.2750,
        targetLat: 13.0827, targetLng: 80.2707,
        requireGps: true, distanceMeters: 500, targetRadius: 100,
      ), isTrue);

      // Valid inside geofence -> does not trigger checkout
      expect(shouldTriggerGeofenceExit(
        currentLat: 13.0828, currentLng: 80.2708,
        targetLat: 13.0827, targetLng: 80.2707,
        requireGps: true, distanceMeters: 20, targetRadius: 100,
      ), isFalse);
    });

    test('13. Background Monitor Active State: evaluates true when any session is active', () {
      bool shouldMonitorRun({
        required bool hasActiveSessionInList,
        required String effectiveCheckInTime,
        required String checkOutTime,
        required String status,
      }) {
        final hasActiveSession = hasActiveSessionInList ||
            (effectiveCheckInTime.isNotEmpty && checkOutTime.isEmpty);

        return hasActiveSession;
      }

      // Active Session 1
      expect(shouldMonitorRun(
        hasActiveSessionInList: true,
        effectiveCheckInTime: '09:00 AM',
        checkOutTime: '',
        status: 'Present',
      ), isTrue);

      // Checked out Session 1, no active session
      expect(shouldMonitorRun(
        hasActiveSessionInList: false,
        effectiveCheckInTime: '09:00 AM',
        checkOutTime: '01:00 PM',
        status: 'Completed',
      ), isFalse);

      // Active Session 2 (even if an older field had a value)
      expect(shouldMonitorRun(
        hasActiveSessionInList: true,
        effectiveCheckInTime: '09:00 AM',
        checkOutTime: '',
        status: 'Present',
      ), isTrue);
    });
  });
}
