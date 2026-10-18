import 'package:flutter/material.dart';

import '../../domain/hierarchy_node.dart';
import '../../domain/hierarchy_tree.dart';
import 'employee_hierarchy_detail_sheet.dart';
import 'hierarchy_node_card.dart';

/// Interactive visual tree diagram displaying the company hierarchy with pan & zoom.
class OrgChartDiagramView extends StatefulWidget {
  const OrgChartDiagramView({
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
  State<OrgChartDiagramView> createState() => _OrgChartDiagramViewState();
}

class _OrgChartDiagramViewState extends State<OrgChartDiagramView> {
  final TransformationController _transformController =
      TransformationController();

  void _zoomIn() {
    final matrix = _transformController.value.clone();
    matrix.scaleByDouble(1.25, 1.25, 1.0, 1.0);
    _transformController.value = matrix;
  }

  void _zoomOut() {
    final matrix = _transformController.value.clone();
    matrix.scaleByDouble(0.8, 0.8, 1.0, 1.0);
    _transformController.value = matrix;
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tree.isEmpty) {
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
              const SizedBox(height: 6),
              const Text(
                'No active employee records match the selected organization filter.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Pan & Zoom Canvas
        InteractiveViewer(
          transformationController: _transformController,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(1500),
          minScale: 0.2,
          maxScale: 2.5,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Render root nodes (with co-leaders grouped and bridged)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildRootTreeWidgets(),
                ),
              ],
            ),
          ),
        ),

        // Floating Zoom / Controls Overlay
        Positioned(
          right: 20,
          bottom: 20,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Zoom In',
                  icon: const Icon(Icons.add, size: 20, color: Color(0xFF475467)),
                  onPressed: _zoomIn,
                ),
                Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),
                IconButton(
                  tooltip: 'Zoom Out',
                  icon: const Icon(Icons.remove, size: 20, color: Color(0xFF475467)),
                  onPressed: _zoomOut,
                ),
                Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),
                IconButton(
                  tooltip: 'Reset Zoom & Center',
                  icon: const Icon(Icons.center_focus_strong_outlined, size: 20, color: Color(0xFF475467)),
                  onPressed: _resetZoom,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTreeNode(HierarchyNode node) {
    final empId = node.employee.employeeId.trim().toLowerCase();
    final hasChildren = node.children.isNotEmpty;

    // Check if expanded either explicitly or auto-expanded via search
    final isExplicitlyExpanded = widget.expandedIds.contains(empId);
    final hasSearchMatchInSubtree = widget.searchQuery.isNotEmpty &&
        node.children.any((c) => c.matchesOrHasDescendantMatch(widget.searchQuery));
    final isExpanded = isExplicitlyExpanded || hasSearchMatchInSubtree;

    final isHighlighted = widget.searchQuery.isNotEmpty &&
        node.matchesQuery(widget.searchQuery);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // The Employee Card
        HierarchyNodeCard(
          node: node,
          isExpanded: isExpanded,
          isHighlighted: isHighlighted,
          onToggleExpand: () => widget.onToggleExpand(empId),
          onTap: () => EmployeeHierarchyDetailSheet.show(context, node: node),
        ),

        // Connecting Lines and Children
        if (hasChildren && isExpanded) ...[
          // Vertical stem from bottom of card
          Container(
            width: 2,
            height: 24,
            color: const Color(0xFF94A3B8),
          ),

          // Custom horizontal branch connecting lines
          _buildChildrenWithBranchLines(node.children),
        ],
      ],
    );
  }

  Widget _buildChildrenWithBranchLines(List<HierarchyNode> children) {
    if (children.length == 1) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 2, height: 20, color: const Color(0xFF94A3B8)),
          _buildTreeNode(children.first),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          painter: _TreeBranchPainter(childCount: children.length),
          child: Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children.map((child) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildTreeNode(child),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildRootTreeWidgets() {
    final roots = widget.tree.rootNodes;
    if (roots.isEmpty) return const [];

    final visited = <HierarchyNode>{};
    final widgets = <Widget>[];

    for (final root in roots) {
      if (visited.contains(root)) continue;

      if (root.children.isNotEmpty) {
        final childIds = root.children
            .map((c) => c.employee.employeeId.trim().toLowerCase())
            .toSet();

        // Check if other root nodes share this identical set of children
        final coLeaders = roots.where((other) {
          if (other.children.length != root.children.length) return false;
          final otherChildIds = other.children
              .map((c) => c.employee.employeeId.trim().toLowerCase())
              .toSet();
          return childIds.containsAll(otherChildIds);
        }).toList();

        if (coLeaders.length > 1) {
          visited.addAll(coLeaders);
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: _buildCoLeaderSubtree(coLeaders, root.children),
            ),
          );
          continue;
        }
      }

      visited.add(root);
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: _buildTreeNode(root),
        ),
      );
    }

    return widgets;
  }

  Widget _buildCoLeaderSubtree(
    List<HierarchyNode> leaders,
    List<HierarchyNode> sharedChildren,
  ) {
    final isAnyExpanded = leaders.any((l) =>
        widget.expandedIds.contains(l.employee.employeeId.trim().toLowerCase()));
    final hasSearchMatchInSubtree = widget.searchQuery.isNotEmpty &&
        sharedChildren.any((c) => c.matchesOrHasDescendantMatch(widget.searchQuery));
    final isExpanded = isAnyExpanded || hasSearchMatchInSubtree;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Row of Co-Leader Cards side-by-side
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: leaders.map((leader) {
            final empId = leader.employee.employeeId.trim().toLowerCase();
            final isHighlighted = widget.searchQuery.isNotEmpty &&
                leader.matchesQuery(widget.searchQuery);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: HierarchyNodeCard(
                node: leader,
                isExpanded: isExpanded,
                isHighlighted: isHighlighted,
                onToggleExpand: () {
                  for (final l in leaders) {
                    widget.onToggleExpand(l.employee.employeeId.trim().toLowerCase());
                  }
                },
                onTap: () =>
                    EmployeeHierarchyDetailSheet.show(context, node: leader),
              ),
            );
          }).toList(),
        ),

        // Connecting Lines and Children
        if (sharedChildren.isNotEmpty && isExpanded) ...[
          // Co-leader connector with top bridge and center drop stem
          CustomPaint(
            painter: _CoLeaderConnectorPainter(leaderCount: leaders.length),
            child: SizedBox(
              width: leaders.length * 360.0,
              height: 40,
            ),
          ),

          // Custom horizontal branch connecting lines to children
          _buildChildrenWithBranchLines(sharedChildren),
        ],
      ],
    );
  }
}

