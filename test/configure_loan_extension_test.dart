import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/loan/domain/employee_loan.dart';

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
  });
}
