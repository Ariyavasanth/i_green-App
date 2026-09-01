import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/providers/authentication_providers.dart';
import '../../employee/domain/employee.dart';
import '../../employee/providers/employee_providers.dart';
export '../../employee/providers/employee_providers.dart' show currentEmployeeProvider;
import '../data/firebase_exit_repository.dart';
import '../domain/exit_model.dart';
import '../domain/exit_repository.dart';

// Firestore implementation active.
final exitRepositoryProvider = Provider<ExitRepository>(
  (ref) => FirebaseExitRepository(),
);

final allExitRequestsProvider = FutureProvider<List<ExitRequest>>((ref) async {
  final repo = ref.watch(exitRepositoryProvider);
  return repo.getAllExitRequests();
});

final myExitRequestProvider = FutureProvider<ExitRequest?>((ref) async {
  final emp = ref.watch(currentEmployeeProvider);
  if (emp == null) return null;
  final repo = ref.watch(exitRepositoryProvider);
  return repo.getExitRequestByEmployeeId(emp.employeeId);
});

final exitClearancesProvider = FutureProvider.family<List<DepartmentClearance>, int>(
  (ref, exitRequestId) async {
    final repo = ref.watch(exitRepositoryProvider);
    return repo.getClearancesForExit(exitRequestId);
  },
);

final exitInterviewProvider = FutureProvider.family<ExitInterview?, int>(
  (ref, exitRequestId) async {
    final repo = ref.watch(exitRepositoryProvider);
    return repo.getExitInterview(exitRequestId);
  },
);

final exitSettlementProvider = FutureProvider.family<ExitSettlement?, int>(
  (ref, exitRequestId) async {
    final repo = ref.watch(exitRepositoryProvider);
    return repo.getExitSettlement(exitRequestId);
  },
);
