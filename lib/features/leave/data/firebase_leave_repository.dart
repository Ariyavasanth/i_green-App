import '../domain/leave_request.dart';
import '../domain/leave_repository.dart';
import '../domain/leave_balance.dart';
import '../domain/leave_type.dart';
import '../domain/salary_calculation.dart';

/// Firebase stub for LeaveRepository.
/// Fill in when switching to Firebase — no screen files need to change.
class FirebaseLeaveRepository implements LeaveRepository {
  @override
  Future<List<LeaveRequest>> getLeaveRequests(int employeeId) {
    throw UnimplementedError('Firebase leave repository not yet implemented');
  }

  @override
  Future<List<LeaveRequest>> getAllLeaveRequests() {
    throw UnimplementedError('Firebase leave repository not yet implemented');
  }

  @override
  Future<void> submitLeaveRequest(LeaveRequest request) {
    throw UnimplementedError('Firebase leave repository not yet implemented');
  }

  @override
  Future<void> approveLeaveRequest(int id, String adminName) {
    throw UnimplementedError('Firebase leave repository not yet implemented');
  }

  @override
  Future<void> denyLeaveRequest(int id, String adminName) {
    throw UnimplementedError('Firebase leave repository not yet implemented');
  }

  @override
  Future<List<LeaveRequest>> getLeaveRequestsForCalendar() {
    throw UnimplementedError('Firebase leave repository not yet implemented');
  }

  @override
  Future<List<LeaveBalance>> getLeaveBalances(int employeeId) {
    throw UnimplementedError('Firebase leave repository not yet implemented');
  }

  @override
  Future<LeaveBalance> getLeaveBalance(int employeeId, String leaveType) {
    throw UnimplementedError('Firebase leave repository not yet implemented');
  }

  @override
  Future<List<LeaveType>> getLeaveTypes() {
    throw UnimplementedError('Firebase leave repository not yet implemented');
  }

  @override
  Future<void> addLeaveType(LeaveType leaveType) {
    throw UnimplementedError('Firebase leave repository not yet implemented');
  }

  @override
  Future<SalaryCalculation> calculateSalaryAndLop(int employeeId, int year, int month, {int workingDays = 26}) {
    throw UnimplementedError('Firebase leave repository not yet implemented');
  }

  @override
  Future<List<Map<String, dynamic>>> getAuditLogs(int leaveRequestId) {
    throw UnimplementedError('Firebase leave repository not yet implemented');
  }
}
