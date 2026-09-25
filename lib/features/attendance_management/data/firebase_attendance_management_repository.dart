import 'package:cloud_firestore/cloud_firestore.dart';
import '../../attendance/domain/attendance_record.dart';
import '../domain/attendance_management_repository.dart';
import '../domain/attendance_management_stats.dart';

class FirebaseAttendanceManagementRepository implements AttendanceManagementRepository {
  final FirebaseFirestore? _customFirestore;
  final Map<String, AttendanceRecord> _localMemoryCache = {};

  FirebaseAttendanceManagementRepository({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _recordsRef =>
      _firestore.collection('attendance_records');
  CollectionReference<Map<String, dynamic>> get _attemptsRef =>
      _firestore.collection('attendance_attempts');
  CollectionReference<Map<String, dynamic>> get _employeesRef =>
      _firestore.collection('employees');

  /// Looks up the employee's string code (e.g. 'EMP-002') from Firestore by integer ID.
  /// No employee-specific codes or offsets are hardcoded — always reads from the database.
  Future<String> _resolveEmpCode(int employeeId) async {
    try {
      final snap = await _employeesRef.get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final dataId = data['id'] is int
            ? data['id'] as int
            : (int.tryParse(data['id']?.toString() ?? '') ?? 0);
        if (dataId == employeeId) {
          // Prefer the stored employee_id field; fallback to doc ID
          return (data['employee_id'] ?? doc.id).toString().trim().toUpperCase();
        }
      }
    } catch (_) {}
    return '';
  }

  String _normalizeDateKey(String dateStr) {
    if (dateStr.trim().isEmpty) return dateStr;
    try {
      final isoDate = DateTime.tryParse(dateStr);
      if (isoDate != null) {
        return '${isoDate.day.toString().padLeft(2, '0')}-${isoDate.month.toString().padLeft(2, '0')}-${isoDate.year}';
      }
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        if (parts[0].length == 4) {
          return '${parts[2].padLeft(2, '0')}-${parts[1].padLeft(2, '0')}-${parts[0]}';
        } else {
          return '${parts[0].padLeft(2, '0')}-${parts[1].padLeft(2, '0')}-${parts[2]}';
        }
      }
    } catch (_) {}
    return dateStr;
  }

  bool _matchesMonthYear(String recordDate, String monthYear) {
    if (recordDate.trim().isEmpty) return true;
    final norm = _normalizeDateKey(recordDate);
    final parts = norm.split('-');
    if (parts.length == 3) {
      final mStr = '${parts[1].padLeft(2, '0')}-${parts[2]}';
      return mStr == monthYear;
    }
    return true;
  }

  bool _matchesStatus(String recordStatus, String? statusFilter) {
    if (statusFilter == null || statusFilter.isEmpty || statusFilter.toLowerCase() == 'all') {
      return true;
    }
    return recordStatus.trim().toLowerCase() == statusFilter.trim().toLowerCase();
  }

