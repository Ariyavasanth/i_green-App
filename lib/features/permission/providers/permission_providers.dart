import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase_permission_repository.dart';
import '../data/sqlite_permission_repository.dart';
import '../domain/permission_balance.dart';
import '../domain/permission_enums.dart';
import '../domain/permission_policy.dart';
import '../domain/permission_repository.dart';
import '../domain/permission_request.dart';

/// Swap to FirebasePermissionRepository() to switch to Firebase — no screen changes needed.
final permissionRepositoryProvider = Provider<PermissionRepository>(
  (ref) => SqlitePermissionRepository(),
);

final permissionPolicyProvider = FutureProvider<PermissionPolicy>((ref) {
  return ref.watch(permissionRepositoryProvider).getPermissionPolicy();
});

final employeePermissionBalanceProvider =
    FutureProvider.family<PermissionBalance, int>((ref, employeeId) {
  return ref
      .watch(permissionRepositoryProvider)
      .getPermissionBalance(employeeId, DateTime.now());
});

final myPermissionRequestsProvider =
    FutureProvider.family<List<PermissionRequest>, int>((ref, employeeId) {
  return ref
      .watch(permissionRepositoryProvider)
      .getEmployeeRequests(employeeId);
});

class AllPermissionRequestsFilter {
  final int? employeeId;
  final String? department;
  final PermissionStatus? status;
  final DateTime? startDate;
  final DateTime? endDate;

  const AllPermissionRequestsFilter({
    this.employeeId,
    this.department,
    this.status,
    this.startDate,
    this.endDate,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AllPermissionRequestsFilter &&
          runtimeType == other.runtimeType &&
          employeeId == other.employeeId &&
          department == other.department &&
          status == other.status &&
          startDate == other.startDate &&
          endDate == other.endDate;

  @override
  int get hashCode => Object.hash(
        employeeId,
        department,
        status,
        startDate,
        endDate,
      );
}

final allPermissionRequestsProvider =
    FutureProvider.family<List<PermissionRequest>, AllPermissionRequestsFilter>((ref, filter) {
  return ref.watch(permissionRepositoryProvider).getAllRequests(
        employeeId: filter.employeeId,
        department: filter.department,
        status: filter.status,
        startDate: filter.startDate,
        endDate: filter.endDate,
      );
});

final allEmployeePermissionUsageProvider =
    FutureProvider.family<List<PermissionBalance>, DateTime>((ref, month) {
  return ref.watch(permissionRepositoryProvider).getAllEmployeeUsage(month);
});
