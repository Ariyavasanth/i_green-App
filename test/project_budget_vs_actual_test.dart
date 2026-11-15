import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/expenses/domain/expense.dart';
import 'package:flutter_application_1/features/fund_requester/domain/models/fund_request.dart';
import 'package:flutter_application_1/features/fund_requester/domain/models/fund_request_item.dart';
import 'package:flutter_application_1/features/projects/domain/models/project_budget_vs_actual.dart';

void main() {
  group('Project Budget vs Actual Financial Calculation Tests', () {
    test('Calculates exact user specification example correctly without double counting', () {
      // Scenario from User Prompt:
      // Allocated Budget: ₹10,00,000
      // Approved Funds: ₹6,00,000 (from Fund Management)
      // Actual Recorded Expenses: ₹4,50,000
      // Expected:
      // Remaining Budget = ₹5,50,000
      // Budget Utilization = 45.0%
      // Unspent Disbursed Funds = ₹1,50,000

      final fundRequests = [
        FundRequest(
          id: 'fr_1',
          requestNumber: 'REQ-001',
          employeeId: 'emp_1',
          employeeName: 'Ravi Site Engg',
          message: 'Initial site mobilization',
          projectCode: 'PRJ-2026-001',
          projectName: 'Pipeline Alpha',
          requestAmount: 700000.0,
          approvedAmount: 600000.0, // Partially approved
          status: 'Partially Approved',
          createdAt: DateTime(2026, 1, 10),
          updatedAt: DateTime(2026, 1, 11),
          items: const [
            FundRequestItem(
              id: 'it_1',
              category: 'Materials',
              subCategory: 'Pipes',
              comments: 'Raw material procurement',
              amount: 400000.0,
            ),
            FundRequestItem(
              id: 'it_2',
              category: 'Machinery & Fuel',
              subCategory: 'Diesel',
              comments: 'Rig operations',
              amount: 200000.0,
            ),
          ],
        ),
      ];

      final expenses = [
        Expense(
          id: 101,
          date: DateTime(2026, 1, 15),
          account: 'Factory Expenses',
          reference: 'INV-101',
          vendor: 'Tata Steel',
          paidThrough: 'Bank Account',
          customer: '',
          status: 'PAID',
          amount: 300000.0,
          projectCode: 'PRJ-2026-001',
          projectId: 'p_1',
        ),
        Expense(
          id: 102,
          date: DateTime(2026, 1, 18),
          account: 'Transportation Expense',
          reference: 'INV-102',
          vendor: 'Local Transport',
          paidThrough: 'Petty Cash',
          customer: '',
          status: 'PAID',
          amount: 150000.0,
          projectCode: 'PRJ-2026-001',
          projectId: 'p_1',
        ),
      ];

      final categoryBudgets = {
        'Material Procurement': 600000.0,
        'Machinery, Equipment & Fuel': 300000.0,
        'Site Operations & Consumables': 100000.0,
      };

      final bva = ProjectBudgetVsActual.calculate(
        projectId: 'p_1',
        projectCode: 'PRJ-2026-001',
        projectName: 'Pipeline Alpha',
        contractValue: 1500000.0,
        allocatedBudget: 1000000.0,
        projectApprovedFunds: fundRequests,
        projectDirectExpenses: expenses,
        categoryBudgets: categoryBudgets,
      );

      // Verify confirmed business rules
      expect(bva.allocatedBudget, 1000000.0);
      expect(bva.approvedFunds, 600000.0);
      expect(bva.actualExpenses, 450000.0);
      expect(bva.remainingBudget, 550000.0);
      expect(bva.utilizationPercentage, 45.0);
      expect(bva.unspentFunds, 150000.0);
      expect(bva.isOverBudget, false);

      // Verify category-wise mapping
      final matCat = bva.categoryBreakdown.firstWhere((c) => c.category == 'Material Procurement');
      expect(matCat.allocatedBudget, 600000.0);
      expect(matCat.actualExpenses, 300000.0);
      expect(matCat.remainingBudget, 300000.0);
      expect(matCat.utilizationPercentage, 50.0);

      final machCat = bva.categoryBreakdown.firstWhere((c) => c.category == 'Machinery, Equipment & Fuel');
      expect(machCat.allocatedBudget, 300000.0);
      expect(machCat.actualExpenses, 150000.0);
      expect(machCat.remainingBudget, 150000.0);
      expect(machCat.utilizationPercentage, 50.0);
    });

    test('Safely handles zero budget without division by zero', () {
      final bva = ProjectBudgetVsActual.calculate(
        projectId: 'p_2',
        projectCode: 'PRJ-2026-002',
        projectName: 'Unbudgeted Project',
        contractValue: 500000.0,
        allocatedBudget: 0.0,
        projectApprovedFunds: [],
        projectDirectExpenses: [],
        categoryBudgets: {},
      );

      expect(bva.allocatedBudget, 0.0);
      expect(bva.actualExpenses, 0.0);
      expect(bva.remainingBudget, 0.0);
      expect(bva.utilizationPercentage, 0.0);
      expect(bva.unspentFunds, 0.0);
      expect(bva.isOverBudget, false);
    });

    test('Correctly identifies over-budget status when actuals exceed allocation', () {
      final expenses = [
        Expense(
          id: 103,
          date: DateTime(2026, 2, 1),
          account: 'Travel Expense',
          reference: 'INV-103',
          vendor: 'Hotel',
          paidThrough: 'Credit Card',
          customer: '',
          status: 'PAID',
          amount: 250000.0,
          projectCode: 'PRJ-2026-003',
        ),
      ];

      final bva = ProjectBudgetVsActual.calculate(
        projectId: 'p_3',
        projectCode: 'PRJ-2026-003',
        projectName: 'Site Beta',
        contractValue: 300000.0,
        allocatedBudget: 200000.0,
        projectApprovedFunds: [],
        projectDirectExpenses: expenses,
        categoryBudgets: {'Site Operations & Consumables': 200000.0},
      );

      expect(bva.allocatedBudget, 200000.0);
      expect(bva.actualExpenses, 250000.0);
      expect(bva.remainingBudget, -50000.0);
      expect(bva.utilizationPercentage, 125.0);
      expect(bva.isOverBudget, true);
    });

    test('Normalizes various category strings to standard heads accurately', () {
      expect(ProjectBudgetVsActual.normalizeCategory('hdpe pipe procurement'), 'Material Procurement');
      expect(ProjectBudgetVsActual.normalizeCategory('Factory Expenses'), 'Material Procurement');
      expect(ProjectBudgetVsActual.normalizeCategory('HDD labor works'), 'Subcontractor & Labor Services');
      expect(ProjectBudgetVsActual.normalizeCategory('Diesel Fuel for Generator'), 'Machinery, Equipment & Fuel');
      expect(ProjectBudgetVsActual.normalizeCategory('NHAI Crossing statutory fees'), 'Permits & Statutory Fees');
      expect(ProjectBudgetVsActual.normalizeCategory('Travel Expense'), 'Site Operations & Consumables');
      expect(ProjectBudgetVsActual.normalizeCategory('Contingency Reserve'), 'Contingency Reserve');
      expect(ProjectBudgetVsActual.normalizeCategory('random unknown'), 'Other Execution Costs');
    });
  });
}
