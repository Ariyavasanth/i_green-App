import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../domain/exit_model.dart';
import '../providers/exit_providers.dart';
import '../../employee/providers/employee_providers.dart';
import 'widgets/exit_policy_dialog.dart';

class MyExitPage extends ConsumerStatefulWidget {
  const MyExitPage({super.key});

  @override
  ConsumerState<MyExitPage> createState() => _MyExitPageState();
}

class _MyExitPageState extends ConsumerState<MyExitPage> {
  void _openPolicyDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ExitPolicyDialog(
        onAccept: (reason, signature) async {
          final emp = ref.read(currentEmployeeProvider);
          if (emp == null) return;

          final now = DateTime.now();
          final noticeEnd = now.add(const Duration(days: 60));
          final dateFormat = DateFormat('yyyy-MM-dd');

          final newRequest = ExitRequest(
            employeeId: emp.employeeId,
            employeeName: '${emp.firstName} ${emp.lastName}',
            department: emp.department,
            designation: emp.designation,
            appliedDate: dateFormat.format(now),
            reason: reason,
            noticeStartDate: dateFormat.format(now),
            noticeEndDate: dateFormat.format(noticeEnd),
            daysCompleted: 0,
            totalNoticeDays: 60,
            lastWorkingDay: dateFormat.format(noticeEnd),
            status: 'Pending',
            policyAccepted: true,
            employeeSignature: signature,
            createdAt: now.toIso8601String(),
          );

          await ref.read(exitRepositoryProvider).submitExitRequest(newRequest);
          ref.refresh(myExitRequestProvider);
          ref.refresh(allExitRequestsProvider);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: const [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 10),
                    Text('Resignation request submitted successfully.'),
                  ],
                ),
                backgroundColor: const Color(0xFF9CC70A),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myExitAsync = ref.watch(myExitRequestProvider);
    final emp = ref.watch(currentEmployeeProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.exit_to_app_rounded, color: Color(0xFF9CC70A), size: 24),
            SizedBox(width: 10),
            Text('My Exit Portal', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
      ),
      body: RefreshIndicator(
        color: const Color(0xFF9CC70A),
        onRefresh: () async {
          ref.invalidate(myExitRequestProvider);
          ref.invalidate(allExitRequestsProvider);
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: myExitAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF9CC70A))),
          error: (err, stack) => Center(child: Text('Error loading exit details: $err')),
          data: (exitRequest) {
            if (exitRequest == null) {
              return _buildNoExitSubmittedView(emp?.employeeId ?? '');
            }
            return _buildResponsiveExitDashboard(context, exitRequest);
          },
        ),
      ),
    );

  }

  Widget _buildNoExitSubmittedView(String empId) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 620),
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF9CC70A).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.assignment_ind_outlined,
                  color: Color(0xFF9CC70A),
                  size: 52,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No Active Exit Process',
                style: AppTextStyles.pageTitle.copyWith(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'You currently do not have any pending or active exit request. If you wish to apply for resignation, please review the company Exit Policy and submit your agreement.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9CC70A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: _openPolicyDialog,
                icon: const Icon(Icons.assignment_turned_in),
                label: const Text(
                  'View Exit Policy & Apply',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveExitDashboard(BuildContext context, ExitRequest request) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Employee Header Banner Card ──────────────────────────────────────
          _EmployeeHeaderCard(request: request),
          const SizedBox(height: 20),

          // ── Leave Warning Alert if leave taken ──────────────────────────────
          if (request.leaveTakenCount > 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                border: Border.all(color: Colors.amber.shade400),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notice Period Policy Warning',
                          style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'According to company policy, leaves are not allowed during the notice period. ${request.leaveTakenCount} day(s) leave detected, which may extend your last working day or incur notice pay shortfall deductions.',
                          style: TextStyle(color: Colors.amber.shade900, fontSize: 12, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Summary Cards Grid ──────────────────────────────────────────────
          _SummaryCardsGrid(request: request, isDesktop: isDesktop),
          const SizedBox(height: 24),

          // ── Notice Progress Bar ─────────────────────────────────────────────
          _NoticeProgressBarCard(request: request),
          const SizedBox(height: 24),

          // ── Responsive Layout: Desktop 2-Column Split vs Mobile Stack ────────
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: _TimelineCard(request: request)),
                const SizedBox(width: 20),
                Expanded(
                  flex: 7,
                  child: Column(
                    children: [
                      _ClearanceAccordionCard(exitRequestId: request.id ?? 0),
                      const SizedBox(height: 20),
                      _SettlementSummaryCard(exitRequestId: request.id ?? 0),
                      const SizedBox(height: 20),
                      _ExitDocumentsCard(request: request),
                    ],
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                _TimelineCard(request: request),
                const SizedBox(height: 20),
                _ClearanceAccordionCard(exitRequestId: request.id ?? 0),
                const SizedBox(height: 20),
                _SettlementSummaryCard(exitRequestId: request.id ?? 0),
                const SizedBox(height: 20),
                _ExitDocumentsCard(request: request),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Employee Header Banner ───────────────────────────────────────────────────
class _EmployeeHeaderCard extends StatelessWidget {
  final ExitRequest request;
  const _EmployeeHeaderCard({required this.request});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF414A51), Color(0xFF2C3237)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFF9CC70A),
            child: Text(
              request.employeeName.isNotEmpty ? request.employeeName[0].toUpperCase() : 'E',
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.employeeName,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  '${request.designation} • ${request.department} (ID: ${request.employeeId})',
                  style: TextStyle(color: Colors.grey.shade300, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _BadgeText(icon: Icons.event, text: 'Applied: ${request.appliedDate}'),
                    _BadgeText(icon: Icons.event_available, text: 'Last Working Day: ${request.lastWorkingDay}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _StatusChip(status: request.status),
        ],
      ),
    );
  }
}

class _BadgeText extends StatelessWidget {
  final IconData icon;
  final String text;
  const _BadgeText({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF9CC70A)),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: Colors.grey.shade300, fontSize: 11)),
      ],
    );
  }
}

