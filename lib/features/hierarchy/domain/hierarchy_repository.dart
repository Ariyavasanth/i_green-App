import 'hierarchy_node.dart';
import 'hierarchy_tree.dart';

/// Abstract interface for the Hierarchy feature following Clean Architecture.
abstract interface class HierarchyRepository {
  /// Builds the complete organizational tree for a given organization.
  Future<HierarchyTree> getHierarchyTree({
    String? organizationId,
    String? organizationName,
  });

  /// Retrieves the linear reporting chain from a given employee up to the highest authority (e.g. Band 7).
  Future<List<HierarchyNode>> getReportingChain(
    String employeeId, {
    String? organizationId,
    String? organizationName,
  });

  /// Retrieves the immediate direct reports for a specific manager.
  Future<List<HierarchyNode>> getDirectReports(
    String employeeId, {
    String? organizationId,
    String? organizationName,
  });
}
