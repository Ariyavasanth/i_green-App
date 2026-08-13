import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase_asset_assignment_repository.dart';
import '../domain/asset_assignment.dart';
import '../domain/asset_assignment_repository.dart';
import '../domain/asset_transfer_request.dart';
import '../../leave/providers/leave_providers.dart';
import '../../employee/domain/employee.dart';

// Firestore implementation active.
final assetAssignmentRepositoryProvider = Provider<AssetAssignmentRepository>(
  (ref) => FirebaseAssetAssignmentRepository(),
);

final assetAssignmentsProvider = FutureProvider<List<AssetAssignment>>((ref) async {
  return ref.watch(assetAssignmentRepositoryProvider).getAssignments();
});

final assignmentSearchQueryProvider = StateProvider<String>((ref) => '');
final assignmentEmployeeFilterProvider = StateProvider<int?>((ref) => null);
final assignmentAssetTypeFilterProvider = StateProvider<int?>((ref) => null);
final assignmentDateRangeFilterProvider = StateProvider<DateTimeRange?>((ref) => null);
final assignmentStatusFilterProvider = StateProvider<String?>((ref) => null);

// Selected employee override provider for My Asset page (useful when admin views employee assets)
final myAssetSelectedEmployeeProvider = StateProvider<Employee?>((ref) => null);

final myAssetSearchQueryProvider = StateProvider<String>((ref) => '');
final myAssetStatusFilterProvider = StateProvider<String>((ref) => 'All');

final myAssetAssignmentsProvider = FutureProvider<List<AssetAssignment>>((ref) async {
  final assignments = await ref.watch(assetAssignmentsProvider.future);
  final overrideEmp = ref.watch(myAssetSelectedEmployeeProvider);
  final currentEmp = overrideEmp ?? ref.watch(currentEmployeeProvider);

  if (currentEmp == null) {
    return assignments;
  }

  final empId = currentEmp.id;
  final empCode = currentEmp.employeeId.trim().toLowerCase();
  final empName = currentEmp.fullName.trim().toLowerCase();

  final filtered = assignments.where((a) {
    final matchesId = (empId > 0 && a.employeeId == empId);
    final matchesCode = (empCode.isNotEmpty && a.employeeCode.trim().toLowerCase() == empCode);
    final matchesName = (empName.isNotEmpty && a.employeeName.trim().toLowerCase() == empName);
    return matchesId || matchesCode || matchesName;
  }).toList();

  return filtered.isNotEmpty ? filtered : assignments;
});

final assetTransferRequestsProvider = FutureProvider<List<AssetTransferRequest>>((ref) async {
  return ref.watch(assetAssignmentRepositoryProvider).getTransferRequests();
});

final myIncomingAssetTransferRequestsProvider = FutureProvider<List<AssetTransferRequest>>((ref) async {
  final requests = await ref.watch(assetTransferRequestsProvider.future);
  final employee = ref.watch(myAssetSelectedEmployeeProvider) ?? ref.watch(currentEmployeeProvider);
  if (employee == null) return const [];
  final code = employee.employeeId.trim().toLowerCase();
  final name = employee.fullName.trim().toLowerCase();
  return requests.where((request) {
    return (employee.id > 0 && request.toEmployeeId == employee.id) ||
        (code.isNotEmpty && request.toEmployeeCode.trim().toLowerCase() == code) ||
        (name.isNotEmpty && request.toEmployeeName.trim().toLowerCase() == name);
  }).toList();
});

final assetAllColumnsProvider = Provider<List<String>>((ref) => const [
  'S.No',
  'Emp ID',
  'Assigned To',
  'Asset Name',
  'Asset Type',
  'Serial Number',
  'Assigned Date',
  'Reason / Description',
  'Status',
  'Actions',
]);

final assetVisibleColumnsProvider = StateProvider<List<String>>((ref) => const [
  'S.No',
  'Emp ID',
  'Assigned To',
  'Asset Name',
  'Asset Type',
  'Serial Number',
  'Assigned Date',
  'Reason / Description',
  'Status',
  'Actions',
]);

final assetColumnOrderProvider = StateProvider<List<String>>((ref) => const [
  'S.No',
  'Emp ID',
  'Assigned To',
  'Asset Name',
  'Asset Type',
  'Serial Number',
  'Assigned Date',
  'Reason / Description',
  'Status',
  'Actions',
]);