// ── Summary Cards Grid ───────────────────────────────────────────────────────
class _SummaryCardsGrid extends ConsumerWidget {
  final ExitRequest request;
  final bool isDesktop;

  const _SummaryCardsGrid({required this.request, required this.isDesktop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysCompleted = request.daysCompleted;
    final totalDays = request.totalNoticeDays > 0 ? request.totalNoticeDays : 60;
    final remainingDays = (totalDays - daysCompleted).clamp(0, totalDays);

    final clearancesAsync = ref.watch(exitClearancesProvider(request.id ?? 0));
    final settlementAsync = ref.watch(exitSettlementProvider(request.id ?? 0));

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = isDesktop ? 4 : (constraints.maxWidth > 550 ? 2 : 2);
        return GridView.count(
          crossAxisCount: crossCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: isDesktop ? 1.8 : 1.5,
          children: [
            _TileCard(
              title: 'Resignation Status',
              value: request.status,
              icon: Icons.assignment_turned_in_outlined,
              color: const Color(0xFF414A51),
            ),
            _TileCard(
              title: 'Notice Remaining',
              value: '$remainingDays Days',
              subtitle: '$daysCompleted of $totalDays days completed',
              icon: Icons.timer_outlined,
              color: const Color(0xFF9CC70A),
            ),
            clearancesAsync.when(
              data: (list) {
                final done = list.where((c) => c.status == 'Approved').length;
                return _TileCard(
                  title: 'Clearance Status',
                  value: '$done / ${list.length} Cleared',
                  icon: Icons.verified_user_outlined,
                  color: Colors.blue.shade700,
                );
              },
              loading: () => const _TileCard(title: 'Clearance Status', value: '...', icon: Icons.hourglass_top, color: Colors.blue),
              error: (_, _) => const _TileCard(title: 'Clearance Status', value: 'Err', icon: Icons.error_outline, color: Colors.red),
            ),
            settlementAsync.when(
              data: (s) => _TileCard(
                title: 'Net Settlement',
                value: s != null ? '₹${s.netSettlement.toStringAsFixed(0)}' : 'Pending',
                subtitle: 'Payout: 45 working days',
                icon: Icons.account_balance_wallet_outlined,
                color: Colors.teal.shade700,
              ),
              loading: () => const _TileCard(title: 'Net Settlement', value: '...', icon: Icons.hourglass_top, color: Colors.teal),
              error: (_, _) => const _TileCard(title: 'Net Settlement', value: 'Err', icon: Icons.error_outline, color: Colors.red),
            ),
          ],
        );
      },
    );
  }
}

