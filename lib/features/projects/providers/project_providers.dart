import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../expenses/providers/expense_providers.dart';
import '../../fund_requester/providers/fund_request_providers.dart';
import '../data/repositories/firebase_project_repository.dart';
import '../domain/models/daily_progress_entry.dart';
import '../domain/models/project_budget_vs_actual.dart';
import '../domain/models/project_compliance_record.dart';
import '../domain/models/project_inventory_item.dart';
import '../domain/models/site_project.dart';
import '../domain/repositories/project_repository.dart';

/// Provider for the [ProjectRepository] interface, defaulting to [FirebaseProjectRepository].
final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return FirebaseProjectRepository();
});

/// Selected division filter across project lists and reports (null = All).
final selectedDivisionFilterProvider = StateProvider<String?>((ref) => null);

/// Filter for dashboard KPI cards.
enum ProjectKpiFilter {
  all,
  live,
  pendingBills,
  retentionDue,
  bgExpiring,
}

final projectKpiFilterProvider =
    StateProvider<ProjectKpiFilter>((ref) => ProjectKpiFilter.all);

/// Real-time stream of all site projects.
final projectsStreamProvider = StreamProvider<List<SiteProject>>((ref) {
  final repo = ref.watch(projectRepositoryProvider);
  return repo.watchProjects();
});

/// Projects filtered by [selectedDivisionFilterProvider].
final filteredProjectsByDivisionProvider =
    Provider<AsyncValue<List<SiteProject>>>((ref) {
  final division = ref.watch(selectedDivisionFilterProvider);
  final projectsAsync = ref.watch(projectsStreamProvider);
  return projectsAsync.whenData((projects) {
    if (division == null || division.isEmpty || division == 'All') {
      return projects;
    }
    return projects.where((p) => p.division == division).toList();
  });
});

/// Metrics aggregated for the currently selected division.
class DivisionMetrics {
  final int totalProjects;
  final int liveProjectsCount;
  final int pendingBillsCount;
  final double pendingBillsAmount;
  final int retentionDueCount;
  final double retentionDueTotalAmount;
  final int bgExpiringCount;

  const DivisionMetrics({
    this.totalProjects = 0,
    this.liveProjectsCount = 0,
    this.pendingBillsCount = 0,
    this.pendingBillsAmount = 0.0,
    this.retentionDueCount = 0,
    this.retentionDueTotalAmount = 0.0,
    this.bgExpiringCount = 0,
  });
}

/// Helper functions to evaluate project status for KPIs.
bool isProjectLive(SiteProject p) {
  return p.status == 'Active' || p.effectiveStatus == 'Active';
}

bool isProjectBillPending(SiteProject p) {
  final hasBill = p.billingDetailsDocuments.isNotEmpty ||
      p.flowOfBillsStatus.trim().isNotEmpty;
  if (!hasBill) return false;
  if (p.status == 'Closed') return false;
  final contract = p.contractValue;
  if (contract > 0 && p.paymentAmount >= contract) return false;
  return p.paymentReceivedDate == null || p.paymentAmount < contract;
}

double getProjectPendingBillAmount(SiteProject p) {
  if (!isProjectBillPending(p)) return 0.0;
  final diff = p.contractValue - p.paymentAmount;
  return diff > 0 ? diff : 0.0;
}

bool isProjectRetentionDue(SiteProject p) {
  final totalRet =
      p.sdRetentionAmount + p.emdRetentionAmount + p.otherRetentionAmount;
  return totalRet > 0 && p.status != 'Closed';
}

double getProjectRetentionAmount(SiteProject p) {
  return p.sdRetentionAmount + p.emdRetentionAmount + p.otherRetentionAmount;
}

