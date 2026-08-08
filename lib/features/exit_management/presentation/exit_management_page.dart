import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../domain/exit_model.dart';
import '../providers/exit_providers.dart';

class ExitManagementPage extends ConsumerStatefulWidget {
  const ExitManagementPage({super.key});

  @override
  ConsumerState<ExitManagementPage> createState() => _ExitManagementPageState();
}

class _ExitManagementPageState extends ConsumerState<ExitManagementPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exitRequestsAsync = ref.watch(allExitRequestsProvider);
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.assignment_return_outlined, color: Color(0xFF9CC70A), size: 24),
            SizedBox(width: 10),
            Text('Exit Management Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: const Color(0xFF9CC70A),
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: const Color(0xFF9CC70A),
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(text: 'Dashboard'),
                Tab(text: 'Resignation Requests'),
                Tab(text: 'Notice Period'),
                Tab(text: 'Clearance'),
                Tab(text: 'Exit Interview'),
                Tab(text: 'Settlement'),
                Tab(text: 'Documents'),
                Tab(text: 'Completed Exits'),
              ],
            ),
          ),
        ),
      ),
      body: exitRequestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF9CC70A))),
        error: (err, stack) => Center(child: Text('Error loading exit records: $err')),
        data: (allRequests) {
          final filteredRequests = allRequests.where((r) {
            final query = _searchQuery.toLowerCase().trim();
            if (query.isEmpty) return true;
            return r.employeeName.toLowerCase().contains(query) ||
                r.employeeId.toLowerCase().contains(query) ||
                r.department.toLowerCase().contains(query);
          }).toList();

          return Column(
            children: [
              // ── Search Bar ─────────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 24,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search exit records by employee name, ID or department...',
                            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                            prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      tooltip: 'Refresh',
                      icon: const Icon(Icons.refresh, color: Color(0xFF414A51)),
                      onPressed: () => ref.refresh(allExitRequestsProvider),
                    ),
                  ],
                ),
              ),

              // ── Tab Views ──────────────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _DashboardTab(requests: filteredRequests, isMobile: isMobile),
                    _ResignationRequestsTab(requests: filteredRequests, isMobile: isMobile),
                    _NoticePeriodTab(requests: filteredRequests, isMobile: isMobile),
                    _ClearanceTab(requests: filteredRequests, isMobile: isMobile),
                    _ExitInterviewTab(requests: filteredRequests, isMobile: isMobile),
                    _SettlementTab(requests: filteredRequests, isMobile: isMobile),
                    _DocumentsTab(requests: filteredRequests, isMobile: isMobile),
                    _CompletedExitsTab(requests: filteredRequests, isMobile: isMobile),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── 1. DASHBOARD TAB ─────────────────────────────────────────────────────────
class _DashboardTab extends StatelessWidget {
  final List<ExitRequest> requests;
  final bool isMobile;

  const _DashboardTab({required this.requests, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final pendingCount = requests.where((r) => r.status == 'Pending').length;
    final noticeCount = requests.where((r) => r.status == 'Approved' || r.status == 'In Notice').length;
    final clearanceCount = requests.where((r) => r.status == 'Clearance').length;
    final settlementCount = requests.where((r) => r.status == 'Settlement').length;
    final completedCount = requests.where((r) => r.status == 'Completed').length;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = isMobile ? 2 : (constraints.maxWidth > 1000 ? 5 : 3);
              return GridView.count(
                crossAxisCount: crossCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: isMobile ? 1.4 : 1.6,
                children: [
                  _StatCard(title: 'Pending Resignations', value: '$pendingCount', color: Colors.amber.shade700, icon: Icons.pending_actions),
                  _StatCard(title: 'Notice Period', value: '$noticeCount', color: const Color(0xFF9CC70A), icon: Icons.timer_outlined),
                  _StatCard(title: 'Pending Clearance', value: '$clearanceCount', color: Colors.blue.shade700, icon: Icons.verified_user_outlined),
                  _StatCard(title: 'Pending Settlement', value: '$settlementCount', color: Colors.purple.shade700, icon: Icons.account_balance_wallet_outlined),
                  _StatCard(title: 'Completed Exit', value: '$completedCount', color: const Color(0xFF414A51), icon: Icons.task_alt),
                ],
              );
            },
          ),
          const SizedBox(height: 28),

