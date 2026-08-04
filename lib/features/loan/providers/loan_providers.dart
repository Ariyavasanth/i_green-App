import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/sqlite_loan_repository.dart';
import '../domain/employee_loan.dart';
import '../domain/loan_repository.dart';

// Default to SqliteLoanRepository for local SQLite database execution.
// Swap to FirebaseLoanRepository() once the Firebase repository implementation is complete.
final loanRepositoryProvider = Provider<LoanRepository>(
  (ref) => SqliteLoanRepository(),
);

final allLoansProvider = FutureProvider<List<EmployeeLoan>>((ref) {
  return ref.watch(loanRepositoryProvider).getAllLoans();
});

final employeeLoansProvider = FutureProvider.family<List<EmployeeLoan>, int>((ref, employeeId) {
  return ref.watch(loanRepositoryProvider).getLoansForEmployee(employeeId);
});

final loanByIdProvider = FutureProvider.family<EmployeeLoan?, int>((ref, id) {
  return ref.watch(loanRepositoryProvider).getLoanById(id);
});

final activeLoanForEmployeeProvider = FutureProvider.family<EmployeeLoan?, ({int employeeId, String month})>((ref, arg) {
  return ref.watch(loanRepositoryProvider).getActiveLoanForEmployee(arg.employeeId, arg.month);
});
