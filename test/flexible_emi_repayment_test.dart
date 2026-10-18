import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/loan/domain/employee_loan.dart';
import 'package:flutter_application_1/features/payroll/domain/payroll.dart';
import 'package:flutter_application_1/features/payroll/services/payroll_calculation_service.dart';

void main() {
  group('Flexible EMI Repayment & Auto-Tenure Extension Tests', () {
    EmployeeLoan buildTestLoan({
      List<LoanRepayment> repayments = const [],
      List<LoanEmiPauseRequest> pauseRequests = const [],
    }) {
      return EmployeeLoan(
        id: 1,
        loanId: 'LN1005',
        employeeId: 101,
        employeeCustomId: 'EMP101',
        employeeName: 'Ravi Kumar',
        department: 'Operations',
        designation: 'Field Supervisor',
        loanType: 'Personal Loan',
        loanAmount: 10000.0,
        loanDate: '2024-01-01',
        disbursementDate: '2024-01-01',
        purpose: 'Personal',
        requestedBy: 'Ravi Kumar',
        totalRepayableAmount: 10000.0,
        installments: 5,
        originalInstallments: 5,
        emiAmount: 2000.0,
        remainingBalance: 10000.0,
        firstDeductionMonth: 'January 2024',
        lastDeductionMonth: 'May 2024',
        status: 'Active',
        repayments: repayments,
        pauseRequests: pauseRequests,
      );
    }

    test('1. Normal loan with no deficit retains original tenure', () {
      final loan = buildTestLoan(
        repayments: const [
          LoanRepayment(
            repaymentId: 'REP01',
            payrollId: 'PAY01',
            month: 'January 2024',
            amount: 2000.0,
            paymentDate: '2024-01-31',
          ),
        ],
      );

      expect(loan.totalTenureMonths, 5);
      expect(loan.isTenureExtended, isFalse);
      expect(loan.extendedMonthsCount, 0);
      expect(loan.effectiveLastDeductionMonth, 'May 2024');
      expect(loan.scheduleMonths.length, 5);
      expect(loan.scheduleMonths.last, 'May 2024');
    });

    test('2. Flexible EMI partial deduction stops auto-extension and accumulates deficit until Admin extension', () {
      // In January, 2000 paid. In February, only 1000 paid.
      // Total paid = 3000, actualRemainingBalance = 7000.
      // Under admin-controlled tenure, original tenure stays fixed at 5 months.
      final loan = buildTestLoan(
        repayments: const [
          LoanRepayment(
            repaymentId: 'REP01',
            payrollId: 'PAY01',
            month: 'January 2024',
            amount: 2000.0,
            paymentDate: '2024-01-31',
          ),
          LoanRepayment(
            repaymentId: 'REP02',
            payrollId: 'PAY02',
            month: 'February 2024',
            amount: 1000.0,
            paymentDate: '2024-02-28',
          ),
        ],
      );

      // Tenure does NOT auto-extend without admin decision
      expect(loan.totalTenureMonths, 5);
      expect(loan.isTenureExtended, isFalse);
      expect(loan.extendedMonthsCount, 0);
      expect(loan.effectiveLastDeductionMonth, 'May 2024');
      expect(loan.accumulatedUnpaidDeficit, 1000.0);

      // When admin configures extension:
      final adminExtended = loan.copyWith(
        extensionInstallments: 1,
        extensionEmiAmount: 1000.0,
        extensionStartMonth: 'June 2024',
      );
      expect(adminExtended.totalTenureMonths, 6);
      expect(adminExtended.isTenureExtended, isTrue);
      expect(adminExtended.extendedMonthsCount, 1);
      expect(adminExtended.effectiveLastDeductionMonth, 'June 2024');
      expect(adminExtended.scheduleMonths.length, 6);
      expect(adminExtended.scheduleMonths.last, 'June 2024');
    });

    test('3. LoanEmiPauseRequest supports Flexible vs Full Pause request types', () {
      const flexibleReq = LoanEmiPauseRequest(
        requestId: 'REQ_01',
        loanId: 'LN1005',
        employeeId: 101,
        employeeName: 'Ravi Kumar',
        month: 'February 2024',
        reason: 'Medical expenses',
        status: 'Approved',
        requestedAt: '2024-02-10T10:00:00Z',
        requestType: 'Flexible',
        requestedAmount: 1000.0,
        approvedAmount: 1000.0,
      );

      expect(flexibleReq.isFlexible, isTrue);
      expect(flexibleReq.isFullPause, isFalse);
      expect(flexibleReq.approvedAmount, 1000.0);

      const fullPauseReq = LoanEmiPauseRequest(
        requestId: 'REQ_02',
        loanId: 'LN1005',
        employeeId: 101,
        employeeName: 'Ravi Kumar',
        month: 'March 2024',
        reason: 'Unforeseen hardship',
        status: 'Approved',
        requestedAt: '2024-03-10T10:00:00Z',
        requestType: 'Pause',
      );

      expect(fullPauseReq.isFlexible, isFalse);
      expect(fullPauseReq.isFullPause, isTrue);
      expect(fullPauseReq.approvedAmount, isNull);
    });

    test('4. PayrollCalculationService deducts approved flexible amount and produces deficit note', () {
      final loan = buildTestLoan(
        repayments: const [
          LoanRepayment(
            repaymentId: 'REP01',
            payrollId: 'PAY01',
            month: 'January 2024',
            amount: 2000.0,
            paymentDate: '2024-01-31',
          ),
        ],
        pauseRequests: const [
          LoanEmiPauseRequest(
            requestId: 'REQ_FLEX',
            loanId: 'LN1005',
            employeeId: 101,
            employeeName: 'Ravi Kumar',
            month: 'February 2024',
            reason: 'Financial difficulty',
            status: 'Approved',
            requestedAt: '2024-02-10T10:00:00Z',
            requestType: 'Flexible',
            requestedAmount: 1000.0,
            approvedAmount: 1000.0,
          ),
        ],
      );

      const settings = PayrollSettings();
      final metrics = PayrollCalculationService.calculateLoanEmi(
        loan: loan,
        month: 'February 2024',
        settings: settings,
      );

      // Deducts approved 1000 instead of standard 2000
      expect(metrics.emiAmount, 1000.0);
      expect(metrics.loanDescription, contains('Partial EMI (₹1000 of ₹2000) - ₹1000 carried forward (LN1005)'));
    });

    test('5. PayrollCalculationService respects custom manual override from admin during payroll run', () {
      final loan = buildTestLoan();
      const settings = PayrollSettings();
      // Admin overrides deduction to 1250 on the fly
      final metrics = PayrollCalculationService.calculateLoanEmi(
        loan: loan,
        month: 'February 2024',
        settings: settings,
        customOverrideAmount: 1250.0,
      );

      expect(metrics.emiAmount, 1250.0);
      expect(metrics.loanDescription, contains('Partial EMI (₹1250 of ₹2000) - ₹750 carried forward (LN1005)'));
    });

    test('6. Dynamic extended installment description tags extended month properly when admin extends', () {
      // 5 repayments of 1800 paid = 9000 total paid. Remaining = 1000.
      final extendedLoan = buildTestLoan(
        repayments: const [
          LoanRepayment(repaymentId: 'R1', payrollId: 'P1', month: 'January 2024', amount: 1800.0, paymentDate: '2024-01-31'),
          LoanRepayment(repaymentId: 'R2', payrollId: 'P2', month: 'February 2024', amount: 1800.0, paymentDate: '2024-02-28'),
          LoanRepayment(repaymentId: 'R3', payrollId: 'P3', month: 'March 2024', amount: 1800.0, paymentDate: '2024-03-31'),
          LoanRepayment(repaymentId: 'R4', payrollId: 'P4', month: 'April 2024', amount: 1800.0, paymentDate: '2024-04-30'),
          LoanRepayment(repaymentId: 'R5', payrollId: 'P5', month: 'May 2024', amount: 1800.0, paymentDate: '2024-05-31'),
        ],
      ).copyWith(
        extensionInstallments: 1,
        extensionEmiAmount: 1000.0,
        extensionStartMonth: 'June 2024',
      );

      const settings = PayrollSettings();
      final metrics = PayrollCalculationService.calculateLoanEmi(
        loan: extendedLoan,
        month: 'June 2024',
        settings: settings,
      );

      // Remaining balance is 1000, so 1000 is deducted to finish loan completely
      expect(metrics.emiAmount, 1000.0);
      expect(metrics.loanDescription, contains('Admin Extended Installment 1 of 1 (LN1005)'));
    });

    test('7. Approved flexible request accumulates deficit and admin extends tenure from 12 to 13 months', () {
      final loan12 = EmployeeLoan(
        id: 2,
        loanId: 'LN2000',
        employeeId: 202,
        employeeCustomId: 'EMP202',
        employeeName: 'Ananya Roy',
        department: 'Finance',
        designation: 'Senior Accountant',
        loanType: 'Personal Loan',
        loanAmount: 20000.0,
        loanDate: '2026-10-01',
        disbursementDate: '2026-10-01',
        purpose: 'Personal',
        requestedBy: 'Ananya Roy',
        totalRepayableAmount: 20000.0,
        installments: 12,
        originalInstallments: 12,
        emiAmount: 1667.0,
        remainingBalance: 20000.0,
        firstDeductionMonth: 'October 2026',
        lastDeductionMonth: 'September 2027',
        status: 'Active',
        repayments: const [],
        pauseRequests: const [
          LoanEmiPauseRequest(
            requestId: 'REQ_OCT',
            loanId: 'LN2000',
            employeeId: 202,
            employeeName: 'Ananya Roy',
            month: 'October 2026',
            reason: 'Financial hardship',
            status: 'Approved',
            requestedAt: '2026-10-05T10:00:00Z',
            requestType: 'Flexible',
            requestedAmount: 833.0,
            approvedAmount: 833.0,
          ),
        ],
      );

      // Tenure does not auto-extend without admin approval
      expect(loan12.totalTenureMonths, 12);
      expect(loan12.isTenureExtended, isFalse);

      // Admin configures 1-month extension
      final adminExtendedLoan = loan12.copyWith(
        extensionInstallments: 1,
        extensionEmiAmount: 834.0,
        extensionStartMonth: 'October 2027',
      );

      expect(adminExtendedLoan.totalTenureMonths, 13);
      expect(adminExtendedLoan.isTenureExtended, isTrue);
      expect(adminExtendedLoan.extendedMonthsCount, 1);
      expect(adminExtendedLoan.effectiveLastDeductionMonth, 'October 2027');
      expect(adminExtendedLoan.scheduleMonths.length, 13);
      expect(adminExtendedLoan.scheduleMonths[0], 'October 2026');
      expect(adminExtendedLoan.scheduleMonths[1], 'November 2026');
      expect(adminExtendedLoan.scheduleMonths[11], 'September 2027');
      expect(adminExtendedLoan.scheduleMonths[12], 'October 2027');
    });

    test('8. Employee gives 3000 directly to admin in Month 2: balance drops from 9000 to 6000, and Month 2 payroll deducts 0 from salary', () {
      const settings = PayrollSettings(
        id: 1,
        payrollStartDay: 20,
        payrollEndDay: 20,
      );

      // 10,000 loan, 1,000/mo EMI, 10 installments
      final loan10k = EmployeeLoan(
        id: 3,
        loanId: 'LN10K',
        employeeId: 303,
        employeeCustomId: 'EMP303',
        employeeName: 'Karthik S',
        department: 'Operations',
        designation: 'Technician',
        loanType: 'Salary Advance',
        loanAmount: 10000.0,
        loanDate: '2026-08-01',
        disbursementDate: '2026-08-01',
        purpose: 'Advance',
        requestedBy: 'Karthik S',
        totalRepayableAmount: 10000.0,
        installments: 10,
        originalInstallments: 10,
        emiAmount: 1000.0,
        remainingBalance: 9000.0,
        firstDeductionMonth: 'September 2026',
        lastDeductionMonth: 'June 2027',
        status: 'Active',
        repayments: const [
          // Month 1: 1,000 deducted from salary via payroll
          LoanRepayment(
            repaymentId: 'REP_M1',
            payrollId: 'PAY_SEP',
            month: 'September 2026',
            amount: 1000.0,
            paymentDate: '2026-09-30',
            paymentType: 'Salary Deduction',
            paymentMode: 'Payroll',
          ),
          // Month 2: Employee gave 3,000 directly to admin in cash outside salary
          LoanRepayment(
            repaymentId: 'DIR_M2',
            payrollId: 'DIRECT_PAYMENT',
            month: 'October 2026',
            amount: 3000.0,
            paymentDate: '2026-10-15',
            paymentType: 'Direct Payment',
            paymentMode: 'Cash',
            receivedBy: 'Admin',
            referenceNote: 'Direct cash payment given to admin',
          ),
        ],
      );

      // Remaining balance: 10,000 - 1,000 (Month 1) - 3,000 (Direct Month 2) = 6,000
      expect(loan10k.totalPaid, 4000.0);
      expect(loan10k.actualRemainingBalance, 6000.0);
      expect(loan10k.paidInstallments, 4); // 4000 covers 4 installments of 1000

      // Payroll calculation for Month 2 (October 2026):
      // The employee already paid 3,000 directly to admin for October 2026.
      // Therefore, payroll should deduct 0 from salary!
      final octMetrics = PayrollCalculationService.calculateLoanEmi(
        loan: loan10k,
        month: 'October 2026',
        settings: settings,
      );

      expect(octMetrics.emiAmount, 0.0);
      expect(octMetrics.loanDescription, contains('Paid Directly to Admin'));
      expect(octMetrics.loanDescription, contains('₹3000 received'));
      expect(octMetrics.loanDescription, contains('advance'));
    });

    test('9. Following month (Month 3 / November 2026) payroll calculates normal 1000 EMI from remaining 6000 balance', () {
      const settings = PayrollSettings(
        id: 1,
        payrollStartDay: 20,
        payrollEndDay: 20,
      );

      final loan10k = EmployeeLoan(
        id: 3,
        loanId: 'LN10K',
        employeeId: 303,
        employeeCustomId: 'EMP303',
        employeeName: 'Karthik S',
        department: 'Operations',
        designation: 'Technician',
        loanType: 'Salary Advance',
        loanAmount: 10000.0,
        loanDate: '2026-08-01',
        disbursementDate: '2026-08-01',
        purpose: 'Advance',
        requestedBy: 'Karthik S',
        totalRepayableAmount: 10000.0,
        installments: 10,
        originalInstallments: 10,
        emiAmount: 1000.0,
        remainingBalance: 9000.0,
        firstDeductionMonth: 'September 2026',
        lastDeductionMonth: 'June 2027',
        status: 'Active',
        repayments: const [
          LoanRepayment(
            repaymentId: 'REP_M1',
            payrollId: 'PAY_SEP',
            month: 'September 2026',
            amount: 1000.0,
            paymentDate: '2026-09-30',
          ),
          LoanRepayment(
            repaymentId: 'DIR_M2',
            payrollId: 'DIRECT_PAYMENT',
            month: 'October 2026',
            amount: 3000.0,
            paymentDate: '2026-10-15',
            paymentType: 'Direct Payment',
            paymentMode: 'Cash',
          ),
        ],
      );

      final novMetrics = PayrollCalculationService.calculateLoanEmi(
        loan: loan10k,
        month: 'November 2026',
        settings: settings,
      );

      expect(novMetrics.emiAmount, 1000.0);
      expect(novMetrics.loanDescription, contains('Installment 3 of 10 (LN10K)'));
    });

    test('10. Partial direct payment of 400 for Month 2 deducts remaining 600 from salary', () {
      const settings = PayrollSettings(
        id: 1,
        payrollStartDay: 20,
        payrollEndDay: 20,
      );

      final loan10k = EmployeeLoan(
        id: 3,
        loanId: 'LN10K',
        employeeId: 303,
        employeeCustomId: 'EMP303',
        employeeName: 'Karthik S',
        department: 'Operations',
        designation: 'Technician',
        loanType: 'Salary Advance',
        loanAmount: 10000.0,
        loanDate: '2026-08-01',
        disbursementDate: '2026-08-01',
        purpose: 'Advance',
        requestedBy: 'Karthik S',
        totalRepayableAmount: 10000.0,
        installments: 10,
        originalInstallments: 10,
        emiAmount: 1000.0,
        remainingBalance: 9000.0,
        firstDeductionMonth: 'September 2026',
        lastDeductionMonth: 'June 2027',
        status: 'Active',
        repayments: const [
          LoanRepayment(
            repaymentId: 'REP_M1',
            payrollId: 'PAY_SEP',
            month: 'September 2026',
            amount: 1000.0,
            paymentDate: '2026-09-30',
          ),
          // 400 given directly to admin for October 2026
          LoanRepayment(
            repaymentId: 'DIR_M2',
            payrollId: 'DIRECT_PAYMENT',
            month: 'October 2026',
            amount: 400.0,
            paymentDate: '2026-10-10',
            paymentType: 'Direct Payment',
            paymentMode: 'Cash',
          ),
        ],
      );

      expect(loan10k.totalPaid, 1400.0);
      expect(loan10k.actualRemainingBalance, 8600.0);

      final octMetrics = PayrollCalculationService.calculateLoanEmi(
        loan: loan10k,
        month: 'October 2026',
        settings: settings,
      );

      // 1000 scheduled - 400 direct = 600 from salary
      expect(octMetrics.emiAmount, 600.0);
      expect(octMetrics.loanDescription, contains('Partial Direct Payment'));
      expect(octMetrics.loanDescription, contains('₹400 paid to admin'));
      expect(octMetrics.loanDescription, contains('₹600 from salary'));
    });
  });
}
