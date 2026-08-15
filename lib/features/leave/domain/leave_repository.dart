import 'leave_request.dart';
import 'leave_balance.dart';
import 'leave_type.dart';
import 'salary_calculation.dart';
import 'permission_allowance.dart';

abstract class LeaveRepository {
  Future<List<LeaveRequest>> getLeaveRequests(int employeeId);
  Future<List<LeaveRequest>> getAllLeaveRequests();
  Future<void> submitLeaveRequest(LeaveRequest request);
  Future<void> updateLeaveRequest(LeaveRequest request);
  Future<void> approveLeaveRequest(
    int id,
    String adminName, {
    String approvalMode = 'as_calculated', // 'as_calculated', 'all_paid', 'all_lop'
    String? overrideReason,
  });
  Future<void> denyLeaveRequest(int id, String adminName);
  Future<void> cancelLeaveRequest(int id, String employeeName);
  Future<List<LeaveRequest>> getLeaveRequestsForCalendar();
  Future<List<LeaveBalance>> getLeaveBalances(int employeeId);
  Future<LeaveBalance> getLeaveBalance(int employeeId, String leaveType);
  Future<List<LeaveType>> getLeaveTypes();
  Future<void> addLeaveType(LeaveType leaveType);
  Future<void> updateLeaveType(LeaveType leaveType);
  Future<void> deleteLeaveType(int id);
  Future<List<Map<String, dynamic>>> getEmployeeOverrides();
  Future<void> addEmployeeOverride(Map<String, dynamic> override);
  Future<void> deleteEmployeeOverride(int id);
  Future<SalaryCalculation> calculateSalaryAndLop(int employeeId, int year, int month, {int workingDays = 26});
  Future<List<Map<String, dynamic>>> getAuditLogs(int leaveRequestId);
  Future<PermissionAllowance> getPermissionAllowance(int employeeId, DateTime month);
}
