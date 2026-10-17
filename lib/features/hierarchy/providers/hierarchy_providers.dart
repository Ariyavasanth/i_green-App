import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../employee/providers/employee_providers.dart';
import '../../organization/providers/organization_providers.dart';
import '../data/firebase_hierarchy_repository.dart';
import '../domain/hierarchy_node.dart';
import '../domain/hierarchy_repository.dart';
import '../domain/hierarchy_tree.dart';

/// Provider for the HierarchyRepository implementation.
final hierarchyRepositoryProvider = Provider<HierarchyRepository>((ref) {
  final empRepo = ref.watch(employeeRepositoryProvider);
  final orgRepo = ref.watch(organizationRepositoryProvider);
  return FirebaseHierarchyRepository(
    employeeRepository: empRepo,
    organizationRepository: orgRepo,
  );
});

/// Currently selected organization ID for hierarchy filtering.
final selectedHierarchyOrgIdProvider = StateProvider<String?>((ref) => null);

/// Search query string for filtering / highlighting nodes in the hierarchy.
final hierarchySearchQueryProvider = StateProvider<String>((ref) => '');

/// View Mode: 0 = "Company Tree" (full org chart), 1 = "My Reporting Chain" (linear path).
final hierarchyViewModeProvider = StateProvider<int>((ref) => 0);

/// Set of expanded node employee IDs.
final hierarchyExpandedNodeIdsProvider = StateProvider<Set<String>>((ref) => {});

/// Provider for the full company hierarchy tree.
final hierarchyTreeProvider = FutureProvider.autoDispose<HierarchyTree>((ref) async {
  final repo = ref.watch(hierarchyRepositoryProvider);
  final selectedOrgId = ref.watch(selectedHierarchyOrgIdProvider);
  final currentEmp = ref.watch(currentEmployeeProvider);

  String? effectiveOrgId = selectedOrgId;
  String? effectiveOrgName;

  // Default to logged-in user's organization if not explicitly selected
  if ((effectiveOrgId == null || effectiveOrgId.isEmpty || effectiveOrgId == 'All') &&
      currentEmp != null) {
    if (currentEmp.organizationId.isNotEmpty) {
      effectiveOrgId = currentEmp.organizationId;
    } else if (currentEmp.organizationName.isNotEmpty) {
      effectiveOrgName = currentEmp.organizationName;
    }
  }

  return repo.getHierarchyTree(
    organizationId: effectiveOrgId,
    organizationName: effectiveOrgName,
  );
});

/// Provider for the linear reporting chain from current user up to the highest authority.
final myReportingChainProvider =
    FutureProvider.autoDispose<List<HierarchyNode>>((ref) async {
      final repo = ref.watch(hierarchyRepositoryProvider);
      final currentEmp = ref.watch(currentEmployeeProvider);

      if (currentEmp == null || currentEmp.employeeId.trim().isEmpty) {
        return const [];
      }

      return repo.getReportingChain(
        currentEmp.employeeId,
        organizationId: currentEmp.organizationId.isNotEmpty
            ? currentEmp.organizationId
            : null,
        organizationName: currentEmp.organizationName.isNotEmpty
            ? currentEmp.organizationName
            : null,
      );
    });
