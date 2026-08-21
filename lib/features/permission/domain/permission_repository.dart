import 'permission_balance.dart';
import 'permission_enums.dart';
import 'permission_policy.dart';
import 'permission_request.dart';

abstract class PermissionRepository {
  // Policy & Settings
  Future<PermissionPolicy> getPermissionPolicy();
  Future<void> updatePermissionPolicy(PermissionPolicy policy);

  // Employee Operations
  Future<PermissionBalance> getPermissionBalance(int employeeId, DateTime date);
  Future<List<PermissionRequest>> getEmployeeRequests(int employeeId);
  Future<PermissionRequest?> getRequestById(int id);
  Future<void> submitRequest(PermissionRequest request);
  Future<void> submitEmergencyRequest(PermissionRequest request);
  Future<void> cancelRequest(int id, String cancelledBy);

  // Admin / Manager Operations
  Future<List<PermissionRequest>> getAllRequests({
    int? employeeId,
    String? department,
    PermissionStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  });
  Future<void> approveNormalRequest(int id, String adminName, {String? comment});
  Future<void> rejectRequest(int id, String adminName, String reason);
  Future<void> reviewEmergencyRequest(
    int id,
    String adminName, {
    required PayrollTreatment decision,
    String? comment,
  });

  // Reporting & Usage
  Future<List<PermissionBalance>> getAllEmployeeUsage(DateTime month);
  Future<void> clearAllRequests();
}
