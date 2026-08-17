import 'on_duty_assignment.dart';

abstract class OnDutyRepository {
  Future<List<OnDutyAssignment>> getAssignmentsForEmployee({
    required int employeeId,
    String? date,
  });

  Future<List<OnDutyAssignment>> getAllAssignments({
    String? date,
    String? statusFilter,
    int? employeeId,
  });

  Future<OnDutyAssignment?> getActiveAssignmentForEmployee(int employeeId);

  Future<OnDutyAssignment?> getAssignmentById(int id);

  Future<int> createAssignment(OnDutyAssignment assignment);

  Future<void> updateAssignment(OnDutyAssignment assignment);

  Future<void> updateAssignmentStatus({
    required int id,
    required String status,
    String? actualStartTime,
    String? actualEndTime,
    double? latitude,
    double? longitude,
    String? photoPath,
    int? durationMinutes,
  });

  Future<void> deleteAssignment(int id);
}
