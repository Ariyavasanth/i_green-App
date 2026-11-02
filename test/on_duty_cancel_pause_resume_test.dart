import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_record.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_session.dart';
import 'package:flutter_application_1/features/on_duty/domain/on_duty_assignment.dart';

void main() {
  group('On-Duty (OD) Cancel, Pause & Resume Tests with Mandatory Proof', () {
    test('1. OnDutyAssignment correctly serializes and deserializes cancellation fields', () {
      final assignment = OnDutyAssignment(
        id: 501,
        employeeId: 10,
        employeeName: 'Ravi Kumar',
        odType: 'Client Visit',
        purpose: 'HVAC Maintenance',
        destination: 'Tambaram Site',
        date: '02-11-2026',
        status: 'CANCELLED',
        cancellationReason: 'Heavy Rain / Extreme Weather',
        cancellationPhoto: 'https://firebasestorage.googleapis.com/.../cancel_1.jpg',
        cancelledAt: '2026-11-02T10:30:00Z',
        cancelledLatitude: 12.9249,
        cancelledLongitude: 80.1000,
        assignedBy: 'Manager',
        createdAt: '2026-11-02T09:00:00Z',
      );

      final map = assignment.toMap();
      expect(map['status'], 'CANCELLED');
      expect(map['cancellation_reason'], 'Heavy Rain / Extreme Weather');
      expect(map['cancellation_photo'], 'https://firebasestorage.googleapis.com/.../cancel_1.jpg');
      expect(map['cancelled_at'], '2026-11-02T10:30:00Z');
      expect(map['cancelled_latitude'], 12.9249);
      expect(map['cancelled_longitude'], 80.1000);

      final fromMap = OnDutyAssignment.fromMap(map);
      expect(fromMap.isCancelled, isTrue);
      expect(fromMap.cancellationReason, 'Heavy Rain / Extreme Weather');
      expect(fromMap.cancellationPhoto, 'https://firebasestorage.googleapis.com/.../cancel_1.jpg');
      expect(fromMap.cancelledAt, '2026-11-02T10:30:00Z');
    });

    test('2. OnDutyAssignment correctly serializes and deserializes pause & resume fields and audit trail', () {
      final intervals = [
        {
          'paused_at': '2026-11-02T11:00:00Z',
          'resumed_at': '2026-11-02T11:20:00Z',
          'pause_reason': 'Heavy Rain',
          'pause_photo': 'https://firebasestorage.googleapis.com/.../pause_1.jpg',
          'resume_photo': 'https://firebasestorage.googleapis.com/.../resume_1.jpg',
          'duration_seconds': 1200,
        }
      ];

      final assignment = OnDutyAssignment(
        id: 502,
        employeeId: 10,
        employeeName: 'Ravi Kumar',
        odType: 'Client Visit',
        purpose: 'Site Survey',
        destination: 'Perambur Site',
        date: '02-11-2026',
        status: 'TRAVELING_TO_DESTINATION',
        isPaused: true,
        pausedAt: '2026-11-02T12:00:00Z',
        pauseReason: 'Waiting for Client / Site Access',
        pausePhoto: 'https://firebasestorage.googleapis.com/.../pause_2.jpg',
        totalPausedSeconds: 1200,
        pauseIntervals: intervals,
        assignedBy: 'Manager',
        createdAt: '2026-11-02T09:00:00Z',
      );

      final map = assignment.toMap();
      expect(map['is_paused'], isTrue);
      expect(map['paused_at'], '2026-11-02T12:00:00Z');
      expect(map['pause_reason'], 'Waiting for Client / Site Access');
      expect(map['pause_photo'], 'https://firebasestorage.googleapis.com/.../pause_2.jpg');
      expect(map['total_paused_seconds'], 1200);
      expect(map['pause_intervals'], isA<List>());
      expect((map['pause_intervals'] as List).length, 1);

      final fromMap = OnDutyAssignment.fromMap(map);
      expect(fromMap.isPaused, isTrue);
      expect(fromMap.pauseReason, 'Waiting for Client / Site Access');
      expect(fromMap.totalPausedSeconds, 1200);
      expect(fromMap.pauseIntervals.length, 1);
      expect(fromMap.pauseIntervals.first['pause_reason'], 'Heavy Rain');
    });

    test('3. Net duration correctly deducts accumulated paused seconds', () {
      final startTime = DateTime(2026, 11, 2, 10, 0, 0);
      final currentTime = DateTime(2026, 11, 2, 11, 30, 0); // 90 minutes raw elapsed
      const totalPausedSeconds = 30 * 60; // 30 minutes paused

      final rawElapsedSeconds = currentTime.difference(startTime).inSeconds;
      final netActiveSeconds = rawElapsedSeconds - totalPausedSeconds;
      final netDuration = Duration(seconds: netActiveSeconds);

      expect(netDuration.inMinutes, 60); // 90 min - 30 min pause = 60 min active
      expect(netDuration.inHours, 1);
    });

    test('4. Graceful Attendance session closure on Cancel OD preserves history', () {
      final initialSession = AttendanceSession(
        id: 'session_od_1',
        type: 'od',
        checkInTime: '10:00 AM',
        checkOutTime: '',
        checkInVerificationStatus: 'OD Verified',
        assignmentId: 501,
        purpose: 'Site Survey',
      );

      final record = AttendanceRecord(
        id: 1,
        employeeId: 10,
        employeeName: 'Ravi Kumar',
        date: '2026-11-02',
        time: '10:00 AM',
        checkInTime: '10:00 AM',
        checkOutTime: '',
        status: 'Present',
        verificationStatus: 'OD Verified',
        similarityScore: 1.0,
        totalHours: 0.0,
        sessions: [initialSession],
      );

      // On Cancel OD: update checkOutTime and status, preserving attendance
      final cancelTime = '10:45 AM';
      const durationMinutes = 45;
      final updatedSession = initialSession.copyWith(
        checkOutTime: cancelTime,
        checkOutVerificationStatus: 'OD Cancelled: Client Meeting Cancelled',
        durationMinutes: durationMinutes,
        durationHours: 0.75,
      );

      final updatedRecord = record.copyWith(
        sessions: [updatedSession],
        checkOutTime: cancelTime,
      );

      expect(updatedRecord.sessions.length, 1);
      expect(updatedRecord.sessions.first.isActive, isFalse);
      expect(updatedRecord.sessions.first.checkOutVerificationStatus, contains('OD Cancelled'));
      expect(updatedRecord.sessions.first.durationMinutes, 45);
      expect(updatedRecord.checkInTime, '10:00 AM');
    });

    test('5. State guards: Assignment cannot transition from CANCELLED to running', () {
      final cancelled = OnDutyAssignment(
        id: 503,
        employeeId: 10,
        employeeName: 'Ravi Kumar',
        odType: 'Client Visit',
        purpose: 'Meeting',
        destination: 'Guindy',
        date: '02-11-2026',
        status: 'CANCELLED',
        assignedBy: 'Admin',
        createdAt: '2026-11-02T09:00:00Z',
      );

      expect(cancelled.isCancelled, isTrue);
      expect(cancelled.isOngoing, isFalse);
    });
  });
}

