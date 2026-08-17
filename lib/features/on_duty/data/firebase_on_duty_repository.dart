import '../domain/on_duty_assignment.dart';
import '../domain/on_duty_repository.dart';

/// Firebase implementation stub for OnDutyRepository (to be completed when backend is connected).
class FirebaseOnDutyRepository implements OnDutyRepository {
  @override
  Future<List<OnDutyAssignment>> getAssignmentsForEmployee({
    required int employeeId,
    String? date,
  }) async {
    return [];
  }

  @override
  Future<List<OnDutyAssignment>> getAllAssignments({
    String? date,
    String? statusFilter,
    int? employeeId,
  }) async {
    return [];
  }

  @override
  Future<OnDutyAssignment?> getActiveAssignmentForEmployee(int employeeId) async {
    return null;
  }

  @override
  Future<OnDutyAssignment?> getAssignmentById(int id) async {
    return null;
  }

  @override
  Future<int> createAssignment(OnDutyAssignment assignment) async {
    return 0;
  }

  @override
  Future<void> updateAssignment(OnDutyAssignment assignment) async {}

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
  }) async {}

  @override
  Future<void> deleteAssignment(int id) async {}
}
