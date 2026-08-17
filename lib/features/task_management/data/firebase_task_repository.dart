import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/task_item.dart';
import '../domain/task_repository.dart';

class FirebaseTaskRepository implements TaskRepository {
  final FirebaseFirestore _firestore;
  static final List<TaskItem> _fallbackTasks = [
    TaskItem(
      id: '101',
      title: 'Client Website',
      projectOrOfficeCode: 'PRJ-101',
      assignedBy: 'Manager',
      assignedTo: 'EMP-001',
      startTime: DateTime.now(),
      status: 'TODO',
    ),
    TaskItem(
      id: '205',
      title: 'Employee Report',
      projectOrOfficeCode: 'OFF-205',
      assignedBy: 'Manager',
      assignedTo: 'EMP-001',
      startTime: DateTime.now(),
      status: 'TODO',
    ),
  ];

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
    final List<TaskItem> result = [];
    try {
      Query<Map<String, dynamic>> query = _tasksRef;

      if (assignedTo != null && assignedTo.isNotEmpty && assignedTo != 'All') {
        query = query.where('assigned_to', isEqualTo: assignedTo);
      }
      if (projectOrOfficeCode != null && projectOrOfficeCode.isNotEmpty && projectOrOfficeCode != 'All') {
        query = query.where('project_or_office_code', isEqualTo: projectOrOfficeCode);
      }
      if (status != null && status.isNotEmpty && status != 'All') {
        query = query.where('status', isEqualTo: status);
      }

      final snapshot = await query.get();
      final firestoreTasks = snapshot.docs.map((doc) => TaskItem.fromMap(doc.data())).toList();
      result.addAll(firestoreTasks);
    } catch (_) {}

    final fallbackFiltered = _filterFallback(
      assignedTo: assignedTo,
      projectOrOfficeCode: projectOrOfficeCode,
      status: status,
    );

    for (final task in fallbackFiltered) {
      if (!result.any((t) => t.id == task.id)) {
        result.add(task);
      }
    }

    result.sort((a, b) => b.startTime.compareTo(a.startTime));
    return result;
  }

  List<TaskItem> _filterFallback({
    String? assignedTo,
    String? projectOrOfficeCode,
    String? status,
  }) {
    return _fallbackTasks.where((t) {
      if (assignedTo != null && assignedTo.isNotEmpty && assignedTo != 'All' && t.assignedTo != assignedTo) {
        return false;
      }
      if (projectOrOfficeCode != null &&
          projectOrOfficeCode.isNotEmpty &&
          projectOrOfficeCode != 'All' &&
          t.projectOrOfficeCode != projectOrOfficeCode) {
        return false;
      }
      if (status != null && status.isNotEmpty && status != 'All' && t.status != status) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<TaskItem?> getTaskById(String id) async {
    try {
      final doc = await _tasksRef.doc(id).get();
      if (!doc.exists || doc.data() == null) {
        return _fallbackTasks.firstWhere((t) => t.id == id, orElse: () => _fallbackTasks.first);
      }
      return TaskItem.fromMap(doc.data()!);
    } catch (_) {
      final index = _fallbackTasks.indexWhere((t) => t.id == id);
      return index >= 0 ? _fallbackTasks[index] : null;
    }
  }

  @override
  Future<void> createTask(TaskItem task) async {
    try {
      await _tasksRef.doc(task.id).set(task.toMap());
    } catch (_) {}
    _fallbackTasks.removeWhere((t) => t.id == task.id);
    _fallbackTasks.insert(0, task);
  }

  @override
  Future<void> updateTask(TaskItem task) async {
    try {
      await _tasksRef.doc(task.id).update(task.toMap());
    } catch (_) {}
    final index = _fallbackTasks.indexWhere((t) => t.id == task.id);
    if (index >= 0) {
      _fallbackTasks[index] = task;
    } else {
      _fallbackTasks.insert(0, task);
    }
  }

  @override
  Future<void> deleteTask(String id) async {
    try {
      await _tasksRef.doc(id).delete();
    } catch (_) {}
    _fallbackTasks.removeWhere((t) => t.id == id);
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
