import '../domain/leave_request.dart';
import '../domain/leave_repository.dart';

/// Firebase stub for LeaveRepository.
/// Fill in when switching to Firebase — no screen files need to change.
class FirebaseLeaveRepository implements LeaveRepository {
  @override
  Future<List<LeaveRequest>> getLeaveRequests(int employeeId) {
    throw UnimplementedError('Firebase leave repository not yet implemented');
  }

  @override
  Future<void> submitLeaveRequest(LeaveRequest request) {
    throw UnimplementedError('Firebase leave repository not yet implemented');
  }

  @override
  Future<void> updateLeaveRequestStatus(int id, String status) {
    throw UnimplementedError('Firebase leave repository not yet implemented');
  }
}
