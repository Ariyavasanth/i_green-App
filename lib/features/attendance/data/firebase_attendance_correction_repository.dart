import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/attendance_correction_repository.dart';
import '../domain/attendance_correction_request.dart';
import '../domain/attendance_record.dart';

class FirebaseAttendanceCorrectionRepository implements AttendanceCorrectionRepository {
  final FirebaseFirestore _firestore;

  FirebaseAttendanceCorrectionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _requestsRef =>
      _firestore.collection('attendance_correction_requests');
  CollectionReference<Map<String, dynamic>> get _recordsRef =>
      _firestore.collection('attendance_records');
  CollectionReference<Map<String, dynamic>> get _attemptsRef =>
      _firestore.collection('attendance_attempts');

  @override
  Future<void> submitRequest(AttendanceCorrectionRequest request) async {
    final docId = '${request.employeeId}_${request.date.replaceAll('-', '')}_correction';
    await _requestsRef.doc(docId).set(request.toMap(), SetOptions(merge: true));
  }

  @override
  Stream<List<AttendanceCorrectionRequest>> watchPendingRequests() {
    return _requestsRef
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AttendanceCorrectionRequest.fromMap(doc.data(), doc.id))
            .toList());
  }

  @override
  Stream<List<AttendanceCorrectionRequest>> watchEmployeeRequests(int employeeId) {
    return _requestsRef
        .where('employee_id', isEqualTo: employeeId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AttendanceCorrectionRequest.fromMap(doc.data(), doc.id))
            .toList());
  }

  @override
  Future<void> approveAndReopenShift({
    required AttendanceCorrectionRequest request,
    required String resumedCheckInTime,
    String? finalCheckOutTime,
    String? adminComment,
    String? reviewedBy,
  }) async {
    final normDate = request.date.replaceAll('-', '');
    final empCode = request.employeeCode.isNotEmpty ? request.employeeCode : request.employeeId.toString();

    // 1. Locate Attendance Record doc
    DocumentSnapshot<Map<String, dynamic>>? recordSnap;
    final primaryDoc = await _recordsRef.doc('${request.employeeId}_$normDate').get();
    if (primaryDoc.exists) {
      recordSnap = primaryDoc;
    } else {
      final codeDoc = await _recordsRef.doc('${empCode}_$normDate').get();
      if (codeDoc.exists) {
        recordSnap = codeDoc;
      } else {
        // Query by employee_id and date
        final querySnap = await _recordsRef
            .where('employee_id', isEqualTo: request.employeeId)
            .get();
        for (final d in querySnap.docs) {
          final dData = d.data();
          final dDate = (dData['date'] ?? '').toString();
          if (dDate.replaceAll('-', '') == normDate || dDate == request.date) {
            recordSnap = d;
            break;
          }
        }
      }
    }

    if (recordSnap != null && recordSnap.exists) {
      final data = recordSnap.data()!;
      final currentRecord = AttendanceRecord.fromMap(data);
      List<AttendanceSession> sessions = List.from(currentRecord.effectiveSessions);

      // Complete session 1 at the accidental check-out time
      if (sessions.isNotEmpty) {
        sessions[0] = sessions[0].copyWith(checkOutTime: request.accidentalCheckOutTime);
      }

      // Add Break Session (type 'lunch' or 'tea_break' so it is excluded from office work hours)
      final isLunch = request.activityType.toLowerCase().contains('lunch');
      final breakType = isLunch ? 'lunch' : 'tea_break';
      final breakStartTime = request.startTime.isNotEmpty ? request.startTime : request.accidentalCheckOutTime;
      
      int breakMinutes = 0;
      final bInM = AttendanceSession.parseTimeToMinutes(breakStartTime);
      final bOutM = AttendanceSession.parseTimeToMinutes(resumedCheckInTime);
      if (bInM != null && bOutM != null) {
        breakMinutes = bOutM - bInM;
        if (breakMinutes < 0) breakMinutes += 1440;
      }

      sessions.add(AttendanceSession(
        id: 'session_break_${DateTime.now().millisecondsSinceEpoch}',
        type: breakType,
        checkInTime: breakStartTime,
        checkOutTime: resumedCheckInTime,
        durationMinutes: breakMinutes,
        durationHours: double.parse((breakMinutes / 60.0).toStringAsFixed(2)),
        checkInMethod: 'Correction Request',
        checkOutMethod: 'Correction Request',
        notes: 'Employee requested break: ${request.description}',
      ));

      // Add the Resumed Office Session
      final isPastDate = finalCheckOutTime != null && finalCheckOutTime.isNotEmpty;
      int resumedOfficeMins = 0;
      if (isPastDate) {
        final rInM = AttendanceSession.parseTimeToMinutes(resumedCheckInTime);
        final rOutM = AttendanceSession.parseTimeToMinutes(finalCheckOutTime);
        if (rInM != null && rOutM != null) {
          resumedOfficeMins = rOutM - rInM;
          if (resumedOfficeMins < 0) resumedOfficeMins += 1440;
        }
      }

      sessions.add(AttendanceSession(
        id: 'session_office_resumed_${DateTime.now().millisecondsSinceEpoch}',
        type: 'office',
        checkInTime: resumedCheckInTime,
        checkOutTime: isPastDate ? finalCheckOutTime : '', // Empty = active session for today!
        durationMinutes: resumedOfficeMins,
        durationHours: double.parse((resumedOfficeMins / 60.0).toStringAsFixed(2)),
        checkInMethod: 'Admin Reopen',
        checkOutMethod: isPastDate ? 'Admin Finalized' : '',
        checkInVerificationStatus: 'Admin Verified',
      ));

      // Calculate total daily hours from completed office sessions
      double totalHours = 0.0;
      for (final s in sessions) {
        if (s.isCompleted && s.isOffice) {
          totalHours += s.effectiveDurationHours;
        }
      }

      final existingNotes = currentRecord.notes;
      final auditNote = 'Admin Reopened Shift: [${request.activityType} ($breakStartTime - $resumedCheckInTime)]';
      final updatedNotes = existingNotes.isNotEmpty ? '$existingNotes | $auditNote' : auditNote;

      final updatedRecord = currentRecord.copyWith(
        checkOutTime: isPastDate ? finalCheckOutTime : '',
        status: isPastDate ? (totalHours >= 8.0 ? 'Present' : 'Insufficient hours') : 'Present',
        totalHours: double.parse(totalHours.toStringAsFixed(2)),
        sessions: sessions,
        notes: updatedNotes,
      );

      final mapToSave = updatedRecord.toMap();

      // Write to primary record reference
      await recordSnap.reference.set(mapToSave, SetOptions(merge: true));

      // Dual-write: Ensure numeric ID document is updated
      await _recordsRef
          .doc('${request.employeeId}_$normDate')
          .set(mapToSave, SetOptions(merge: true));

      // Dual-write: Ensure code-keyed document is updated
      if (empCode.isNotEmpty) {
        await _recordsRef
            .doc('${empCode}_$normDate')
            .set(mapToSave, SetOptions(merge: true));
      }
      if (currentRecord.employeeCode.isNotEmpty && currentRecord.employeeCode != empCode) {
        await _recordsRef
            .doc('${currentRecord.employeeCode}_$normDate')
            .set(mapToSave, SetOptions(merge: true));
      }

      // Write audit log to attendance_attempts
      await _attemptsRef.add({
        'employee_id': request.employeeId,
        'employee_name': request.employeeName,
        'date': request.date,
        'action': 'ADMIN_CHECKOUT_REOPEN',
        'previous_checkout': request.accidentalCheckOutTime,
        'resumed_checkin': resumedCheckInTime,
        'reviewed_by': reviewedBy ?? 'Admin',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    // Mark Request as approved
    await _requestsRef.doc(request.id).update({
      'status': 'approved',
      'resumed_check_in_time': resumedCheckInTime,
      'final_checkout_time': finalCheckOutTime,
      'admin_comment': adminComment ?? '',
      'reviewed_by': reviewedBy ?? 'Admin',
      'reviewed_at': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> rejectRequest({
    required String requestId,
    required String reason,
    String? reviewedBy,
  }) async {
    await _requestsRef.doc(requestId).update({
      'status': 'rejected',
      'admin_comment': reason,
      'reviewed_by': reviewedBy ?? 'Admin',
      'reviewed_at': FieldValue.serverTimestamp(),
    });
  }
}
