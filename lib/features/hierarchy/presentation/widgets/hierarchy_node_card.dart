import 'dart:convert';
import 'package:flutter/material.dart';

import '../../domain/hierarchy_node.dart';

/// Card component representing an individual employee in the hierarchy tree.
class HierarchyNodeCard extends StatelessWidget {
  const HierarchyNodeCard({
    required this.node,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onTap,
    this.isHighlighted = false,
    this.isSelected = false,
    super.key,
  });

  final HierarchyNode node;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onTap;
  final bool isHighlighted;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final emp = node.employee;
    final hasChildren = node.children.isNotEmpty;

    // Determine band styling
    final Color bandColor;
    if (node.bandColorHex != null && node.bandColorHex! != 0) {
      bandColor = Color(node.bandColorHex!);
    } else if (node.bandLevel >= 6) {
      bandColor = const Color(0xFF9CC70A); // Primary Green for Leadership
    } else if (node.bandLevel >= 4) {
      bandColor = const Color(0xFF2563EB); // Blue for Management
    } else if (node.bandLevel >= 2) {
      bandColor = const Color(0xFF414A51); // Dark Secondary for Professionals
    } else {
      bandColor = const Color(0xFF64748B); // Slate for Entry Level / Unassigned
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 280,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isHighlighted
                ? const Color(0xFFF7FCEB) // Subtle green highlight
                : (isSelected ? const Color(0xFFF1F5F9) : Colors.white),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isHighlighted
                  ? const Color(0xFF9CC70A)
                  : (isSelected
                      ? const Color(0xFF414A51)
                      : const Color(0xFFE2E8F0)),
              width: isHighlighted || isSelected ? 2.0 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isHighlighted
                    ? const Color(0xFF9CC70A).withValues(alpha: 0.18)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: isHighlighted ? 12 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Bar: Avatar + Name + ID
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildAvatar(emp.fullName, emp.profileImageUrl),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          emp.fullName.isNotEmpty ? emp.fullName : 'Unnamed Employee',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            emp.employeeId.isNotEmpty
                                ? emp.employeeId
                                : (emp.id != 0 ? 'ID: ${emp.id}' : '-'),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Designation & Department
              Text(
                emp.designation.isNotEmpty
                    ? emp.designation
                    : 'Designation Unspecified',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (emp.department.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.apartment_outlined,
                      size: 13,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        emp.department,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 8),

              // Bottom Row: Band Badge + Direct Reports / Expand Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Band Badge
                  if (node.hasBand)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: bandColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: bandColor.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: bandColor,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                node.bandCode.isNotEmpty
                                    ? node.bandCode
                                    : 'Band ${node.bandLevel}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: bandColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    const Text(
                      'No Band',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                        fontStyle: FontStyle.italic,
                      ),
                    ),

                  // Direct Reports Toggle Button
                  if (hasChildren)
                    InkWell(
                      onTap: onToggleExpand,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isExpanded
                              ? const Color(0xFF414A51)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isExpanded
                                ? const Color(0xFF414A51)
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.group_outlined,
                              size: 13,
                              color: isExpanded
                                  ? Colors.white
                                  : const Color(0xFF475467),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${node.directReportsCount}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isExpanded
                                    ? Colors.white
                                    : const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              size: 15,
                              color: isExpanded
                                  ? Colors.white
                                  : const Color(0xFF64748B),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              // Edge Case Warnings: Missing Manager or Cycle Detected
              if (node.isMissingManager) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 14,
                        color: Color(0xFFD97706),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Unlinked Manager (${node.missingManagerId})',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB45309),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (node.hasCycle) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.loop_rounded,
                        size: 14,
                        color: Color(0xFFDC2626),
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Circular reporting loop detected',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFDC2626),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String fullName, String photoUrl) {
    const double radius = 20;
    final initial = fullName.trim().isNotEmpty ? fullName.trim()[0].toUpperCase() : '?';

    if (photoUrl.isNotEmpty) {
      if (photoUrl.startsWith('data:')) {
        try {
          final comma = photoUrl.indexOf(',');
          final bytes = base64Decode(
            comma != -1 ? photoUrl.substring(comma + 1) : photoUrl,
          );
          return CircleAvatar(
            radius: radius,
            backgroundColor: const Color(0xFFF1F5F9),
            backgroundImage: MemoryImage(bytes),
          );
        } catch (_) {}
      } else if (photoUrl.startsWith('http')) {
        return CircleAvatar(
          radius: radius,
          backgroundColor: const Color(0xFFF1F5F9),
          backgroundImage: NetworkImage(photoUrl),
        );
      }
    }

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF9CC70A),
            const Color(0xFF9CC70A).withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
