import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: unused_import -- kept so switching repositories remains a one-line change.
import '../data/firebase_loan_repository.dart';
import '../data/sqlite_loan_repository.dart';
import '../domain/employee_loan.dart';
import '../domain/loan_repository.dart';

// Change only this line to FirebaseLoanRepository() when its stub is implemented.
final loanRepositoryProvider = Provider<LoanRepository>(
  (ref) => FirebaseLoanRepository(),
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
