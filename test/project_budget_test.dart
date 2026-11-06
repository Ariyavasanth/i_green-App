import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/projects/domain/models/project_budget.dart';
import 'package:flutter_application_1/features/projects/domain/models/site_project.dart';

void main() {
  group('ProjectBudgetItem Model Tests', () {
    test('creates item and computes percent of contract value correctly', () {
      final item = ProjectBudgetItem.create(
        category: 'Materials',
        description: 'HDPE Ducts & Joint Closures',
        allocatedAmount: 300000.0,
        contractValue: 1000000.0,
        remarks: '80% of client breakdown supply',
      );

      expect(item.id.isNotEmpty, true);
      expect(item.category, 'Materials');
      expect(item.description, 'HDPE Ducts & Joint Closures');
      expect(item.allocatedAmount, 300000.0);
      expect(item.remarks, '80% of client breakdown supply');
      // 3,00,000 on a 10,00,000 contract is 30.0%
      expect(item.percentageOfContract, 30.0);
    });

    test('toJson and fromJson preserves all fields', () {
      const item = ProjectBudgetItem(
        id: 'bg_01',
        category: 'Services',
        description: 'HDD Drilling Subcontract',
        allocatedAmount: 450000.0,
        percentageOfContract: 45.0,
        remarks: 'Contractor quotation verified',
      );

      final json = item.toJson();
      expect(json['id'], 'bg_01');
      expect(json['category'], 'Services');
      expect(json['description'], 'HDD Drilling Subcontract');
      expect(json['allocated_amount'], 450000.0);
      expect(json['percentage_of_contract'], 45.0);
      expect(json['remarks'], 'Contractor quotation verified');

      final reconstructed = ProjectBudgetItem.fromJson(json);
      expect(reconstructed.id, 'bg_01');
      expect(reconstructed.category, 'Services');
      expect(reconstructed.description, 'HDD Drilling Subcontract');
      expect(reconstructed.allocatedAmount, 450000.0);
      expect(reconstructed.percentageOfContract, 45.0);
      expect(reconstructed.remarks, 'Contractor quotation verified');
    });

    test('copyWith properly updates item properties', () {
      const item = ProjectBudgetItem(
        id: 'bg_02',
        category: 'Labour',
        description: 'Splicing Technicians',
        allocatedAmount: 50000.0,
      );

      final updated = item.copyWith(
        allocatedAmount: 65000.0,
        remarks: 'Revised for 2 additional days',
      );

      expect(updated.id, 'bg_02');
      expect(updated.allocatedAmount, 65000.0);
      expect(updated.remarks, 'Revised for 2 additional days');
      expect(updated.category, 'Labour');
    });
  });

  group('ProjectBudget Model & Profitability Tests', () {
    test('calculates total budget and totals per category accurately', () {
      final items = <ProjectBudgetItem>[
        const ProjectBudgetItem(
          id: '1',
          category: 'Materials',
          description: 'Cables & Hardware',
          allocatedAmount: 400000.0,
        ),
        const ProjectBudgetItem(
          id: '2',
          category: 'Services',
          description: 'Trenching & HDD',
          allocatedAmount: 300000.0,
        ),
        const ProjectBudgetItem(
          id: '3',
          category: 'Labour',
          description: 'Site Technicians',
          allocatedAmount: 50000.0,
        ),
        const ProjectBudgetItem(
          id: '4',
          category: 'Contingency',
          description: 'Buffer (3%)',
          allocatedAmount: 30000.0,
        ),
      ];

      final budget = ProjectBudget(
        items: items,
        status: BudgetStatus.approved,
        approvedBy: 'EMP-001',
        approvedAt: DateTime(2026, 3, 15),
      );

      expect(budget.totalBudget, 780000.0);
      expect(budget.budgetForCategory('Materials'), 400000.0);
      expect(budget.budgetForCategory('Services'), 300000.0);
      expect(budget.budgetForCategory('Labour'), 50000.0);
      expect(budget.budgetForCategory('Contingency'), 30000.0);
      expect(budget.budgetForCategory('Equipment'), 0.0);
    });

    test('calculates planned gross profit and margin percentage against contract value', () {
      final budget = ProjectBudget(
        items: const [
          ProjectBudgetItem(
            id: '1',
            category: 'Materials',
            description: 'Materials',
            allocatedAmount: 600000.0,
          ),
          ProjectBudgetItem(
            id: '2',
            category: 'Services',
            description: 'Works',
            allocatedAmount: 200000.0,
          ),
        ],
      );

      const contractValue = 1000000.0;
      // Total budget = 8,00,000. Planned Profit = 10,00,000 - 8,00,000 = 2,00,000
      expect(budget.totalBudget, 800000.0);
      expect(budget.plannedProfit(contractValue), 200000.0);
      // Margin = 2,00,000 / 10,00,000 * 100 = 20.0%
      expect(budget.plannedMarginPercentage(contractValue), 20.0);

      // Edge case: 0 contract value
      expect(budget.plannedMarginPercentage(0), 0.0);
    });

    test('toJson and fromJson preserves all budget items and approval metadata', () {
      final original = ProjectBudget(
        items: const [
          ProjectBudgetItem(
            id: 'b1',
            category: 'Equipment',
            description: 'OTDR & Splicing Machine Rent',
            allocatedAmount: 40000.0,
          ),
        ],
        status: BudgetStatus.approved,
        approvalNotes: 'Sanctioned by Management',
        approvedBy: 'Director',
        approvedAt: DateTime(2026, 4, 1),
      );

      final json = original.toJson();
      expect(json['status'], 'approved');
      expect(json['approval_notes'], 'Sanctioned by Management');
      expect(json['approved_by'], 'Director');
      expect(json['approved_at'], isNotNull);
      expect((json['items'] as List).length, 1);

      final reconstructed = ProjectBudget.fromJson(json);
      expect(reconstructed.status, BudgetStatus.approved);
      expect(reconstructed.approvalNotes, 'Sanctioned by Management');
      expect(reconstructed.approvedBy, 'Director');
      expect(reconstructed.totalBudget, 40000.0);
      expect(reconstructed.items.first.description, 'OTDR & Splicing Machine Rent');
    });
  });

  group('SiteProject Integration with ProjectBudget', () {
    test('SiteProject serializes and deserializes budget correctly', () {
      final project = SiteProject(
        id: 'prj_test_100',
        projectCode: 'PRJ-2026-050',
        employeeName: 'Ramesh K',
        clientName: 'BSNL Telecom',
        generalCode: 'GC-100',
        actualProjectValue: 2500000.0,
        budget: const ProjectBudget(
          items: [
            ProjectBudgetItem(
              id: 'item_1',
              category: 'Materials',
              description: 'OFC & Accessories',
              allocatedAmount: 900000.0,
            ),
            ProjectBudgetItem(
              id: 'item_2',
              category: 'Services',
              description: 'Directional Drilling',
              allocatedAmount: 1000000.0,
            ),
          ],
          status: BudgetStatus.draft,
        ),
      );

      expect(project.budget, isNotNull);
      expect(project.budget!.totalBudget, 1900000.0);
      expect(project.budget!.plannedProfit(project.contractValue), 600000.0);

      final json = project.toJson();
      expect(json['budget'], isNotNull);

      final reconstructed = SiteProject.fromJson(json, docId: 'prj_test_100');
      expect(reconstructed.budget, isNotNull);
      expect(reconstructed.budget!.totalBudget, 1900000.0);
      expect(reconstructed.budget!.status, BudgetStatus.draft);
      expect(reconstructed.budget!.items.length, 2);
    });

    test('SiteProject copyWith updates budget', () {
      final project = SiteProject(
        id: 'prj_test_101',
        projectCode: 'PRJ-2026-051',
        employeeName: 'Ramesh K',
        clientName: 'BSNL Telecom',
        generalCode: 'GC-101',
        actualProjectValue: 1500000.0,
      );

      expect(project.budget, isNull);

      final updated = project.copyWith(
        budget: const ProjectBudget(
          items: [
            ProjectBudgetItem(
              id: 'i1',
              category: 'Services',
              description: 'River HDD Execution',
              allocatedAmount: 1100000.0,
            ),
          ],
        ),
      );

      expect(updated.budget, isNotNull);
      expect(updated.budget!.totalBudget, 1100000.0);
    });
  });
}
