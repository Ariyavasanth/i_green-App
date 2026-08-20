import '../domain/permission_balance.dart';
import '../domain/permission_enums.dart';
import '../domain/permission_policy.dart';
import '../domain/permission_repository.dart';
import '../domain/permission_request.dart';

/// Empty Firebase stub for PermissionRepository.
/// Fill in Firestore / Firebase calls when switching from SQLite.
class FirebasePermissionRepository implements PermissionRepository {
  @override
  Future<PermissionPolicy> getPermissionPolicy() async {
    return const PermissionPolicy();
  }

  @override
  Future<void> updatePermissionPolicy(PermissionPolicy policy) async {}

  @override
  Future<PermissionBalance> getPermissionBalance(int employeeId, DateTime date) async {
    return PermissionBalance(
      employeeId: employeeId,
      month: date,
      monthlyLimitMinutes: 180,
      monthlyUsedMinutes: 0,
      todayLimitMinutes: 60,
      todayUsedMinutes: 0,
    );
  }

  @override
  Future<List<PermissionRequest>> getEmployeeRequests(int employeeId) async {
    return [];
  }

  @override
  Future<PermissionRequest?> getRequestById(int id) async {
    return null;
  }

  @override
  Future<void> submitRequest(PermissionRequest request) async {}

  @override
  Future<void> submitEmergencyRequest(PermissionRequest request) async {}

  @override
  Future<void> cancelRequest(int id, String cancelledBy) async {}

  @override
  Future<List<PermissionRequest>> getAllRequests({
    int? employeeId,
    String? department,
    PermissionStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return [];
  }

  @override
  Future<void> approveNormalRequest(int id, String adminName, {String? comment}) async {}

  @override
  Future<void> rejectRequest(int id, String adminName, String reason) async {}

  @override
  Future<void> reviewEmergencyRequest(
    int id,
    String adminName, {
    required PayrollTreatment decision,
    String? comment,
  }) async {}

  @override
  Future<List<PermissionBalance>> getAllEmployeeUsage(DateTime month) async {
    return [];
  }
}