class _TileCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const _TileCard({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Notice Progress Bar Card ──────────────────────────────────────────────────
class _NoticeProgressBarCard extends StatelessWidget {
  final ExitRequest request;
  const _NoticeProgressBarCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final daysCompleted = request.daysCompleted;
    final totalDays = request.totalNoticeDays > 0 ? request.totalNoticeDays : 60;
    final progress = (daysCompleted / totalDays).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Notice Period Completion',
                style: AppTextStyles.heading.copyWith(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(progress * 100).toInt()}% Completed',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF9CC70A), fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 14,
              backgroundColor: Colors.grey.shade200,
              color: const Color(0xFF9CC70A),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Notice Start: ${request.noticeStartDate}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              Text('Notice End: ${request.noticeEndDate}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Timeline Card ─────────────────────────────────────────────────────────────
class _TimelineCard extends StatelessWidget {
  final ExitRequest request;
  const _TimelineCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final daysCompleted = request.daysCompleted;
    final totalDays = request.totalNoticeDays > 0 ? request.totalNoticeDays : 60;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Exit Timeline & Progress',
            style: AppTextStyles.heading.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const Divider(height: 24),
          _TimelineItem(
            title: 'Resignation Submitted',
            subtitle: request.appliedDate,
            isCompleted: true,
          ),
          _TimelineItem(
            title: 'Manager Approval',
            subtitle: request.managerApprovalStatus,
            isCompleted: request.managerApprovalStatus == 'Approved',
          ),
          _TimelineItem(
            title: 'HR Approval',
            subtitle: request.hrApprovalStatus,
            isCompleted: request.hrApprovalStatus == 'Approved',
          ),
          _TimelineItem(
            title: 'Notice Period Served',
            subtitle: '$daysCompleted / $totalDays Days',
            isCompleted: daysCompleted >= totalDays,
          ),
          _TimelineItem(
            title: 'Department Clearance',
            subtitle: 'IT, HR, Admin, Accounts, Manager',
            isCompleted: request.status == 'Settlement' || request.status == 'Completed',
          ),
          _TimelineItem(
            title: 'Settlement Finalized',
            subtitle: '45 Working Days Payout',
            isCompleted: request.status == 'Completed',
          ),
          _TimelineItem(
            title: 'Relieving Documents Issued',
            subtitle: 'Experience & Relieving Letter',
            isCompleted: request.status == 'Completed',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isLast;

  const _TimelineItem({
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? const Color(0xFF9CC70A) : Colors.grey.shade300,
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : const Icon(Icons.circle, size: 10, color: Colors.white),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 38,
                color: isCompleted ? const Color(0xFF9CC70A) : Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: isCompleted ? FontWeight.bold : FontWeight.w500,
                    color: isCompleted ? AppColors.textPrimary : Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Clearance Accordion Card ──────────────────────────────────────────────────
class _ClearanceAccordionCard extends ConsumerWidget {
  final int exitRequestId;
  const _ClearanceAccordionCard({required this.exitRequestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clearancesAsync = ref.watch(exitClearancesProvider(exitRequestId));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Clearance Sign-offs by Department',
            style: AppTextStyles.heading.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const Divider(height: 24),
          clearancesAsync.when(
            data: (clearances) {
              if (clearances.isEmpty) {
                return const Text('No clearance checklist generated yet.');
              }
              return Column(
                children: clearances.map((c) => _ClearanceItemTile(clearance: c)).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF9CC70A))),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

class _ClearanceItemTile extends StatelessWidget {
  final DepartmentClearance clearance;
  const _ClearanceItemTile({required this.clearance});

  @override
  Widget build(BuildContext context) {
    final isApproved = clearance.status == 'Approved';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _getDeptIcon(clearance.department),
                    size: 20,
                    color: const Color(0xFF414A51),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${clearance.department} Department',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isApproved ? const Color(0xFF9CC70A).withValues(alpha: 0.15) : Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  clearance.status,
                  style: TextStyle(
                    color: isApproved ? const Color(0xFF9CC70A) : Colors.amber.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...clearance.checklist.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3.0),
              child: Row(
                children: [
                  Icon(
                    e.value ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 16,
                    color: e.value ? const Color(0xFF9CC70A) : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    e.key,
                    style: TextStyle(fontSize: 13, color: e.value ? Colors.black87 : Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getDeptIcon(String dept) {
    switch (dept.toUpperCase()) {
      case 'IT':
        return Icons.computer;
      case 'HR':
        return Icons.people_alt_outlined;
      case 'ADMIN':
        return Icons.business;
      case 'ACCOUNTS':
        return Icons.account_balance_outlined;
      case 'MANAGER':
        return Icons.work_outline;
      default:
        return Icons.verified_user_outlined;
    }
  }
}

// ── Settlement Summary Card ──────────────────────────────────────────────────
class _SettlementSummaryCard extends ConsumerWidget {
  final int exitRequestId;
  const _SettlementSummaryCard({required this.exitRequestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settlementAsync = ref.watch(exitSettlementProvider(exitRequestId));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Final Settlement Calculation',
            style: AppTextStyles.heading.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const Divider(height: 24),
          settlementAsync.when(
            data: (s) {
              final sData = s ?? const ExitSettlement(exitRequestId: 0);
              return Column(
                children: [
                  _CostRow(label: 'Gross Salary Balance', value: '₹${sData.grossSalary.toStringAsFixed(2)}', isCredit: true),
                  _CostRow(label: 'Notice Pay Credit', value: '₹${sData.noticePay.toStringAsFixed(2)}', isCredit: true),
                  const Divider(height: 16),
                  _CostRow(label: 'Insurance Deduction (<6 mos)', value: '-₹${sData.insuranceDeduction.toStringAsFixed(2)}', isCredit: false),
                  _CostRow(label: 'Uniform & Shoes Deduction', value: '-₹${sData.uniformDeduction.toStringAsFixed(2)}', isCredit: false),
                  _CostRow(label: 'Loan Outstanding', value: '-₹${sData.loanDeduction.toStringAsFixed(2)}', isCredit: false),
                  _CostRow(label: 'Notice Shortfall Deduction', value: '-₹${sData.noticeShortfallDeduction.toStringAsFixed(2)}', isCredit: false),
                  const Divider(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9CC70A).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Net Settlement Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(
                          '₹${sData.netSettlement.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF9CC70A)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '* Final settlement amount will be processed to bank account after 45 working days as per company policy.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF9CC70A))),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

class _CostRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isCredit;

  const _CostRow({required this.label, required this.value, required this.isCredit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isCredit ? Colors.green.shade800 : Colors.red.shade800,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Exit Documents Card ───────────────────────────────────────────────────────
class _ExitDocumentsCard extends StatelessWidget {
  final ExitRequest request;
  const _ExitDocumentsCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final isCompleted = request.status == 'Completed';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Relieving & Exit Documents',
            style: AppTextStyles.heading.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const Divider(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _DocTile(title: 'Resignation Acceptance', isAvailable: true),
              _DocTile(title: 'Settlement Summary', isAvailable: true),
              _DocTile(title: 'NOC Certificate', isAvailable: true),
              _DocTile(
                title: 'Relieving Letter',
                isAvailable: isCompleted,
                lockReason: isCompleted ? null : 'Available after Exit Completion',
              ),
              _DocTile(
                title: 'Experience Certificate',
                isAvailable: isCompleted,
                lockReason: isCompleted ? null : 'Available after Exit Completion',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  final String title;
  final bool isAvailable;
  final String? lockReason;

  const _DocTile({
    required this.title,
    required this.isAvailable,
    this.lockReason,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAvailable ? Colors.grey.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isAvailable ? Colors.grey.shade300 : Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.picture_as_pdf,
                color: isAvailable ? const Color(0xFF9CC70A) : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isAvailable ? Colors.black87 : Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (lockReason != null) ...[
            const SizedBox(height: 4),
            Text(
              lockReason!,
              style: TextStyle(fontSize: 10, color: Colors.red.shade700, fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: isAvailable ? () {} : null,
                icon: const Icon(Icons.download, size: 14),
                label: const Text('Download', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Status Chip Helper ──────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.amber.shade100;
    Color fg = Colors.amber.shade900;

    if (status == 'Approved' || status == 'Completed') {
      bg = const Color(0xFF9CC70A).withValues(alpha: 0.2);
      fg = const Color(0xFF9CC70A);
    } else if (status == 'Rejected') {
      bg = Colors.red.shade100;
      fg = Colors.red.shade800;
    } else if (status == 'In Notice' || status == 'Clearance') {
      bg = Colors.blue.shade100;
      fg = Colors.blue.shade900;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        status,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}
