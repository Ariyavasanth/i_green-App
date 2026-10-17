import 'dart:convert';
import 'package:flutter/material.dart';

import '../../domain/hierarchy_node.dart';

/// Modal bottom sheet or dialog displaying authorized, non-sensitive organizational details
/// for an employee selected in the hierarchy tree.
class EmployeeHierarchyDetailSheet extends StatelessWidget {
  const EmployeeHierarchyDetailSheet({
    required this.node,
    this.onFocusManager,
    super.key,
  });

  final HierarchyNode node;
  final VoidCallback? onFocusManager;

  static Future<void> show(
    BuildContext context, {
    required HierarchyNode node,
    VoidCallback? onFocusManager,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 640;
    if (isMobile) {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: EmployeeHierarchyDetailSheet(
            node: node,
            onFocusManager: onFocusManager,
          ),
        ),
      );
    } else {
      return showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            width: 520,
            child: EmployeeHierarchyDetailSheet(
              node: node,
              onFocusManager: onFocusManager,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final emp = node.employee;

    // Determine band display color
    final Color bandColor;
    if (node.bandColorHex != null && node.bandColorHex! != 0) {
      bandColor = Color(node.bandColorHex!);
    } else if (node.bandLevel >= 6) {
      bandColor = const Color(0xFF9CC70A);
    } else if (node.bandLevel >= 4) {
      bandColor = const Color(0xFF2563EB);
    } else if (node.bandLevel >= 2) {
      bandColor = const Color(0xFF414A51);
    } else {
      bandColor = const Color(0xFF64748B);
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Avatar and Name
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
            child: Row(
              children: [
                _buildAvatar(emp.fullName, emp.profileImageUrl),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        emp.fullName.isNotEmpty ? emp.fullName : 'Unnamed Employee',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
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
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF475467),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: emp.status.toLowerCase() == 'active'
                                  ? const Color(0xFFECFDF3)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              emp.status.isNotEmpty ? emp.status : 'Active',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: emp.status.toLowerCase() == 'active'
                                    ? const Color(0xFF027A48)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEAECF0)),

          // Scrollable Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Organizational Assignment
                  _buildSectionHeader(Icons.badge_outlined, 'Job & Assignment Details'),
                  const SizedBox(height: 10),
                  _buildInfoGrid([
                    _InfoPair('Designation', emp.designation.isNotEmpty ? emp.designation : '—'),
                    _InfoPair('Department', emp.department.isNotEmpty ? emp.department : '—'),
                    _InfoPair('Organization', emp.organizationName.isNotEmpty ? emp.organizationName : '—'),
                    _InfoPair('Work Location', emp.workLocation.isNotEmpty ? emp.workLocation : '—'),
                    if (emp.businessUnit.isNotEmpty)
                      _InfoPair('Business Unit', emp.businessUnit),
                    if (emp.joiningDate.isNotEmpty)
                      _InfoPair('Joining Date', emp.joiningDate),
                  ]),
                  const SizedBox(height: 20),

                  // 2. Band & Seniority Level
                  _buildSectionHeader(Icons.layers_outlined, 'Seniority & Band Level'),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bandColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: bandColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: bandColor,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            node.hasBand ? '${node.bandLevel}' : '—',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                node.hasBand
                                    ? (node.bandCode.isNotEmpty
                                        ? node.bandCode
                                        : 'Band ${node.bandLevel}')
                                    : 'No Band Assigned',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: bandColor,
                                ),
                              ),
                              if (node.bandTitle.isNotEmpty)
                                Text(
                                  node.bandTitle,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF475467),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. Reporting Manager
                  _buildSectionHeader(Icons.person_outline_rounded, 'Reporting Manager'),
                  const SizedBox(height: 10),
                  if (emp.reportingManagerId.isNotEmpty || emp.reportingManager.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: Color(0xFF414A51),
                            child: Icon(Icons.person, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  emp.reportingManager.isNotEmpty
                                      ? emp.reportingManager
                                      : 'Manager ID: ${emp.reportingManagerId}',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                if (emp.reportingManagerTitle.isNotEmpty)
                                  Text(
                                    emp.reportingManagerTitle,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_outlined, color: Color(0xFF9CC70A), size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Highest Authority / Top Leadership (No Manager)',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475467),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),

                  // 4. Direct Subordinates
                  _buildSectionHeader(
                    Icons.groups_outlined,
                    'Direct Reports (${node.children.length})',
                  ),
                  const SizedBox(height: 10),
                  if (node.children.isNotEmpty)
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: node.children.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 6),
                      itemBuilder: (context, idx) {
                        final child = node.children[idx];
                        final cEmp = child.employee;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: const Color(0xFF9CC70A),
                                child: Text(
                                  cEmp.fullName.isNotEmpty
                                      ? cEmp.fullName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cEmp.fullName,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    Text(
                                      '${cEmp.designation} • ${cEmp.department}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (child.hasBand)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  child: Text(
                                    child.bandCode.isNotEmpty
                                        ? child.bandCode
                                        : 'L${child.bandLevel}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF475467),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'No direct subordinate reports.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF414A51)),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoGrid(List<_InfoPair> pairs) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: pairs
            .map(
              (p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        p.label,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        p.value,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildAvatar(String fullName, String photoUrl) {
    const double radius = 24;
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
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF9CC70A),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _InfoPair {
  final String label;
  final String value;
  const _InfoPair(this.label, this.value);
}
