import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_searchable_dropdown.dart';
import '../../employee/providers/employee_providers.dart';
import '../../organization/domain/organization.dart';
import '../../organization/providers/organization_providers.dart';
import '../domain/hierarchy_node.dart';
import '../domain/hierarchy_tree.dart';
import '../providers/hierarchy_providers.dart';
import 'widgets/org_chart_diagram_view.dart';
import 'widgets/org_outline_tree_view.dart';
import 'widgets/reporting_chain_view.dart';

/// Main page for the Employee Hierarchy module.
class HierarchyPage extends ConsumerStatefulWidget {
  const HierarchyPage({super.key});

  @override
  ConsumerState<HierarchyPage> createState() => _HierarchyPageState();
}

class _HierarchyPageState extends ConsumerState<HierarchyPage> {
  late final TextEditingController _searchController;
  int _displayMode = 0; // 0 = Diagram Chart, 1 = Outline List

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _expandAll(HierarchyTree tree) {
    final allIds = <String>{};
    void collect(HierarchyNode n) {
      if (n.children.isNotEmpty) {
        allIds.add(n.employee.employeeId.trim().toLowerCase());
        for (final c in n.children) {
          collect(c);
        }
      }
    }

    for (final root in tree.rootNodes) {
      collect(root);
    }

    ref.read(hierarchyExpandedNodeIdsProvider.notifier).state = allIds;
  }

  void _collapseAll() {
    ref.read(hierarchyExpandedNodeIdsProvider.notifier).state = {};
  }