  @override
  Future<List<AttendanceRecord>> getAllAttendanceRecords({
    int? employeeId,
    String? monthYear,
    String? statusFilter,
  }) async {
    // Resolve the target employee code so we can strictly isolate records
    final String targetEmpCode = employeeId != null ? await _resolveEmpCode(employeeId) : '';

    List<AttendanceRecord> firestoreRecords = [];
    try {
      final snap = await _recordsRef.get();
      for (final doc in snap.docs) {
        final data = doc.data();
        if (employeeId != null) {
          final docEmpCode = (data['employee_code'] ?? data['employee_id'] ?? '').toString().trim().toUpperCase();
          final docEmpIdRaw = data['employee_id'];
          final docEmpIdNum = docEmpIdRaw is int ? docEmpIdRaw : (int.tryParse(docEmpIdRaw?.toString() ?? '') ?? 0);

          // Strict isolation: skip records that explicitly belong to a different employee
          if (targetEmpCode.isNotEmpty && docEmpCode.isNotEmpty && docEmpCode != targetEmpCode) {
            continue;
          }

          final matchesEmp = (targetEmpCode.isNotEmpty && docEmpCode == targetEmpCode) ||
              (docEmpIdNum == employeeId && (docEmpCode.isEmpty || targetEmpCode.isEmpty || docEmpCode == targetEmpCode));
          if (!matchesEmp) continue;
        }
        firestoreRecords.add(AttendanceRecord.fromMap(data));
      }
    } catch (_) {}

    final combinedMap = <String, AttendanceRecord>{};
    for (final r in _localMemoryCache.values) {
      if (employeeId != null) {
        final rCode = r.employeeCode.trim().toUpperCase();
        if (targetEmpCode.isNotEmpty && rCode.isNotEmpty && rCode != targetEmpCode) continue;
        if (r.employeeId != employeeId && !(targetEmpCode.isNotEmpty && rCode == targetEmpCode)) continue;
      }
      final norm = _normalizeDateKey(r.date);
      final key = r.employeeCode.isNotEmpty ? '${r.employeeCode}_$norm' : '${r.employeeId}_$norm';
      combinedMap[key] = r;
    }
    for (final r in firestoreRecords) {
      final norm = _normalizeDateKey(r.date);
      final key = r.employeeCode.isNotEmpty ? '${r.employeeCode}_$norm' : '${r.employeeId}_$norm';
      combinedMap[key] = r;
    }

    var list = combinedMap.values.toList();

    if (monthYear != null && monthYear.isNotEmpty) {
      list = list.where((r) => _matchesMonthYear(r.date, monthYear)).toList();
    }

    if (statusFilter != null && statusFilter.isNotEmpty) {
      list = list.where((r) => _matchesStatus(r.status, statusFilter)).toList();
    }

    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  @override
  Stream<List<AttendanceRecord>> watchAllAttendanceRecords({
    int? employeeId,
    String? monthYear,
    String? statusFilter,
  }) async* {
    // Resolve the employee code once before streaming so we never hardcode IDs
    final String targetEmpCode = employeeId != null ? await _resolveEmpCode(employeeId) : '';

    yield* _recordsRef.snapshots().map((snap) {
      final List<AttendanceRecord> firestoreRecords = [];
      for (final doc in snap.docs) {
        final data = doc.data();
        if (employeeId != null) {
          final docEmpCode = (data['employee_code'] ?? data['employee_id'] ?? '').toString().trim().toUpperCase();
          final docEmpIdRaw = data['employee_id'];
          final docEmpIdNum = docEmpIdRaw is int ? docEmpIdRaw : (int.tryParse(docEmpIdRaw?.toString() ?? '') ?? 0);

          if (targetEmpCode.isNotEmpty && docEmpCode.isNotEmpty && docEmpCode != targetEmpCode) continue;

          final matchesEmp = (targetEmpCode.isNotEmpty && docEmpCode == targetEmpCode) ||
              (docEmpIdNum == employeeId && (docEmpCode.isEmpty || targetEmpCode.isEmpty || docEmpCode == targetEmpCode));
          if (!matchesEmp) continue;
        }
        firestoreRecords.add(AttendanceRecord.fromMap(data));
      }

      final combinedMap = <String, AttendanceRecord>{};
      for (final r in _localMemoryCache.values) {
        if (employeeId != null) {
          final rCode = r.employeeCode.trim().toUpperCase();
          if (targetEmpCode.isNotEmpty && rCode.isNotEmpty && rCode != targetEmpCode) continue;
          if (r.employeeId != employeeId && !(targetEmpCode.isNotEmpty && rCode == targetEmpCode)) continue;
        }
        final norm = _normalizeDateKey(r.date);
        final key = r.employeeCode.isNotEmpty ? '${r.employeeCode}_$norm' : '${r.employeeId}_$norm';
        combinedMap[key] = r;
      }
      for (final r in firestoreRecords) {
        final norm = _normalizeDateKey(r.date);
        final key = r.employeeCode.isNotEmpty ? '${r.employeeCode}_$norm' : '${r.employeeId}_$norm';
        combinedMap[key] = r;
      }

      var list = combinedMap.values.toList();

      if (monthYear != null && monthYear.isNotEmpty) {
        list = list.where((r) => _matchesMonthYear(r.date, monthYear)).toList();
      }

      if (statusFilter != null && statusFilter.isNotEmpty) {
        list = list.where((r) => _matchesStatus(r.status, statusFilter)).toList();
      }

      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  @override
  Future<AttendanceManagementStats> getAttendanceStats({String? date}) async {
    try {
      final now = DateTime.now();
      final defaultDate = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
      final targetDate = _normalizeDateKey(date ?? defaultDate);

      int totalEmployees = 0;
      try {
        final empSnap = await _employeesRef.get();
        totalEmployees = empSnap.docs.length;
      } catch (_) {}

      List<AttendanceRecord> firestoreRecords = [];
      try {
        final recordsSnap = await _recordsRef.get();
        firestoreRecords = recordsSnap.docs.map((d) => AttendanceRecord.fromMap(d.data())).toList();
      } catch (_) {}

      final combinedMap = <String, AttendanceRecord>{};
      for (final r in _localMemoryCache.values) {
        final norm = _normalizeDateKey(r.date);
        if (norm == targetDate) {
          final key = r.employeeCode.isNotEmpty ? '${r.employeeCode}_$norm' : '${r.employeeId}_$norm';
          combinedMap[key] = r;
        }
      }
      for (final r in firestoreRecords) {
        final norm = _normalizeDateKey(r.date);
        if (norm == targetDate) {
          final key = r.employeeCode.isNotEmpty ? '${r.employeeCode}_$norm' : '${r.employeeId}_$norm';
          combinedMap[key] = r;
        }
      }

      final todayRecords = combinedMap.values.toList();

      int present = 0;
      int late = 0;
      int checkedOut = 0;
      double totalHoursSum = 0;
      int hoursCount = 0;

      for (final r in todayRecords) {
        final statusLower = r.status.trim().toLowerCase();
        if (statusLower == 'present') present++;
        if (statusLower == 'late') late++;
        if (statusLower == 'checked out') checkedOut++;
        if (r.totalHours > 0) {
          totalHoursSum += r.totalHours;
          hoursCount++;
        }
      }

      final markedTotal = present + late + checkedOut;
      final absent = (totalEmployees - markedTotal).clamp(0, 9999);
      final avgHours = hoursCount > 0 ? double.parse((totalHoursSum / hoursCount).toStringAsFixed(1)) : 0.0;

      return AttendanceManagementStats(
        totalEmployees: totalEmployees > 0 ? totalEmployees : markedTotal,
        presentToday: present,
        lateToday: late,
        checkedOutToday: checkedOut,
        absentToday: absent,
        onLeaveToday: 0,
        averageWorkHours: avgHours,
      );
    } catch (_) {
      return AttendanceManagementStats.empty();
    }
  }

  @override
  Stream<AttendanceManagementStats> watchAttendanceStats({String? date}) {
    final now = DateTime.now();
    final defaultDate = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
    final targetDate = _normalizeDateKey(date ?? defaultDate);

    return _recordsRef.snapshots().asyncMap((snap) async {
      int totalEmployees = 0;
      try {
        final empSnap = await _employeesRef.get();
        totalEmployees = empSnap.docs.length;
      } catch (_) {}

      final firestoreRecords = snap.docs.map((d) => AttendanceRecord.fromMap(d.data())).toList();

      final combinedMap = <String, AttendanceRecord>{};
      for (final r in _localMemoryCache.values) {
        final norm = _normalizeDateKey(r.date);
        if (norm == targetDate) {
          final key = r.employeeCode.isNotEmpty ? '${r.employeeCode}_$norm' : '${r.employeeId}_$norm';
          combinedMap[key] = r;
        }
      }
      for (final r in firestoreRecords) {
        final norm = _normalizeDateKey(r.date);
        if (norm == targetDate) {
          final key = r.employeeCode.isNotEmpty ? '${r.employeeCode}_$norm' : '${r.employeeId}_$norm';
          combinedMap[key] = r;
        }
      }

      final todayRecords = combinedMap.values.toList();

      int present = 0;
      int late = 0;
      int checkedOut = 0;
      double totalHoursSum = 0;
      int hoursCount = 0;

      for (final r in todayRecords) {
        final statusLower = r.status.trim().toLowerCase();
        if (statusLower == 'present') present++;
        if (statusLower == 'late') late++;
        if (statusLower == 'checked out') checkedOut++;
        if (r.totalHours > 0) {
          totalHoursSum += r.totalHours;
          hoursCount++;
        }
      }

      final markedTotal = present + late + checkedOut;
      final absent = (totalEmployees - markedTotal).clamp(0, 9999);
      final avgHours = hoursCount > 0 ? double.parse((totalHoursSum / hoursCount).toStringAsFixed(1)) : 0.0;

      return AttendanceManagementStats(
        totalEmployees: totalEmployees > 0 ? totalEmployees : markedTotal,
        presentToday: present,
        lateToday: late,
        checkedOutToday: checkedOut,
        absentToday: absent,
        onLeaveToday: 0,
        averageWorkHours: avgHours,
      );
    });
  }

  @override
  Future<void> saveOrOverrideAttendance(AttendanceRecord record) async {
    final cacheKey = record.employeeCode.isNotEmpty
        ? '${record.employeeCode}_${record.date}'
        : '${record.employeeId}_${record.date}';
    _localMemoryCache[cacheKey] = record;
    try {
      final key = record.employeeCode.isNotEmpty ? record.employeeCode : record.employeeId.toString();
      final docId = '${key}_${record.date.replaceAll('-', '')}';

      double totalHours = 0.0;
      if (record.sessions.isNotEmpty) {
        for (final s in record.sessions) {
          if (s.isCompleted) {
            totalHours += s.effectiveDurationHours;
          }
        }
        totalHours = double.parse(totalHours.toStringAsFixed(2));
      }
      if (totalHours == 0.0 && record.totalHours > 0) {
        totalHours = record.totalHours;
      }
      if (totalHours == 0.0 && record.effectiveCheckInTime.isNotEmpty && record.checkOutTime.isNotEmpty) {
        try {
          final inMin = _parseTimeToMinutes(record.effectiveCheckInTime);
          final outMin = _parseTimeToMinutes(record.checkOutTime);
          if (inMin != null && outMin != null && outMin > inMin) {
            totalHours = double.parse(((outMin - inMin) / 60.0).toStringAsFixed(2));
          }
        } catch (_) {}
      }

      String status = record.status;
      if (status == 'Missing Check-Out' && record.checkOutTime.isNotEmpty) {
        status = 'Present';
      }

      final toSave = record.copyWith(
        time: record.effectiveCheckInTime,
        checkInTime: record.effectiveCheckInTime,
        status: status,
        totalHours: totalHours,
        markedAt: record.markedAt.isNotEmpty ? record.markedAt : DateTime.now().toIso8601String(),
      );

      await _recordsRef.doc(docId).set(toSave.toMap(), SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  Future<void> deleteAttendanceRecord(int employeeId, String date) async {
    final normDate = _normalizeDateKey(date);
    final empCode = await _resolveEmpCode(employeeId);

    // Clear memory cache for both key forms
    _localMemoryCache.remove('${employeeId}_$date');
    _localMemoryCache.remove('${employeeId}_$normDate');
    if (empCode.isNotEmpty) {
      _localMemoryCache.remove('${empCode}_$date');
      _localMemoryCache.remove('${empCode}_$normDate');
    }

    try {
      // Delete code-keyed document (e.g. EMPCODE_20260925)
      if (empCode.isNotEmpty) {
        await _recordsRef.doc('${empCode}_${normDate.replaceAll('-', '')}').delete();
        await _recordsRef.doc('${empCode}_${date.replaceAll('-', '')}').delete();
      }

      // Delete integer-keyed document, but ONLY if it belongs to this employee
      // (to avoid accidentally deleting a different employee's legacy doc)
      final intDocId = '${employeeId}_${normDate.replaceAll('-', '')}';
      final intSnap = await _recordsRef.doc(intDocId).get();
      if (intSnap.exists) {
        final docEmpCode = (intSnap.data()?['employee_code'] ?? intSnap.data()?['employee_id'] ?? '').toString().trim().toUpperCase();
        // Only delete if the document's code matches this employee (or doc has no code)
        if (docEmpCode.isEmpty || empCode.isEmpty || docEmpCode == empCode) {
          await _recordsRef.doc(intDocId).delete();
        }
      }
    } catch (_) {}
  }

  @override
  Future<List<Map<String, dynamic>>> getAuditAttempts({int? employeeId, int limit = 100}) async {
    try {
      Query<Map<String, dynamic>> query = _attemptsRef.orderBy('created_at', descending: true).limit(limit);
      if (employeeId != null) {
        query = _attemptsRef.where('employee_id', isEqualTo: employeeId).limit(limit);
      }
      final snap = await query.get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> bulkMarkAttendance({
    required List<int> employeeIds,
    required String date,
    required String status,
    required String checkInTime,
  }) async {
    // Resolve employee codes first so we use code-keyed Firestore docs
    final empCodeMap = <int, String>{};
    for (final empId in employeeIds) {
      empCodeMap[empId] = await _resolveEmpCode(empId);
    }

    for (final empId in employeeIds) {
      final empCode = empCodeMap[empId] ?? '';
      final rec = AttendanceRecord(
        id: empId * 10000 + DateTime.now().millisecondsSinceEpoch % 10000,
        employeeId: empId,
        employeeCode: empCode,
        employeeName: '',
        date: date,
        time: checkInTime,
        checkInTime: checkInTime,
        checkOutTime: '',
        status: status,
        verificationStatus: 'Admin Bulk Mark',
        similarityScore: 1.0,
        markedAt: DateTime.now().toIso8601String(),
      );
      final cacheKey = empCode.isNotEmpty ? '${empCode}_$date' : '${empId}_$date';
      _localMemoryCache[cacheKey] = rec;
    }
    try {
      final batch = _firestore.batch();
      for (final empId in employeeIds) {
        final empCode = empCodeMap[empId] ?? '';
        // Use employee code as doc key (isolated), falling back to integer only if code unknown
        final key = empCode.isNotEmpty ? empCode : empId.toString();
        final docId = '${key}_${date.replaceAll('-', '')}';
        final ref = _recordsRef.doc(docId);
        batch.set(
          ref,
          {
            'employee_id': empId,
            if (empCode.isNotEmpty) 'employee_code': empCode,
            'date': date,
            'time': checkInTime,
            'check_in_time': checkInTime,
            'status': status,
            'verification_status': 'Admin Bulk Mark',
            'similarity_score': 1.0,
            'marked_at': DateTime.now().toIso8601String(),
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    } catch (_) {}
  }

  int? _parseTimeToMinutes(String timeStr) {
    try {
      final clean = timeStr.trim();
      final isPm = clean.toUpperCase().contains('PM');
      final isAm = clean.toUpperCase().contains('AM');
      final rawNumbers = clean.replaceAll(RegExp(r'[^0-9:]'), '').split(':').where((p) => p.trim().isNotEmpty).toList();
      if (rawNumbers.length >= 2) {
        int hour = int.parse(rawNumbers[0]);
        final min = int.parse(rawNumbers[1]);
        if (isPm && hour < 12) hour += 12;
        if (isAm && hour == 12) hour = 0;
        return hour * 60 + min;
      }
    } catch (_) {}
    return null;
  }
}

