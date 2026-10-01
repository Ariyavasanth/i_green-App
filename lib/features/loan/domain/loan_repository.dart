import 'employee_loan.dart';

abstract class LoanRepository {
  Future<List<EmployeeLoan>> getAllLoans();
  Future<List<EmployeeLoan>> getLoansForEmployee(int employeeId);
  Future<EmployeeLoan?> getLoanById(int id);
  Future<EmployeeLoan?> getLoanByLoanId(String loanId);
  Future<EmployeeLoan?> getActiveLoanForEmployee(int employeeId, String month);
  Future<void> saveLoan(EmployeeLoan loan);
  Future<void> deleteLoan(int id);
  Future<void> updateLoanBalance(String loanId, double deductionAmount);
  Future<void> recordRepayment({
    required String loanId,
    required String payrollId,
    required String month,
    required double amount,
    required String paymentDate,
    String referenceNote,
  });
  Future<void> changeLoanStatus(int id, String status);
  Future<String> approveLoan({
    required int id,
    required String approverName,
    required String approverRole,
    int? installments,
    double? emiAmount,
    double? totalRepayableAmount,
    String? firstDeductionMonth,
    String? lastDeductionMonth,
  });
  Future<void> disburseLoan(int id, String disbursementDate);
  Future<void> rejectLoan(int id, String reason);
  Future<void> submitEmiPauseRequest(LoanEmiPauseRequest request);
  Future<void> reviewEmiPauseRequest({
    required String loanId,
    required String requestId,
    required String status,
    required String reviewedBy,
    String? adminRemarks,
  });
  Future<void> markPauseRequestRecovered({
    required String loanId,
    required String requestId,
  });
  Future<void> cancelEmiPauseRequest({
    required String loanId,
    required String requestId,
  });
  Future<List<LoanEmiPauseRequest>> getAllPendingPauseRequests();
}
