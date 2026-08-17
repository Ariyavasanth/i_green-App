import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase_on_duty_repository.dart';
import '../domain/on_duty_assignment.dart';
import '../domain/on_duty_repository.dart';

final onDutyRepositoryProvider = Provider<OnDutyRepository>((ref) {
  return FirebaseOnDutyRepository();
});

final activeOnDutyAssignmentProvider =
    FutureProvider.family<OnDutyAssignment?, int>((ref, employeeId) async {
  final repository = ref.watch(onDutyRepositoryProvider);
  return repository.getActiveAssignmentForEmployee(employeeId);
});

final employeeOnDutyAssignmentsProvider = FutureProvider.family<
    List<OnDutyAssignment>,
    ({int employeeId, String? date})>((ref, arg) async {
  final repository = ref.watch(onDutyRepositoryProvider);
  return repository.getAssignmentsForEmployee(
    employeeId: arg.employeeId,
    date: arg.date,
  );
});

final allOnDutyAssignmentsProvider = FutureProvider.family<
    List<OnDutyAssignment>,
    ({String? date, String? statusFilter, int? employeeId})>((ref, arg) async {
  final repository = ref.watch(onDutyRepositoryProvider);
  return repository.getAllAssignments(
    date: arg.date,
    statusFilter: arg.statusFilter,
    employeeId: arg.employeeId,
  );
});

// Company Pre-set Sites list provider
final companySitesProvider = Provider<List<String>>((ref) {
  return [
    'Tambaram Site',
    'Perambur Site',
    'Avadi Site',
    'Guindy Site',
    'Chennai Office',
    'Warehouse',
    'Other Location',
  ];
});
