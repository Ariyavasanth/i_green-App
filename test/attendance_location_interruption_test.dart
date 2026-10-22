import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_record.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_repository.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_settings.dart';
import 'package:flutter_application_1/features/attendance/providers/attendance_providers.dart';
import 'package:flutter_application_1/features/attendance/services/attendance_location_service.dart';

class FakeAttendanceRepository implements AttendanceRepository {
  final Map<String, AttendanceRecord> records = {};
  final List<Map<String, dynamic>> loggedAttempts = [];
  final List<Map<String, dynamic>> recordedInterruptions = [];

  bool mockInsideGeofence = true;
  bool mockAutoCheckoutTriggered = false;

  @override
  Future<AttendanceSettings> getAttendanceSettings() async {
    return AttendanceSettings.defaults();
  }

  @override
  Future<void> saveAttendanceSettings(AttendanceSettings settings) async {}

  @override
  Future<AttendanceRecord?> getAttendanceRecordForDate(int employeeId, String date) async {
    return records['${employeeId}_$date'];
  }

  @override
  Future<AttendanceRecord?> getActiveAttendanceRecord(int employeeId) async {
    return records.values.firstWhere(
      (r) => r.employeeId == employeeId && r.effectiveCheckInTime.isNotEmpty && r.checkOutTime.isEmpty,
      orElse: () => AttendanceRecord(
        id: 0,
        employeeId: 0,
        employeeName: '',
        date: '',
        time: '',
        status: '',
        verificationStatus: '',
        similarityScore: 0,
      ),
    );
  }

  @override
  Future<List<AttendanceRecord>> getAttendanceRecords(int employeeId) async {
    return records.values.where((r) => r.employeeId == employeeId).toList();
  }

  @override
  Future<List<AttendanceRecord>> getAllAttendanceRecords() async {
    return records.values.toList();
  }

  @override
  Future<bool> hasAttendanceForDate(int employeeId, String date) async {
    return records.containsKey('${employeeId}_$date');
  }

  @override
  Future<bool> verifyLocationWithinGeofence({
    required int employeeId,
    required double latitude,
    required double longitude,
  }) async {
    return mockInsideGeofence;
  }

  @override
  Future<bool> handleGeofenceExitAutoCheckOut({
    required int employeeId,
    required double currentLatitude,
    required double currentLongitude,
    String? exitTime,
  }) async {
    mockAutoCheckoutTriggered = true;
    final key = records.keys.firstWhere((k) => k.startsWith('${employeeId}_'), orElse: () => '');
    if (key.isNotEmpty && records.containsKey(key)) {
      final rec = records[key]!;
      records[key] = rec.copyWith(
        checkOutTime: exitTime ?? '03:00 PM',
        checkOutVerificationStatus: 'Auto-Checked Out (Geofence Exit)',
        status: 'Completed',
      );
    }
    return true;
  }

  @override
  Future<void> recordLocationInterruption({
    required int employeeId,
    required String date,
    required String startTime,
    String? endTime,
    String reason = 'Location services unavailable',
  }) async {
    recordedInterruptions.add({
      'employee_id': employeeId,
      'date': date,
      'start_time': startTime,
      'end_time': endTime,
      'reason': reason,
    });

    final key = '${employeeId}_$date';
    if (records.containsKey(key)) {
      final rec = records[key]!;
      final updatedList = List<Map<String, dynamic>>.from(rec.locationInterruptions);
      final idx = updatedList.indexWhere((it) => it['start_time'] == startTime);
      if (idx != -1) {
        if (endTime != null && endTime.isNotEmpty) {
          updatedList[idx] = {
            ...updatedList[idx],
            'end_time': endTime,
            'reason': reason,
          };
        }
      } else {
        updatedList.add({
          'start_time': startTime,
          if (endTime != null) 'end_time': endTime,
          'reason': reason,
        });
      }
      records[key] = rec.copyWith(locationInterruptions: updatedList);
    }
  }

