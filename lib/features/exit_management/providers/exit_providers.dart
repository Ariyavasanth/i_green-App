import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/providers/authentication_providers.dart';
import '../../employee/domain/employee.dart';
import '../../employee/providers/employee_providers.dart';
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

final currentEmployeeProvider = Provider<Employee?>((ref) {
  final emailOrId = ref.watch(currentUserEmailProvider);
  final employeesAsync = ref.watch(employeesProvider);
  return employeesAsync.maybeWhen(
    data: (list) {
      if (list.isEmpty) return null;
      if (emailOrId != null && emailOrId.trim().isNotEmpty) {
        final matches = list.where((e) {
          final target = emailOrId.trim().toLowerCase();
          return e.emailAddress.trim().toLowerCase() == target ||
              e.employeeId.trim().toLowerCase() == target;
        }).toList();
        if (matches.isNotEmpty) return matches.first;
      }
      return list.firstWhere(
        (e) =>
            e.userType.toUpperCase() == 'SUPER_ADMIN' ||
            e.userType.toUpperCase() == 'SUPER ADMIN' ||
            e.userType.toUpperCase() == 'ADMIN',
        orElse: () => list.first,
      );
    },
    orElse: () => null,
  );
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
