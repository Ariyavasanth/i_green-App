import 'task_item.dart';

abstract class TaskRepository {
  Future<List<TaskItem>> getTasks({
    String? assignedTo,
    String? projectOrOfficeCode,
    String? status,
  });

  Future<TaskItem?> getTaskById(String id);

  Future<void> createTask(TaskItem task);

  Future<void> updateTask(TaskItem task);

  Future<void> deleteTask(String id);

  Future<Map<String, double>> getHoursByProject({String? assignedTo});
}
