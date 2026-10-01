import 'package:flutter_application_1/features/loan/domain/employee_loan.dart';
import 'package:flutter_application_1/features/payroll/domain/payroll.dart';
import 'package:flutter_application_1/features/payroll/services/payroll_calculation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Loan EMI Pause & Carry-Forward Calculation Tests', () {
    const settings = PayrollSettings(
      id: 1,
      payrollStartDay: 20,
      payrollEndDay: 20,
      workingDaysInMonth: 26,
    );

    EmployeeLoan createBaseLoan({
      List<LoanEmiPauseRequest> pauseRequests = const [],
      List<LoanRepayment> repayments = const [],
    }) {
      return EmployeeLoan(
        id: 101,
        loanId: 'LN001',
        employeeId: 10,
        employeeName: 'John Doe',
        employeeCustomId: 'EMP-0010',
        department: 'Engineering',
        designation: 'Software Developer',
        loanType: 'Personal Loan',
        loanAmount: 12000.0,
        loanDate: '2026-09-01',
        disbursementDate: '2026-09-01',
        purpose: 'Medical emergency',
        installments: 12,
        emiAmount: 1000.0,
        firstDeductionMonth: 'September 2026',
        lastDeductionMonth: 'August 2027',
        interestRate: 0.0,
        totalRepayableAmount: 12000.0,
        requestedBy: 'John Doe',
        status: 'Active',
        remainingBalance: 12000.0,
        repayments: repayments,
        pauseRequests: pauseRequests,
      );
    }

    test('1. Normal EMI deduction when no pause request exists', () {
      final loan = createBaseLoan();

      final metrics = PayrollCalculationService.calculateLoanEmi(
        loan: loan,
        month: 'September 2026',
        settings: settings,
      );

      expect(metrics.emiAmount, 1000.0);
      expect(metrics.loanDescription, contains('Installment 1 of 12 (LN001)'));
    });

    test('2. Approved pause for current month produces ₹0 EMI and deferral note', () {
      final loan = createBaseLoan(
        pauseRequests: [
          const LoanEmiPauseRequest(
            requestId: 'PAUSE_1',
            loanId: 'LN001',
            employeeId: 10,
            employeeName: 'John Doe',
            month: 'October 2026',
            reason: 'Medical expense, please pause this month',
            status: 'Approved',
            requestedAt: '2026-10-01T10:00:00Z',
          ),
        ],
      );

      final metrics = PayrollCalculationService.calculateLoanEmi(
        loan: loan,
        month: 'October 2026',
        settings: settings,
      );

      expect(metrics.emiAmount, 0.0);
      expect(metrics.loanDescription, contains('EMI Deferred for October 2026 (LN001)'));
      expect(metrics.loanDescription, contains('Carried forward'));
    });

    test('3. Pending or Rejected pause request continues with normal EMI deduction', () {
      final loanWithPending = createBaseLoan(
        pauseRequests: [
          const LoanEmiPauseRequest(
            requestId: 'PAUSE_PENDING',
            loanId: 'LN001',
            employeeId: 10,
            employeeName: 'John Doe',
            month: 'October 2026',
            reason: 'Awaiting admin decision',
            status: 'Pending',
            requestedAt: '2026-10-01T10:00:00Z',
          ),
        ],
      );

      final pendingMetrics = PayrollCalculationService.calculateLoanEmi(
        loan: loanWithPending,
        month: 'October 2026',
        settings: settings,
      );
      expect(pendingMetrics.emiAmount, 1000.0);

      final loanWithRejected = createBaseLoan(
        pauseRequests: [
          const LoanEmiPauseRequest(
            requestId: 'PAUSE_REJ',
            loanId: 'LN001',
            employeeId: 10,
            employeeName: 'John Doe',
            month: 'October 2026',
            reason: 'Not approved',
            status: 'Rejected',
            requestedAt: '2026-10-01T10:00:00Z',
          ),
        ],
      );

      final rejectedMetrics = PayrollCalculationService.calculateLoanEmi(
        loan: loanWithRejected,
        month: 'October 2026',
        settings: settings,
      );
      expect(rejectedMetrics.emiAmount, 1000.0);
    });

    test('4. Following month after approved pause deducts 2x EMI (normal + deferred)', () {
      final loan = createBaseLoan(
        pauseRequests: [
          const LoanEmiPauseRequest(
            requestId: 'PAUSE_1',
            loanId: 'LN001',
            employeeId: 10,
            employeeName: 'John Doe',
            month: 'October 2026',
            reason: 'Paused',
            status: 'Approved',
            isRecovered: false,
            requestedAt: '2026-10-01T10:00:00Z',
          ),
        ],
      );

      final metrics = PayrollCalculationService.calculateLoanEmi(
        loan: loan,
        month: 'November 2026',
        settings: settings,
      );

      expect(metrics.emiAmount, 2000.0);
      expect(metrics.loanDescription, contains('2 EMIs: deferred October 2026 + November 2026'));
    });

    test('5. After recovery is marked (isRecovered: true), subsequent month returns to normal 1x EMI', () {
      final loan = createBaseLoan(
        pauseRequests: [
          const LoanEmiPauseRequest(
            requestId: 'PAUSE_1',
            loanId: 'LN001',
            employeeId: 10,
            employeeName: 'John Doe',
            month: 'October 2026',
            reason: 'Paused',
            status: 'Approved',
            isRecovered: true, // Recovered during November payroll
            requestedAt: '2026-10-01T10:00:00Z',
          ),
        ],
        repayments: [
          const LoanRepayment(
            repaymentId: 'REP_1',
            payrollId: 'PAY_SEP',
            month: 'September 2026',
            amount: 1000.0,
            paymentDate: '2026-09-30',
          ),
          const LoanRepayment(
            repaymentId: 'REP_2',
            payrollId: 'PAY_NOV',
            month: 'November 2026',
            amount: 2000.0,
            paymentDate: '2026-11-30',
          ),
        ],
      );

      final metrics = PayrollCalculationService.calculateLoanEmi(
        loan: loan,
        month: 'December 2026',
        settings: settings,
      );

      expect(metrics.emiAmount, 1000.0);
      expect(metrics.loanDescription, contains('Installment 4 of 12 (LN001)'));
    });

    test('6. Multiple independent loans remain isolated', () {
      final loanA = createBaseLoan(
        pauseRequests: [
          const LoanEmiPauseRequest(
            requestId: 'PAUSE_A',
            loanId: 'LN001',
            employeeId: 10,
            employeeName: 'John Doe',
            month: 'October 2026',
            reason: 'Paused loan A',
            status: 'Approved',
            isRecovered: false,
            requestedAt: '2026-10-01T10:00:00Z',
          ),
        ],
      );

      final loanB = EmployeeLoan(
        id: 102,
        loanId: 'LN002',
        employeeId: 20,
        employeeName: 'Jane Smith',
        employeeCustomId: 'EMP-0020',
        department: 'HR',
        designation: 'HR Executive',
        loanType: 'Salary Advance',
        loanAmount: 5000.0,
        loanDate: '2026-09-01',
        disbursementDate: '2026-09-01',
        purpose: 'Advance',
        installments: 5,
        emiAmount: 1000.0,
        firstDeductionMonth: 'September 2026',
        lastDeductionMonth: 'January 2027',
        interestRate: 0.0,
        totalRepayableAmount: 5000.0,
        requestedBy: 'Jane Smith',
        status: 'Active',
        remainingBalance: 5000.0,
      );

      // Loan A for November (recovering 2x)
      final metricsA = PayrollCalculationService.calculateLoanEmi(
        loan: loanA,
        month: 'November 2026',
        settings: settings,
      );
      expect(metricsA.emiAmount, 2000.0);

      // Loan B for November (normal 1x)
      final metricsB = PayrollCalculationService.calculateLoanEmi(
        loan: loanB,
        month: 'November 2026',
        settings: settings,
      );
      expect(metricsB.emiAmount, 1000.0);
      expect(metricsB.loanDescription, contains('Installment 3 of 5 (LN002)'));
    });
  });
}