  @override
  Future<void> logAttendanceAttempt({
    required int employeeId,
    required String employeeName,
    required String date,
    required String time,
    required String verificationStatus,
    required double similarityScore,
    required String message,
  }) async {
    loggedAttempts.add({
      'employee_id': employeeId,
      'date': date,
      'time': time,
      'verification_status': verificationStatus,
      'message': message,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getAttendanceAttempts() async => loggedAttempts;

  @override
  Future<AttendanceVerificationResult> verifyAttendance({
    required int employeeId,
    required String date,
    required String employeeName,
    required String profileImageUrl,
    required String scheduledCheckInTime,
    required double currentLatitude,
    required double currentLongitude,
    bool faceMatched = true,
    double similarityScore = 1.0,
  }) async => const AttendanceVerificationResult(
        allowed: true,
        similarityScore: 1.0,
        verificationStatus: 'Verified',
        message: 'Allowed',
        capturedImagePath: '',
      );

  @override
  Future<AttendanceVerificationResult> verifyCheckOut({
    required int employeeId,
    required String date,
    required String employeeName,
    required String profileImageUrl,
    required double currentLatitude,
    required double currentLongitude,
    bool faceMatched = true,
    double similarityScore = 1.0,
  }) async => const AttendanceVerificationResult(
        allowed: true,
        similarityScore: 1.0,
        verificationStatus: 'Verified',
        message: 'Allowed',
        capturedImagePath: '',
      );

  @override
  Future<void> markAttendance({
    required int employeeId,
    required String employeeName,
    required String date,
    required String time,
    required String verificationStatus,
    required double similarityScore,
    required String status,
    String notes = '',
  }) async {}

  @override
  Future<void> checkOut({
    required int employeeId,
    required String date,
    required String checkOutTime,
    required String verificationStatus,
    required double similarityScore,
  }) async {}

  @override
  Future<void> adminSaveAttendance(AttendanceRecord record) async {}

  @override
  Future<void> unmarkAttendance({required int employeeId, required String date}) async {}

  @override
  Future<AttendanceVerificationResult> startOdAttendanceSession({
    required int employeeId,
    required String employeeName,
    String employeeCode = '',
    required String date,
    required String time,
    required int assignmentId,
    String purpose = '',
    String destination = '',
    String destinationAddress = '',
    double? latitude,
    double? longitude,
    double? destinationLatitude,
    double? destinationLongitude,
    int destinationRadius = 100,
    bool startOdFromHome = false,
    String? projectCode,
    String? projectId,
    String notes = '',
  }) async => const AttendanceVerificationResult(
        allowed: true,
        similarityScore: 1.0,
        verificationStatus: 'OD Started',
        message: 'Allowed',
        capturedImagePath: '',
      );

  @override
  Future<AttendanceVerificationResult> completeOdAttendanceSession({
    required int employeeId,
    required String employeeName,
    String employeeCode = '',
    required String date,
    required String time,
    required int assignmentId,
    double? latitude,
    double? longitude,
    double? destinationLatitude,
    double? destinationLongitude,
    int destinationRadius = 100,
    String afterCompletionOption = 'RETURN_TO_OFFICE',
  }) async => const AttendanceVerificationResult(
        allowed: true,
        similarityScore: 1.0,
        verificationStatus: 'OD Completed',
        message: 'Allowed',
        capturedImagePath: '',
      );

  @override
  Future<void> autoResolveMissingCheckOuts({int? employeeId}) async {}

  @override
  Future<void> recalculateAttendanceForDate(int employeeId, String date) async {}

  @override
  Future<void> clearAllAttendanceRecords() async {}

  @override
  Future<void> startActivitySession({
    required int employeeId,
    required String date,
    required String activityType,
    required String time,
  }) async {}

  @override
  Future<void> stopActivitySession({
    required int employeeId,
    required String date,
    required String time,
  }) async {}
}

void main() {
  group('Attendance Location Services Interruption & Recovery Tests', () {
    late FakeAttendanceRepository repo;
    late ProviderContainer container;

    setUp(() {
      repo = FakeAttendanceRepository();
      container = ProviderContainer(
        overrides: [
          attendanceRepositoryProvider.overrideWithValue(repo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      AttendanceLocationService.instance.stopPeriodicGeofenceMonitoring();
    });

    test('1. AttendanceRecord serializes and deserializes locationInterruptions correctly', () {
      final record = AttendanceRecord(
        id: 1,
        employeeId: 8,
        employeeName: 'Gokul Raj G',
        date: '2026-10-22',
        time: '10:35 AM',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        locationInterruptions: [
          {
            'start_time': '11:15:00 AM',
            'end_time': '11:30:00 AM',
            'reason': 'Location services disabled',
          },
        ],
      );

      final map = record.toMap();
      expect(map['location_interruptions'], isNotNull);
      expect((map['location_interruptions'] as List).length, equals(1));

      final fromMap = AttendanceRecord.fromMap(map);
      expect(fromMap.locationInterruptions.length, equals(1));
      expect(fromMap.locationInterruptions.first['start_time'], equals('11:15:00 AM'));
      expect(fromMap.locationInterruptions.first['end_time'], equals('11:30:00 AM'));
      expect(fromMap.locationInterruptions.first['reason'], equals('Location services disabled'));
    });

    test('2. recordLocationInterruption logs start time and later updates with recovery end time', () async {
      repo.records['8_2026-10-22'] = AttendanceRecord(
        id: 101,
        employeeId: 8,
        employeeName: 'Gokul Raj G',
        date: '2026-10-22',
        time: '10:35 AM',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
      );

      // Step A: Record Interruption Start
      await repo.recordLocationInterruption(
        employeeId: 8,
        date: '2026-10-22',
        startTime: '11:15:00 AM',
        reason: 'Location services disabled on device',
      );

      expect(repo.recordedInterruptions.length, equals(1));
      expect(repo.recordedInterruptions.first['start_time'], equals('11:15:00 AM'));
      expect(repo.recordedInterruptions.first['end_time'], isNull);

      final recordAfterStart = repo.records['8_2026-10-22']!;
      expect(recordAfterStart.locationInterruptions.length, equals(1));
      expect(recordAfterStart.locationInterruptions.first['start_time'], equals('11:15:00 AM'));
      expect(recordAfterStart.locationInterruptions.first['end_time'], isNull);

      // Step B: Record Recovery Time
      await repo.recordLocationInterruption(
        employeeId: 8,
        date: '2026-10-22',
        startTime: '11:15:00 AM',
        endTime: '11:35:00 AM',
        reason: 'Location services restored',
      );

      final recordAfterRecovery = repo.records['8_2026-10-22']!;
      expect(recordAfterRecovery.locationInterruptions.length, equals(1));
      expect(recordAfterRecovery.locationInterruptions.first['start_time'], equals('11:15:00 AM'));
      expect(recordAfterRecovery.locationInterruptions.first['end_time'], equals('11:35:00 AM'));
      expect(recordAfterRecovery.locationInterruptions.first['reason'], equals('Location services restored'));
    });

    test('3. On recovery, revalidation outside geofence triggers auto check-out', () async {
      repo.records['8_2026-10-22'] = AttendanceRecord(
        id: 101,
        employeeId: 8,
        employeeName: 'Gokul Raj G',
        date: '2026-10-22',
        time: '10:35 AM',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
      );

      // Mock that employee is outside geofence upon recovery
      repo.mockInsideGeofence = false;

      final isInside = await repo.verifyLocationWithinGeofence(
        employeeId: 8,
        latitude: 13.0827,
        longitude: 80.2707,
      );
      expect(isInside, isFalse);

      if (!isInside) {
        await repo.handleGeofenceExitAutoCheckOut(
          employeeId: 8,
          currentLatitude: 13.0827,
          currentLongitude: 80.2707,
          exitTime: '11:35:00 AM',
        );
      }

      expect(repo.mockAutoCheckoutTriggered, isTrue);
      final updatedRec = repo.records['8_2026-10-22']!;
      expect(updatedRec.checkOutTime, equals('11:35:00 AM'));
      expect(updatedRec.checkOutVerificationStatus, equals('Auto-Checked Out (Geofence Exit)'));
    });

    test('4. On recovery, revalidation inside geofence resumes normal monitoring without auto check-out', () async {
      repo.records['8_2026-10-22'] = AttendanceRecord(
        id: 101,
        employeeId: 8,
        employeeName: 'Gokul Raj G',
        date: '2026-10-22',
        time: '10:35 AM',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
      );

      // Mock that employee is inside geofence upon recovery
      repo.mockInsideGeofence = true;

      final isInside = await repo.verifyLocationWithinGeofence(
        employeeId: 8,
        latitude: 12.96285,
        longitude: 80.214441,
      );
      expect(isInside, isTrue);

      expect(repo.mockAutoCheckoutTriggered, isFalse);
      final updatedRec = repo.records['8_2026-10-22']!;
      expect(updatedRec.checkOutTime.isEmpty, isTrue);
      expect(updatedRec.status, equals('Present'));
    });

    test('5. Missing check-out fallback remains active for unclosed sessions', () {
      final unclosedRecord = AttendanceRecord(
        id: 102,
        employeeId: 8,
        employeeName: 'Gokul Raj G',
        date: '2026-10-21',
        time: '10:35 AM',
        checkInTime: '10:35 AM',
        checkOutTime: '',
        status: 'Missing Check-Out',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
      );

      expect(unclosedRecord.isMissingCheckOut, isTrue);
      expect(unclosedRecord.requiresCorrection, isTrue);
    });
  });
}
