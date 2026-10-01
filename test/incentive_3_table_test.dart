import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/employee/domain/employee.dart';
import 'package:flutter_application_1/features/incentive/domain/incentive_payout_ledger.dart';
import 'package:flutter_application_1/features/incentive/domain/incentive_request.dart';
import 'package:flutter_application_1/features/incentive/domain/incentive_settings.dart';
import 'package:flutter_application_1/features/payroll/domain/payroll.dart';
import 'package:flutter_application_1/features/payroll/services/payroll_calculation_service.dart';


void main() {
  group('Incentive – 3-Table Payout System Tests', () {
    final testEmployee = Employee(
      id: 101,
      employeeId: 'EMP101',
      firstName: 'Priya',
      lastName: 'M',
      designation: 'Operator',
      department: 'Production',
      organizationName: 'IGreen',
      emailAddress: 'priya@example.com',
      phoneNumber: '9876543210',
      gender: 'Female',
      dob: '01-01-1995',
      employmentType: 'Full-Time',
      joiningDate: '01-01-2025',
      status: 'Active',
      salaryBasic: 20000.0,
      salaryHra: 10000.0,
    );



    final standardSettings = PayrollSettings(
      payrollStartDay: 21,
      payrollEndDay: 20,
    );

    test('1. Normal Cycle: ₹10,000 incentive yields ₹5,000 immediate + ₹5,000 deferred', () {
      // October 2026 payroll (Period: 21 Sep 2026 to 20 Oct 2026)
      final period = standardSettings.getPayrollPeriod(2026, 10);
      final incentiveSettings = const IncentiveSettings(
        is3TableRuleEnabled: true,
        immediatePercentage: 50.0,
        deferredPercentage: 50.0,
        releaseIntervalCycles: 3, // Months 3, 6, 9, 12 or interval=3
      );

      final requests = [
        IncentiveRequest(
          id: 1,
          requestId: 'INC001',
          employeeId: 101,
          employeeName: 'Priya M',
          designation: 'Operator',
          site: 'Main Unit',
          productName: 'Solar Panel',
          meters: 100,
          rate: 100,
          amount: 10000.0,
          approvedAmount: 10000.0,
          status: 'Approved',
          createdAt: '2026-10-05T10:00:00.000Z',
        ),
      ];

      final result = PayrollCalculationService.calculateIncentives(
        employee: testEmployee,
        requests: requests,
        period: period,
        cycleMonth: 'October 2026', // Month 10: Not a release cycle (10 % 3 != 0)
        incentiveSettings: incentiveSettings,
        ledgers: [],
      );

      expect(result.totalEarnedIncentive, equals(10000.0));
      expect(result.immediateIncentive, equals(5000.0));
      expect(result.currentDeferredIncentive, equals(5000.0));
      expect(result.releasedDeferredIncentive, equals(0.0));
      expect(result.totalPayableIncentive, equals(5000.0));
      expect(result.totalPendingDeferredBalance, equals(5000.0));
      expect(result.isReleaseCycle, isFalse);
    });

    test('2. Next Normal Cycle: New 50% immediate is paid, previous ₹5,000 stays pending in deferred balance', () {
      // November 2026 payroll (Period: 21 Oct 2026 to 20 Nov 2026)
      final period = standardSettings.getPayrollPeriod(2026, 11);
      final incentiveSettings = const IncentiveSettings(
        is3TableRuleEnabled: true,
        immediatePercentage: 50.0,
        deferredPercentage: 50.0,
        releaseIntervalCycles: 3,
      );

      // Existing ledger from October (₹5,000 pending)
      final octLedger = IncentivePayoutLedger(
        id: 'ledger_101_October_2026',
        employeeId: 101,
        employeeName: 'Priya M',
        earnedCycle: 'October 2026',
        totalEarnedAmount: 10000.0,
        immediateAmount: 5000.0,
        deferredAmount: 5000.0,
        status: 'Pending',
        createdAt: '2026-10-21T00:00:00Z',
      );

      // Earned ₹6,000 in November cycle
      final requests = [
        IncentiveRequest(
          id: 2,
          requestId: 'INC002',
          employeeId: 101,
          employeeName: 'Priya M',
          designation: 'Operator',
          site: 'Main Unit',
          productName: 'Solar Panel',
          meters: 60,
          rate: 100,
          amount: 6000.0,
          approvedAmount: 6000.0,
          status: 'Approved',
          createdAt: '2026-11-02T10:00:00.000Z',
        ),
      ];

      final result = PayrollCalculationService.calculateIncentives(
        employee: testEmployee,
        requests: requests,
        period: period,
        cycleMonth: 'November 2026', // Month 11: Not a release cycle
        incentiveSettings: incentiveSettings,
        ledgers: [octLedger],
      );

      expect(result.totalEarnedIncentive, equals(6000.0));
      expect(result.immediateIncentive, equals(3000.0));
      expect(result.currentDeferredIncentive, equals(3000.0));
      expect(result.releasedDeferredIncentive, equals(0.0));
      expect(result.totalPayableIncentive, equals(3000.0));
      // Total pending deferred balance = Oct (5000) + Nov (3000) = 8000
      expect(result.totalPendingDeferredBalance, equals(8000.0));
      expect(result.isReleaseCycle, isFalse);
    });

    test('3. Release Cycle (Table 3): Releases all eligible previous deferred amounts + pays current 50% immediate', () {
      // December 2026 payroll (Month 12: 12 % 3 == 0 -> Release Cycle)
      final period = standardSettings.getPayrollPeriod(2026, 12);
      final incentiveSettings = const IncentiveSettings(
        is3TableRuleEnabled: true,
        immediatePercentage: 50.0,
        deferredPercentage: 50.0,
        releaseIntervalCycles: 3,
      );

      // Pending ledgers from Oct and Nov
      final octLedger = IncentivePayoutLedger(
        id: 'ledger_101_October_2026',
        employeeId: 101,
        employeeName: 'Priya M',
        earnedCycle: 'October 2026',
        totalEarnedAmount: 10000.0,
        immediateAmount: 5000.0,
        deferredAmount: 5000.0,
        status: 'Pending',
        createdAt: '2026-10-21T00:00:00Z',
      );

      final novLedger = IncentivePayoutLedger(
        id: 'ledger_101_November_2026',
        employeeId: 101,
        employeeName: 'Priya M',
        earnedCycle: 'November 2026',
        totalEarnedAmount: 6000.0,
        immediateAmount: 3000.0,
        deferredAmount: 3000.0,
        status: 'Pending',
        createdAt: '2026-11-21T00:00:00Z',
      );

      // Earned ₹8,000 in December cycle
      final decRequests = [
        IncentiveRequest(
          id: 3,
          requestId: 'INC003',
          employeeId: 101,
          employeeName: 'Priya M',
          designation: 'Operator',
          site: 'Main Unit',
          productName: 'Solar Panel',
          meters: 80,
          rate: 100,
          amount: 8000.0,
          approvedAmount: 8000.0,
          status: 'Approved',
          createdAt: '2026-12-05T10:00:00.000Z',
        ),
      ];

      final result = PayrollCalculationService.calculateIncentives(
        employee: testEmployee,
        requests: decRequests,
        period: period,
        cycleMonth: 'December 2026',
        incentiveSettings: incentiveSettings,
        ledgers: [octLedger, novLedger],
      );

      expect(result.isReleaseCycle, isTrue);
      expect(result.totalEarnedIncentive, equals(8000.0));
      expect(result.immediateIncentive, equals(4000.0)); // 50% of Dec
      expect(result.currentDeferredIncentive, equals(4000.0)); // 50% of Dec
      // Released deferred from Oct (5000) + Nov (3000) = 8000
      expect(result.releasedDeferredIncentive, equals(8000.0));
      expect(result.eligibleLedgersToRelease.length, equals(2));
      // Total payable in Dec payroll = Dec Immediate (4000) + Released (8000) = 12000
      expect(result.totalPayableIncentive, equals(12000.0));
    });

    test('4. CRITICAL RULE: Current cycle deferred 50% is NEVER released in the same cycle', () {
      // In December 2026, Dec earned ₹8,000 (Immediate = 4,000, Deferred = 4,000).
      // Dec's own ₹4,000 MUST NOT be part of releasedDeferredIncentive.
      final period = standardSettings.getPayrollPeriod(2026, 12);
      final incentiveSettings = const IncentiveSettings(
        is3TableRuleEnabled: true,
        immediatePercentage: 50.0,
        deferredPercentage: 50.0,
        releaseIntervalCycles: 3,
      );

      final decRequests = [
        IncentiveRequest(
          id: 3,
          requestId: 'INC003',
          employeeId: 101,
          employeeName: 'Priya M',
          designation: 'Operator',
          site: 'Main Unit',
          productName: 'Solar Panel',
          meters: 80,
          rate: 100,
          amount: 8000.0,
          approvedAmount: 8000.0,
          status: 'Approved',
          createdAt: '2026-12-05T10:00:00.000Z',
        ),
      ];

      // No previous pending ledgers
      final result = PayrollCalculationService.calculateIncentives(
        employee: testEmployee,
        requests: decRequests,
        period: period,
        cycleMonth: 'December 2026',
        incentiveSettings: incentiveSettings,
        ledgers: [],
      );

      expect(result.isReleaseCycle, isTrue);
      expect(result.immediateIncentive, equals(4000.0));
      expect(result.currentDeferredIncentive, equals(4000.0));
      // Released deferred must be 0 because there are no previous cycles
      expect(result.releasedDeferredIncentive, equals(0.0));
      expect(result.totalPayableIncentive, equals(4000.0));
      expect(result.totalPendingDeferredBalance, equals(4000.0));
    });

    test('5. Idempotency & Re-running: Recalculating an already released payroll produces identical result without double-paying', () {
      final period = standardSettings.getPayrollPeriod(2026, 12);
      final incentiveSettings = const IncentiveSettings(
        is3TableRuleEnabled: true,
        immediatePercentage: 50.0,
        deferredPercentage: 50.0,
        releaseIntervalCycles: 3,
      );

      // Suppose Oct and Nov ledgers were marked 'Released' for 'December 2026'
      final octLedgerReleased = IncentivePayoutLedger(
        id: 'ledger_101_October_2026',
        employeeId: 101,
        employeeName: 'Priya M',
        earnedCycle: 'October 2026',
        totalEarnedAmount: 10000.0,
        immediateAmount: 5000.0,
        deferredAmount: 5000.0,
        status: 'Released',
        releaseCycle: 'December 2026',
        releasedAmount: 5000.0,
        createdAt: '2026-10-21T00:00:00Z',
        releasedAt: '2026-12-21T00:00:00Z',
      );

      final novLedgerReleased = IncentivePayoutLedger(
        id: 'ledger_101_November_2026',
        employeeId: 101,
        employeeName: 'Priya M',
        earnedCycle: 'November 2026',
        totalEarnedAmount: 6000.0,
        immediateAmount: 3000.0,
        deferredAmount: 3000.0,
        status: 'Released',
        releaseCycle: 'December 2026',
        releasedAmount: 3000.0,
        createdAt: '2026-11-21T00:00:00Z',
        releasedAt: '2026-12-21T00:00:00Z',
      );

      // Ledger from August that was released back in September 2026
      final augLedgerOldReleased = IncentivePayoutLedger(
        id: 'ledger_101_August_2026',
        employeeId: 101,
        employeeName: 'Priya M',
        earnedCycle: 'August 2026',
        totalEarnedAmount: 4000.0,
        immediateAmount: 2000.0,
        deferredAmount: 2000.0,
        status: 'Released',
        releaseCycle: 'September 2026',
        releasedAmount: 2000.0,
        createdAt: '2026-08-21T00:00:00Z',
        releasedAt: '2026-09-21T00:00:00Z',
      );

      final decRequests = [
        IncentiveRequest(
          id: 3,
          requestId: 'INC003',
          employeeId: 101,
          employeeName: 'Priya M',
          designation: 'Operator',
          site: 'Main Unit',
          productName: 'Solar Panel',
          meters: 80,
          rate: 100,
          amount: 8000.0,
          approvedAmount: 8000.0,
          status: 'Approved',
          createdAt: '2026-12-05T10:00:00.000Z',
        ),
      ];

      final result = PayrollCalculationService.calculateIncentives(
        employee: testEmployee,
        requests: decRequests,
        period: period,
        cycleMonth: 'December 2026',
        incentiveSettings: incentiveSettings,
        ledgers: [octLedgerReleased, novLedgerReleased, augLedgerOldReleased],
      );

      // Re-running December recognizes that Oct and Nov were the ones released for December (8000 total)
      // and explicitly IGNORES the August ledger released in September!
      expect(result.releasedDeferredIncentive, equals(8000.0));
      expect(result.totalPayableIncentive, equals(12000.0));
    });

    test('6. Dynamic Salary Cycle: Changing start/end day dynamically updates eligible requests without code change', () {
      // Changed salary cycle configuration to 1st - 30th (Calendar month cycle)
      final calendarSettings = PayrollSettings(
        payrollStartDay: 1,
        payrollEndDay: 30,
      );

      // November cycle: 1 Nov 2026 to 30 Nov 2026
      final period = calendarSettings.getPayrollPeriod(2026, 11);
      final incentiveSettings = const IncentiveSettings(
        is3TableRuleEnabled: true,
        immediatePercentage: 50.0,
        deferredPercentage: 50.0,
      );

      // Request on 21 October (was inside old 21st-20th cycle, but outside new 1st-30th Nov cycle)
      final reqOct21 = IncentiveRequest(
        id: 10,
        requestId: 'INC010',
        employeeId: 101,
        employeeName: 'Priya M',
        designation: 'Operator',
        site: 'Main Unit',
        productName: 'Solar Panel',
        meters: 50,
        rate: 100,
        amount: 5000.0,
        approvedAmount: 5000.0,
        status: 'Approved',
        createdAt: '2026-10-21T10:00:00.000Z',
      );

      // Request on 5 November (inside 1-30 Nov cycle)
      final reqNov5 = IncentiveRequest(
        id: 11,
        requestId: 'INC011',
        employeeId: 101,
        employeeName: 'Priya M',
        designation: 'Operator',
        site: 'Main Unit',
        productName: 'Solar Panel',
        meters: 50,
        rate: 100,
        amount: 5000.0,
        approvedAmount: 5000.0,
        status: 'Approved',
        createdAt: '2026-11-05T10:00:00.000Z',
      );

      final result = PayrollCalculationService.calculateIncentives(
        employee: testEmployee,
        requests: [reqOct21, reqNov5],
        period: period,
        cycleMonth: 'November 2026',
        incentiveSettings: incentiveSettings,
        ledgers: [],
      );

      // Only reqNov5 (₹5,000) falls into the configured period
      expect(result.totalEarnedIncentive, equals(5000.0));
      expect(result.immediateIncentive, equals(2500.0));
      expect(result.currentDeferredIncentive, equals(2500.0));
    });

    test('7. Configurable Release Cycles (e.g. Custom Designated Release Cycle Names)', () {
      final customSettings = const IncentiveSettings(
        is3TableRuleEnabled: true,
        immediatePercentage: 50.0,
        deferredPercentage: 50.0,
        releaseCycles: ['Custom Release Cycle 1', 'Special Milestone Cycle'],
      );

      expect(customSettings.isReleaseCycle('Custom Release Cycle 1'), isTrue);
      expect(customSettings.isReleaseCycle('Special Milestone Cycle'), isTrue);
      expect(customSettings.isReleaseCycle('Standard Month Cycle'), isFalse);
    });

    test('8. Rejected and Pending status requests must NOT be counted towards incentive payouts', () {
      final period = standardSettings.getPayrollPeriod(2026, 10);
      final incentiveSettings = const IncentiveSettings(
        is3TableRuleEnabled: true,
      );

      final requests = [
        IncentiveRequest(
          id: 20,
          requestId: 'INC020',
          employeeId: 101,
          employeeName: 'Priya M',
          designation: 'Operator',
          site: 'Main Unit',
          productName: 'Solar Panel',
          meters: 50,
          rate: 100,
          amount: 5000.0,
          status: 'Rejected',
          createdAt: '2026-10-05T10:00:00.000Z',
        ),
        IncentiveRequest(
          id: 21,
          requestId: 'INC021',
          employeeId: 101,
          employeeName: 'Priya M',
          designation: 'Operator',
          site: 'Main Unit',
          productName: 'Solar Panel',
          meters: 50,
          rate: 100,
          amount: 5000.0,
          status: 'Pending',
          createdAt: '2026-10-06T10:00:00.000Z',
        ),
      ];

      final result = PayrollCalculationService.calculateIncentives(
        employee: testEmployee,
        requests: requests,
        period: period,
        cycleMonth: 'October 2026',
        incentiveSettings: incentiveSettings,
        ledgers: [],
      );

      expect(result.totalEarnedIncentive, equals(0.0));
      expect(result.immediateIncentive, equals(0.0));
      expect(result.currentDeferredIncentive, equals(0.0));
      expect(result.totalPayableIncentive, equals(0.0));
    });
  });
}