bool isProjectBgOrSdExpiring(SiteProject p) {
  if (p.shouldAutoReopenForRetention) return true;
  final now = DateTime.now();
  final threshold = now.add(const Duration(days: 30));
  final dates = [
    p.sdRetentionDate,
    p.emdRetentionDate,
    p.otherRetentionDate,
    p.sdAgreementDate,
  ];
  return dates.any((d) => d != null && !d.isAfter(threshold));
}

/// Provider computing division-wise metrics reactively in memory without extra Firestore calls.
final divisionMetricsProvider = Provider<DivisionMetrics>((ref) {
  final projects =
      ref.watch(filteredProjectsByDivisionProvider).valueOrNull ?? [];
  if (projects.isEmpty) return const DivisionMetrics();

  int live = 0;
  int pendingBills = 0;
  double pendingBillsAmt = 0.0;
  int retentionCount = 0;
  double retentionAmt = 0.0;
  int bgExpiring = 0;

  for (final p in projects) {
    if (isProjectLive(p)) live++;
    if (isProjectBillPending(p)) {
      pendingBills++;
      pendingBillsAmt += getProjectPendingBillAmount(p);
    }
    if (isProjectRetentionDue(p)) {
      retentionCount++;
      retentionAmt += getProjectRetentionAmount(p);
    }
    if (isProjectBgOrSdExpiring(p)) {
      bgExpiring++;
    }
  }

  return DivisionMetrics(
    totalProjects: projects.length,
    liveProjectsCount: live,
    pendingBillsCount: pendingBills,
    pendingBillsAmount: pendingBillsAmt,
    retentionDueCount: retentionCount,
    retentionDueTotalAmount: retentionAmt,
    bgExpiringCount: bgExpiring,
  );
});

/// Projects filtered by division AND active KPI card filter.
final filteredProjectsWithKpiProvider =
    Provider<AsyncValue<List<SiteProject>>>((ref) {
  final kpi = ref.watch(projectKpiFilterProvider);
  final projectsAsync = ref.watch(filteredProjectsByDivisionProvider);

  return projectsAsync.whenData((projects) {
    switch (kpi) {
      case ProjectKpiFilter.live:
        return projects.where(isProjectLive).toList();
      case ProjectKpiFilter.pendingBills:
        return projects.where(isProjectBillPending).toList();
      case ProjectKpiFilter.retentionDue:
        return projects.where(isProjectRetentionDue).toList();
      case ProjectKpiFilter.bgExpiring:
        return projects.where(isProjectBgOrSdExpiring).toList();
      case ProjectKpiFilter.all:
      default:
        return projects;
    }
  });
});

/// Provider for loaded Tender Types.
final tenderTypesProvider = FutureProvider<List<String>>((ref) {
  final repo = ref.watch(projectRepositoryProvider);
  return repo.getTenderTypes();
});

/// Provider for project sequence number used in code generation.
final projectSequenceProvider = FutureProvider<int>((ref) {
  final repo = ref.watch(projectRepositoryProvider);
  return repo.getNextProjectSequence();
});

/// Daily progress stream for a project code.
final dailyProgressStreamProvider =
    StreamProvider.family<List<DailyProgressEntry>, String>((ref, projectCode) {
  final repo = ref.watch(projectRepositoryProvider);
  return repo.watchDailyProgress(projectCode);
});

/// Project inventory stream for a project code.
final projectInventoryStreamProvider =
    StreamProvider.family<List<ProjectInventoryItem>, String>(
        (ref, projectCode) {
  final repo = ref.watch(projectRepositoryProvider);
  return repo.watchProjectInventory(projectCode);
});

/// Permissions stream for a project code.
final projectPermissionsStreamProvider =
    StreamProvider.family<List<ProjectPermission>, String>((ref, projectCode) {
  final repo = ref.watch(projectRepositoryProvider);
  return repo.watchPermissions(projectCode);
});

/// Insurance stream for a project code.
final projectInsuranceStreamProvider =
    StreamProvider.family<List<ProjectInsurance>, String>((ref, projectCode) {
  final repo = ref.watch(projectRepositoryProvider);
  return repo.watchInsurance(projectCode);
});