  void _toggleNodeExpand(String empId) {
    final current = ref.read(hierarchyExpandedNodeIdsProvider);
    final next = Set<String>.from(current);
    if (next.contains(empId)) {
      next.remove(empId);
    } else {
      next.add(empId);
    }
    ref.read(hierarchyExpandedNodeIdsProvider.notifier).state = next;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final viewMode = ref.watch(hierarchyViewModeProvider);
    final treeAsync = ref.watch(hierarchyTreeProvider);
    final chainAsync = ref.watch(myReportingChainProvider);
    final orgsAsync = ref.watch(organizationsProvider);
    final selectedOrgId = ref.watch(selectedHierarchyOrgIdProvider);
    final expandedIds = ref.watch(hierarchyExpandedNodeIdsProvider);
    final searchQuery = ref.watch(hierarchySearchQueryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // ── Top Header Toolbar ──
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 24,
              vertical: 14,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFEAECF0))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9CC70A).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.account_tree_outlined,
                            color: Color(0xFF9CC70A),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Employee Hierarchy',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'Company-wide reporting lines and organizational leadership',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Organization Selector (Desktop / Tablet)
                    if (!isMobile)
                      _buildOrgDropdown(orgsAsync, selectedOrgId),
                  ],
                ),

                if (isMobile) ...[
                  const SizedBox(height: 12),
                  _buildOrgDropdown(orgsAsync, selectedOrgId),
                ],

                const SizedBox(height: 14),

                // Controls Row: View Mode Tabs + Search + Expand/Collapse Buttons
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Mode Tabs: [ Company Tree ] [ My Reporting Chain ]
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSegmentButton(
                            label: 'Company Tree',
                            icon: Icons.schema_outlined,
                            isSelected: viewMode == 0,
                            onTap: () => ref
                                .read(hierarchyViewModeProvider.notifier)
                                .state = 0,
                          ),
                          _buildSegmentButton(
                            label: 'My Reporting Chain',
                            icon: Icons.linear_scale_rounded,
                            isSelected: viewMode == 1,
                            onTap: () => ref
                                .read(hierarchyViewModeProvider.notifier)
                                .state = 1,
                          ),
                        ],
                      ),
                    ),

                    // Search Field (Only in Company Tree view)
                    if (viewMode == 0)
                      SizedBox(
                        width: isMobile ? double.infinity : 260,
                        height: 38,
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Search by name, ID, role...',
                            hintStyle: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF94A3B8),
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              size: 18,
                              color: Color(0xFF64748B),
                            ),
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      ref
                                          .read(hierarchySearchQueryProvider.notifier)
                                          .state = '';
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 0,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFF9CC70A),
                                width: 1.5,
                              ),
                            ),
                          ),
                          onChanged: (val) {
                            ref
                                .read(hierarchySearchQueryProvider.notifier)
                                .state = val.trim();
                          },
                        ),
                      ),

                    // Expand / Collapse Buttons (Tree View Only)
                    if (viewMode == 0) ...[
                      treeAsync.maybeWhen(
                        data: (tree) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _expandAll(tree),
                              icon: const Icon(Icons.unfold_more, size: 15),
                              label: const Text(
                                'Expand All',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF475467),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _collapseAll,
                              icon: const Icon(Icons.unfold_less, size: 15),
                              label: const Text(
                                'Collapse All',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF475467),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        orElse: () => const SizedBox.shrink(),
                      ),

                      // Chart / Outline Toggle
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Diagram Chart View',
                              icon: Icon(
                                Icons.hub_outlined,
                                size: 18,
                                color: _displayMode == 0
                                    ? const Color(0xFF9CC70A)
                                    : const Color(0xFF64748B),
                              ),
                              onPressed: () => setState(() => _displayMode = 0),
                            ),
                            Container(width: 1, height: 20, color: const Color(0xFFCBD5E1)),
                            IconButton(
                              tooltip: 'Outline List View',
                              icon: Icon(
                                Icons.view_stream_outlined,
                                size: 18,
                                color: _displayMode == 1
                                    ? const Color(0xFF9CC70A)
                                    : const Color(0xFF64748B),
                              ),
                              onPressed: () => setState(() => _displayMode = 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // ── Main Content Area ──
          Expanded(
            child: viewMode == 1
                ? chainAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: Color(0xFF9CC70A)),
                    ),
                    error: (err, _) => Center(
                      child: Text(
                        'Failed to load reporting chain: $err',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    data: (chain) => ReportingChainView(chain: chain),
                  )
                : treeAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: Color(0xFF9CC70A)),
                    ),
                    error: (err, stack) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 40, color: Colors.red),
                            const SizedBox(height: 12),
                            Text(
                              'Error loading hierarchy tree: $err',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ),
                    data: (tree) {
                      return _displayMode == 0
                          ? OrgChartDiagramView(
                              tree: tree,
                              expandedIds: expandedIds,
                              onToggleExpand: _toggleNodeExpand,
                              searchQuery: searchQuery,
                            )
                          : OrgOutlineTreeView(
                              tree: tree,
                              expandedIds: expandedIds,
                              onToggleExpand: _toggleNodeExpand,
                              searchQuery: searchQuery,
                            );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrgDropdown(
    AsyncValue<List<Organization>> orgsAsync,
    String? selectedOrgId,
  ) {
    return orgsAsync.when(
      loading: () => const SizedBox(
        width: 180,
        height: 38,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (err, _) => const SizedBox.shrink(),
      data: (orgs) {
        if (orgs.isEmpty) return const SizedBox.shrink();

        final items = ['All', ...orgs.map((o) => o.canonicalId)];

        return SizedBox(
          width: 240,
          child: AppSearchableDropdown<String>(
            label: 'Organization',
            value: (selectedOrgId != null && items.contains(selectedOrgId))
                ? selectedOrgId
                : 'All',
            items: items,
            itemLabel: (id) {
              if (id == 'All') return 'All Organizations';
              final found = orgs.where((o) => o.canonicalId == id).firstOrNull;
              return found?.name ?? id;
            },
            onChanged: (val) {
              ref.read(selectedHierarchyOrgIdProvider.notifier).state =
                  (val == null || val == 'All') ? null : val;
            },
          ),
        );
      },
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? const Color(0xFF414A51)
                  : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF1E293B)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
