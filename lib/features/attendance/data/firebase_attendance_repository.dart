import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/attendance_record.dart';
import '../domain/attendance_session.dart';
import '../domain/attendance_settings.dart';
import '../domain/attendance_repository.dart';
import '../../employee/domain/employee.dart';

class FirebaseAttendanceRepository implements AttendanceRepository {
  final FirebaseFirestore _firestore;
  final Map<String, AttendanceRecord> _localMemoryCache = {};

  FirebaseAttendanceRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _recordsRef => _firestore.collection('attendance_records');
  CollectionReference<Map<String, dynamic>> get _attemptsRef => _firestore.collection('attendance_attempts');
  DocumentReference<Map<String, dynamic>> get _settingsRef => _firestore.collection('attendance_settings').doc('global');

  @override
  Future<AttendanceSettings> getAttendanceSettings() async {
    try {
      final snap = await _settingsRef.get();
      if (!snap.exists || snap.data() == null) return AttendanceSettings.defaults();
      return AttendanceSettings.fromMap(snap.data()!);
    } catch (_) {
      return AttendanceSettings.defaults();
    }
  }

  @override
  Future<void> saveAttendanceSettings(AttendanceSettings settings) async {
    try {
      await _settingsRef.set(settings.toMap(), SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  Future<void> autoResolveMissingCheckOuts({int? employeeId}) async {
    try {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final snap = await _recordsRef.get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final docEmpIdRaw = data['employee_id'];
        final docEmpIdNum = docEmpIdRaw is int
            ? docEmpIdRaw
            : (int.tryParse(docEmpIdRaw?.toString() ?? '') ?? 0);

        if (employeeId != null && employeeId > 0 && docEmpIdNum != employeeId) continue;

        final checkOutTime = (data['check_out_time'] ?? '').toString().trim();
        final status = (data['status'] ?? '').toString();
        final recDateStr = (data['date'] ?? '').toString().trim();
        if (recDateStr.isEmpty) continue;
        final normDate = _normalizeDateKey(recDateStr);
        final inTimeStr = (data['check_in_time'] ?? data['time'] ?? '').toString().trim();

        if (normDate == todayStr && checkOutTime.isEmpty && status == 'Missing Check-Out') {
          await doc.reference.set({'status': 'Present'}, SetOptions(merge: true));
          continue;
        }

        if (checkOutTime.isNotEmpty || status == 'Missing Check-Out' || status == 'Absent' || status == 'On Leave' || inTimeStr.isEmpty) {
          continue;
        }

        bool isPastDate = normDate.compareTo(todayStr) < 0;

        if (isPastDate) {
          final existingNotes = (data['notes'] ?? '').toString();
          final newNotes = existingNotes.isNotEmpty
              ? (existingNotes.contains('Missing Check-Out') ? existingNotes : '$existingNotes | Missing Check-Out (Requires Correction)')
              : 'Missing Check-Out (Requires Correction)';

          await doc.reference.set({
            'status': 'Missing Check-Out',
            'total_hours': 0.0,
            'notes': newNotes,
          }, SetOptions(merge: true));
        }
      }
    } catch (_) {}
  }

  @override
  Future<List<AttendanceRecord>> getAttendanceRecords(int employeeId) async {
    List<AttendanceRecord> firestoreList = [];
    try {
      final snap = await _recordsRef.get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final docEmpIdRaw = data['employee_id'];
        final docEmpIdNum = docEmpIdRaw is int
            ? docEmpIdRaw
            : (int.tryParse(docEmpIdRaw?.toString() ?? '') ?? 0);
        final docEmpCode = (data['employee_code'] ?? data['employee_id'] ?? '').toString().trim().toUpperCase();

        final matchesEmp = (employeeId != 0 && docEmpIdNum == employeeId) ||
            (employeeId == 0) ||
            data['employee_id']?.toString() == employeeId.toString();

        if (matchesEmp) {
          firestoreList.add(AttendanceRecord.fromMap(data));
        }
      }
    } catch (_) {}

    final combinedMap = <String, AttendanceRecord>{};
    for (final r in _localMemoryCache.values) {
      if (r.employeeId == employeeId || employeeId == 0) {
        combinedMap['${r.employeeId}_${r.date}'] = r;
      }
    }
    for (final r in firestoreList) {
      combinedMap['${r.employeeId}_${r.date}'] = r;
    }
    return combinedMap.values.toList();
  }

  @override
  Future<List<AttendanceRecord>> getAllAttendanceRecords() async {
    List<AttendanceRecord> firestoreList = [];
    try {
      await autoResolveMissingCheckOuts();
      final snap = await _recordsRef.get();
      firestoreList = snap.docs.map((d) => AttendanceRecord.fromMap(d.data())).toList();
    } catch (_) {}

    final combinedMap = <String, AttendanceRecord>{};
    for (final r in _localMemoryCache.values) {
      combinedMap['${r.employeeId}_${r.date}'] = r;
    }
    for (final r in firestoreList) {
      combinedMap['${r.employeeId}_${r.date}'] = r;
    }
    return combinedMap.values.toList();
  }

  @override
  Future<AttendanceRecord?> getAttendanceRecordForDate(int employeeId, String date) async {
    try {
      await autoResolveMissingCheckOuts(employeeId: employeeId);
      final todayNormDate = _normalizeDateKey('${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}');
      final normDate = _normalizeDateKey(date);
      final docId = '${employeeId}_${normDate.replaceAll('-', '')}';
      final recordSnap = await _recordsRef.doc(docId).get();
      if (recordSnap.exists && recordSnap.data() != null) {
        final rec = AttendanceRecord.fromMap(recordSnap.data()!);
        if (rec.status == 'Missing Check-Out' && rec.checkOutTime.trim().isEmpty && _normalizeDateKey(rec.date) == todayNormDate) {
          return rec.copyWith(status: 'Present');
        }
        return rec;
      }

      final snap = await _recordsRef.get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final docEmpIdRaw = data['employee_id'];
        final docEmpIdNum = docEmpIdRaw is int
            ? docEmpIdRaw
            : (int.tryParse(docEmpIdRaw?.toString() ?? '') ?? 0);
        final docEmpCode = (data['employee_code'] ?? data['employee_id'] ?? '').toString().trim().toUpperCase();

        final matchesEmp = (employeeId != 0 && docEmpIdNum == employeeId) ||
            (employeeId == 0) ||
            data['employee_id']?.toString() == employeeId.toString();

        final docDate = (data['date'] ?? '').toString();
        final normDocDate = _normalizeDateKey(docDate);
        final matchesDate = docDate == date || docDate.replaceAll('-', '') == date.replaceAll('-', '') || normDocDate == normDate;

        if (matchesEmp && matchesDate) {
          return AttendanceRecord.fromMap(data);
        }
      }
    } catch (_) {}
    return _localMemoryCache['${employeeId}_$date'];
  }

