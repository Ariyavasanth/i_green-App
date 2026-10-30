import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/employee/providers/employee_providers.dart';
import 'package:flutter_application_1/features/fund_requester/domain/models/fund_request.dart';
import 'package:flutter_application_1/features/fund_management/providers/fund_management_providers.dart';
import '../widgets/all_funds_mobile_card.dart';
import '../widgets/all_funds_table_view.dart';
import '../widgets/approve_fund_dialog.dart';
import '../widgets/fund_request_read_details_dialog.dart';
import '../widgets/pending_fund_mobile_card.dart';
import '../widgets/pending_funds_table_view.dart';
import '../widgets/reject_reason_dialog.dart';

class FundManagementPage extends ConsumerStatefulWidget {
  const FundManagementPage({super.key});

  @override
  ConsumerState<FundManagementPage> createState() => _FundManagementPageState();
}

class _FundManagementPageState extends ConsumerState<FundManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedTabIndex = 0; // 0: Pending Requests, 1: View All Requests
  String _selectedStatusFilter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleApprove(FundRequest request) {
    showDialog(
      context: context,
      builder: (ctx) => ApproveFundDialog(
        request: request,
        onConfirm: (approvedAmount, remarks) async {
          final currentEmp = ref.read(currentEmployeeProvider);
          final adminName = currentEmp?.fullName.isNotEmpty == true
              ? currentEmp!.fullName
              : 'Admin Approver';

          final repo = ref.read(fundManagementRepositoryProvider);
          await repo.approveOrPartiallyApproveRequest(
            requestId: request.id,
            projectCode: request.projectCode,
            approvedAmount: approvedAmount,
            approvedBy: adminName,
            remarks: remarks,
          );

          if (mounted) {
            final isPartial = approvedAmount < (request.requestAmount - 0.01);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isPartial
                      ? 'Fund Request partially approved (₹${approvedAmount.toStringAsFixed(2)} deducted from project ${request.projectCode})'
                      : 'Fund Request approved (₹${approvedAmount.toStringAsFixed(2)} deducted from project ${request.projectCode})',
                ),
                backgroundColor: const Color(0xFF16A34A),
              ),
            );
          }
        },
      ),
    );
  }

  void _handleReject(FundRequest request) {
    showDialog(
      context: context,
      builder: (ctx) => RejectReasonDialog(
        requestNumber: request.requestNumber.isNotEmpty ? request.requestNumber : request.id,
        onConfirm: (reason) async {
          final currentEmp = ref.read(currentEmployeeProvider);
          final adminName = currentEmp?.fullName.isNotEmpty == true
              ? currentEmp!.fullName
              : 'Admin Approver';

          final repo = ref.read(fundManagementRepositoryProvider);
          await repo.rejectRequest(
            requestId: request.id,
            rejectedBy: adminName,
            reason: reason,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Fund Request rejected: $reason'),
                backgroundColor: const Color(0xFFDC2626),
              ),
            );
          }
        },
      ),
    );
  }

  void _handleViewDetails(FundRequest request) {
    FundRequestReadDetailsDialog.show(
      context: context,
      request: request,
      onApprove: _selectedTabIndex == 0 ? _handleApprove : null,
      onReject: _selectedTabIndex == 0 ? _handleReject : null,
    );
  }

  List<FundRequest> _applySearchAndFilter(List<FundRequest> list, {required bool isPendingTab}) {
    final query = _searchController.text.trim().toLowerCase();
    return list.where((item) {
      if (isPendingTab) {
        if (item.status.toLowerCase() != 'pending') return false;
      } else {
        // View All Requests tab shows reviewed/processed requests (Approved, Partially Approved, Rejected)
        if (item.status.toLowerCase() == 'pending') return false;

        if (_selectedStatusFilter != 'All') {
          if (item.status.toLowerCase() != _selectedStatusFilter.toLowerCase()) {
            return false;
          }
        }
      }

      if (query.isEmpty) return true;

      final empId = (item.employeeCustomId.isNotEmpty ? item.employeeCustomId : item.employeeId).toLowerCase();
      final empName = item.employeeName.toLowerCase();
      final proj = item.projectCode.toLowerCase();
      final msg = item.message.toLowerCase();

      return empId.contains(query) ||
          empName.contains(query) ||
          proj.contains(query) ||
          msg.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingFundRequestsStreamProvider);
    final allAsync = ref.watch(allFundRequestsStreamProvider);

    final pendingList = pendingAsync.asData?.value ?? [];
    final pendingCount = pendingList.where((r) => r.status.toLowerCase() == 'pending').length;
    final allList = allAsync.asData?.value ?? [];
    final processedCount = allList.where((r) => r.status.toLowerCase() != 'pending').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Prominent 2-Tab Navigation: Pending Requests & View All Requests
            _buildTabsHeader(pendingCount, processedCount),

            // Search & Filter Strip
            _buildFilterStrip(),

            // Content Body based on selected tab
            Expanded(
              child: _selectedTabIndex == 0
                  ? _buildPendingTabContent(pendingAsync)
                  : _buildAllRequestsTabContent(allAsync),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabsHeader(int pendingCount, int allCount) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Tab 1: Pending Requests
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTabIndex = 0),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _selectedTabIndex == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.hourglass_top_rounded,
                      size: 18,
                      color: _selectedTabIndex == 0 ? const Color(0xFFB45309) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Pending Requests',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: _selectedTabIndex == 0 ? FontWeight.bold : FontWeight.w600,
                        color: _selectedTabIndex == 0 ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _selectedTabIndex == 0 ? const Color(0xFFFEF3C7) : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$pendingCount',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _selectedTabIndex == 0 ? const Color(0xFFB45309) : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Tab 2: View All Requests
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTabIndex = 1),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _selectedTabIndex == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.ballot_outlined,
                      size: 18,
                      color: _selectedTabIndex == 1 ? const Color(0xFF414A51) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'View All Requests',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: _selectedTabIndex == 1 ? FontWeight.bold : FontWeight.w600,
                        color: _selectedTabIndex == 1 ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _selectedTabIndex == 1 ? const Color(0xFF414A51) : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$allCount',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _selectedTabIndex == 1 ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          // Search input
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search by employee ID, name, project code...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
            ),
          ),
          if (_selectedTabIndex == 1) ...[
            const SizedBox(width: 12),
            // Status filter dropdown for "View All Requests" tab
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedStatusFilter,
                  icon: const Icon(Icons.filter_list, size: 18, color: Color(0xFF414A51)),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Processed')),
                    DropdownMenuItem(value: 'Approved', child: Text('Approved')),
                    DropdownMenuItem(value: 'Partially Approved', child: Text('Partially Approved')),
                    DropdownMenuItem(value: 'Rejected', child: Text('Rejected')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedStatusFilter = val);
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingTabContent(AsyncValue<List<FundRequest>> pendingAsync) {
    return pendingAsync.when(
      data: (data) {
        final filtered = _applySearchAndFilter(data, isPendingTab: true);
        return LayoutBuilder(
          builder: (ctx, constraints) {
            final isMobile = constraints.maxWidth < 900;
            return RefreshIndicator(
              onRefresh: () async => ref.refresh(pendingFundRequestsStreamProvider),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: isMobile
                    ? Column(
                        children: filtered
                            .map((r) => PendingFundMobileCard(
                                  request: r,
                                  onApprove: _handleApprove,
                                  onReject: _handleReject,
                                ))
                            .toList(),
                      )
                    : PendingFundsTableView(
                        requests: filtered,
                        onApprove: _handleApprove,
                        onReject: _handleReject,
                      ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading pending requests: $e')),
    );
  }

  Widget _buildAllRequestsTabContent(AsyncValue<List<FundRequest>> allAsync) {
    return allAsync.when(
      data: (data) {
        final filtered = _applySearchAndFilter(data, isPendingTab: false);
        return LayoutBuilder(
          builder: (ctx, constraints) {
            final isMobile = constraints.maxWidth < 900;
            return RefreshIndicator(
              onRefresh: () async => ref.refresh(allFundRequestsStreamProvider),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: isMobile
                    ? Column(
                        children: filtered
                            .map((r) => AllFundsMobileCard(request: r))
                            .toList(),
                      )
                    : AllFundsTableView(
                        requests: filtered,
                        onViewDetails: _handleViewDetails,
                      ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading fund requests: $e')),
    );
  }
}
