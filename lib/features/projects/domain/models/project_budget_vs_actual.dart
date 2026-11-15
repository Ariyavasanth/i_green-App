import 'package:flutter/foundation.dart';

@immutable
class CategoryBudgetVsActual {
  const CategoryBudgetVsActual({
    required this.category,
    required this.allocatedBudget,
    required this.approvedFunds,
    required this.actualExpenses,
    required this.remainingBudget,
    required this.utilizationPercentage,
    required this.unspentFunds,
  });

  final String category;
  final double allocatedBudget;
  final double approvedFunds;
  final double actualExpenses;
  final double remainingBudget;
  final double utilizationPercentage;
  final double unspentFunds;

  bool get isOverBudget => actualExpenses > allocatedBudget && allocatedBudget > 0;
}

@immutable
class ProjectBudgetVsActual {
  const ProjectBudgetVsActual({
    required this.projectId,
    required this.projectCode,
    required this.projectName,
    required this.contractValue,
    required this.allocatedBudget,
    required this.approvedFunds,
    required this.actualExpenses,
    required this.remainingBudget,
    required this.utilizationPercentage,
    required this.unspentFunds,
    required this.categoryBreakdown,
  });

  final String projectId;
  final String projectCode;
  final String projectName;
  final double contractValue;
  final double allocatedBudget;
  final double approvedFunds;
  final double actualExpenses;
  final double remainingBudget;
  final double utilizationPercentage;
  final double unspentFunds;
  final List<CategoryBudgetVsActual> categoryBreakdown;

  bool get isOverBudget => actualExpenses > allocatedBudget && allocatedBudget > 0;
  bool get hasBudget => allocatedBudget > 0;

  static const List<String> standardCategories = [
    'Material Procurement',
    'Subcontractor & Labor Services',
    'Machinery, Equipment & Fuel',
    'Permits & Statutory Fees',
    'Site Operations & Consumables',
    'Contingency Reserve',
    'Other Execution Costs',
  ];

  /// Normalize heterogeneous expense account names and fund request categories into standard BOQ heads.
  static String normalizeCategory(String? input) {
    if (input == null || input.trim().isEmpty) {
      return 'Other Execution Costs';
    }
    final lower = input.toLowerCase().trim();

    if (lower.contains('material') ||
        lower.contains('procurement') ||
        lower.contains('pipe') ||
        lower.contains('casing') ||
        lower.contains('supply') ||
        lower.contains('supplies') ||
        lower.contains('factory')) {
      return 'Material Procurement';
    }

    if (lower.contains('subcontractor') ||
        lower.contains('labor') ||
        lower.contains('labour') ||
        lower.contains('manpower') ||
        lower.contains('welder') ||
        lower.contains('civil') ||
        lower.contains('hdd') ||
        lower.contains('service')) {
      return 'Subcontractor & Labor Services';
    }

    if (lower.contains('machinery') ||
        lower.contains('machine') ||
        lower.contains('equipment') ||
        lower.contains('fuel') ||
        lower.contains('diesel') ||
        lower.contains('petrol') ||
        lower.contains('transport') ||
        lower.contains('vehicle') ||
        lower.contains('crane') ||
        lower.contains('rig')) {
      return 'Machinery, Equipment & Fuel';
    }

    if (lower.contains('permit') ||
        lower.contains('statutory') ||
        lower.contains('license') ||
        lower.contains('licence') ||
        lower.contains('govt') ||
        lower.contains('rto') ||
        lower.contains('nhai') ||
        lower.contains('fee')) {
      return 'Permits & Statutory Fees';
    }

    if (lower.contains('operation') ||
        lower.contains('travel') ||
        lower.contains('food') ||
        lower.contains('stay') ||
        lower.contains('hotel') ||
        lower.contains('office') ||
        lower.contains('consumable') ||
        lower.contains('site') ||
        lower.contains('petty')) {
      return 'Site Operations & Consumables';
    }

    if (lower.contains('contingency') ||
        lower.contains('reserve') ||
        lower.contains('unforeseen')) {
      return 'Contingency Reserve';
    }

    return 'Other Execution Costs';
  }

  /// Calculates real-time Budget vs Actual metrics for a [SiteProject]
  /// using approved portions of FundRequests and project-linked Expenses.
  factory ProjectBudgetVsActual.calculate({
    required String projectId,
    required String projectCode,
    required String projectName,
    required double contractValue,
    required double allocatedBudget,
    required List<dynamic> projectApprovedFunds, // List<FundRequest>
    required List<dynamic> projectDirectExpenses, // List<Expense>
    required Map<String, double> categoryBudgets,
  }) {
    double totalApprovedFunds = 0.0;
    final Map<String, double> catFundsMap = {
      for (final c in standardCategories) c: 0.0,
    };

    for (final req in projectApprovedFunds) {
      final approvedAmt = (req.approvedAmount as num?)?.toDouble() ?? 0.0;
      totalApprovedFunds += approvedAmt;

      // Attribute approved items by category
      final items = req.items as List<dynamic>? ?? [];
      for (final item in items) {
        final cat = normalizeCategory(item.category as String?);
        final amt = (item.amount as num?)?.toDouble() ?? 0.0;
        catFundsMap[cat] = (catFundsMap[cat] ?? 0.0) + amt;
      }
    }

    double totalActualExpenses = 0.0;
    final Map<String, double> catExpensesMap = {
      for (final c in standardCategories) c: 0.0,
    };

    for (final exp in projectDirectExpenses) {
      final amt = (exp.amount as num?)?.toDouble() ?? 0.0;
      totalActualExpenses += amt;
      final cat = normalizeCategory(exp.account as String?);
      catExpensesMap[cat] = (catExpensesMap[cat] ?? 0.0) + amt;
    }

    final remainingBudget = allocatedBudget - totalActualExpenses;
    final utilizationPct = allocatedBudget > 0
        ? ((totalActualExpenses / allocatedBudget) * 10000).roundToDouble() / 100
        : 0.0;
    final unspentFunds = totalApprovedFunds - totalActualExpenses;

    final breakdown = standardCategories.map((cat) {
      final catBudget = categoryBudgets[cat] ?? 0.0;
      final catActual = catExpensesMap[cat] ?? 0.0;
      final catFund = catFundsMap[cat] ?? 0.0;
      final catRem = catBudget - catActual;
      final catUtil = catBudget > 0
          ? ((catActual / catBudget) * 10000).roundToDouble() / 100
          : 0.0;
      final catUnspent = catFund - catActual;

      return CategoryBudgetVsActual(
        category: cat,
        allocatedBudget: catBudget,
        approvedFunds: catFund,
        actualExpenses: catActual,
        remainingBudget: catRem,
        utilizationPercentage: catUtil,
        unspentFunds: catUnspent,
      );
    }).toList();

    return ProjectBudgetVsActual(
      projectId: projectId,
      projectCode: projectCode,
      projectName: projectName,
      contractValue: contractValue,
      allocatedBudget: allocatedBudget,
      approvedFunds: totalApprovedFunds,
      actualExpenses: totalActualExpenses,
      remainingBudget: remainingBudget,
      utilizationPercentage: utilizationPct,
      unspentFunds: unspentFunds,
      categoryBreakdown: breakdown,
    );
  }
}