          // Recent Requests Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Exit Requests',
                style: AppTextStyles.heading.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'Showing ${requests.length} records',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (requests.isEmpty)
            _EmptyStateCard(message: 'No exit requests available.')
          else
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                  columns: const [
                    DataColumn(label: Text('Employee', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Applied Date', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Last Working Day', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: requests.take(10).map((r) {
                    return DataRow(cells: [
                      DataCell(
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: const Color(0xFF414A51),
                              child: Text(
                                r.employeeName.isNotEmpty ? r.employeeName[0] : 'E',
                                style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(r.employeeName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      DataCell(Text(r.department)),
                      DataCell(Text(r.appliedDate)),
                      DataCell(Text(r.lastWorkingDay)),
                      DataCell(_StatusBadge(status: r.status)),
                    ]);
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 2. RESIGNATION REQUESTS TAB ──────────────────────────────────────────────
class _ResignationRequestsTab extends ConsumerWidget {
  final List<ExitRequest> requests;
  final bool isMobile;

  const _ResignationRequestsTab({required this.requests, required this.isMobile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (requests.isEmpty) {
      return const _EmptyStateCard(message: 'No pending resignation requests.');
    }

    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        final isPending = req.status == 'Pending';

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF9CC70A),
                          child: Text(
                            req.employeeName.isNotEmpty ? req.employeeName[0] : 'E',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(req.employeeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('${req.department} • ${req.designation} (ID: ${req.employeeId})', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    _StatusBadge(status: req.status),
                  ],
                ),
                const Divider(height: 24),
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    _InfoCell(label: 'Applied Date', value: req.appliedDate),
                    _InfoCell(label: 'Notice Period', value: '${req.totalNoticeDays} Days'),
                    _InfoCell(label: 'Last Working Day', value: req.lastWorkingDay),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Reason for Resignation:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(req.reason, style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
                      if (req.employeeSignature != null && req.employeeSignature!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('Digitally Signed by: ${req.employeeSignature}', style: const TextStyle(fontSize: 11, color: Color(0xFF9CC70A), fontWeight: FontWeight.bold)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (isPending)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade400),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Reject'),
                        onPressed: () async {
                          await ref.read(exitRepositoryProvider).updateExitRequestStatus(req.id!, 'Rejected');
                          ref.refresh(allExitRequestsProvider);
                        },
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9CC70A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Approve & Start Notice', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          await ref.read(exitRepositoryProvider).updateExitRequestStatus(req.id!, 'In Notice');
                          ref.refresh(allExitRequestsProvider);
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── 3. NOTICE PERIOD TAB ─────────────────────────────────────────────────────
class _NoticePeriodTab extends StatelessWidget {
  final List<ExitRequest> requests;
  final bool isMobile;

  const _NoticePeriodTab({required this.requests, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final noticeList = requests.where((r) => r.status == 'In Notice' || r.status == 'Approved' || r.status == 'Clearance').toList();

    if (noticeList.isEmpty) {
      return const _EmptyStateCard(message: 'No employees currently serving notice period.');
    }

    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      itemCount: noticeList.length,
      itemBuilder: (context, index) {
        final req = noticeList[index];
        final daysCompleted = req.daysCompleted;
        final totalDays = req.totalNoticeDays > 0 ? req.totalNoticeDays : 60;
        final progress = (daysCompleted / totalDays).clamp(0.0, 1.0);
        final remaining = (totalDays - daysCompleted).clamp(0, totalDays);

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(req.employeeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${(progress * 100).toInt()}% Notice Served',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF9CC70A), fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 12,
                    backgroundColor: Colors.grey.shade200,
                    color: const Color(0xFF9CC70A),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    _InfoCell(label: 'Notice Start', value: req.noticeStartDate),
                    _InfoCell(label: 'Notice End', value: req.noticeEndDate),
                    _InfoCell(label: 'Days Completed', value: '$daysCompleted Days'),
                    _InfoCell(label: 'Days Remaining', value: '$remaining Days'),
                    _InfoCell(label: 'Leave Taken', value: '${req.leaveTakenCount} Days'),
                  ],
                ),
                if (req.leaveTakenCount > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Warning: Policy prohibits taking leave during notice period. Employee has logged leave.',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── 4. CLEARANCE TAB ─────────────────────────────────────────────────────────
class _ClearanceTab extends ConsumerWidget {
  final List<ExitRequest> requests;
  final bool isMobile;

  const _ClearanceTab({required this.requests, required this.isMobile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        final clearancesAsync = ref.watch(exitClearancesProvider(req.id ?? 0));

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Department Clearance: ${req.employeeName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    _StatusBadge(status: req.status),
                  ],
                ),
                const Divider(height: 20),
                clearancesAsync.when(
                  data: (clearances) {
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: clearances.map((c) {
                        return Container(
                          width: isMobile ? double.infinity : 260,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(c.department, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  _StatusBadge(status: c.status),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...c.checklist.entries.map((entry) {
                                return CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(entry.key, style: const TextStyle(fontSize: 12)),
                                  value: entry.value,
                                  activeColor: const Color(0xFF9CC70A),
                                  onChanged: (val) async {
                                    final updatedList = Map<String, bool>.from(c.checklist);
                                    updatedList[entry.key] = val ?? false;
                                    final allDone = updatedList.values.every((v) => v);
                                    final updatedClearance = c.copyWith(
                                      checklist: updatedList,
                                      status: allDone ? 'Approved' : 'Pending',
                                      updatedAt: DateTime.now().toIso8601String(),
                                    );
                                    await ref.read(exitRepositoryProvider).saveOrUpdateClearance(updatedClearance);
                                    ref.refresh(exitClearancesProvider(req.id!));
                                  },
                                );
                              }),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF9CC70A))),
                  error: (e, _) => Text('Error: $e'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── 5. EXIT INTERVIEW TAB ────────────────────────────────────────────────────
class _ExitInterviewTab extends ConsumerWidget {
  final List<ExitRequest> requests;
  final bool isMobile;

  const _ExitInterviewTab({required this.requests, required this.isMobile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        final interviewAsync = ref.watch(exitInterviewProvider(req.id ?? 0));

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Exit Interview: ${req.employeeName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Divider(height: 20),
                interviewAsync.when(
                  data: (interview) {
                    if (interview == null) {
                      return const Text('Exit interview feedback not recorded yet.');
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoCell(label: 'Reason for Leaving Category', value: interview.reasonCategory),
                        const SizedBox(height: 8),
                        _InfoCell(label: 'Detailed Feedback', value: interview.feedback),
                        const SizedBox(height: 8),
                        _InfoCell(label: 'Would Recommend Company', value: interview.recommendCompany ? 'Yes' : 'No'),
                      ],
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── 6. SETTLEMENT TAB ────────────────────────────────────────────────────────
class _SettlementTab extends ConsumerWidget {
  final List<ExitRequest> requests;
  final bool isMobile;

  const _SettlementTab({required this.requests, required this.isMobile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        final settlementAsync = ref.watch(exitSettlementProvider(req.id ?? 0));

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Final Settlement: ${req.employeeName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    _StatusBadge(status: req.status),
                  ],
                ),
                const Divider(height: 20),
                settlementAsync.when(
                  data: (s) {
                    final settlement = s ?? ExitSettlement(exitRequestId: req.id!, grossSalary: 50000, insuranceDeduction: 2000, uniformDeduction: 500, totalDeductions: 2500, netSettlement: 47500);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 24,
                          runSpacing: 12,
                          children: [
                            _InfoCell(label: 'Gross Salary', value: '₹${settlement.grossSalary}'),
                            _InfoCell(label: 'Insurance Deduction', value: '₹${settlement.insuranceDeduction}'),
                            _InfoCell(label: 'Uniform/Asset Deduction', value: '₹${settlement.uniformDeduction}'),
                            _InfoCell(label: 'Total Deductions', value: '₹${settlement.totalDeductions}'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: const Color(0xFF9CC70A).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Net Settlement Amount:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              Text('₹${settlement.netSettlement}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF9CC70A))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Note: Salary is processed after 45 working days as per company policy.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── 7. DOCUMENTS TAB ─────────────────────────────────────────────────────────
class _DocumentsTab extends StatelessWidget {
  final List<ExitRequest> requests;
  final bool isMobile;

  const _DocumentsTab({required this.requests, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        final isCompleted = req.status == 'Completed';

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Relieving Documents: ${req.employeeName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Divider(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _DocItemCard(title: 'Offer Letter', enabled: true),
                    _DocItemCard(title: 'Acceptance Letter', enabled: true),
                    _DocItemCard(title: 'Salary Slip', enabled: true),
                    _DocItemCard(title: 'Settlement Letter', enabled: true),
                    _DocItemCard(title: 'NOC Certificate', enabled: true),
                    _DocItemCard(title: 'Relieving Letter', enabled: isCompleted, subtitle: isCompleted ? null : 'Disabled until Exit Completed'),
                    _DocItemCard(title: 'Experience Letter', enabled: isCompleted, subtitle: isCompleted ? null : 'Disabled until Exit Completed'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── 8. COMPLETED EXITS TAB ───────────────────────────────────────────────────
class _CompletedExitsTab extends StatelessWidget {
  final List<ExitRequest> requests;
  final bool isMobile;

  const _CompletedExitsTab({required this.requests, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final completed = requests.where((r) => r.status == 'Completed').toList();

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Employee', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Last Working Day', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: completed.isEmpty
                ? [
                    const DataRow(cells: [
                      DataCell(Text('No completed exit records yet.')),
                      DataCell(Text('-')),
                      DataCell(Text('-')),
                      DataCell(Text('-')),
                      DataCell(Text('-')),
                    ])
                  ]
                : completed.map((r) {
                    return DataRow(cells: [
                      DataCell(Text(r.employeeName)),
                      DataCell(Text(r.department)),
                      DataCell(Text(r.lastWorkingDay)),
                      DataCell(_StatusBadge(status: r.status)),
                      DataCell(
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF414A51), foregroundColor: Colors.white),
                          icon: const Icon(Icons.timeline, size: 16),
                          label: const Text('View Timeline'),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                title: Text('Exit Timeline • ${r.employeeName}'),
                                content: Text('Completed all exit steps on ${r.lastWorkingDay}. Clearance & settlement verified.'),
                                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
                              ),
                            );
                          },
                        ),
                      ),
                    ]);
                  }).toList(),
          ),
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({required this.title, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(status, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}

class _InfoCell extends StatelessWidget {
  final String label;
  final String value;
  const _InfoCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _DocItemCard extends StatelessWidget {
  final String title;
  final bool enabled;
  final String? subtitle;

  const _DocItemCard({required this.title, required this.enabled, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: enabled ? Colors.grey.shade300 : Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.picture_as_pdf, color: enabled ? const Color(0xFF9CC70A) : Colors.grey, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: enabled ? Colors.black87 : Colors.grey))),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: TextStyle(fontSize: 10, color: Colors.red.shade700, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(onPressed: enabled ? () {} : null, child: const Text('Preview', style: TextStyle(fontSize: 11))),
              TextButton(onPressed: enabled ? () {} : null, child: const Text('Download', style: TextStyle(fontSize: 11))),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final String message;
  const _EmptyStateCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(message, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
