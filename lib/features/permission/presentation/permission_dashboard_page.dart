import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../authentication/providers/authentication_providers.dart';
import '../../employee/domain/employee.dart';
import '../../leave/providers/leave_providers.dart';
import '../domain/permission_enums.dart';
import '../domain/permission_request.dart';
import '../providers/permission_providers.dart';
import 'apply_emergency_permission_page.dart';
import 'apply_permission_page.dart';
import 'permission_details_page.dart';

class PermissionDashboardPage extends ConsumerStatefulWidget {
  const PermissionDashboardPage({super.key});

  static const Color primaryGreen = Color(0xFF9CC70A);
  static const Color darkNeutral = Color(0xFF414A51);

  @override
  ConsumerState<PermissionDashboardPage> createState() => _PermissionDashboardPageState();
}

class _PermissionDashboardPageState extends ConsumerState<PermissionDashboardPage> {
  String _statusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final currentEmp = ref.watch(currentEmployeeProvider);
    final employeeId = currentEmp?.id ?? 1;

    final balanceAsync = ref.watch(employeePermissionBalanceProvider(employeeId));
    final requestsAsync = ref.watch(myPermissionRequestsProvider(employeeId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(employeePermissionBalanceProvider(employeeId));
          ref.invalidate(myPermissionRequestsProvider(employeeId));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Permission Quota Balance Card
              balanceAsync.when(
                data: (balance) {
                  final monthlyPercent = balance.monthlyLimitMinutes > 0
                      ? (balance.monthlyUsedMinutes / balance.monthlyLimitMinutes).clamp(0.0, 1.0)
                      : 0.0;

                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [PermissionDashboardPage.darkNeutral, PermissionDashboardPage.darkNeutral.withOpacity(0.9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: PermissionDashboardPage.darkNeutral.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'THIS MONTH PERMISSION ALLOWANCE',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Used',
                                  style: TextStyle(color: Colors.white60, fontSize: 12),
                                ),
                                Text(
                                  '${balance.monthlyUsedHours.toStringAsFixed(1)}h',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              height: 30,
                              width: 1,
                              color: Colors.white24,
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Remaining',
                                  style: TextStyle(color: Colors.white60, fontSize: 12),
                                ),
                                Text(
                                  '${balance.monthlyRemainingHours.toStringAsFixed(1)}h',
                                  style: TextStyle(
                                    color: PermissionDashboardPage.primaryGreen,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              height: 30,
                              width: 1,
                              color: Colors.white24,
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Limit',
                                  style: TextStyle(color: Colors.white60, fontSize: 12),
                                ),
                                Text(
                                  '${balance.monthlyLimitHours.toStringAsFixed(1)}h',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: monthlyPercent,
                            minHeight: 8,
                            backgroundColor: Colors.white12,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              monthlyPercent > 0.8 ? Colors.orangeAccent : PermissionDashboardPage.primaryGreen,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white24, height: 1),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Today's Used: ${balance.todayUsedHours.toStringAsFixed(1)}h",
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            Text(
                              "Remaining: ${balance.todayRemainingHours.toStringAsFixed(1)}h",
                              style: TextStyle(color: PermissionDashboardPage.primaryGreen, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Text('Error loading balance: $err'),
              ),
              const SizedBox(height: 20),

              // Action Buttons Row
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context.go('/permission/apply');
                      },
                      icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                      label: const Text(
                        'Apply Permission',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PermissionDashboardPage.primaryGreen,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Recent Requests Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Requests',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: PermissionDashboardPage.darkNeutral,
                    ),
                  ),
                  _AnimatedRefreshButton(
                    onPressed: () {
                      ref.invalidate(myPermissionRequestsProvider(employeeId));
                      ref.invalidate(employeePermissionBalanceProvider(employeeId));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12), // 12px gap below heading to filter bar

              // Filter Bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Pending'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Emergency'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Approved'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Rejected'),
                  ],
                ),
              ),
              const SizedBox(height: 6), // gap between filter bar and subtext

              // Request List & Count Subtext
              requestsAsync.when(
                data: (allRequests) {
                  final filtered = allRequests.where((r) {
                    if (_statusFilter == 'Pending') return r.status == PermissionStatus.pending;
                    if (_statusFilter == 'Emergency') return r.isEmergency || r.status == PermissionStatus.emergencyPending;
                    if (_statusFilter == 'Approved') return r.status == PermissionStatus.approved;
                    if (_statusFilter == 'Rejected') return r.status == PermissionStatus.rejected;
                    return true;
                  }).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subtext ("Showing X requests")
                      Text(
                        'Showing ${filtered.length} ${filtered.length == 1 ? 'request' : 'requests'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (filtered.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.assignment_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                'No permission requests found',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final req = filtered[index];
                            return _buildRequestCard(context, req, ref);
                          },
                        ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Text('Error loading requests: $err'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _statusFilter == label;
    return InkWell(
      onTap: () {
        setState(() {
          _statusFilter = label;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? PermissionDashboardPage.darkNeutral : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : PermissionDashboardPage.darkNeutral,
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, PermissionRequest req, WidgetRef ref) {
    Color statusColor;
    IconData statusIcon;
    switch (req.status) {
      case PermissionStatus.approved:
        statusColor = Colors.green.shade700;
        statusIcon = Icons.check_circle_outline;
        break;
      case PermissionStatus.rejected:
        statusColor = Colors.red.shade700;
        statusIcon = Icons.cancel_outlined;
        break;
      case PermissionStatus.emergencyPending:
        statusColor = Colors.orange.shade800;
        statusIcon = Icons.warning_amber_rounded;
        break;
      case PermissionStatus.cancelled:
        statusColor = Colors.grey.shade600;
        statusIcon = Icons.remove_circle_outline;
        break;
      case PermissionStatus.pending:
      default:
        statusColor = Colors.blue.shade700;
        statusIcon = Icons.hourglass_top_rounded;
        break;
    }

    final dateStr = '${req.date.day} ${_getMonthAbbr(req.date.month)} ${req.date.year}';

    return InkWell(
      onTap: () {
        context.go('/permission/details', extra: req);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(statusIcon, color: statusColor, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              req.permissionType.label,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: PermissionDashboardPage.darkNeutral,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    req.status == PermissionStatus.emergencyPending
                        ? 'Emergency Pending'
                        : (req.isEmergency ? 'Emergency' : req.status.label),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${req.fromTime} - ${req.toTime}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${req.durationMinutes} min',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: PermissionDashboardPage.darkNeutral,
                    ),
                  ),
                ),
              ],
            ),
            if (req.reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Reason: ${req.reason}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getMonthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}

class _AnimatedRefreshButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _AnimatedRefreshButton({required this.onPressed});

  @override
  State<_AnimatedRefreshButton> createState() => _AnimatedRefreshButtonState();
}

class _AnimatedRefreshButtonState extends State<_AnimatedRefreshButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0.0);
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _handleTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RotationTransition(
              turns: Tween(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
              ),
              child: const Icon(Icons.refresh, size: 16, color: PermissionDashboardPage.darkNeutral),
            ),
            const SizedBox(width: 4),
            const Text(
              'Refresh',
              style: TextStyle(
                color: PermissionDashboardPage.darkNeutral,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
