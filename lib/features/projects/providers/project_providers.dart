import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/firebase_project_repository.dart';
import '../domain/models/site_project.dart';
import '../domain/repositories/project_repository.dart';

/// Provider for the [ProjectRepository] interface, defaulting to [FirebaseProjectRepository].
final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return FirebaseProjectRepository();
});

/// Real-time stream of all site projects.
final projectsStreamProvider = StreamProvider<List<SiteProject>>((ref) {
  final repo = ref.watch(projectRepositoryProvider);
  return repo.watchProjects();
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
