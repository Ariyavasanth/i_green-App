import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../projects/domain/models/daily_progress_entry.dart';
import '../../projects/domain/models/project_compliance_record.dart';
import '../../projects/providers/project_providers.dart';
import '../data/repositories/firebase_project_incentive_repository.dart';
import '../domain/models/project_incentive_record.dart';
import '../domain/models/project_incentive_settings.dart';
import '../domain/repositories/project_incentive_repository.dart';
import '../domain/services/project_incentive_calculator.dart';

final projectIncentiveRepositoryProvider =
    Provider<ProjectIncentiveRepository>((ref) {
  final projectRepo = ref.watch(projectRepositoryProvider);
  return FirebaseProjectIncentiveRepository(
    projectRepository: projectRepo,
  );
});

final projectIncentiveSettingsStreamProvider =
    StreamProvider<ProjectIncentiveSettings>((ref) {
  final repo = ref.watch(projectIncentiveRepositoryProvider);
  return repo.watchSettings();
});

/// Real-time stream of all saved incentive records
final projectIncentiveRecordsStreamProvider =
    StreamProvider<List<ProjectIncentiveRecord>>((ref) {
  final repo = ref.watch(projectIncentiveRepositoryProvider);
  return repo.watchIncentiveRecords();
});

/// Dynamic live calculated incentive records derived directly from projects,
/// approved daily progress, timely bills, payment collection, and incidents.
final liveProjectIncentivesStreamProvider =
    StreamProvider<List<ProjectIncentiveRecord>>((ref) async* {
  final projectsAsync = ref.watch(projectsStreamProvider);
  final settingsAsync = ref.watch(projectIncentiveSettingsStreamProvider);
  final repo = ref.watch(projectIncentiveRepositoryProvider);

  final projects = projectsAsync.valueOrNull ?? [];
  final settings = settingsAsync.valueOrNull ?? const ProjectIncentiveSettings();

  // If projects are available, compute dynamic incentive state for each
  final results = <ProjectIncentiveRecord>[];

  for (final project in projects) {
    List<DailyProgressEntry> dailyEntries = [];
    List<IncidentLogEntry> incidents = [];

    final projectRepo = ref.watch(projectRepositoryProvider);
    try {
      dailyEntries = await projectRepo.watchDailyProgress(project.projectCode).first;
    } catch (_) {}

    try {
      incidents = await projectRepo.watchIncidents(project.projectCode).first;
    } catch (_) {}

    final record = ProjectIncentiveCalculator.calculate(
      project: project,
      dailyProgressEntries: dailyEntries,
      incidents: incidents,
      settings: settings,
    );
    results.add(record);
  }

  // If live results are empty, fall back to repo stream
  if (results.isEmpty) {
    yield* repo.watchIncentiveRecords();
  } else {
    results.sort((a, b) => b.calculatedAt.compareTo(a.calculatedAt));
    yield results;
  }
});

/// Filter state providers
final incentiveSearchQueryProvider = StateProvider<String>((ref) => '');
final incentiveStatusFilterProvider = StateProvider<String>((ref) => 'ALL'); // 'ALL' | 'ELIGIBLE' | 'DISQUALIFIED' | 'ON_HOLD'
final incentiveDivisionFilterProvider = StateProvider<String?>((ref) => null);

/// Filtered incentive records
final filteredProjectIncentivesProvider =
    Provider<List<ProjectIncentiveRecord>>((ref) {
  final recordsAsync = ref.watch(liveProjectIncentivesStreamProvider);
  final records = recordsAsync.valueOrNull ?? [];
  final query = ref.watch(incentiveSearchQueryProvider).trim().toLowerCase();
  final statusFilter = ref.watch(incentiveStatusFilterProvider);
  final divisionFilter = ref.watch(incentiveDivisionFilterProvider);

  return records.where((r) {
    if (divisionFilter != null &&
        divisionFilter.isNotEmpty &&
        r.division.toLowerCase() != divisionFilter.toLowerCase()) {
      return false;
    }

    if (statusFilter == 'ELIGIBLE' && r.isDisqualified) return false;
    if (statusFilter == 'DISQUALIFIED' && !r.isDisqualified) return false;
    if (statusFilter == 'ON_HOLD' && r.status != 'ON_HOLD') return false;

    if (query.isNotEmpty) {
      final code = r.projectCode.toLowerCase();
      final name = r.projectName.toLowerCase();
      final client = r.clientName.toLowerCase();
      final assigned = r.assignedEmployeeNames.join(' ').toLowerCase();
      if (!code.contains(query) &&
          !name.contains(query) &&
          !client.contains(query) &&
          !assigned.contains(query)) {
        return false;
      }
    }

    return true;
  }).toList();
});

