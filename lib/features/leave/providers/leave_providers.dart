import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/providers/authentication_providers.dart';
import '../../employee/domain/employee.dart';
import '../../employee/providers/employee_providers.dart';
export '../../employee/providers/employee_providers.dart' show currentEmployeeProvider;
import '../data/firebase_leave_repository.dart';
import '../domain/leave_repository.dart';
import '../domain/leave_request.dart';
import '../domain/leave_balance.dart';
import '../domain/leave_type.dart';
import '../domain/salary_calculation.dart';
import '../domain/permission_allowance.dart';

/// Swap to FirebaseLeaveRepository() to switch to Firebase — no screen changes needed.
final leaveRepositoryProvider = Provider<LeaveRepository>(
  (ref) => FirebaseLeaveRepository(),
);

final leaveRequestsProvider = FutureProvider.family<List<LeaveRequest>, int>(
  (ref, employeeId) => ref.watch(leaveRepositoryProvider).getLeaveRequests(employeeId),
);

final allLeaveRequestsProvider = FutureProvider<List<LeaveRequest>>(
  (ref) => ref.watch(leaveRepositoryProvider).getAllLeaveRequests(),
);

final leaveTypesProvider = FutureProvider<List<LeaveType>>(
  (ref) => ref.watch(leaveRepositoryProvider).getLeaveTypes(),
);

final employeeOverridesProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(leaveRepositoryProvider).getEmployeeOverrides(),
);

final leaveBalancesProvider = FutureProvider.family<List<LeaveBalance>, int>(
  (ref, employeeId) => ref.watch(leaveRepositoryProvider).getLeaveBalances(employeeId),
);

final permissionAllowanceProvider =
    FutureProvider.family<PermissionAllowance, int>((ref, employeeId) {
  return ref
      .watch(leaveRepositoryProvider)
      .getPermissionAllowance(employeeId, DateTime.now());
});

class SalaryCalcParam {
  final int employeeId;
  final int year;
  final int month;
  final int workingDays;

  const SalaryCalcParam({
    required this.employeeId,
    required this.year,
    required this.month,
    required this.workingDays,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalaryCalcParam &&
          runtimeType == other.runtimeType &&
          employeeId == other.employeeId &&
          year == other.year &&
          month == other.month &&
          workingDays == other.workingDays;

  @override
  int get hashCode => Object.hash(employeeId, year, month, workingDays);
}

final salaryCalculationProvider = FutureProvider.family<SalaryCalculation, SalaryCalcParam>(
  (ref, param) => ref.watch(leaveRepositoryProvider).calculateSalaryAndLop(
        param.employeeId,
        param.year,
        param.month,
        workingDays: param.workingDays,
      ),
);

final leaveAuditLogsProvider = FutureProvider.family<List<Map<String, dynamic>>, int>(
  (ref, requestId) => ref.watch(leaveRepositoryProvider).getAuditLogs(requestId),
);
