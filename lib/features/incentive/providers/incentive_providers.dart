import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/sqlite_incentive_repository.dart';
import '../domain/incentive_repository.dart';
import '../domain/incentive_request.dart';

// Swap SqliteIncentiveRepository() to FirebaseIncentiveRepository() to switch data source
final incentiveRepositoryProvider = Provider<IncentiveRepository>(
  (ref) => SqliteIncentiveRepository(),
);

final allIncentiveRequestsProvider = FutureProvider<List<IncentiveRequest>>((ref) {
  return ref.watch(incentiveRepositoryProvider).getAllRequests();
});

final employeeIncentiveRequestsProvider = FutureProvider.family<List<IncentiveRequest>, String>((ref, employeeName) {
  return ref.watch(incentiveRepositoryProvider).getRequestsByEmployeeName(employeeName);
});

final employeeDesignationProvider = StateProvider<String>((ref) => 'Operator');