class ProjectIncentiveMetrics {
  final double totalNetPayable;
  final double totalGrossIncentive;
  final int totalProjects;
  final int eligibleCount;
  final int disqualifiedCount;
  final double totalRestorationCostTracked;
  final int totalIncidentsRecorded;
  final double timelyBillComplianceRate;
  final double averagePaymentCollectionRate;

  const ProjectIncentiveMetrics({
    this.totalNetPayable = 0.0,
    this.totalGrossIncentive = 0.0,
    this.totalProjects = 0,
    this.eligibleCount = 0,
    this.disqualifiedCount = 0,
    this.totalRestorationCostTracked = 0.0,
    this.totalIncidentsRecorded = 0,
    this.timelyBillComplianceRate = 0.0,
    this.averagePaymentCollectionRate = 0.0,
  });
}

final projectIncentiveMetricsProvider = Provider<ProjectIncentiveMetrics>((ref) {
  final recordsAsync = ref.watch(liveProjectIncentivesStreamProvider);
  final records = recordsAsync.valueOrNull ?? [];

  if (records.isEmpty) {
    return const ProjectIncentiveMetrics();
  }

  double totalNet = 0.0;
  double totalGross = 0.0;
  int eligible = 0;
  int disqualified = 0;
  double totalRestoration = 0.0;
  int totalIncidents = 0;
  int timelyBills = 0;
  double totalCollectionPct = 0.0;

  for (final r in records) {
    totalNet += r.netPayableIncentive;
    totalGross += r.grossEarnedIncentive;
    if (r.isDisqualified) {
      disqualified++;
    } else {
      eligible++;
    }
    totalRestoration += r.totalRestorationCost;
    totalIncidents += r.incidentCount;
    if (r.isBillTimely) {
      timelyBills++;
    }
    totalCollectionPct += r.paymentCollectionPercentage;
  }

  return ProjectIncentiveMetrics(
    totalNetPayable: totalNet,
    totalGrossIncentive: totalGross,
    totalProjects: records.length,
    eligibleCount: eligible,
    disqualifiedCount: disqualified,
    totalRestorationCostTracked: totalRestoration,
    totalIncidentsRecorded: totalIncidents,
    timelyBillComplianceRate:
        records.isNotEmpty ? (timelyBills / records.length * 100.0) : 0.0,
    averagePaymentCollectionRate:
        records.isNotEmpty ? (totalCollectionPct / records.length) : 0.0,
  );
});

/// Individual project live calculation provider
final projectIncentiveCalculationProvider =
    FutureProvider.family<ProjectIncentiveRecord, String>((ref, projectCode) async {
  final projectRepo = ref.watch(projectRepositoryProvider);
  final settings = await ref.watch(projectIncentiveSettingsStreamProvider.future);

  final projects = await projectRepo.getProjects();
  final project = projects.firstWhere(
    (p) => p.projectCode == projectCode || p.id == projectCode,
    orElse: () => throw Exception('Project not found: $projectCode'),
  );

  List<DailyProgressEntry> dailyEntries = [];
  List<IncidentLogEntry> incidents = [];

  try {
    dailyEntries = await projectRepo.watchDailyProgress(project.projectCode).first;
  } catch (_) {}

  try {
    incidents = await projectRepo.watchIncidents(project.projectCode).first;
  } catch (_) {}

  return ProjectIncentiveCalculator.calculate(
    project: project,
    dailyProgressEntries: dailyEntries,
    incidents: incidents,
    settings: settings,
  );
});