  @override
  Future<bool> hasAttendanceForDate(int employeeId, String date) async {
    final rec = await getAttendanceRecordForDate(employeeId, date);
    return rec != null;
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

  Future<Map<String, dynamic>> _resolveEffectiveLocation({
    required int employeeId,
    required AttendanceSettings globalSettings,
  }) async {
    try {
      final snap = await _firestore.collection('employees').where('id', isEqualTo: employeeId).limit(1).get();
      if (snap.docs.isNotEmpty) {
        final emp = Employee.fromMap(snap.docs.first.data());
        if (emp.isDynamicEmployee && (emp.siteLatitude != 0 || emp.siteLongitude != 0)) {
          return {
            'targetLat': emp.siteLatitude,
            'targetLng': emp.siteLongitude,
            'targetRadius': emp.siteAllowedRadiusMeters,
            'requireGps': emp.siteRequireGpsVerification,
            'isSite': true,
          };
        }
      }
    } catch (_) {}
    return {
      'targetLat': globalSettings.officeLatitude,
      'targetLng': globalSettings.officeLongitude,
      'targetRadius': globalSettings.allowedAttendanceRadiusMeters,
      'requireGps': globalSettings.requireGpsVerification,
      'isSite': false,
    };
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
    bool faceMatched = true,
    double similarityScore = 1.0,
  }) async {
    await autoResolveMissingCheckOuts(employeeId: employeeId);
    final score = similarityScore;
    final now = DateTime.now();
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final settings = await getAttendanceSettings();
    final loc = await _resolveEffectiveLocation(employeeId: employeeId, globalSettings: settings);
    final targetLat = loc['targetLat'] as double;
    final targetLng = loc['targetLng'] as double;
    final targetRadius = loc['targetRadius'] as int;
    final requireGps = loc['requireGps'] as bool;
    final isSite = loc['isSite'] as bool;
    final distance = _distanceInMeters(
      startLatitude: targetLat,
      startLongitude: targetLng,
      endLatitude: currentLatitude,
      endLongitude: currentLongitude,
    );
    final bool effectiveRequireGps = requireGps && (targetLat != 0 || targetLng != 0);
    final withinRadius = !effectiveRequireGps || distance <= targetRadius;
    final message = !withinRadius
        ? (isSite
            ? 'You are not at your site location. Please go to your site location to check in.'
            : 'You are not at the office. Please go to the office location to check in.')
        : 'Check in successful.';
    final result = AttendanceVerificationResult(
      allowed: withinRadius,
      similarityScore: score,
      verificationStatus: !withinRadius ? 'Outside Radius' : 'Verified',
      message: message,
      capturedImagePath: '',
    );
    await logAttendanceAttempt(employeeId: employeeId, employeeName: employeeName, date: date, time: time, verificationStatus: result.verificationStatus, similarityScore: score, message: result.message);
    if (result.allowed) {
      Employee? employee;
      try {
        final snap = await _firestore.collection('employees').get();
        for (final doc in snap.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          final docId = doc.id;
          final docIdNum = int.tryParse(docId.replaceAll(RegExp(r'\D'), '')) ?? 0;
          final idNum = data['id'] is int ? data['id'] : (int.tryParse(data['id']?.toString() ?? '') ?? 0);
          final codeStr = (data['employee_code'] ?? data['employee_id'] ?? '').toString().trim().toUpperCase();
          final codeNum = int.tryParse(codeStr.replaceAll(RegExp(r'\D'), '')) ?? 0;

          final matches = (employeeId != 0 && (idNum == employeeId || docIdNum == employeeId || codeNum == employeeId)) ||
              docId == employeeId.toString() ||
              data['id']?.toString() == employeeId.toString() ||
              data['employee_id']?.toString() == employeeId.toString();

          if (matches) {
            if (!data.containsKey('id') || data['id'] == null || data['id'] == 0) {
              data['id'] = (docIdNum != 0) ? docIdNum : (docId.hashCode & 0x7FFFFFFF);
            }
            employee = Employee.fromMap(data);
            break;
          }
        }
      } catch (_) {}

      String status = 'Present';
      String notes = '';

      final isDynamic = employee?.isDynamicEmployee ?? false;
      final schedIn = scheduledCheckInTime.trim().isNotEmpty
          ? scheduledCheckInTime.trim()
          : (employee?.inTime.trim().isNotEmpty == true
              ? employee!.inTime.trim()
              : '');

      final scheduledMinutes = _parseMinutes(schedIn);

      if (isDynamic || scheduledMinutes == null) {
        status = 'Present';
        notes = 'Flexible schedule';
      } else {
        final actualMinutes = now.hour * 60 + now.minute;

        final approvedPermissions = await _getApprovedPermissions(
          employeeId,
          date,
          employeeCode: employee?.employeeId,
        );

        int maxApprovedToMinutes = -1;
        int totalApprovedMins = 0;
        for (final p in approvedPermissions) {
          final toStr = (p['to_time'] ?? '').toString();
          final dur = (p['duration_minutes'] as num?)?.toInt() ?? 0;
          totalApprovedMins += dur;
          final toMins = _parseMinutes(toStr);
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
          status = 'Present';
          notes = (totalApprovedMins > 0 || maxApprovedToMinutes > 0)
              ? 'Present (Authorized Permission)'
              : 'On time';
        } else if (netUnauthorizedDelay <= settings.lateLimitMinutes) {
          status = 'Late';
          notes = (totalApprovedMins > 0 || maxApprovedToMinutes > 0)
              ? 'Late = $netUnauthorizedDelay mins unauthorized after permission'
              : 'Late = $netUnauthorizedDelay minutes';
        } else {
          status = 'Absent';
          notes = (totalApprovedMins > 0 || maxApprovedToMinutes > 0)
              ? 'Absent (Exceeds late limit cutoff after permission)'
              : 'Absent (Exceeds late limit cutoff of ${settings.lateLimitMinutes} mins)';
        }
      }

      if (isDynamic) {
        await markAttendance(
          employeeId: employeeId,
          employeeName: employeeName,
          employeeCode: employee?.employeeId ?? '',
          date: date,
          time: time,
          verificationStatus: result.verificationStatus,
          similarityScore: score,
          status: status,
          notes: notes,
        );
      } else {
        final sessionResult = await _startOfficeAttendanceSession(
          employeeId: employeeId,
          employeeName: employeeName,
          employeeCode: employee?.employeeId ?? '',
          date: date,
          time: time,
          verificationStatus: result.verificationStatus,
          similarityScore: score,
          status: status,
          notes: notes,
          currentLatitude: currentLatitude,
          currentLongitude: currentLongitude,
        );
        if (!sessionResult.allowed) {
          return sessionResult;
        }
      }
    }
    return result;
  }