/// Custom painter for the co-leader bridge connecting lines.
class _CoLeaderConnectorPainter extends CustomPainter {
  final int leaderCount;
  final double cardSpan;

  const _CoLeaderConnectorPainter({
    required this.leaderCount,
    this.cardSpan = 360.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (leaderCount <= 1) return;

    final paint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;

    // Center of leader i is at: 180 + i * cardSpan
    final firstX = 180.0;
    final lastX = 180.0 + (leaderCount - 1) * cardSpan;

    // Vertical lines from bottom of each leader card down to Y = 20
    for (int i = 0; i < leaderCount; i++) {
      final lx = 180.0 + i * cardSpan;
      canvas.drawLine(Offset(lx, 0), Offset(lx, 20), paint);
    }

    // Horizontal bridge connecting all leader stems at Y = 20
    canvas.drawLine(Offset(firstX, 20), Offset(lastX, 20), paint);

    // Central vertical drop line from Y = 20 to Y = 40
    canvas.drawLine(Offset(cx, 20), Offset(cx, 40), paint);
  }

  @override
  bool shouldRepaint(covariant _CoLeaderConnectorPainter oldDelegate) =>
      oldDelegate.leaderCount != leaderCount || oldDelegate.cardSpan != cardSpan;
}

/// Custom painter for the orthogonal connecting branch lines.
class _TreeBranchPainter extends CustomPainter {
  final int childCount;
  const _TreeBranchPainter({required this.childCount});

  @override
  void paint(Canvas canvas, Size size) {
    if (childCount <= 1) return;

    final paint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Center point at top (from parent stem)
    final centerX = size.width / 2;

    // Vertical top half connector (from Y=0 to Y=20)
    canvas.drawLine(Offset(centerX, 0), Offset(centerX, 20), paint);

    // The horizontal branch line extends across the width of all children
    // Aligns with the center of each 280px-wide card with 16px horizontal padding
    final startX = 156.0;
    final endX = size.width - 156.0;

    if (endX >= startX) {
      canvas.drawLine(Offset(startX, 20), Offset(endX, 20), paint);

      // Vertical droppers down into the top center of each child card (from Y=20 to Y=40)
      for (int i = 0; i < childCount; i++) {
        final childX = childCount == 1
            ? centerX
            : startX + i * (endX - startX) / (childCount - 1);
        canvas.drawLine(Offset(childX, 20), Offset(childX, 40), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TreeBranchPainter oldDelegate) =>
      oldDelegate.childCount != childCount;
}
