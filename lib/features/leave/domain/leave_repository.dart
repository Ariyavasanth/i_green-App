import 'leave_request.dart';

abstract class LeaveRepository {
  Future<List<LeaveRequest>> getLeaveRequests(int employeeId);
  Future<void> submitLeaveRequest(LeaveRequest request);
  Future<void> updateLeaveRequestStatus(int id, String status);
}
