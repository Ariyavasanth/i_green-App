import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/permission_balance.dart';
import '../domain/permission_enums.dart';
import '../domain/permission_policy.dart';
import '../domain/permission_repository.dart';
import '../domain/permission_request.dart';
import 'sqlite_permission_repository.dart';

/// Full Firebase implementation for PermissionRepository with SQLite fallback.
class FirebasePermissionRepository implements PermissionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SqlitePermissionRepository _sqliteRepo = SqlitePermissionRepository();

  CollectionReference<Map<String, dynamic>> get _requestsRef =>
      _firestore.collection('permission_requests');

  CollectionReference<Map<String, dynamic>> get _settingsRef =>
      _firestore.collection('permission_settings');

  @override
  Future<PermissionPolicy> getPermissionPolicy() async {
    try {
      final doc = await _settingsRef.doc('policy').get();
      if (doc.exists && doc.data() != null) {
        return PermissionPolicy.fromMap(doc.data()!);
      }
    } catch (_) {}
    return _sqliteRepo.getPermissionPolicy();
  }

  @override
  Future<void> updatePermissionPolicy(PermissionPolicy policy) async {
    try {
      await _settingsRef.doc('policy').set(policy.toMap(), SetOptions(merge: true));
    } catch (_) {}
    await _sqliteRepo.updatePermissionPolicy(policy);
  }

  @override
  Future<PermissionBalance> getPermissionBalance(int employeeId, DateTime date) async {
    final policy = await getPermissionPolicy();
    final all = await getEmployeeRequests(employeeId);
    
    final targetMonthYear = '${date.year}-${date.month.toString().padLeft(2, '0')}';
    final targetDateStr = date.toIso8601String().split('T').first;

    int todayUsed = 0;
    int monthUsed = 0;

    for (final req in all) {
      if (req.status == PermissionStatus.rejected || req.status == PermissionStatus.cancelled) {
        continue;
      }
      final reqDateStr = req.date.toIso8601String().split('T').first;
      final reqMonthYear = '${req.date.year}-${req.date.month.toString().padLeft(2, '0')}';

      if (reqMonthYear == targetMonthYear) {
        monthUsed += req.durationMinutes;
      }
      if (reqDateStr == targetDateStr) {
        todayUsed += req.durationMinutes;
      }
    }

    final dailyLimitMins = (policy.dailyLimitHours * 60).round();
    final monthlyLimitMins = (policy.monthlyLimitHours * 60).round();

    return PermissionBalance(
      employeeId: employeeId,
      month: date,
      monthlyLimitMinutes: monthlyLimitMins,
      monthlyUsedMinutes: monthUsed,
      todayLimitMinutes: dailyLimitMins,
      todayUsedMinutes: todayUsed,
    );
  }

  @override
  Future<List<PermissionRequest>> getEmployeeRequests(int employeeId) async {
    try {
      final snapshot = await _requestsRef.get();
      final list = <PermissionRequest>[];
      for (final doc in snapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        if (data['id'] == null) {
          final parsedId = int.tryParse(doc.id.replaceAll(RegExp(r'\D'), ''));
          data['id'] = parsedId ?? (doc.id.hashCode & 0x7FFFFFFF);
        }
        final req = PermissionRequest.fromMap(data);
        final docEmpIdRaw = data['employee_id'];
        final docEmpIdNum = docEmpIdRaw is int
            ? docEmpIdRaw
            : (int.tryParse(docEmpIdRaw?.toString() ?? '') ?? 0);

        final isMatch = employeeId == 0 ||
            req.employeeId == employeeId ||
            docEmpIdNum == employeeId ||
            (employeeId == 1 && (req.employeeId == 0 || req.employeeId == 1));

        if (isMatch) {
          list.add(req);
        }
      }
      list.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      return list;
    } catch (_) {
      return _sqliteRepo.getEmployeeRequests(employeeId);
    }
  }

  @override
  Future<PermissionRequest?> getRequestById(int id) async {
    try {
      final doc = await _requestsRef.doc(id.toString()).get();
      if (doc.exists && doc.data() != null) {
        return PermissionRequest.fromMap(doc.data()!);
      }
      final query = await _requestsRef.where('id', isEqualTo: id).limit(1).get();
      if (query.docs.isNotEmpty) {
        return PermissionRequest.fromMap(query.docs.first.data());
      }
    } catch (_) {}
    return _sqliteRepo.getRequestById(id);
  }

  @override
  Future<void> submitRequest(PermissionRequest request) async {
    final newId = request.id ?? DateTime.now().millisecondsSinceEpoch;
    final reqWithId = request.copyWith(id: newId);
    try {
      await _requestsRef.doc(newId.toString()).set(reqWithId.toMap(), SetOptions(merge: true));
    } catch (_) {}
    await _sqliteRepo.submitRequest(reqWithId);
  }

  @override
  Future<void> submitEmergencyRequest(PermissionRequest request) async {
    final newId = request.id ?? DateTime.now().millisecondsSinceEpoch;
    final reqWithId = request.copyWith(id: newId, isEmergency: true);
    try {
      await _requestsRef.doc(newId.toString()).set(reqWithId.toMap(), SetOptions(merge: true));
    } catch (_) {}
    await _sqliteRepo.submitEmergencyRequest(reqWithId);
  }

  @override
  Future<void> cancelRequest(int id, String cancelledBy) async {
    try {
      await _requestsRef.doc(id.toString()).set({
        'status': PermissionStatus.cancelled.name,
        'reviewed_by': cancelledBy,
        'reviewed_at': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (_) {}
    await _sqliteRepo.cancelRequest(id, cancelledBy);
  }

  @override
  Future<List<PermissionRequest>> getAllRequests({
    int? employeeId,
    String? department,
    PermissionStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final snapshot = await _requestsRef.get();
      var list = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        if (data['id'] == null) {
          final parsedId = int.tryParse(doc.id.replaceAll(RegExp(r'\D'), ''));
          data['id'] = parsedId ?? (doc.id.hashCode & 0x7FFFFFFF);
        }
        return PermissionRequest.fromMap(data);
      }).toList();

      if (employeeId != null) {
        list = list.where((r) => r.employeeId == employeeId).toList();
      }
      if (department != null && department.isNotEmpty && department != 'All Departments') {
        list = list.where((r) => r.department == department).toList();
      }
      if (status != null) {
        list = list.where((r) => r.status == status).toList();
      }
      if (startDate != null) {
        list = list.where((r) => r.date.isAfter(startDate.subtract(const Duration(days: 1)))).toList();
      }
      if (endDate != null) {
        list = list.where((r) => r.date.isBefore(endDate.add(const Duration(days: 1)))).toList();
      }

      list.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      return list;
    } catch (_) {
      return _sqliteRepo.getAllRequests(
        employeeId: employeeId,
        department: department,
        status: status,
        startDate: startDate,
        endDate: endDate,
      );
    }
  }

  @override
  Future<void> approveNormalRequest(int id, String adminName, {String? comment}) async {
    try {
      await _requestsRef.doc(id.toString()).set({
        'status': PermissionStatus.approved.name,
        'reviewed_by': adminName,
        'reviewed_at': DateTime.now().toIso8601String(),
        if (comment != null) 'admin_comment': comment,
      }, SetOptions(merge: true));
    } catch (_) {}
    await _sqliteRepo.approveNormalRequest(id, adminName, comment: comment);
  }

  @override
  Future<void> rejectRequest(int id, String adminName, String reason) async {
    try {
      await _requestsRef.doc(id.toString()).set({
        'status': PermissionStatus.rejected.name,
        'reviewed_by': adminName,
        'reviewed_at': DateTime.now().toIso8601String(),
        'admin_comment': reason,
      }, SetOptions(merge: true));
    } catch (_) {}
    await _sqliteRepo.rejectRequest(id, adminName, reason);
  }

  @override
  Future<void> reviewEmergencyRequest(
    int id,
    String adminName, {
    required PayrollTreatment decision,
    String? comment,
  }) async {
    final statusStr = (decision == PayrollTreatment.paid || decision == PayrollTreatment.lop)
        ? PermissionStatus.approved.name
        : PermissionStatus.rejected.name;

    try {
      await _requestsRef.doc(id.toString()).set({
        'status': statusStr,
        'payroll_treatment': decision.name,
        'reviewed_by': adminName,
        'reviewed_at': DateTime.now().toIso8601String(),
        if (comment != null) 'admin_comment': comment,
      }, SetOptions(merge: true));
    } catch (_) {}
    await _sqliteRepo.reviewEmergencyRequest(
      id,
      adminName,
      decision: decision,
      comment: comment,
    );
  }

  @override
  Future<List<PermissionBalance>> getAllEmployeeUsage(DateTime month) async {
    final allRequests = await getAllRequests();
    final targetMonthYear = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final policy = await getPermissionPolicy();

    final empUsedMap = <int, int>{};
    for (final req in allRequests) {
      if (req.status == PermissionStatus.rejected || req.status == PermissionStatus.cancelled) {
        continue;
      }
      final reqMonthYear = '${req.date.year}-${req.date.month.toString().padLeft(2, '0')}';
      if (reqMonthYear == targetMonthYear) {
        empUsedMap[req.employeeId] = (empUsedMap[req.employeeId] ?? 0) + req.durationMinutes;
      }
    }

    final dailyLimitMins = (policy.dailyLimitHours * 60).round();
    final monthlyLimitMins = (policy.monthlyLimitHours * 60).round();

    return empUsedMap.entries.map((e) {
      return PermissionBalance(
        employeeId: e.key,
        month: month,
        monthlyLimitMinutes: monthlyLimitMins,
        monthlyUsedMinutes: e.value,
        todayLimitMinutes: dailyLimitMins,
        todayUsedMinutes: 0,
      );
    }).toList();
  }

  @override
  Future<void> clearAllRequests() async {
    try {
      final snap = await _requestsRef.get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}
    await _sqliteRepo.clearAllRequests();
  }
}
