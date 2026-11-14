import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/firebase_project_repository.dart';
import '../domain/models/daily_progress_entry.dart';
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

/// Real-time stream of all site projects.
final projectsStreamProvider = StreamProvider<List<SiteProject>>((ref) {
  final repo = ref.watch(projectRepositoryProvider);
  return repo.watchProjects();
});

/// Projects filtered by [selectedDivisionFilterProvider].
final filteredProjectsByDivisionProvider = Provider<AsyncValue<List<SiteProject>>>((ref) {
  final division = ref.watch(selectedDivisionFilterProvider);
  final projectsAsync = ref.watch(projectsStreamProvider);
  return projectsAsync.whenData((projects) {
    if (division == null || division.isEmpty || division == 'All') {
      return projects;
    }
    return projects.where((p) => p.division == division).toList();
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
