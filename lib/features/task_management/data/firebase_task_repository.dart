import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/task_item.dart';
import '../domain/task_repository.dart';

class FirebaseTaskRepository implements TaskRepository {
  final FirebaseFirestore _firestore;

  FirebaseTaskRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _tasksRef =>
      _firestore.collection('tasks');

  @override
  Future<List<TaskItem>> getTasks({
    String? assignedTo,
    String? projectOrOfficeCode,
    String? status,
  }) async {
    Query<Map<String, dynamic>> query = _tasksRef;

    if (assignedTo != null && assignedTo.isNotEmpty) {
      query = query.where('assigned_to', isEqualTo: assignedTo);
    }
    if (projectOrOfficeCode != null && projectOrOfficeCode.isNotEmpty && projectOrOfficeCode != 'All') {
      query = query.where('project_or_office_code', isEqualTo: projectOrOfficeCode);
    }
    if (status != null && status.isNotEmpty && status != 'All') {
      query = query.where('status', isEqualTo: status);
    }

    final snapshot = await query.get();
    final tasks = snapshot.docs.map((doc) => TaskItem.fromMap(doc.data())).toList();
    tasks.sort((a, b) => b.startTime.compareTo(a.startTime));
    return tasks;
  }

  @override
  Future<TaskItem?> getTaskById(String id) async {
    final doc = await _tasksRef.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return TaskItem.fromMap(doc.data()!);
  }

  @override
  Future<void> createTask(TaskItem task) async {
    await _tasksRef.doc(task.id).set(task.toMap());
  }

  @override
  Future<void> updateTask(TaskItem task) async {
    await _tasksRef.doc(task.id).update(task.toMap());
  }

  @override
  Future<void> deleteTask(String id) async {
    await _tasksRef.doc(id).delete();
  }

  @override
  Future<Map<String, double>> getHoursByProject({String? assignedTo}) async {
    final tasks = await getTasks(assignedTo: assignedTo);
    final Map<String, double> result = {};
    for (final task in tasks) {
      final code = task.projectOrOfficeCode;
      result[code] = (result[code] ?? 0.0) + task.durationInHours;
    }
    return result;
  }
}
