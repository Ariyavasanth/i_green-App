import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../incentive/domain/incentive_request.dart';
import '../data/sqlite_incentive_management_repository.dart';
import '../domain/incentive_management_repository.dart';

// Swap SqliteIncentiveManagementRepository() to FirebaseIncentiveManagementRepository() to switch data source
final incentiveManagementRepositoryProvider = Provider<IncentiveManagementRepository>(
  (ref) => SqliteIncentiveManagementRepository(),
);

final allManagementRequestsProvider = FutureProvider<List<IncentiveRequest>>((ref) {
  return ref.watch(incentiveManagementRepositoryProvider).getAllRequests();
});

final incentiveManagementTabProvider = StateProvider<String>((ref) => 'Pending');

final selectedManagementRequestIdProvider = StateProvider<int?>((ref) => null);

final incentiveRequestByIdProvider = FutureProvider.family<IncentiveRequest?, int>((ref, id) async {
  final repo = ref.watch(incentiveManagementRepositoryProvider);
  return repo.getRequestById(id);
});

final incentiveAllColumnsProvider = Provider<List<String>>((ref) => const [
  'Emp ID',
  'Employee',
  'Designation',
  'Site',
  'Amount',
  'Status',
  'Action',
]);

final incentiveVisibleColumnsProvider = StateProvider<List<String>>((ref) => const [
  'Emp ID',
  'Employee',
  'Designation',
  'Site',
  'Amount',
  'Status',
  'Action',
]);

final incentiveColumnOrderProvider = StateProvider<List<String>>((ref) => const [
  'Emp ID',
  'Employee',
  'Designation',
  'Site',
  'Amount',
  'Status',
  'Action',
]);
