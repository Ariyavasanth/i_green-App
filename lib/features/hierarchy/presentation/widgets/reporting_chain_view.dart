import 'package:flutter/material.dart';

import '../../domain/hierarchy_node.dart';
import 'employee_hierarchy_detail_sheet.dart';

/// Stepper/timeline view of an employee's direct reporting chain to top leadership.
class ReportingChainView extends StatelessWidget {
  const ReportingChainView({
    required this.chain,
    super.key,
  });

  /// The linear chain ordered from target employee [0] up to highest authority [last].
  final List<HierarchyNode> chain;

  @override
  Widget build(BuildContext context) {
    if (chain.isEmpty) {
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
                  Icons.account_tree_outlined,
                  size: 36,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Reporting Chain Found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Reporting manager data is unassigned or employee is not found in the current organization.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    // Display from top authority (CEO / Band 7) down to employee, or vice versa
    // Top-to-bottom: Reversed chain (highest authority first)
    final reversedChain = chain.reversed.toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.route_outlined,
                        color: Color(0xFF9CC70A),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reporting Line of Command',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${chain.length} levels from ${chain.first.employee.fullName} to highest authority',
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
              ),
              const SizedBox(height: 24),

              // Step-by-Step Chain
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: reversedChain.length,
                itemBuilder: (context, idx) {
                  final node = reversedChain[idx];
                  final isTopAuthority = idx == 0;
                  final isTargetEmployee = idx == reversedChain.length - 1;
                  final isImmediateManager = idx == reversedChain.length - 2;

                  final String levelRoleLabel;
                  if (isTargetEmployee) {
                    levelRoleLabel = 'You / Target Employee';
                  } else if (isImmediateManager) {
                    levelRoleLabel = 'Immediate Reporting Manager';
                  } else if (isTopAuthority) {
                    levelRoleLabel = 'Top Authority / Organization Lead';
                  } else {
                    levelRoleLabel = 'Level ${reversedChain.length - idx} Superior';
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Timeline Indicator Column
                      Column(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isTargetEmployee
                                  ? const Color(0xFF9CC70A)
                                  : (isTopAuthority
                                      ? const Color(0xFF414A51)
                                      : Colors.white),
                              border: Border.all(
                                color: isTargetEmployee
                                    ? const Color(0xFF9CC70A)
                                    : (isTopAuthority
                                        ? const Color(0xFF414A51)
                                        : const Color(0xFF94A3B8)),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: isTargetEmployee
                                  ? const Icon(Icons.person, color: Colors.white, size: 16)
                                  : (isTopAuthority
                                      ? const Icon(Icons.shield, color: Colors.white, size: 16)
                                      : Text(
                                          '${reversedChain.length - idx}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF475467),
                                          ),
                                        )),
                            ),
                          ),
                          if (idx < reversedChain.length - 1)
                            Container(
                              width: 2,
                              height: 64,
                              color: const Color(0xFFCBD5E1),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),

                      // Node Card
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: InkWell(
                            onTap: () => EmployeeHierarchyDetailSheet.show(
                              context,
                              node: node,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isTargetEmployee
                                      ? const Color(0xFF9CC70A)
                                      : (isTopAuthority
                                          ? const Color(0xFF414A51)
                                          : const Color(0xFFE2E8F0)),
                                  width: isTargetEmployee || isTopAuthority ? 1.5 : 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Label Header
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        levelRoleLabel,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isTargetEmployee
                                              ? const Color(0xFF658204)
                                              : const Color(0xFF64748B),
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      if (node.hasBand)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF9CC70A).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: const Color(0xFF9CC70A).withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Text(
                                            node.bandCode.isNotEmpty
                                                ? node.bandCode
                                                : 'Band ${node.bandLevel}',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF658204),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),

                                  // Name
                                  Text(
                                    node.employee.fullName,
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),

                                  // Designation & Department
                                  Text(
                                    '${node.employee.designation} • ${node.employee.department}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
