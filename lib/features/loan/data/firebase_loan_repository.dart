import '../domain/employee_loan.dart';
import '../domain/loan_repository.dart';

/// Firebase implementation stub for Employee Loans.
/// Empty for now, to be filled during later production staging.
class FirebaseLoanRepository implements LoanRepository {
  @override
  Future<List<EmployeeLoan>> getAllLoans() {
    throw UnimplementedError('FirebaseLoanRepository.getAllLoans is not implemented yet.');
  }

  @override
  Future<List<EmployeeLoan>> getLoansForEmployee(int employeeId) {
    throw UnimplementedError('FirebaseLoanRepository.getLoansForEmployee is not implemented yet.');
  }

  @override
  Future<EmployeeLoan?> getLoanById(int id) {
    throw UnimplementedError('FirebaseLoanRepository.getLoanById is not implemented yet.');
  }

  @override
  Future<EmployeeLoan?> getLoanByLoanId(String loanId) {
    throw UnimplementedError('FirebaseLoanRepository.getLoanByLoanId is not implemented yet.');
  }

  @override
  Future<EmployeeLoan?> getActiveLoanForEmployee(int employeeId, String month) {
    throw UnimplementedError('FirebaseLoanRepository.getActiveLoanForEmployee is not implemented yet.');
  }

  @override
  Future<void> saveLoan(EmployeeLoan loan) {
    throw UnimplementedError('FirebaseLoanRepository.saveLoan is not implemented yet.');
  }

  @override
  Future<void> deleteLoan(int id) {
    throw UnimplementedError('FirebaseLoanRepository.deleteLoan is not implemented yet.');
  }

  @override
  Future<void> updateLoanBalance(String loanId, double deductionAmount) {
    throw UnimplementedError('FirebaseLoanRepository.updateLoanBalance is not implemented yet.');
  }

  @override
  Future<void> changeLoanStatus(int id, String status) {
    throw UnimplementedError('FirebaseLoanRepository.changeLoanStatus is not implemented yet.');
  }
}
