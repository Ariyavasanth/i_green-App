import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/task_item.dart';
import '../domain/task_repository.dart';
import '../data/firebase_task_repository.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return FirebaseTaskRepository();
});

typedef TaskFilter = ({String? assignedTo, String? projectOrOfficeCode, String? status});

final tasksProvider = FutureProvider.family<List<TaskItem>, TaskFilter>((ref, filter) async {
  final repo = ref.watch(taskRepositoryProvider);
  return repo.getTasks(
    assignedTo: filter.assignedTo,
    projectOrOfficeCode: filter.projectOrOfficeCode,
    status: filter.status,
  );
});

final taskProjectHoursProvider = FutureProvider.family<Map<String, double>, String?>((ref, assignedTo) async {
  final repo = ref.watch(taskRepositoryProvider);
  return repo.getHoursByProject(assignedTo: assignedTo);
});

final activeTaskProvider = FutureProvider.family<TaskItem?, String>((ref, employeeId) async {
  if (employeeId.trim().isEmpty) return null;
  final repo = ref.watch(taskRepositoryProvider);
  final tasks = await repo.getTasks(assignedTo: employeeId.trim(), status: 'IN_PROGRESS');
  if (tasks.isNotEmpty) {
    return tasks.first;
  }
  return null;
});
