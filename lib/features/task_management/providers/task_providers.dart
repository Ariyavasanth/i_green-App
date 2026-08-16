import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/task_item.dart';
import '../domain/task_repository.dart';
import '../data/firebase_task_repository.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return FirebaseTaskRepository();
  // To switch back to SQLite: return SqliteTaskRepository();
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
