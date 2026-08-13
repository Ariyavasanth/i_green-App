import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../incentive/domain/incentive_request.dart';
import '../data/firebase_incentive_management_repository.dart';
import '../domain/incentive_management_repository.dart';

// Firestore implementation active. Both sides use incentive_requests.
final incentiveManagementRepositoryProvider = Provider<IncentiveManagementRepository>(
  (ref) => FirebaseIncentiveManagementRepository(),
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

final employeeRequestsProvider = FutureProvider.family<List<IncentiveRequest>, ({int? employeeId, String employeeName})>((ref, args) async {
  // Watch allManagementRequestsProvider so updates automatically invalidate/refresh
  ref.watch(allManagementRequestsProvider);
  final repo = ref.watch(incentiveManagementRepositoryProvider);
  return repo.getRequestsByEmployee(args.employeeId, args.employeeName);
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
