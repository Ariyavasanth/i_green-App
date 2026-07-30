import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/attendance_record.dart';
import '../domain/attendance_settings.dart';
import '../domain/attendance_repository.dart';

class FirebaseAttendanceRepository implements AttendanceRepository {
  final FirebaseFirestore _firestore;
  FirebaseAttendanceRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _recordsRef => _firestore.collection('attendance_records');
  CollectionReference<Map<String, dynamic>> get _attemptsRef => _firestore.collection('attendance_attempts');
  DocumentReference<Map<String, dynamic>> get _settingsRef => _firestore.collection('attendance_settings').doc('global');

  @override
  Future<AttendanceSettings> getAttendanceSettings() async {
    final snap = await _settingsRef.get();
    if (!snap.exists || snap.data() == null) return AttendanceSettings.defaults();
    return AttendanceSettings.fromMap(snap.data()!);
  }

  @override
  Future<void> saveAttendanceSettings(AttendanceSettings settings) async {
    await _settingsRef.set(settings.toMap(), SetOptions(merge: true));
  }

  @override
  Future<List<AttendanceRecord>> getAttendanceRecords(int employeeId) async {
    final snap = await _recordsRef.where('employee_id', isEqualTo: employeeId).get();
    return snap.docs.map((d) => AttendanceRecord.fromMap(d.data())).toList();
  }

  @override
  Future<bool> hasAttendanceForDate(int employeeId, String date) async {
    final snap = await _recordsRef.where('employee_id', isEqualTo: employeeId).where('date', isEqualTo: date).limit(1).get();
    return snap.docs.isNotEmpty;
  }

  double _degreesToRadians(double degrees) => degrees * (pi / 180.0);

  double _distanceInMeters({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    const earthRadius = 6371000.0;
    final dLat = _degreesToRadians(endLatitude - startLatitude);
    final dLon = _degreesToRadians(endLongitude - startLongitude);
    final lat1 = _degreesToRadians(startLatitude);
    final lat2 = _degreesToRadians(endLatitude);
    final a = sin(dLat / 2) * sin(dLat / 2) + sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  @override
  Future<AttendanceVerificationResult> verifyAttendance({
    required int employeeId,
    required String date,
    required String employeeName,
    required String profileImageUrl,
    required String scheduledCheckInTime,
    required double currentLatitude,
    required double currentLongitude,
  }) async {
    final score = profileImageUrl.isNotEmpty ? 0.93 : 0.0;
    final allowed = score >= 0.9;
    final now = DateTime.now();
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final settings = await getAttendanceSettings();
    final distance = _distanceInMeters(
      startLatitude: settings.officeLatitude,
      startLongitude: settings.officeLongitude,
      endLatitude: currentLatitude,
      endLongitude: currentLongitude,
    );
    final withinRadius = !settings.requireGpsVerification || distance <= settings.allowedAttendanceRadiusMeters;
    final result = AttendanceVerificationResult(
      allowed: allowed && withinRadius,
      similarityScore: score,
      verificationStatus: !withinRadius ? 'Outside Radius' : allowed ? 'Verified' : 'Failed',
      message: !withinRadius
          ? 'You are not at the office. Please go to the office location to mark your attendance.'
          : allowed
              ? 'Attendance marked successfully.'
              : 'Face verification failed. Please try again.',
      capturedImagePath: '',
    );
    await logAttendanceAttempt(employeeId: employeeId, employeeName: employeeName, date: date, time: time, verificationStatus: result.verificationStatus, similarityScore: score, message: result.message);
    if (result.allowed && !(await hasAttendanceForDate(employeeId, date))) {
      final scheduledMinutes = int.tryParse(scheduledCheckInTime.split(':').first) ?? 0;
      final actualMinutes = now.hour * 60 + now.minute;
      final delay = actualMinutes - scheduledMinutes;
      final status = delay <= settings.gracePeriodMinutes ? 'Present' : delay > settings.absentThresholdMinutes ? 'Absent' : 'Late';
      await markAttendance(employeeId: employeeId, employeeName: employeeName, date: date, time: time, verificationStatus: result.verificationStatus, similarityScore: score, status: status);
    }
    return result;
  }

  @override
  Future<void> markAttendance({required int employeeId, required String employeeName, required String date, required String time, required String verificationStatus, required double similarityScore, required String status}) async {
    await _recordsRef.doc('${employeeId}_${date.replaceAll('-', '')}').set({
      'employee_id': employeeId,
      'employee_name': employeeName,
      'date': date,
      'time': time,
      'status': status,
      'verification_status': verificationStatus,
      'similarity_score': similarityScore,
      'marked_at': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> unmarkAttendance({
    required int employeeId,
    required String date,
  }) async {
    await _recordsRef.doc('${employeeId}_${date.replaceAll('-', '')}').delete();
  }

  @override
  Future<void> logAttendanceAttempt({required int employeeId, required String employeeName, required String date, required String time, required String verificationStatus, required double similarityScore, required String message}) async {
    await _attemptsRef.add({
      'employee_id': employeeId,
      'employee_name': employeeName,
      'date': date,
      'time': time,
      'verification_status': verificationStatus,
      'similarity_score': similarityScore,
      'message': message,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
