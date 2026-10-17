import 'package:flutter/material.dart';

import '../../domain/hierarchy_node.dart';
import '../../domain/hierarchy_tree.dart';
import 'employee_hierarchy_detail_sheet.dart';
import 'hierarchy_node_card.dart';

/// Responsive list-style indented outline view of the employee hierarchy.
class OrgOutlineTreeView extends StatelessWidget {
  const OrgOutlineTreeView({
    required this.tree,
    required this.expandedIds,
    required this.onToggleExpand,
    required this.searchQuery,
    super.key,
  });

  final HierarchyTree tree;
  final Set<String> expandedIds;
  final ValueChanged<String> onToggleExpand;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    if (tree.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFF1F5F9),
                ),
                child: const Icon(
                  Icons.group_off_outlined,
                  size: 36,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Employees Found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: tree.rootNodes.map((root) {
        return _buildOutlineNode(context, root, 0);
      }).toList(),
    );
  }

  Widget _buildOutlineNode(BuildContext context, HierarchyNode node, int level) {
    final empId = node.employee.employeeId.trim().toLowerCase();
    final hasChildren = node.children.isNotEmpty;

    final isExplicitlyExpanded = expandedIds.contains(empId);
    final hasSearchMatchInSubtree = searchQuery.isNotEmpty &&
        node.children.any((c) => c.matchesOrHasDescendantMatch(searchQuery));
    final isExpanded = isExplicitlyExpanded || hasSearchMatchInSubtree;

    final isHighlighted = searchQuery.isNotEmpty && node.matchesQuery(searchQuery);

    return Padding(
      padding: EdgeInsets.only(left: (level * 22.0).clamp(0, 160)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: HierarchyNodeCard(
              node: node,
              isExpanded: isExpanded,
              isHighlighted: isHighlighted,
              onToggleExpand: () => onToggleExpand(empId),
              onTap: () => EmployeeHierarchyDetailSheet.show(context, node: node),
            ),
          ),
          if (hasChildren && isExpanded)
            ...node.children.map((child) => _buildOutlineNode(context, child, level + 1)),
        ],
      ),
    );
  }
}
