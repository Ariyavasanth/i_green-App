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