/// Incident log stream for a project code.
final projectIncidentsStreamProvider =
    StreamProvider.family<List<IncidentLogEntry>, String>((ref, projectCode) {
  final repo = ref.watch(projectRepositoryProvider);
  return repo.watchIncidents(projectCode);
});

/// Real-time Budget vs Actual metrics for all site projects.
final allProjectsBudgetVsActualProvider =
    Provider<AsyncValue<List<ProjectBudgetVsActual>>>((ref) {
  final projectsAsync = ref.watch(projectsStreamProvider);
  final fundsAsync = ref.watch(allFundRequestsStreamProvider);
  final expensesAsync = ref.watch(expensesStreamProvider);

  if (projectsAsync.isLoading || fundsAsync.isLoading || expensesAsync.isLoading) {
    return const AsyncValue.loading();
  }

  if (projectsAsync.hasError) {
    return AsyncValue.error(projectsAsync.error!, projectsAsync.stackTrace!);
  }
  if (fundsAsync.hasError) {
    return AsyncValue.error(fundsAsync.error!, fundsAsync.stackTrace!);
  }
  if (expensesAsync.hasError) {
    return AsyncValue.error(expensesAsync.error!, expensesAsync.stackTrace!);
  }

  final projects = projectsAsync.value ?? [];
  final funds = fundsAsync.value ?? [];
  final expenses = expensesAsync.value ?? [];

  final list = projects.map((p) {
    final projCode = p.projectCode.trim().toLowerCase();
    final projName = p.projectName.trim().toLowerCase();

    // Approved & Partially Approved funds for this project
    final matchingFunds = funds.where((f) {
      if (f.isDeleted) return false;
      final st = f.status.toLowerCase().trim();
      if (st != 'approved' && st != 'partially approved') return false;
      final fCode = f.projectCode.trim().toLowerCase();
      final fName = f.projectName.trim().toLowerCase();
      return (fCode.isNotEmpty && fCode == projCode) ||
          (fName.isNotEmpty && fName == projName);
    }).toList();

    // Direct expenses tagged with this project
    final matchingExpenses = expenses.where((e) {
      final eCode = e.projectCode.trim().toLowerCase();
      final eId = e.projectId.trim();
      return (eCode.isNotEmpty && eCode == projCode) ||
          (eId.isNotEmpty && eId == p.id);
    }).toList();

    // Category budgets
    final catBudgets = <String, double>{
      for (final c in ProjectBudgetVsActual.standardCategories) c: 0.0,
    };
    if (p.budget != null) {
      for (final item in p.budget!.items) {
        final cat = ProjectBudgetVsActual.normalizeCategory(item.category);
        catBudgets[cat] = (catBudgets[cat] ?? 0.0) + item.allocatedAmount;
      }
    }

    final allocated = p.budget?.totalBudget ?? 0.0;
    final contract = p.actualProjectValue > 0
        ? p.actualProjectValue
        : p.approximateProjectValue;

    return ProjectBudgetVsActual.calculate(
      projectId: p.id,
      projectCode: p.projectCode,
      projectName: p.projectName,
      contractValue: contract,
      allocatedBudget: allocated,
      projectApprovedFunds: matchingFunds,
      projectDirectExpenses: matchingExpenses,
      categoryBudgets: catBudgets,
    );
  }).toList();

  return AsyncValue.data(list);
});

/// Real-time Budget vs Actual metrics for a specific project ID.
final projectBudgetVsActualProvider =
    Provider.family<AsyncValue<ProjectBudgetVsActual?>, String>((ref, projectId) {
  final allAsync = ref.watch(allProjectsBudgetVsActualProvider);
  return allAsync.whenData((list) {
    try {
      return list.firstWhere((item) => item.projectId == projectId);
    } catch (_) {
      return null;
    }
  });
});
