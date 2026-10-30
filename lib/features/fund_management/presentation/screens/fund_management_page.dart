import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/features/employee/providers/employee_providers.dart';
import 'package:flutter_application_1/features/fund_requester/domain/models/fund_request.dart';
import 'package:flutter_application_1/features/fund_management/providers/fund_management_providers.dart';
import '../widgets/all_funds_mobile_card.dart';
import '../widgets/all_funds_table_view.dart';
import '../widgets/approve_fund_dialog.dart';
import '../widgets/pending_fund_mobile_card.dart';
import '../widgets/pending_funds_table_view.dart';
import '../widgets/reject_reason_dialog.dart';
import '../widgets/view_quotation_dialog.dart';

class FundManagementPage extends ConsumerStatefulWidget {
  const FundManagementPage({super.key});

  @override
  ConsumerState<FundManagementPage> createState() => _FundManagementPageState();
}

class _FundManagementPageState extends ConsumerState<FundManagementPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  List<FundRequest> _applySearchAndFilter(List<FundRequest> list, {bool isPendingTab = false}) {
    final query = _searchController.text.trim().toLowerCase();
    return list.where((item) {
      if (isPendingTab && item.status != 'Pending') return false;

      if (!isPendingTab && _selectedStatusFilter != 'All') {
        if (item.status.toLowerCase() != _selectedStatusFilter.toLowerCase()) {
          return false;
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
    final pendingCount = pendingList.where((r) => r.status == 'Pending').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar / Title Header
            _buildTopHeader(pendingCount),

            // Tab Bar
            _buildTabBar(pendingCount),

            // Search & Filter Strip
            _buildFilterStrip(),

            // Content Body
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Pending Fund Requests
                  pendingAsync.when(
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
                  ),

                  // Tab 2: All Fund Requests
                  allAsync.when(
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
                                      onViewDetails: (r) {
                                        showDialog(
                                          context: context,
                                          builder: (_) => ViewQuotationDialog(request: r),
                                        );
                                      },
                                    ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error loading fund requests: $e')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader(int pendingCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      color: Colors.white,
      child: Row(
        children: [
          if (Navigator.of(context).canPop()) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 6),
          ],
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.account_balance_wallet,
              color: AppColors.active,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fund Management',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  'Review employee fund requests, approve or deduct against project actual values',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(int pendingCount) {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.active,
        unselectedLabelColor: const Color(0xFF64748B),
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Pending Fund Requests'),
                if (pendingCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$pendingCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Tab(
            text: 'All Fund Requests',
          ),
        ],
      ),
    );
  }

  Widget _buildFilterStrip() {
    final isAllFundsTab = _tabController.index == 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
            ],
          ),

          // Quick Filter Chips (for Tab 2: All Funds)
          if (isAllFundsTab) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text(
                    'Status: ',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildStatusChip('All'),
                  _buildStatusChip('Pending'),
                  _buildStatusChip('Approved'),
                  _buildStatusChip('Partially Approved'),
                  _buildStatusChip('Rejected'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final isSelected = _selectedStatusFilter == status;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(
          status,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
        selected: isSelected,
        selectedColor: AppColors.active,
        backgroundColor: const Color(0xFFF1F5F9),
        showCheckmark: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: isSelected ? AppColors.active : const Color(0xFFE2E8F0),
          ),
        ),
        onSelected: (val) {
          setState(() {
            _selectedStatusFilter = status;
          });
        },
      ),
    );
  }
}

