import 'hierarchy_node.dart';

/// Represents the complete organizational tree for an organization.
class HierarchyTree {
  const HierarchyTree({
    required this.organizationId,
    required this.organizationName,
    required this.rootNodes,
    required this.totalEmployees,
    required this.departmentsCount,
    this.maxDepth = 0,
    this.hasCycles = false,
    this.hasMissingManagers = false,
  });

  final String organizationId;
  final String organizationName;
  final List<HierarchyNode> rootNodes;
  final int totalEmployees;
  final int departmentsCount;
  final int maxDepth;
  final bool hasCycles;
  final bool hasMissingManagers;

  bool get isEmpty => rootNodes.isEmpty;
  bool get isNotEmpty => rootNodes.isNotEmpty;

  /// Flatten all nodes in the tree.
  List<HierarchyNode> get allNodes {
    final list = <HierarchyNode>[];
    void collect(HierarchyNode node) {
      list.add(node);
      for (final child in node.children) {
        collect(child);
      }
    }

    for (final root in rootNodes) {
      collect(root);
    }
    return list;
  }

  /// Finds a specific node by employeeId, numeric ID, or email.
  HierarchyNode? findNode(String identifier) {
    final target = identifier.trim().toLowerCase();
    if (target.isEmpty) return null;

    HierarchyNode? search(HierarchyNode node) {
      final emp = node.employee;
      if (emp.employeeId.trim().toLowerCase() == target ||
          emp.id.toString() == target ||
          emp.emailAddress.trim().toLowerCase() == target) {
        return node;
      }
      for (final child in node.children) {
        final res = search(child);
        if (res != null) return res;
      }
      return null;
    }

    for (final root in rootNodes) {
      final res = search(root);
      if (res != null) return res;
    }
    return null;
  }
}
