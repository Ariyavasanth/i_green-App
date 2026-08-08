import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase_asset_assignment_repository.dart';
import '../domain/asset_assignment.dart';
import '../domain/asset_assignment_repository.dart';

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
