import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/task_item.dart';
import '../domain/task_repository.dart';
import '../data/sqlite_task_repository.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return SqliteTaskRepository();
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
  final repo = ref.watch(taskRepositoryProvider);
  final empId = employeeId == 'EMP-0001' ? 'EMP-001' : employeeId;
  final tasks = await repo.getTasks(assignedTo: empId, status: 'IN_PROGRESS');
  if (tasks.isNotEmpty) {
    return tasks.first;
  }
  if (empId == 'EMP-001') {
    final tasksAlt = await repo.getTasks(assignedTo: 'EMP-0001', status: 'IN_PROGRESS');
    if (tasksAlt.isNotEmpty) return tasksAlt.first;
  }
  return null;
});
