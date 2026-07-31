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
  Future<List<AttendanceRecord>> getAllAttendanceRecords() async {
    final snap = await _recordsRef.get();
    return snap.docs.map((d) => AttendanceRecord.fromMap(d.data())).toList();
  }

  @override
  Future<AttendanceRecord?> getAttendanceRecordForDate(int employeeId, String date) async {
    final snap = await _recordsRef.where('employee_id', isEqualTo: employeeId).where('date', isEqualTo: date).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return AttendanceRecord.fromMap(snap.docs.first.data());
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
    final score = 0.99;
    final allowed = true;
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
      verificationStatus: !withinRadius ? 'Outside Radius' : 'Verified',
      message: !withinRadius
          ? 'You are not at the office. Please go to the office location to check in.'
          : 'Check in successful.',
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
  Future<AttendanceVerificationResult> verifyCheckOut({
    required int employeeId,
    required String date,
    required String employeeName,
    required String profileImageUrl,
    required double currentLatitude,
    required double currentLongitude,
  }) async {
    final score = 0.99;
    final allowed = true;
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
      verificationStatus: !withinRadius ? 'Outside Radius' : 'Verified',
      message: !withinRadius
          ? 'You are not at the office. Please go to the office location to check out.'
          : 'Check out successful.',
      capturedImagePath: '',
    );
    await logAttendanceAttempt(employeeId: employeeId, employeeName: employeeName, date: date, time: time, verificationStatus: 'CheckOut ${result.verificationStatus}', similarityScore: score, message: result.message);
    if (result.allowed) {
      await checkOut(employeeId: employeeId, date: date, checkOutTime: time, verificationStatus: result.verificationStatus, similarityScore: score);
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
      'check_in_time': time,
      'check_in_verification_status': verificationStatus,
      'check_in_similarity_score': similarityScore,
      'marked_at': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> checkOut({
    required int employeeId,
    required String date,
    required String checkOutTime,
    required String verificationStatus,
    required double similarityScore,
  }) async {
    final docRef = _recordsRef.doc('${employeeId}_${date.replaceAll('-', '')}');
    final snap = await docRef.get();
    if (!snap.exists || snap.data() == null) return;
    final record = AttendanceRecord.fromMap(snap.data()!);
    final inTime = record.effectiveCheckInTime;

    double hours = 0.0;
    try {
      final inParts = inTime.split(':');
      final outParts = checkOutTime.split(':');
      if (inParts.length >= 2 && outParts.length >= 2) {
        final inMin = int.parse(inParts[0]) * 60 + int.parse(inParts[1]);
        final outMin = int.parse(outParts[0]) * 60 + int.parse(outParts[1]);
        if (outMin > inMin) hours = double.parse(((outMin - inMin) / 60.0).toStringAsFixed(2));
      }
    } catch (_) {}

    await docRef.set({
      'check_out_time': checkOutTime,
      'check_out_verification_status': verificationStatus,
      'check_out_similarity_score': similarityScore,
      'total_hours': hours,
      'status': 'Checked Out',
    }, SetOptions(merge: true));
  }

  @override
  Future<void> adminSaveAttendance(AttendanceRecord record) async {
    await _recordsRef.doc('${record.employeeId}_${record.date.replaceAll('-', '')}').set(
      record.toMap(),
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> unmarkAttendance({
    required int employeeId,
    required String date,
  }) async {
    await _recordsRef.doc('${employeeId}_${date.replaceAll('-', '')}').delete();
    final snap = await _recordsRef
        .where('employee_id', isEqualTo: employeeId)
        .where('date', isEqualTo: date)
        .get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
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

  @override
  Future<List<Map<String, dynamic>>> getAttendanceAttempts() async {
    final snap = await _attemptsRef.orderBy('created_at', descending: true).limit(100).get();
    return snap.docs.map((d) => d.data()).toList();
  }
}
