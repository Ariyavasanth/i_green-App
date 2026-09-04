import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/on_duty_assignment.dart';
import '../domain/on_duty_repository.dart';

/// Firebase Firestore implementation for OnDutyRepository.
class FirebaseOnDutyRepository implements OnDutyRepository {
  FirebaseOnDutyRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('on_duty_assignments');

  @override
  Future<List<OnDutyAssignment>> getAssignmentsForEmployee({
    required int employeeId,
    String? date,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          _collection.where('employee_id', isEqualTo: employeeId);
      if (date != null && date.isNotEmpty) {
        query = query.where('date', isEqualTo: date);
      }
      final snapshot = await query.get();
      final items = snapshot.docs
          .map((doc) => OnDutyAssignment.fromMap({...doc.data(), 'id': int.tryParse(doc.id) ?? doc.data()['id'] ?? 0}))
          .toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<OnDutyAssignment>> getAllAssignments({
    String? date,
    String? statusFilter,
    int? employeeId,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _collection;

      if (date != null && date.isNotEmpty) {
        query = query.where('date', isEqualTo: date);
      }
      if (employeeId != null && employeeId != 0) {
        query = query.where('employee_id', isEqualTo: employeeId);
      }

      final snapshot = await query.get();
      var items = snapshot.docs
          .map((doc) => OnDutyAssignment.fromMap({...doc.data(), 'id': int.tryParse(doc.id) ?? doc.data()['id'] ?? 0}))
          .toList();

      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'All') {
        final filterUpper = statusFilter.toUpperCase();
        items = items.where((item) {
          final s = item.status.toUpperCase();
          if (filterUpper == 'IN_PROGRESS') {
            return s == 'IN_PROGRESS' || s == 'ACTIVE';
          }
          return s == filterUpper;
        }).toList();
      }

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<OnDutyAssignment?> getActiveAssignmentForEmployee(int employeeId) async {
    try {
      final snapshot = await _collection.get();

      final activeItems = snapshot.docs
          .map((doc) => OnDutyAssignment.fromMap({...doc.data(), 'id': int.tryParse(doc.id) ?? doc.data()['id'] ?? 0}))
          .where((item) {
            final s = item.status.toUpperCase();
            final matchesEmp = item.employeeId == employeeId || employeeId == 0;
            return matchesEmp && (s == 'IN_PROGRESS' || s == 'ASSIGNED' || s == 'ACTIVE');
          })
          .toList();

      if (activeItems.isEmpty) return null;

      activeItems.sort((a, b) {
        final rankA = (a.status == 'IN_PROGRESS' || a.status == 'ACTIVE') ? 1 : 2;
        final rankB = (b.status == 'IN_PROGRESS' || b.status == 'ACTIVE') ? 1 : 2;
        if (rankA != rankB) return rankA.compareTo(rankB);
        return b.createdAt.compareTo(a.createdAt);
      });

      return activeItems.first;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<OnDutyAssignment?> getAssignmentById(int id) async {
    try {
      final doc = await _collection.doc(id.toString()).get();
      if (!doc.exists || doc.data() == null) return null;
      return OnDutyAssignment.fromMap({...doc.data()!, 'id': id});
    } catch (_) {
      return null;
    }
  }

  @override
  Future<int> createAssignment(OnDutyAssignment assignment) async {
    try {
      final int newId = DateTime.now().millisecondsSinceEpoch;
      final data = assignment.copyWith(id: newId).toMap();
      await _collection.doc(newId.toString()).set(data);
      return newId;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<void> updateAssignment(OnDutyAssignment assignment) async {
    try {
      await _collection.doc(assignment.id.toString()).set(assignment.toMap(), SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  Future<void> updateAssignmentStatus({
    required int id,
    required String status,
    String? actualStartTime,
    String? actualEndTime,
    double? latitude,
    double? longitude,
    String? photoPath,
    int? durationMinutes,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': status.toUpperCase(),
      };
      if (actualStartTime != null) updates['actual_start_time'] = actualStartTime;
      if (actualEndTime != null) updates['actual_end_time'] = actualEndTime;
      if (status.toUpperCase() == 'IN_PROGRESS') {
        if (latitude != null) updates['start_latitude'] = latitude;
        if (longitude != null) updates['start_longitude'] = longitude;
        if (photoPath != null) updates['start_photo'] = photoPath;
      } else if (status.toUpperCase() == 'COMPLETED') {
        if (latitude != null) updates['end_latitude'] = latitude;
        if (longitude != null) updates['end_longitude'] = longitude;
        if (photoPath != null) updates['end_photo'] = photoPath;
      }
      if (durationMinutes != null) updates['duration_minutes'] = durationMinutes;

      await _collection.doc(id.toString()).set(updates, SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  Future<void> deleteAssignment(int id) async {
    try {
      await _collection.doc(id.toString()).delete();
    } catch (_) {}
  }
}
