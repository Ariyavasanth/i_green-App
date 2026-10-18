import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/loan/domain/employee_loan.dart';
import 'package:flutter_application_1/features/payroll/domain/payroll.dart';
import 'package:flutter_application_1/features/payroll/services/payroll_calculation_service.dart';

void main() {
  group('Configure Loan Extension - Amount, Month & Percentage Tests', () {
    test('1. EmployeeLoan correctly serializes and deserializes extension fields', () {
      final loan = EmployeeLoan(
        id: 10,
        loanId: 'LN5407',
        employeeId: 5407,
        employeeCustomId: 'EMP5407',
        employeeName: 'Nithya Sri J',
        department: 'Production',
        designation: 'Operator',
        loanType: 'Personal Loan',
        loanAmount: 2000.0,
        loanDate: '2026-10-01',
        disbursementDate: '2026-10-01',
        purpose: 'Personal',
        requestedBy: 'Nithya Sri J',
        totalRepayableAmount: 2000.0,
        installments: 10,
        originalInstallments: 10,
        emiAmount: 200.0,
        remainingBalance: 1000.0,
        firstDeductionMonth: 'October 2026',
        lastDeductionMonth: 'July 2027',
        status: 'Active',
        repayments: const [],
        extensionInstallments: 4,
        extensionEmiAmount: 250.0,
        extensionStartMonth: 'August 2027',
        extensionApprovedBy: 'Admin User',
        extensionApprovalDate: '19 Oct 2026, 01:30 AM',
        extensionRemarks: '4 months extension at ₹250/mo',
        extensionInterestRate: 2.5,
      );

      final map = loan.toMap();
      expect(map['extension_installments'], 4);
      expect(map['extension_emi_amount'], 250.0);
      expect(map['extension_start_month'], 'August 2027');
      expect(map['extension_approved_by'], 'Admin User');
      expect(map['extension_approval_date'], '19 Oct 2026, 01:30 AM');
      expect(map['extension_remarks'], '4 months extension at ₹250/mo');
      expect(map['extension_interest_rate'], 2.5);

      final restored = EmployeeLoan.fromMap(map);
      expect(restored.extensionInstallments, 4);
      expect(restored.extensionEmiAmount, 250.0);
      expect(restored.extensionStartMonth, 'August 2027');
      expect(restored.extensionApprovedBy, 'Admin User');
      expect(restored.extensionApprovalDate, '19 Oct 2026, 01:30 AM');
      expect(restored.extensionRemarks, '4 months extension at ₹250/mo');
      expect(restored.extensionInterestRate, 2.5);
    });

    test('2. Calculating Amount & Percentage when Admin sets Month', () {
      const outstanding = 1000.0;
      const months = 4;
      const interestRate = 0.0;

      final total = outstanding + (outstanding * (interestRate / 100.0));
      final emi = total / months;
      final percent = (emi / outstanding) * 100.0;

      expect(emi, 250.0);
      expect(percent, 25.0);
    });

    test('3. Calculating Month & Percentage when Admin sets Amount (EMI)', () {
      const outstanding = 1000.0;
      const emi = 200.0;
      const interestRate = 0.0;

      final total = outstanding + (outstanding * (interestRate / 100.0));
      final months = (total / emi).ceil();
      final percent = (emi / outstanding) * 100.0;

      expect(months, 5);
      expect(percent, 20.0);
    });

    test('4. Calculating Month & Amount when Admin sets Percentage', () {
      const outstanding = 1000.0;
      const percent = 10.0; // 10% per month
      const interestRate = 0.0;

      final emi = outstanding * (percent / 100.0);
      final total = outstanding + (outstanding * (interestRate / 100.0));
      final months = (total / emi).ceil();

      expect(emi, 100.0);
      expect(months, 10);
    });

    test('5. Calculating with Interest Rate applied to outstanding deficit', () {
      const outstanding = 1000.0;
      const months = 4;
      const interestRate = 5.0; // 5% markup

      final totalInterest = outstanding * (interestRate / 100.0);
      final totalToRecover = outstanding + totalInterest;
      final emi = totalToRecover / months;
      final percent = (emi / outstanding) * 100.0;

      expect(totalInterest, 50.0);
      expect(totalToRecover, 1050.0);
      expect(emi, 262.5);
      expect(percent, 26.25);
    });

    test('6. Month sequence progression and final installment adjustment', () {
      const startMonth = 'August 2027';
      const extraMonths = 3;
      const totalToRecover = 1000.0;
      final emiPerMonth = (totalToRecover / extraMonths).roundToDouble(); // 333

      final installments = <double>[];
      for (int i = 0; i < extraMonths; i++) {
        final isLast = i == extraMonths - 1;
        final amt = (isLast && extraMonths > 1)
            ? (totalToRecover - (emiPerMonth * (extraMonths - 1)))
            : emiPerMonth;
        installments.add(amt);
      }

      expect(installments[0], 333.0);
      expect(installments[1], 333.0);
      expect(installments[2], 334.0);
      expect(installments.reduce((a, b) => a + b), 1000.0);

      // Verify months
      expect(EmployeeLoan.getMonthAtOffset(startMonth, 0), 'August 2027');
      expect(EmployeeLoan.getMonthAtOffset(startMonth, 1), 'September 2027');
      expect(EmployeeLoan.getMonthAtOffset(startMonth, 2), 'October 2027');
    });

    test('7. Loan tenure lifecycle: transition to isAwaitingExtensionDecision and extension activation', () {
      final baseLoan = EmployeeLoan(
        id: 1,
        loanId: 'LN1001',
        employeeId: 101,
        employeeCustomId: 'EMP101',
        employeeName: 'Ramesh K',
        department: 'Operations',
        designation: 'Technician',
        loanType: 'Personal Loan',
        loanAmount: 1000.0,
        loanDate: '2026-10-01',
        disbursementDate: '2026-10-01',
        purpose: 'Personal',
        requestedBy: 'Ramesh K',
        totalRepayableAmount: 1000.0,
        installments: 5,
        originalInstallments: 5,
        emiAmount: 200.0,
        remainingBalance: 400.0,
        firstDeductionMonth: 'October 2026',
        lastDeductionMonth: 'February 2027',
        status: 'Active',
        repayments: [
          for (int i = 0; i < 5; i++)
            LoanRepayment(
              repaymentId: 'REP_$i',
              payrollId: 'PAY_$i',
              month: EmployeeLoan.getMonthAtOffset('October 2026', i),
              amount: 120.0, // Partial repayment creating deficit
              paymentDate: '2026-10-25',
              createdAt: '2026-10-25',
            ),
        ],
      );

      // 5 repayments made on 5-installment tenure with 400 balance remaining
      expect(baseLoan.repayments.length, 5);
      expect(baseLoan.actualRemainingBalance, 400.0);
      expect(baseLoan.isOriginalTenureFinished, isTrue);
      expect(baseLoan.isAwaitingExtensionDecision, isTrue);
      expect(baseLoan.isTenureExtended, isFalse);

      // Admin configures 2-month extension at 200/month
      final extendedLoan = baseLoan.copyWith(
        extensionInstallments: 2,
        extensionEmiAmount: 200.0,
        extensionStartMonth: 'March 2027',
        extensionApprovedBy: 'Admin',
        extensionApprovalDate: '2027-02-28',
        extensionRemarks: '2 months extension approved',
      );

      expect(extendedLoan.isAwaitingExtensionDecision, isFalse);
      expect(extendedLoan.isTenureExtended, isTrue);
      expect(extendedLoan.totalTenureMonths, 7);
      expect(extendedLoan.extendedMonthsCount, 2);
      expect(extendedLoan.scheduleMonths.length, 7);
      expect(extendedLoan.scheduleMonths[5], 'March 2027');
      expect(extendedLoan.scheduleMonths[6], 'April 2027');
    });

    test('8. PayrollCalculationService blocks deduction during awaiting extension and resumes on approval', () {
      final settings = const PayrollSettings();

      final baseLoan = EmployeeLoan(
        id: 2,
        loanId: 'LN1002',
        employeeId: 102,
        employeeCustomId: 'EMP102',
        employeeName: 'Suresh M',
        department: 'Operations',
        designation: 'Operator',
        loanType: 'Personal Loan',
        loanAmount: 1000.0,
        loanDate: '2026-10-01',
        disbursementDate: '2026-10-01',
        purpose: 'Personal',
        requestedBy: 'Suresh M',
        totalRepayableAmount: 1000.0,
        installments: 3,
        originalInstallments: 3,
        emiAmount: 333.0,
        remainingBalance: 500.0,
        firstDeductionMonth: 'October 2026',
        lastDeductionMonth: 'December 2026',
        status: 'Active',
        repayments: [
          for (int i = 0; i < 3; i++)
            LoanRepayment(
              repaymentId: 'REP_$i',
              payrollId: 'PAY_$i',
              month: EmployeeLoan.getMonthAtOffset('October 2026', i),
              amount: 166.0,
              paymentDate: '2026-10-25',
              createdAt: '2026-10-25',
            ),
        ],
      );

      // Month beyond original tenure (January 2027) before admin extension
      final beforeApproval = PayrollCalculationService.calculateLoanEmi(
        loan: baseLoan,
        month: 'January 2027',
        settings: settings,
      );
      expect(beforeApproval.emiAmount, 0.0);
      expect(beforeApproval.loanDescription, contains('Awaiting Extension Decision'));

      // After Admin approves extension of 2 months at 250 EMI
      final approvedLoan = baseLoan.copyWith(
        extensionInstallments: 2,
        extensionEmiAmount: 250.0,
        extensionStartMonth: 'January 2027',
        extensionApprovedBy: 'Admin',
        extensionApprovalDate: '01 Jan 2027',
      );

      final afterApproval = PayrollCalculationService.calculateLoanEmi(
        loan: approvedLoan,
        month: 'January 2027',
        settings: settings,
      );
      expect(afterApproval.emiAmount, 250.0);
      expect(afterApproval.loanDescription, contains('Admin Extended Installment 1 of 2'));
    });

    test('9. Final installment cleanly recovers remaining balance with rounding and prevents overcharging', () {
      final settings = const PayrollSettings();

      final loanAtFinalMonth = EmployeeLoan(
        id: 3,
        loanId: 'LN1003',
        employeeId: 103,
        employeeCustomId: 'EMP103',
        employeeName: 'Anitha V',
        department: 'Production',
        designation: 'Operator',
        loanType: 'Personal Loan',
        loanAmount: 1000.0,
        loanDate: '2026-10-01',
        disbursementDate: '2026-10-01',
        purpose: 'Personal',
        requestedBy: 'Anitha V',
        totalRepayableAmount: 1000.0,
        installments: 3,
        originalInstallments: 3,
        emiAmount: 333.0,
        remainingBalance: 334.0, // Remaining balance has 1 rupee rounding difference
        firstDeductionMonth: 'October 2026',
        lastDeductionMonth: 'December 2026',
        status: 'Active',
        extensionInstallments: 2,
        extensionEmiAmount: 167.0,
        extensionStartMonth: 'January 2027',
        repayments: [
          // 3 original repayments of 222 (paid 666, balance 334)
          for (int i = 0; i < 3; i++)
            LoanRepayment(
              repaymentId: 'REP_$i',
              payrollId: 'PAY_$i',
              month: EmployeeLoan.getMonthAtOffset('October 2026', i),
              amount: 222.0,
              paymentDate: '2026-10-25',
              createdAt: '2026-10-25',
            ),
          // First extended month paid 167 (leaving 167)
          LoanRepayment(
            repaymentId: 'REP_EXT1',
            payrollId: 'PAY_EXT1',
            month: 'January 2027',
            amount: 167.0,
            paymentDate: '2027-01-25',
            createdAt: '2027-01-25',
          ),
        ],
      );

      // Remaining balance is exactly 1000 - 666 - 167 = 167
      expect(loanAtFinalMonth.actualRemainingBalance, 167.0);

      // Payroll calculation for the final extended month (February 2027, index 4 of 5)
      final finalInstallment = PayrollCalculationService.calculateLoanEmi(
        loan: loanAtFinalMonth,
        month: 'February 2027',
        settings: settings,
      );

      expect(finalInstallment.emiAmount, 167.0);
      expect(finalInstallment.loanDescription, contains('Admin Extended Installment 2 of 2'));
    });
  });
}
