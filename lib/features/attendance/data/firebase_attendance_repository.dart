import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/attendance_record.dart';
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
        final rawDelay = actualMinutes - scheduledMinutes;

        final approvedPermissionMins = await _getApprovedPermissionMinutes(employeeId, date);
        final totalAuthorizedWindowMins = settings.gracePeriodMinutes + approvedPermissionMins;
        final netUnauthorizedDelay = rawDelay - totalAuthorizedWindowMins;

        if (netUnauthorizedDelay <= 0) {
          status = 'Present';
          notes = approvedPermissionMins > 0
              ? 'Present (Authorized Permission)'
              : 'On time';
        } else if (netUnauthorizedDelay <= settings.lateLimitMinutes) {
          status = 'Late';
          notes = approvedPermissionMins > 0
              ? 'Late = $netUnauthorizedDelay mins unauthorized after $approvedPermissionMins mins permission'
              : 'Late = $netUnauthorizedDelay minutes';
        } else {
          status = 'Absent';
          notes = approvedPermissionMins > 0
              ? 'Absent (Exceeds late limit cutoff after $approvedPermissionMins mins permission)'
              : 'Absent (Exceeds late limit cutoff of ${settings.lateLimitMinutes} mins)';
        }
      }

      await markAttendance(
        employeeId: employeeId,
        employeeName: employeeName,
        date: date,
        time: time,
        verificationStatus: result.verificationStatus,
        similarityScore: score,
        status: status,
        notes: notes,
      );
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
    final withinRadius = !requireGps || distance <= targetRadius;
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
      await checkOut(employeeId: employeeId, date: date, checkOutTime: time, verificationStatus: result.verificationStatus, similarityScore: score);
    }
    return result;
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

    try {
      await _recordsRef.doc(docId).set({
        'employee_id': employeeId,
        'employee_name': employeeName,
        'date': normDate,
        'time': time,
        'status': status,
        'verification_status': verificationStatus,
        'similarity_score': similarityScore,
        'check_in_time': time,
        'check_in_verification_status': verificationStatus,
        'check_in_similarity_score': similarityScore,
        'notes': notes,
        'marked_at': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
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
        final inParts = inTime.split(':');
        final outParts = checkOutTime.split(':');
        if (inParts.length >= 2 && outParts.length >= 2) {
          final inMin = int.parse(inParts[0]) * 60 + int.parse(inParts[1]);
          final outMin = int.parse(outParts[0]) * 60 + int.parse(outParts[1]);
          if (outMin > inMin) {
            hours = double.parse(((outMin - inMin) / 60.0).toStringAsFixed(2));
          }
        }
      } catch (_) {}
    }

    Employee? employee;
    try {
      final empSnap = await _firestore.collection('employees').where('id', isEqualTo: employeeId).limit(1).get();
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

    try {
      await docRef.set({
        'check_out_time': checkOutTime,
        'check_out_verification_status': verificationStatus,
        'check_out_similarity_score': similarityScore,
        'total_hours': hours,
        'status': finalStatus,
        'notes': updatedNotes,
      }, SetOptions(merge: true));
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

  Future<int> _getApprovedPermissionMinutes(int employeeId, String date) async {
    try {
      final snap = await _firestore
          .collection('permission_requests')
          .get();

      int approvedMins = 0;
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

        final docEmpIdRaw = data['employee_id'];
        final docEmpIdNum = docEmpIdRaw is int
            ? docEmpIdRaw
            : (int.tryParse(docEmpIdRaw?.toString() ?? '') ?? 0);
        final docEmpCode = (data['employee_code'] ?? data['employee_id'] ?? '').toString().trim().toUpperCase();
        final statusStr = (data['status'] ?? '').toString().toLowerCase();

        final isDateMatch = docDateStr == date ||
            docDateStr.startsWith(date) ||
            docDateStr.contains(date) ||
            (rawDate != null && rawDate.toString().contains(date));
        final isEmpMatch = (employeeId != 0 && docEmpIdNum == employeeId) ||
            data['employee_id']?.toString() == employeeId.toString();

        if (isDateMatch && isEmpMatch && statusStr == 'approved') {
          approvedMins += (data['duration_minutes'] as num?)?.toInt() ?? 0;
        }
      }
      return approvedMins;
    } catch (_) {
      return 0;
    }
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

