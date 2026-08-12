import '../domain/employee_loan.dart';
import '../domain/loan_repository.dart';

/// Firestore stub — returns safe empty values until fully implemented.
class FirebaseLoanRepository implements LoanRepository {
  @override Future<List<EmployeeLoan>> getAllLoans() async => [];
  @override Future<List<EmployeeLoan>> getLoansForEmployee(int employeeId) async => [];
  @override Future<EmployeeLoan?> getLoanById(int id) async => null;
  @override Future<EmployeeLoan?> getLoanByLoanId(String loanId) async => null;
  @override Future<EmployeeLoan?> getActiveLoanForEmployee(int employeeId, String month) async => null;
  @override Future<void> saveLoan(EmployeeLoan loan) async {}
  @override Future<void> deleteLoan(int id) async {}
  @override Future<void> updateLoanBalance(String loanId, double deductionAmount) async {}
  @override Future<void> changeLoanStatus(int id, String status) async {}
}
