import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sqlite_asset_assignment_repository.dart';
import '../data/firebase_asset_assignment_repository.dart';
import '../domain/asset_assignment.dart';
import '../domain/asset_assignment_repository.dart';
import '../../leave/providers/leave_providers.dart';
import '../../employee/domain/employee.dart';

final assetAssignmentRepositoryProvider = Provider<AssetAssignmentRepository>(
  (ref) => SqliteAssetAssignmentRepository(),
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

final assetAllColumnsProvider = Provider<List<String>>((ref) => const [
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
  'Assigned To',
  'Asset Name',
  'Asset Type',
  'Serial Number',
  'Assigned Date',
  'Reason / Description',
  'Status',
  'Actions',
]);
