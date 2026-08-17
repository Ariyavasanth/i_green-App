import 'package:cloud_firestore/cloud_firestore.dart';
import '../../attendance/domain/attendance_record.dart';
import '../domain/attendance_management_repository.dart';
import '../domain/attendance_management_stats.dart';

class FirebaseAttendanceManagementRepository implements AttendanceManagementRepository {
  final FirebaseFirestore? _customFirestore;

  FirebaseAttendanceManagementRepository({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _recordsRef =>
      _firestore.collection('attendance_records');
  CollectionReference<Map<String, dynamic>> get _attemptsRef =>
      _firestore.collection('attendance_attempts');
  CollectionReference<Map<String, dynamic>> get _employeesRef =>
      _firestore.collection('employees');

  @override
  Future<List<AttendanceRecord>> getAllAttendanceRecords({
    int? employeeId,
    String? monthYear,
    String? statusFilter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _recordsRef;

      if (employeeId != null) {
        query = query.where('employee_id', isEqualTo: employeeId);
      }

      final snap = await query.get();
      var list = snap.docs.map((d) => AttendanceRecord.fromMap(d.data())).toList();

      // In-memory filter for monthYear (MM-yyyy) or date range if provided
      if (monthYear != null && monthYear.isNotEmpty) {
        list = list.where((r) {
          if (r.date.length >= 10) {
            final parts = r.date.split('-');
            if (parts.length == 3) {
              final recordMonthYear = '${parts[1]}-${parts[2]}';
              return recordMonthYear == monthYear;
            }
          }
          return true;
        }).toList();
      }

      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'All') {
        list = list.where((r) => r.status == statusFilter).toList();
      }

      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<AttendanceManagementStats> getAttendanceStats({String? date}) async {
    try {
      final targetDate = date ??
          '${DateTime.now().day.toString().padLeft(2, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().year}';

      final empSnap = await _employeesRef.get();
      final totalEmployees = empSnap.docs.length;

      final recordsSnap = await _recordsRef.where('date', isEqualTo: targetDate).get();
      final todayRecords = recordsSnap.docs.map((d) => AttendanceRecord.fromMap(d.data())).toList();

      int present = 0;
      int late = 0;
      int checkedOut = 0;
      double totalHoursSum = 0;
      int hoursCount = 0;

      for (final r in todayRecords) {
        if (r.status == 'Present') present++;
        if (r.status == 'Late') late++;
        if (r.status == 'Checked Out') checkedOut++;
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
      return const AttendanceManagementStats(
        totalEmployees: 0,
        presentToday: 0,
        lateToday: 0,
        checkedOutToday: 0,
        absentToday: 0,
        onLeaveToday: 0,
        averageWorkHours: 0,
      );
    }
  }

  @override
  Future<void> saveOrOverrideAttendance(AttendanceRecord record) async {
    final docId = '${record.employeeId}_${record.date.replaceAll('-', '')}';

    double totalHours = record.totalHours;
    if (record.effectiveCheckInTime.isNotEmpty && record.checkOutTime.isNotEmpty) {
      try {
        final inParts = record.effectiveCheckInTime.split(':');
        final outParts = record.checkOutTime.split(':');
        if (inParts.length >= 2 && outParts.length >= 2) {
          final inMin = int.parse(inParts[0]) * 60 + int.parse(inParts[1]);
          final outMin = int.parse(outParts[0]) * 60 + int.parse(outParts[1]);
          if (outMin > inMin) {
            totalHours = double.parse(((outMin - inMin) / 60.0).toStringAsFixed(2));
          }
        }
      } catch (_) {}
    }

    final toSave = record.copyWith(
      time: record.effectiveCheckInTime,
      checkInTime: record.effectiveCheckInTime,
      totalHours: totalHours,
      markedAt: record.markedAt.isNotEmpty ? record.markedAt : DateTime.now().toIso8601String(),
    );

    await _recordsRef.doc(docId).set(toSave.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteAttendanceRecord(int employeeId, String date) async {
    final docId = '${employeeId}_${date.replaceAll('-', '')}';
    await _recordsRef.doc(docId).delete();
  }

  @override
  Future<List<Map<String, dynamic>>> getAuditAttempts({int? employeeId, int limit = 100}) async {
    Query<Map<String, dynamic>> query = _attemptsRef.orderBy('created_at', descending: true).limit(limit);

    if (employeeId != null) {
      query = _attemptsRef.where('employee_id', isEqualTo: employeeId).limit(limit);
    }

    final snap = await query.get();
    return snap.docs.map((d) => d.data()).toList();
  }

  @override
  Future<void> bulkMarkAttendance({
    required List<int> employeeIds,
    required String date,
    required String status,
    required String checkInTime,
  }) async {
    final batch = _firestore.batch();
    for (final empId in employeeIds) {
      final docId = '${empId}_${date.replaceAll('-', '')}';
      final ref = _recordsRef.doc(docId);
      batch.set(
        ref,
        {
          'employee_id': empId,
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
  }
}