  Future<AttendanceVerificationResult> _startOfficeAttendanceSession({
    required int employeeId,
    required String employeeName,
    String employeeCode = '',
    required String date,
    required String time,
    required String verificationStatus,
    required double similarityScore,
    required String status,
    String notes = '',
    required double currentLatitude,
    required double currentLongitude,
  }) async {
    final normDate = _normalizeDateKey(date);
    final docId = '${employeeId}_${normDate.replaceAll('-', '')}';

    // 1. Fetch existing attendance record for this date
    AttendanceRecord? existingRecord = await getAttendanceRecordForDate(employeeId, date);

    // 2. Check if an active session already exists
    if (existingRecord != null) {
      final bool hasActiveSession = existingRecord.sessions.any((s) => s.isActive);
      final bool hasLegacyActiveSession = existingRecord.sessions.isEmpty &&
          existingRecord.checkInTime.isNotEmpty &&
          existingRecord.checkOutTime.isEmpty;

      if (hasActiveSession || hasLegacyActiveSession) {
        final activeSession = existingRecord.sessions.where((s) => s.isActive).firstOrNull;
        final isOd = activeSession?.isOd ?? false;
        return AttendanceVerificationResult(
          allowed: false,
          similarityScore: similarityScore,
          verificationStatus: isOd ? 'OD Session Active' : 'Already Checked In',
          message: isOd
              ? 'You have an active On-Duty session. Please complete On-Duty before checking in at the office.'
              : 'You already have an active check-in session.',
          capturedImagePath: '',
        );
      }
    }

    // 3. Create the new session
    final newSessionIndex = (existingRecord?.sessions.length ?? 0) + 1;
    final sessionUuid = 'session_${DateTime.now().millisecondsSinceEpoch}_$newSessionIndex';
    final newSession = AttendanceSession(
      id: sessionUuid,
      type: 'office',
      checkInTime: time,
      checkOutTime: '',
      checkInVerificationStatus: verificationStatus,
      checkOutVerificationStatus: '',
      checkInSimilarityScore: similarityScore,
      checkOutSimilarityScore: 0.0,
      checkInLatitude: currentLatitude,
      checkInLongitude: currentLongitude,
      checkInMethod: 'Face + Geofence',
      checkOutMethod: '',
      durationHours: 0.0,
      durationMinutes: 0,
      notes: notes,
      createdAt: DateTime.now().toIso8601String(),
    );

    // 4. Update or create the AttendanceRecord
    List<AttendanceSession> updatedSessions = [];
    if (existingRecord != null) {
      updatedSessions = List<AttendanceSession>.from(existingRecord.sessions);
      if (updatedSessions.isEmpty &&
          existingRecord.checkInTime.isNotEmpty &&
          existingRecord.checkOutTime.isNotEmpty) {
        // Preserve legacy single session
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
    } else {
      updatedSessions.add(newSession);
    }

    final AttendanceRecord updatedRecord;
    if (existingRecord != null) {
      updatedRecord = existingRecord.copyWith(
        employeeCode: employeeCode.isNotEmpty ? employeeCode : existingRecord.employeeCode,
        employeeName: employeeName.isNotEmpty ? employeeName : existingRecord.employeeName,
        time: existingRecord.time.isNotEmpty ? existingRecord.time : time,
        checkInTime: existingRecord.checkInTime.isNotEmpty ? existingRecord.checkInTime : time,
        checkOutTime: existingRecord.checkOutTime,
        status: (existingRecord.status == 'Absent' || existingRecord.status == 'Late')
            ? existingRecord.status
            : status,
        verificationStatus: existingRecord.verificationStatus.isNotEmpty
            ? existingRecord.verificationStatus
            : verificationStatus,
        similarityScore: existingRecord.similarityScore > 0
            ? existingRecord.similarityScore
            : similarityScore,
        checkInVerificationStatus: existingRecord.checkInVerificationStatus.isNotEmpty
            ? existingRecord.checkInVerificationStatus
            : verificationStatus,
        checkInSimilarityScore: existingRecord.checkInSimilarityScore > 0
            ? existingRecord.checkInSimilarityScore
            : similarityScore,
        totalHours: existingRecord.totalHours,
        notes: existingRecord.notes.isNotEmpty ? existingRecord.notes : notes,
        markedAt: existingRecord.markedAt.isNotEmpty
            ? existingRecord.markedAt
            : DateTime.now().toIso8601String(),
        sessions: updatedSessions,
      );
    } else {
      updatedRecord = AttendanceRecord(
        id: employeeId * 10000 + DateTime.now().millisecondsSinceEpoch % 10000,
        employeeId: employeeId,
        employeeCode: employeeCode,
        employeeName: employeeName,
        date: normDate,
        time: time,
        checkInTime: time,
        checkOutTime: '',
        status: status,
        verificationStatus: verificationStatus,
        similarityScore: similarityScore,
        checkInVerificationStatus: verificationStatus,
        checkInSimilarityScore: similarityScore,
        totalHours: 0.0,
        notes: notes,
        markedAt: DateTime.now().toIso8601String(),
        sessions: updatedSessions,
      );
    }

    // 5. Update Firestore first, then local cache upon success
    try {
      await _recordsRef.doc(docId).set(updatedRecord.toMap(), SetOptions(merge: true));
      if (employeeCode.isNotEmpty) {
        await _recordsRef
            .doc('${employeeCode}_${normDate.replaceAll('-', '')}')
            .set(updatedRecord.toMap(), SetOptions(merge: true));
      }
    } catch (_) {
      return AttendanceVerificationResult(
        allowed: false,
        similarityScore: similarityScore,
        verificationStatus: 'Failed',
        message: 'Failed to record check-in. Please try again.',
        capturedImagePath: '',
      );
    }

    _localMemoryCache['${employeeId}_$date'] = updatedRecord;
    _localMemoryCache['${employeeId}_$normDate'] = updatedRecord;
    if (employeeCode.isNotEmpty) {
      _localMemoryCache['${employeeCode}_$date'] = updatedRecord;
      _localMemoryCache['${employeeCode}_$normDate'] = updatedRecord;
    }

    return AttendanceVerificationResult(
      allowed: true,
      similarityScore: similarityScore,
      verificationStatus: verificationStatus,
      message: 'Check in successful.',
      capturedImagePath: '',
    );
  }

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
  }) async {
    final score = similarityScore;
    final now = DateTime.now();
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final settings = await getAttendanceSettings();
    final loc = await _resolveEffectiveLocation(employeeId: employeeId, globalSettings: settings);
    final targetLat = loc['targetLat'] as double;
    final targetLng = loc['targetLng'] as double;
    final targetRadius = loc['targetRadius'] as int;
    final requireGps = loc['requireGps'] as bool;
    final isSite = loc['isSite'] as bool;
    final distance = _distanceInMeters(
      startLatitude: targetLat,
      startLongitude: targetLng,
      endLatitude: currentLatitude,
      endLongitude: currentLongitude,
    );
    final bool effectiveRequireGps = requireGps && (targetLat != 0 || targetLng != 0);
    final withinRadius = !effectiveRequireGps || distance <= targetRadius;
    final message = !withinRadius
        ? (isSite
            ? 'You are not at your site location. Please go to your site location to check out.'
            : 'You are not at the office. Please go to the office location to check out.')
        : 'Check out successful.';
    final result = AttendanceVerificationResult(
      allowed: withinRadius,
      similarityScore: score,
      verificationStatus: !withinRadius ? 'Outside Radius' : 'Verified',
      message: message,
      capturedImagePath: '',
    );
    await logAttendanceAttempt(employeeId: employeeId, employeeName: employeeName, date: date, time: time, verificationStatus: 'CheckOut ${result.verificationStatus}', similarityScore: score, message: result.message);
    if (result.allowed) {
      Employee? employee;
      try {
        final snap = await _firestore.collection('employees').get();
        for (final doc in snap.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          final docId = doc.id;
          final docIdNum = int.tryParse(docId.replaceAll(RegExp(r'\D'), '')) ?? 0;
          final idNum = data['id'] is int ? data['id'] : (int.tryParse(data['id']?.toString() ?? '') ?? 0);
          final codeStr = (data['employee_code'] ?? data['employee_id'] ?? '').toString().trim().toUpperCase();
          final codeNum = int.tryParse(codeStr.replaceAll(RegExp(r'\D'), '')) ?? 0;

          final matches = (employeeId != 0 && (idNum == employeeId || docIdNum == employeeId || codeNum == employeeId)) ||
              docId == employeeId.toString() ||
              data['id']?.toString() == employeeId.toString() ||
              data['employee_id']?.toString() == employeeId.toString();

          if (matches) {
            if (!data.containsKey('id') || data['id'] == null || data['id'] == 0) {
              data['id'] = (docIdNum != 0) ? docIdNum : (docId.hashCode & 0x7FFFFFFF);
            }
            employee = Employee.fromMap(data);
            break;
          }
        }
      } catch (_) {}

      final isDynamic = employee?.isDynamicEmployee ?? false;

      if (isDynamic) {
        await checkOut(
          employeeId: employeeId,
          date: date,
          checkOutTime: time,
          verificationStatus: result.verificationStatus,
          similarityScore: score,
        );
      } else {
        final sessionResult = await _completeOfficeAttendanceSession(
          employeeId: employeeId,
          employeeName: employeeName,
          employeeCode: employee?.employeeId ?? '',
          date: date,
          time: time,
          verificationStatus: result.verificationStatus,
          similarityScore: score,
          currentLatitude: currentLatitude,
          currentLongitude: currentLongitude,
        );
        if (!sessionResult.allowed) {
          return sessionResult;
        }
      }
    }
    return result;
  }

  Future<AttendanceVerificationResult> _completeOfficeAttendanceSession({
    required int employeeId,
    required String employeeName,
    String employeeCode = '',
    required String date,
    required String time,
    required String verificationStatus,
    required double similarityScore,
    double? currentLatitude,
    double? currentLongitude,
  }) async {
    final normDate = _normalizeDateKey(date);
    final docId = '${employeeId}_${normDate.replaceAll('-', '')}';

    // 1. Fetch existing attendance record for this date
    AttendanceRecord? existingRecord = await getAttendanceRecordForDate(employeeId, date);

    if (existingRecord == null) {
      return AttendanceVerificationResult(
        allowed: false,
        similarityScore: similarityScore,
        verificationStatus: 'No Active Session',
        message: 'No active check-in session found.',
        capturedImagePath: '',
      );
    }

    // 2. Locate the active session
    List<AttendanceSession> updatedSessions = List<AttendanceSession>.from(existingRecord.sessions);
    int activeIndex = updatedSessions.indexWhere((s) => s.isActive);

    // Backward compatibility for legacy records with checkInTime but no sessions array
    if (activeIndex == -1 &&
        updatedSessions.isEmpty &&
        existingRecord.checkInTime.isNotEmpty &&
        existingRecord.checkOutTime.isEmpty) {
      final legacySession = AttendanceSession(
        id: 'session_legacy_1',
        checkInTime: existingRecord.checkInTime,
        checkOutTime: '',
        checkInVerificationStatus: existingRecord.checkInVerificationStatus.isNotEmpty
            ? existingRecord.checkInVerificationStatus
            : existingRecord.verificationStatus,
        checkOutVerificationStatus: '',
        checkInSimilarityScore: existingRecord.checkInSimilarityScore > 0
            ? existingRecord.checkInSimilarityScore
            : existingRecord.similarityScore,
        checkOutSimilarityScore: 0.0,
        checkInLatitude: null,
        checkInLongitude: null,
        checkInMethod: 'Face + Geofence',
        checkOutMethod: '',
        durationHours: 0.0,
        durationMinutes: 0,
        notes: existingRecord.notes,
        createdAt: existingRecord.markedAt,
      );
      updatedSessions.add(legacySession);
      activeIndex = 0;
    }

    // 3. If no active session found, reject checkout safely
    if (activeIndex == -1) {
      return AttendanceVerificationResult(
        allowed: false,
        similarityScore: similarityScore,
        verificationStatus: 'No Active Session',
        message: 'No active check-in session found.',
        capturedImagePath: '',
      );
    }

    // 4. Complete only the active session
    final activeSession = updatedSessions[activeIndex];
    if (activeSession.isOd) {
      return AttendanceVerificationResult(
        allowed: false,
        similarityScore: similarityScore,
        verificationStatus: 'Active Session is OD',
        message: 'The active session is an On-Duty session. Please complete On-Duty from the OD card.',
        capturedImagePath: '',
      );
    }

    int sessionDurationMinutes = 0;
    double sessionDurationHours = 0.0;

    final inMin = _parseMinutes(activeSession.checkInTime);
    final outMin = _parseMinutes(time);
    if (inMin != null && outMin != null && outMin >= inMin) {
      sessionDurationMinutes = outMin - inMin;
      sessionDurationHours = double.parse((sessionDurationMinutes / 60.0).toStringAsFixed(2));
    }

    final completedSession = activeSession.copyWith(
      checkOutTime: time,
      checkOutVerificationStatus: verificationStatus,
      checkOutSimilarityScore: similarityScore,
      checkOutLatitude: currentLatitude,
      checkOutLongitude: currentLongitude,
      checkOutMethod: 'Face + Geofence',
      durationHours: sessionDurationHours,
      durationMinutes: sessionDurationMinutes,
    );
    updatedSessions[activeIndex] = completedSession;

    // 5. Calculate total daily hours as the sum of all completed sessions
    double totalDailyHours = 0.0;
    for (final session in updatedSessions) {
      if (session.isCompleted) {
        totalDailyHours += session.effectiveDurationHours;
      }
    }
    totalDailyHours = double.parse(totalDailyHours.toStringAsFixed(2));

    // 6. Update the AttendanceRecord preserving top-level legacy fields
    final updatedRecord = existingRecord.copyWith(
      employeeCode: employeeCode.isNotEmpty ? employeeCode : existingRecord.employeeCode,
      employeeName: employeeName.isNotEmpty ? employeeName : existingRecord.employeeName,
      checkOutTime: time,
      checkOutVerificationStatus: verificationStatus,
      checkOutSimilarityScore: similarityScore,
      totalHours: totalDailyHours,
      sessions: updatedSessions,
    );

    // 7. Update Firestore first, then local cache upon success
    try {
      await _recordsRef.doc(docId).set(updatedRecord.toMap(), SetOptions(merge: true));
      if (employeeCode.isNotEmpty) {
        await _recordsRef
            .doc('${employeeCode}_${normDate.replaceAll('-', '')}')
            .set(updatedRecord.toMap(), SetOptions(merge: true));
      }
      if (existingRecord.employeeCode.isNotEmpty && existingRecord.employeeCode != employeeCode) {
        await _recordsRef
            .doc('${existingRecord.employeeCode}_${normDate.replaceAll('-', '')}')
            .set(updatedRecord.toMap(), SetOptions(merge: true));
      }
    } catch (_) {
      return AttendanceVerificationResult(
        allowed: false,
        similarityScore: similarityScore,
        verificationStatus: 'Failed',
        message: 'Failed to record check-out. Please try again.',
        capturedImagePath: '',
      );
    }

    _localMemoryCache['${employeeId}_$date'] = updatedRecord;
    _localMemoryCache['${employeeId}_$normDate'] = updatedRecord;
    if (employeeCode.isNotEmpty) {
      _localMemoryCache['${employeeCode}_$date'] = updatedRecord;
      _localMemoryCache['${employeeCode}_$normDate'] = updatedRecord;
    }
    if (existingRecord.employeeCode.isNotEmpty) {
      _localMemoryCache['${existingRecord.employeeCode}_$date'] = updatedRecord;
      _localMemoryCache['${existingRecord.employeeCode}_$normDate'] = updatedRecord;
    }

    return AttendanceVerificationResult(
      allowed: true,
      similarityScore: similarityScore,
      verificationStatus: verificationStatus,
      message: 'Check out successful.',
      capturedImagePath: '',
    );
  }

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
    String notes = '',
  }) async {
    final normDate = _normalizeDateKey(date);
    final docId = '${employeeId}_${normDate.replaceAll('-', '')}';

    // 1. Validate that the assignment exists and is not cancelled/rejected
    if (assignmentId > 0) {
      try {
        final assignDoc = await _firestore.collection('on_duty_assignments').doc(assignmentId.toString()).get();
        if (assignDoc.exists && assignDoc.data() != null) {
          final assignData = assignDoc.data()!;
          final assignStatus = (assignData['status'] ?? '').toString().toUpperCase();
          if (assignStatus == 'CANCELLED' || assignStatus == 'REJECTED') {
            return const AttendanceVerificationResult(
              allowed: false,
              similarityScore: 1.0,
              verificationStatus: 'Invalid Assignment',
              message: 'This On-Duty assignment has been cancelled or rejected.',
              capturedImagePath: '',
            );
          }
        }
      } catch (_) {}
    }

    // 2. Fetch existing attendance record
    AttendanceRecord? existingRecord = await getAttendanceRecordForDate(employeeId, date);

    // 3. Mutual exclusion check
    if (existingRecord != null) {
      final bool hasActiveSession = existingRecord.sessions.any((s) => s.isActive);
      final bool hasLegacyActiveSession = existingRecord.sessions.isEmpty &&
          existingRecord.checkInTime.isNotEmpty &&
          existingRecord.checkOutTime.isEmpty;

      if (hasActiveSession || hasLegacyActiveSession) {
        final activeSession = existingRecord.sessions.where((s) => s.isActive).firstOrNull;
        final isOffice = activeSession?.isOffice ?? true;
        return AttendanceVerificationResult(
          allowed: false,
          similarityScore: 1.0,
          verificationStatus: isOffice ? 'Office Session Active' : 'OD Session Active',
          message: isOffice
              ? 'You are currently checked in at the office. Please check out before starting On-Duty.'
              : 'You already have an active On-Duty session in progress.',
          capturedImagePath: '',
        );
      }
    }

    // 4. Determine status if first check-in of the day
    String status = existingRecord?.status ?? 'Present';
    String initialNotes = notes.isNotEmpty
        ? notes
        : 'On Duty: ${purpose.isNotEmpty ? purpose : "Field Duty"}${destination.isNotEmpty ? " ($destination)" : ""}';

    // 5. Create new OD session
    final newSessionIndex = (existingRecord?.sessions.length ?? 0) + 1;
    final sessionUuid = 'session_${DateTime.now().millisecondsSinceEpoch}_$newSessionIndex';
    final newSession = AttendanceSession(
      id: sessionUuid,
      type: 'od',
      checkInTime: time,
      checkOutTime: '',
      checkInVerificationStatus: 'OD Verified',
      checkOutVerificationStatus: '',
      checkInSimilarityScore: 1.0,
      checkOutSimilarityScore: 0.0,
      checkInLatitude: latitude,
      checkInLongitude: longitude,
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude,
      destinationRadius: destinationRadius > 0 ? destinationRadius : 100,
      checkInMethod: 'OD GPS + Photo',
      checkOutMethod: '',
      assignmentId: assignmentId,
      purpose: purpose,
      destination: destination,
      destinationAddress: destinationAddress,
      durationHours: 0.0,
      durationMinutes: 0,
      notes: initialNotes,
      createdAt: DateTime.now().toIso8601String(),
    );

    // 6. Update or create the AttendanceRecord
    List<AttendanceSession> updatedSessions = [];
    if (existingRecord != null) {
      updatedSessions = List<AttendanceSession>.from(existingRecord.sessions);
      if (updatedSessions.isEmpty &&
          existingRecord.checkInTime.isNotEmpty &&
          existingRecord.checkOutTime.isNotEmpty) {
        // Preserve legacy single session
        updatedSessions.add(AttendanceSession(
          id: 'session_legacy_1',
          type: 'office',
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
    } else {
      updatedSessions.add(newSession);
    }

    final AttendanceRecord updatedRecord;
    if (existingRecord != null) {
      updatedRecord = existingRecord.copyWith(
        employeeCode: employeeCode.isNotEmpty ? employeeCode : existingRecord.employeeCode,
        employeeName: employeeName.isNotEmpty ? employeeName : existingRecord.employeeName,
        time: existingRecord.time.isNotEmpty ? existingRecord.time : time,
        checkInTime: existingRecord.checkInTime.isNotEmpty ? existingRecord.checkInTime : time,
        checkOutTime: existingRecord.checkOutTime,
        status: (existingRecord.status == 'Absent' || existingRecord.status == 'Late')
            ? existingRecord.status
            : status,
        verificationStatus: existingRecord.verificationStatus.isNotEmpty
            ? existingRecord.verificationStatus
            : 'OD Verified',
        similarityScore: existingRecord.similarityScore > 0
            ? existingRecord.similarityScore
            : 1.0,
        totalHours: existingRecord.totalHours,
        notes: existingRecord.notes.isNotEmpty ? existingRecord.notes : initialNotes,
        markedAt: existingRecord.markedAt.isNotEmpty
            ? existingRecord.markedAt
            : DateTime.now().toIso8601String(),
        sessions: updatedSessions,
      );
    } else {
      updatedRecord = AttendanceRecord(
        id: employeeId * 10000 + DateTime.now().millisecondsSinceEpoch % 10000,
        employeeId: employeeId,
        employeeCode: employeeCode,
        employeeName: employeeName,
        date: normDate,
        time: time,
        checkInTime: time,
        checkOutTime: '',
        status: status,
        verificationStatus: 'OD Verified',
        similarityScore: 1.0,
        checkInVerificationStatus: 'OD Verified',
        checkInSimilarityScore: 1.0,
        totalHours: 0.0,
        notes: initialNotes,
        markedAt: DateTime.now().toIso8601String(),
        sessions: updatedSessions,
      );
    }

    try {
      await _recordsRef.doc(docId).set(updatedRecord.toMap(), SetOptions(merge: true));
      if (employeeCode.isNotEmpty) {
        await _recordsRef
            .doc('${employeeCode}_${normDate.replaceAll('-', '')}')
            .set(updatedRecord.toMap(), SetOptions(merge: true));
      }
    } catch (_) {
      return const AttendanceVerificationResult(
        allowed: false,
        similarityScore: 1.0,
        verificationStatus: 'Failed',
        message: 'Failed to record On-Duty session. Please try again.',
        capturedImagePath: '',
      );
    }

    _localMemoryCache['${employeeId}_$date'] = updatedRecord;
    _localMemoryCache['${employeeId}_$normDate'] = updatedRecord;
    if (employeeCode.isNotEmpty) {
      _localMemoryCache['${employeeCode}_$date'] = updatedRecord;
      _localMemoryCache['${employeeCode}_$normDate'] = updatedRecord;
    }

    return const AttendanceVerificationResult(
      allowed: true,
      similarityScore: 1.0,
      verificationStatus: 'OD Verified',
      message: 'On-Duty session started.',
      capturedImagePath: '',
    );
  }

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
  }) async {
    final normDate = _normalizeDateKey(date);
    final docId = '${employeeId}_${normDate.replaceAll('-', '')}';

    AttendanceRecord? existingRecord = await getAttendanceRecordForDate(employeeId, date);
    if (existingRecord == null) {
      return const AttendanceVerificationResult(
        allowed: false,
        similarityScore: 1.0,
        verificationStatus: 'No Active Session',
        message: 'No active On-Duty session found.',
        capturedImagePath: '',
      );
    }

    List<AttendanceSession> updatedSessions = List<AttendanceSession>.from(existingRecord.sessions);
    int activeIndex = updatedSessions.indexWhere((s) => s.isActive && (s.isOd || s.assignmentId == assignmentId));

    // Fallback: any active session
    if (activeIndex == -1) {
      activeIndex = updatedSessions.indexWhere((s) => s.isActive);
    }

    if (activeIndex == -1) {
      return const AttendanceVerificationResult(
        allowed: false,
        similarityScore: 1.0,
        verificationStatus: 'No Active Session',
        message: 'No active On-Duty session found.',
        capturedImagePath: '',
      );
    }

    final activeSession = updatedSessions[activeIndex];

    // Destination Geofence verification
    final targetLat = destinationLatitude ?? activeSession.destinationLatitude;
    final targetLng = destinationLongitude ?? activeSession.destinationLongitude;
    final targetRadius = destinationRadius > 0
        ? destinationRadius
        : (activeSession.destinationRadius > 0 ? activeSession.destinationRadius : 100);

    if (targetLat != null && targetLng != null && targetLat != 0 && targetLng != 0) {
      if (latitude == null || longitude == null || latitude == 0 || longitude == 0) {
        return const AttendanceVerificationResult(
          allowed: false,
          similarityScore: 1.0,
          verificationStatus: 'GPS Required',
          message: 'GPS location is required to verify destination arrival.',
          capturedImagePath: '',
        );
      }

      final distance = _distanceInMeters(
        startLatitude: targetLat,
        startLongitude: targetLng,
        endLatitude: latitude,
        endLongitude: longitude,
      );

      if (distance > targetRadius) {
        final distRounded = distance.round();
        return AttendanceVerificationResult(
          allowed: false,
          similarityScore: 1.0,
          verificationStatus: 'Outside Destination',
          message: 'You are not at the selected destination. Please reach the destination before completing OD. (Distance: ${distRounded}m, Allowed: within ${targetRadius}m)',
          capturedImagePath: '',
        );
      }
    }

    int sessionDurationMinutes = 0;
    double sessionDurationHours = 0.0;

    final inMin = _parseMinutes(activeSession.checkInTime);
    final outMin = _parseMinutes(time);
    if (inMin != null && outMin != null && outMin >= inMin) {
      sessionDurationMinutes = outMin - inMin;
      sessionDurationHours = double.parse((sessionDurationMinutes / 60.0).toStringAsFixed(2));
    }

    final completedSession = activeSession.copyWith(
      checkOutTime: time,
      checkOutVerificationStatus: 'OD Completed',
      checkOutSimilarityScore: 1.0,
      checkOutLatitude: latitude,
      checkOutLongitude: longitude,
      destinationLatitude: targetLat,
      destinationLongitude: targetLng,
      destinationRadius: targetRadius,
      checkOutMethod: 'OD GPS Capture',
      durationHours: sessionDurationHours,
      durationMinutes: sessionDurationMinutes,
    );
    updatedSessions[activeIndex] = completedSession;

    // Calculate total daily hours as the sum of all completed sessions (Office + OD)
    double totalDailyHours = 0.0;
    for (final session in updatedSessions) {
      if (session.isCompleted) {
        totalDailyHours += session.effectiveDurationHours;
      }
    }
    totalDailyHours = double.parse(totalDailyHours.toStringAsFixed(2));

    final isCheckoutFromOd = afterCompletionOption.toUpperCase().contains('CHECKOUT');

    final updatedRecord = existingRecord.copyWith(
      employeeCode: employeeCode.isNotEmpty ? employeeCode : existingRecord.employeeCode,
      employeeName: employeeName.isNotEmpty ? employeeName : existingRecord.employeeName,
      checkOutTime: isCheckoutFromOd ? time : existingRecord.checkOutTime,
      checkOutVerificationStatus: isCheckoutFromOd ? 'OD Location Verified' : existingRecord.checkOutVerificationStatus,
      checkOutSimilarityScore: isCheckoutFromOd ? 1.0 : existingRecord.checkOutSimilarityScore,
      totalHours: totalDailyHours,
      sessions: updatedSessions,
    );

    try {
      await _recordsRef.doc(docId).set(updatedRecord.toMap(), SetOptions(merge: true));
      if (employeeCode.isNotEmpty) {
        await _recordsRef
            .doc('${employeeCode}_${normDate.replaceAll('-', '')}')
            .set(updatedRecord.toMap(), SetOptions(merge: true));
      }
      if (existingRecord.employeeCode.isNotEmpty && existingRecord.employeeCode != employeeCode) {
        await _recordsRef
            .doc('${existingRecord.employeeCode}_${normDate.replaceAll('-', '')}')
            .set(updatedRecord.toMap(), SetOptions(merge: true));
      }
    } catch (_) {
      return const AttendanceVerificationResult(
        allowed: false,
        similarityScore: 1.0,
        verificationStatus: 'Failed',
        message: 'Failed to complete On-Duty session. Please try again.',
        capturedImagePath: '',
      );
    }

    _localMemoryCache['${employeeId}_$date'] = updatedRecord;
    _localMemoryCache['${employeeId}_$normDate'] = updatedRecord;
    if (employeeCode.isNotEmpty) {
      _localMemoryCache['${employeeCode}_$date'] = updatedRecord;
      _localMemoryCache['${employeeCode}_$normDate'] = updatedRecord;
    }
    if (existingRecord.employeeCode.isNotEmpty) {
      _localMemoryCache['${existingRecord.employeeCode}_$date'] = updatedRecord;
      _localMemoryCache['${existingRecord.employeeCode}_$normDate'] = updatedRecord;
    }

    return const AttendanceVerificationResult(
      allowed: true,
      similarityScore: 1.0,
      verificationStatus: 'OD Completed',
      message: 'On-Duty session completed.',
      capturedImagePath: '',
    );
  }

  String _normalizeDateKey(String dateStr) {
    final parts = dateStr.split(RegExp(r'[-/]'));
    if (parts.length == 3) {
      if (parts[0].length == 4) {
        return '${parts[0]}-${parts[1].padLeft(2, '0')}-${parts[2].padLeft(2, '0')}';
      } else if (parts[2].length == 4) {
        return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
      }
    }
    return dateStr;
  }

  @override
  Future<void> markAttendance({
    required int employeeId,
    required String employeeName,
    String employeeCode = '',
    required String date,
    required String time,
    required String verificationStatus,
    required double similarityScore,
    required String status,
    String notes = '',
  }) async {
    final normDate = _normalizeDateKey(date);
    final docId = '${employeeId}_${normDate.replaceAll('-', '')}';

    final rec = AttendanceRecord(
      id: employeeId * 10000 + DateTime.now().millisecondsSinceEpoch % 10000,
      employeeId: employeeId,
      employeeCode: employeeCode,
      employeeName: employeeName,
      date: normDate,
      time: time,
      checkInTime: time,
      checkOutTime: '',
      status: status,
      verificationStatus: verificationStatus,
      similarityScore: similarityScore,
      notes: notes,
      markedAt: DateTime.now().toIso8601String(),
    );
    _localMemoryCache['${employeeId}_$date'] = rec;
    _localMemoryCache['${employeeId}_$normDate'] = rec;
    if (employeeCode.isNotEmpty) {
      _localMemoryCache['${employeeCode}_$date'] = rec;
      _localMemoryCache['${employeeCode}_$normDate'] = rec;
    }

    try {
      await _recordsRef.doc(docId).set(rec.toMap(), SetOptions(merge: true));
      if (employeeCode.isNotEmpty) {
        await _recordsRef.doc('${employeeCode}_${normDate.replaceAll('-', '')}').set(rec.toMap(), SetOptions(merge: true));
      }
    } catch (_) {}
  }

  @override
  Future<void> checkOut({
    required int employeeId,
    required String date,
    required String checkOutTime,
    required String verificationStatus,
    required double similarityScore,
  }) async {
    final normDate = _normalizeDateKey(date);
    final docId = '${employeeId}_${normDate.replaceAll('-', '')}';
    final docRef = _recordsRef.doc(docId);

    AttendanceRecord? record;
    try {
      final snap = await docRef.get();
      if (snap.exists && snap.data() != null) {
        record = AttendanceRecord.fromMap(snap.data()!);
      }
    } catch (_) {}

    record ??= await getAttendanceRecordForDate(employeeId, date);
    if (record == null) return;

    double hours = 0.0;
    final inTime = record.effectiveCheckInTime;
    if (inTime.isNotEmpty && checkOutTime.isNotEmpty) {
      try {
        final inMin = _parseMinutes(inTime);
        final outMin = _parseMinutes(checkOutTime);
        if (inMin != null && outMin != null && outMin > inMin) {
          hours = double.parse(((outMin - inMin) / 60.0).toStringAsFixed(2));
        }
      } catch (_) {}
    }

    Employee? employee;
    try {
      final snap = await _firestore.collection('employees').get();
      for (final doc in snap.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        final dId = doc.id;
        final dIdNum = int.tryParse(dId.replaceAll(RegExp(r'\D'), '')) ?? 0;
        final idNum = data['id'] is int ? data['id'] : (int.tryParse(data['id']?.toString() ?? '') ?? 0);
        final codeStr = (data['employee_code'] ?? data['employee_id'] ?? '').toString().trim().toUpperCase();
        final codeNum = int.tryParse(codeStr.replaceAll(RegExp(r'\D'), '')) ?? 0;

        final matches = (employeeId != 0 && (idNum == employeeId || dIdNum == employeeId || codeNum == employeeId)) ||
            dId == employeeId.toString() ||
            data['id']?.toString() == employeeId.toString() ||
            data['employee_id']?.toString() == employeeId.toString();

        if (matches) {
          if (!data.containsKey('id') || data['id'] == null || data['id'] == 0) {
            data['id'] = (dIdNum != 0) ? dIdNum : (dId.hashCode & 0x7FFFFFFF);
          }
          employee = Employee.fromMap(data);
          break;
        }
      }
    } catch (_) {}

    final isDynamic = employee?.isDynamicEmployee ?? false;
    final requiredHours = (employee?.requiredWorkingHours ?? 0) > 0
        ? employee!.requiredWorkingHours
        : 9.0;

    final shortfallHours = (requiredHours - hours).clamp(0, requiredHours);
    final shortfallMins = (shortfallHours * 60).ceil();
    final approvedPermissionMins = await _getApprovedPermissionMinutes(employeeId, date);

    String finalStatus = record.status;
    String updatedNotes = record.notes;

    if (shortfallMins == 0) {
      if (isDynamic) {
        finalStatus = 'Completed';
        updatedNotes = 'Worked ${hours.toStringAsFixed(1)} hrs (Completed ${requiredHours.toStringAsFixed(0)} hrs target)';
      } else {
        finalStatus = record.status == 'Late' ? 'Late' : 'Completed';
        updatedNotes = 'Worked ${hours.toStringAsFixed(1)} hrs (Completed shift)';
      }
    } else {
      if (approvedPermissionMins >= shortfallMins) {
        finalStatus = isDynamic ? 'Completed' : (record.status == 'Late' ? 'Late' : 'Completed');
        updatedNotes = 'Authorized early checkout (covers ${shortfallMins} mins)';
      } else if (approvedPermissionMins > 0) {
        final unauthorizedMins = shortfallMins - approvedPermissionMins;
        finalStatus = 'Insufficient hours';
        updatedNotes = record.notes.isNotEmpty
            ? '${record.notes} | Worked ${hours.toStringAsFixed(1)} hrs (Partially authorized: ${approvedPermissionMins} mins authorized, ${unauthorizedMins} mins unauthorized)'
            : 'Worked ${hours.toStringAsFixed(1)} hrs (Partially authorized: ${approvedPermissionMins} mins authorized, ${unauthorizedMins} mins unauthorized)';
      } else {
        final unauthorizedMins = shortfallMins - approvedPermissionMins;
        finalStatus = 'Insufficient hours';
        updatedNotes = record.notes.isNotEmpty
            ? '${record.notes} | Worked ${hours.toStringAsFixed(1)} hrs (Insufficient hours, $unauthorizedMins mins unauthorized)'
            : 'Worked ${hours.toStringAsFixed(1)} hrs (Insufficient hours, $unauthorizedMins mins unauthorized)';
      }
    }

    final updatedRec = record.copyWith(
      checkOutTime: checkOutTime,
      totalHours: hours,
      status: finalStatus,
      notes: updatedNotes,
    );
    _localMemoryCache['${employeeId}_$date'] = updatedRec;
    _localMemoryCache['${employeeId}_$normDate'] = updatedRec;
    if (record.employeeCode.isNotEmpty) {
      _localMemoryCache['${record.employeeCode}_$date'] = updatedRec;
      _localMemoryCache['${record.employeeCode}_$normDate'] = updatedRec;
    }

    try {
      await docRef.set(updatedRec.toMap(), SetOptions(merge: true));

      final allSnap = await _recordsRef.get();
      for (final doc in allSnap.docs) {
        final data = doc.data();
        final docEmpIdRaw = data['employee_id'];
        final docEmpIdNum = docEmpIdRaw is int
            ? docEmpIdRaw
            : (int.tryParse(docEmpIdRaw?.toString() ?? '') ?? 0);
        final docEmpCode = (data['employee_code'] ?? data['employee_id'] ?? '').toString().trim().toUpperCase();
        final isEmpMatch = (employeeId != 0 && docEmpIdNum == employeeId) ||
            data['employee_id']?.toString() == employeeId.toString() ||
            (record.employeeCode.isNotEmpty && docEmpCode == record.employeeCode.toUpperCase()) ||
            (employee?.employeeId.isNotEmpty == true && docEmpCode == employee!.employeeId.toUpperCase());

        final docDate = (data['date'] ?? '').toString();
        final normDocDate = _normalizeDateKey(docDate);
        final isDateMatch = docDate == date || docDate.replaceAll('-', '') == date.replaceAll('-', '') || normDocDate == normDate;

        if (isEmpMatch && isDateMatch && doc.id != docId) {
          await doc.reference.set(updatedRec.toMap(), SetOptions(merge: true));
        }
      }
    } catch (_) {}
  }

  @override
  Future<void> adminSaveAttendance(AttendanceRecord record) async {
    final inTime = record.effectiveCheckInTime;
    final outTime = record.checkOutTime;
    double hours = record.totalHours;
    String status = record.status;
    String notes = record.notes;

    if (inTime.isNotEmpty && outTime.isNotEmpty) {
      try {
        final inParts = inTime.split(':');
        final outParts = outTime.split(':');
        if (inParts.length >= 2 && outParts.length >= 2) {
          final inMin = int.parse(inParts[0]) * 60 + int.parse(inParts[1]);
          final outMin = int.parse(outParts[0]) * 60 + int.parse(outParts[1]);
          if (outMin > inMin) {
            hours = double.parse(((outMin - inMin) / 60.0).toStringAsFixed(2));
          }
        }
      } catch (_) {}

      Employee? employee;
      try {
        final empSnap = await _firestore.collection('employees').where('id', isEqualTo: record.employeeId).limit(1).get();
        if (empSnap.docs.isNotEmpty) {
          employee = Employee.fromMap(empSnap.docs.first.data());
        }
      } catch (_) {}

      final isDynamic = employee?.isDynamicEmployee ?? false;
      final requiredHours = (employee?.requiredWorkingHours ?? 0) > 0
          ? employee!.requiredWorkingHours
          : 9.0;

      final shortfallHours = (requiredHours - hours).clamp(0, requiredHours);
      final shortfallMins = (shortfallHours * 60).ceil();
      final approvedPermissionMins = await _getApprovedPermissionMinutes(record.employeeId, record.date);

      int outMin = 0;
      try {
        final parts = outTime.split(':');
        if (parts.length >= 2) outMin = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      } catch (_) {}
      int? empOutMin;
      if (employee != null && employee.outTime.trim().isNotEmpty) {
        empOutMin = _parseMinutes(employee.outTime);
      } else if (employee != null && employee.inTime.trim().isNotEmpty) {
        final parsedIn = _parseMinutes(employee.inTime);
        if (parsedIn != null) {
          empOutMin = (parsedIn + (requiredHours * 60).toInt()) % 1440;
        }
      }
      final isLateCheckout = empOutMin != null && empOutMin > 0 && outMin > empOutMin;

      if (shortfallMins == 0) {
        if (isDynamic) {
          status = 'Completed';
          notes = 'Worked ${hours.toStringAsFixed(1)} hrs (Completed ${requiredHours.toStringAsFixed(0)} hrs target)${isLateCheckout ? ' | Late Checkout' : ''}';
        } else {
          status = record.status == 'Late' ? 'Late' : 'Completed';
          notes = 'Worked ${hours.toStringAsFixed(1)} hrs (Completed shift)${isLateCheckout ? ' | Late Checkout' : ''}';
        }
      } else {
        if (approvedPermissionMins >= shortfallMins) {
          status = isDynamic ? 'Completed' : (record.status == 'Late' ? 'Late' : 'Completed');
          notes = 'Authorized early checkout (covers ${shortfallMins} mins)';
        } else if (approvedPermissionMins > 0) {
          final unauthorizedMins = shortfallMins - approvedPermissionMins;
          status = 'Insufficient hours';
          notes = 'Worked ${hours.toStringAsFixed(1)} hrs (Partially authorized: ${approvedPermissionMins} mins authorized, ${unauthorizedMins} mins unauthorized)';
        } else {
          status = 'Insufficient hours';
          notes = 'Worked ${hours.toStringAsFixed(1)} hrs (Insufficient hours, ${shortfallMins} mins unauthorized)';
        }
      }
    }

    final toSave = record.copyWith(
      time: inTime,
      checkInTime: inTime,
      status: status,
      notes: notes,
      totalHours: hours,
      markedAt: record.markedAt.isNotEmpty ? record.markedAt : DateTime.now().toIso8601String(),
    );

    _localMemoryCache['${record.employeeId}_${record.date}'] = toSave;

    try {
      await _recordsRef.doc('${record.employeeId}_${record.date.replaceAll('-', '')}').set(
        toSave.toMap(),
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  @override
  Future<void> unmarkAttendance({
    required int employeeId,
    required String date,
  }) async {
    final normDate = _normalizeDateKey(date);
    _localMemoryCache.remove('${employeeId}_$date');
    _localMemoryCache.remove('${employeeId}_$normDate');
    try {
      await _recordsRef.doc('${employeeId}_${normDate.replaceAll('-', '')}').delete();
      await _recordsRef.doc('${employeeId}_${date.replaceAll('-', '')}').delete();
      final allSnap = await _recordsRef.get();
      for (final doc in allSnap.docs) {
        final data = doc.data();
        final docEmpId = data['employee_id'] is int ? data['employee_id'] : int.tryParse(data['employee_id']?.toString() ?? '');
        final docDate = (data['date'] ?? '').toString();
        final normDocDate = _normalizeDateKey(docDate);
        if ((docEmpId == employeeId || data['employee_id']?.toString() == employeeId.toString()) &&
            (docDate == date || docDate == normDate || normDocDate == normDate)) {
          await doc.reference.delete();
        }
      }
    } catch (_) {}
  }

  @override
  Future<void> logAttendanceAttempt({required int employeeId, required String employeeName, required String date, required String time, required String verificationStatus, required double similarityScore, required String message}) async {
    try {
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
    } catch (_) {}
  }

  @override
  Future<List<Map<String, dynamic>>> getAttendanceAttempts() async {
    try {
      final snap = await _attemptsRef.orderBy('created_at', descending: true).limit(100).get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getApprovedPermissions(int employeeId, String date, {String? employeeCode}) async {
    try {
      final snap = await _firestore
          .collection('permission_requests')
          .get();

      final normTargetDate = _normalizeDateKey(date);
      final List<Map<String, dynamic>> approved = [];
      for (final doc in snap.docs) {
        final data = doc.data();
        final rawDate = data['date'];
        DateTime? docDate;
        if (rawDate is Timestamp) {
          docDate = rawDate.toDate();
        } else if (rawDate is DateTime) {
          docDate = rawDate;
        } else if (rawDate is String) {
          docDate = DateTime.tryParse(rawDate);
        }
        final docDateStr = docDate != null
            ? '${docDate.year}-${docDate.month.toString().padLeft(2, '0')}-${docDate.day.toString().padLeft(2, '0')}'
            : (rawDate ?? '').toString();
        final normDocDate = _normalizeDateKey(docDateStr);

        final docEmpIdRaw = data['employee_id'];
        final docEmpIdNum = docEmpIdRaw is int
            ? docEmpIdRaw
            : (int.tryParse(docEmpIdRaw?.toString() ?? '') ?? 0);
        final docEmpCode = (data['employee_code'] ?? data['employee_id'] ?? '').toString().trim().toUpperCase();
        final statusStr = (data['status'] ?? '').toString().toLowerCase();

        final isDateMatch = normDocDate == normTargetDate ||
            docDateStr == date ||
            docDateStr.startsWith(date) ||
            docDateStr.contains(date) ||
            (rawDate != null && rawDate.toString().contains(date));
        final isEmpMatch = (employeeId != 0 && docEmpIdNum == employeeId) ||
            data['employee_id']?.toString() == employeeId.toString() ||
            (employeeCode != null && employeeCode.isNotEmpty && docEmpCode == employeeCode.toUpperCase());

        if (isDateMatch && isEmpMatch && statusStr == 'approved') {
          approved.add(data);
        }
      }
      return approved;
    } catch (_) {
      return [];
    }
  }

  Future<int> _getApprovedPermissionMinutes(int employeeId, String date) async {
    final permissions = await _getApprovedPermissions(employeeId, date);
    int total = 0;
    for (final p in permissions) {
      total += (p['duration_minutes'] as num?)?.toInt() ?? 0;
    }
    return total;
  }

  int? _parseMinutes(String timeStr) {
    if (timeStr.trim().isEmpty) return null;
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPm = clean.contains('PM');
      final isAm = clean.contains('AM');
      final digits = clean.replaceAll(RegExp(r'[^0-9:]'), '');
      final parts = digits.split(':').where((p) => p.trim().isNotEmpty).toList();
      if (parts.isNotEmpty) {
        int? hours = int.tryParse(parts[0]);
        if (hours == null) return null;
        final minutes = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
        if (isPm && hours < 12) hours += 12;
        if (isAm && hours == 12) hours = 0;
        return hours * 60 + minutes;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> recalculateAttendanceForDate(int employeeId, String date) async {
    try {
      final normDate = _normalizeDateKey(date);
      final docId = '${employeeId}_${normDate.replaceAll('-', '')}';
      final docRef = _recordsRef.doc(docId);

      AttendanceRecord? record;
      final snap = await docRef.get();
      if (snap.exists && snap.data() != null) {
        record = AttendanceRecord.fromMap(snap.data()!);
      }
      record ??= await getAttendanceRecordForDate(employeeId, date);
      if (record == null) return;

      final inTime = record.effectiveCheckInTime.trim();
      if (inTime.isEmpty) return;

      Employee? employee;
      try {
        final snap = await _firestore.collection('employees').get();
        for (final doc in snap.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          final dId = doc.id;
          final dIdNum = int.tryParse(dId.replaceAll(RegExp(r'\D'), '')) ?? 0;
          final idNum = data['id'] is int ? data['id'] : (int.tryParse(data['id']?.toString() ?? '') ?? 0);
          final codeStr = (data['employee_code'] ?? data['employee_id'] ?? '').toString().trim().toUpperCase();
          final codeNum = int.tryParse(codeStr.replaceAll(RegExp(r'\D'), '')) ?? 0;

          final matches = (employeeId != 0 && (idNum == employeeId || dIdNum == employeeId || codeNum == employeeId)) ||
              dId == employeeId.toString() ||
              data['id']?.toString() == employeeId.toString() ||
              data['employee_id']?.toString() == employeeId.toString();

          if (matches) {
            if (!data.containsKey('id') || data['id'] == null || data['id'] == 0) {
              data['id'] = (dIdNum != 0) ? dIdNum : (dId.hashCode & 0x7FFFFFFF);
            }
            employee = Employee.fromMap(data);
            break;
          }
        }
      } catch (_) {}

      final isDynamic = employee?.isDynamicEmployee ?? false;
      final settings = await getAttendanceSettings();
      final approvedPermissions = await _getApprovedPermissions(
        employeeId,
        date,
        employeeCode: employee?.employeeId ?? record.employeeCode,
      );

      String schedIn = '';
      if (employee != null && employee.inTime.trim().isNotEmpty) {
        schedIn = employee.inTime.trim();
      }
      if (schedIn.isEmpty) schedIn = '09:00 AM';

      final scheduledMinutes = _parseMinutes(schedIn);
      final checkInMinutes = _parseMinutes(inTime);

      String newStatus = record.status;
      String newNotes = record.notes;

      if (isDynamic || scheduledMinutes == null || checkInMinutes == null) {
        if (record.checkOutTime.trim().isEmpty) {
          newStatus = 'Present';
          newNotes = 'Flexible schedule';
        }
      } else {
        int maxApprovedToMinutes = -1;
        int totalApprovedMins = 0;
        for (final p in approvedPermissions) {
          final toStr = (p['to_time'] ?? '').toString();
          final dur = (p['duration_minutes'] as num?)?.toInt() ?? 0;
          totalApprovedMins += dur;
          final toMins = _parseMinutes(toStr);
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

        final netUnauthorizedDelay = checkInMinutes - effectiveAllowedMinutes;

        if (record.checkOutTime.trim().isEmpty) {
          if (netUnauthorizedDelay <= 0) {
            newStatus = 'Present';
            newNotes = (totalApprovedMins > 0 || maxApprovedToMinutes > 0)
                ? 'Present (Authorized Permission)'
                : 'On time';
          } else if (netUnauthorizedDelay <= settings.lateLimitMinutes) {
            newStatus = 'Late';
            newNotes = (totalApprovedMins > 0 || maxApprovedToMinutes > 0)
                ? 'Late = $netUnauthorizedDelay mins unauthorized after permission'
                : 'Late = $netUnauthorizedDelay minutes';
          } else {
            newStatus = 'Absent';
            newNotes = (totalApprovedMins > 0 || maxApprovedToMinutes > 0)
                ? 'Absent (Exceeds late limit cutoff after permission)'
                : 'Absent (Exceeds late limit cutoff of ${settings.lateLimitMinutes} mins)';
          }
        } else {
          final checkOutTime = record.checkOutTime.trim();
          double hours = record.totalHours;
          final outMinutes = _parseMinutes(checkOutTime);
          if (outMinutes != null && outMinutes > checkInMinutes) {
            hours = double.parse(((outMinutes - checkInMinutes) / 60.0).toStringAsFixed(2));
          }

          final requiredHours = (employee?.requiredWorkingHours ?? 0) > 0
              ? employee!.requiredWorkingHours
              : 9.0;
          final shortfallHours = (requiredHours - hours).clamp(0, requiredHours);
          final shortfallMins = (shortfallHours * 60).ceil();

          if (netUnauthorizedDelay <= 0) {
            if (shortfallMins == 0 || totalApprovedMins >= shortfallMins) {
              newStatus = 'Completed';
              newNotes = totalApprovedMins > 0
                  ? 'Worked ${hours.toStringAsFixed(1)} hrs (Permission Authorized)'
                  : 'Worked ${hours.toStringAsFixed(1)} hrs (Completed shift)';
            } else {
              newStatus = 'Insufficient hours';
              newNotes = 'Worked ${hours.toStringAsFixed(1)} hrs (Insufficient hours)';
            }
          } else if (netUnauthorizedDelay <= settings.lateLimitMinutes) {
            newStatus = 'Late';
            newNotes = 'Worked ${hours.toStringAsFixed(1)} hrs (Late: $netUnauthorizedDelay mins)';
          } else {
            newStatus = 'Absent';
            newNotes = 'Worked ${hours.toStringAsFixed(1)} hrs (Exceeded late limit)';
          }
        }
      }

      final updatedRec = record.copyWith(
        status: newStatus,
        notes: newNotes,
      );
      _localMemoryCache['${employeeId}_$normDate'] = updatedRec;
      _localMemoryCache['${employeeId}_$date'] = updatedRec;
      if (record.employeeCode.isNotEmpty) {
        _localMemoryCache['${record.employeeCode}_$normDate'] = updatedRec;
        _localMemoryCache['${record.employeeCode}_$date'] = updatedRec;
      }

      await docRef.set(updatedRec.toMap(), SetOptions(merge: true));

      final allSnap = await _recordsRef.get();
      for (final doc in allSnap.docs) {
        final data = doc.data();
        final docEmpIdRaw = data['employee_id'];
        final docEmpIdNum = docEmpIdRaw is int
            ? docEmpIdRaw
            : (int.tryParse(docEmpIdRaw?.toString() ?? '') ?? 0);
        final docEmpCode = (data['employee_code'] ?? data['employee_id'] ?? '').toString().trim().toUpperCase();
        final isEmpMatch = (employeeId != 0 && docEmpIdNum == employeeId) ||
            data['employee_id']?.toString() == employeeId.toString() ||
            (record.employeeCode.isNotEmpty && docEmpCode == record.employeeCode.toUpperCase()) ||
            (employee?.employeeId.isNotEmpty == true && docEmpCode == employee!.employeeId.toUpperCase());

        final docDate = (data['date'] ?? '').toString();
        final normDocDate = _normalizeDateKey(docDate);
        final isDateMatch = docDate == date || docDate.replaceAll('-', '') == date.replaceAll('-', '') || normDocDate == normDate;

        if (isEmpMatch && isDateMatch && doc.id != docId) {
          await doc.reference.set(updatedRec.toMap(), SetOptions(merge: true));
        }
      }
    } catch (_) {}
  }

  @override
  Future<void> clearAllAttendanceRecords() async {
    _localMemoryCache.clear();
    try {
      final recordsSnap = await _recordsRef.get();
      for (final doc in recordsSnap.docs) {
        await doc.reference.delete();
      }
      final attemptsSnap = await _attemptsRef.get();
      for (final doc in attemptsSnap.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}
  }
}

