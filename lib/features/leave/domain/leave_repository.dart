import 'leave_request.dart';
import 'leave_balance.dart';
import 'leave_type.dart';
import 'salary_calculation.dart';

abstract class LeaveRepository {
  Future<List<LeaveRequest>> getLeaveRequests(int employeeId);
  Future<List<LeaveRequest>> getAllLeaveRequests();
  Future<void> submitLeaveRequest(LeaveRequest request);
  Future<void> approveLeaveRequest(int id, String adminName);
  Future<void> denyLeaveRequest(int id, String adminName);
  Future<List<LeaveRequest>> getLeaveRequestsForCalendar();
  Future<List<LeaveBalance>> getLeaveBalances(int employeeId);
  Future<LeaveBalance> getLeaveBalance(int employeeId, String leaveType);
  Future<List<LeaveType>> getLeaveTypes();
  Future<void> addLeaveType(LeaveType leaveType);
  Future<SalaryCalculation> calculateSalaryAndLop(int employeeId, int year, int month, {int workingDays = 26});
  Future<List<Map<String, dynamic>>> getAuditLogs(int leaveRequestId);
}
