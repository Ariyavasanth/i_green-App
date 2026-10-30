import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/features/employee/providers/employee_providers.dart';
import 'package:flutter_application_1/features/fund_requester/domain/models/fund_category_constants.dart';
import 'package:flutter_application_1/features/fund_requester/domain/models/fund_request.dart';
import 'package:flutter_application_1/features/fund_requester/providers/fund_request_providers.dart';
import 'widgets/fund_request_details_dialog.dart';
import 'widgets/fund_request_mobile_card.dart';
import 'widgets/fund_request_table_view.dart';
import 'widgets/searchable_select_picker.dart';

class FundRequesterPage extends ConsumerStatefulWidget {
  const FundRequesterPage({super.key});

  @override
  ConsumerState<FundRequesterPage> createState() => _FundRequesterPageState();
}

class _FundRequesterPageState extends ConsumerState<FundRequesterPage> {
  late final TextEditingController _searchController;

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

  void _openCreatePage() {
    context.push('/fund-requester/create');
  }

  void _showDetailsDialog(FundRequest request) {
    final currentEmp = ref.read(currentEmployeeProvider);
    final canReview = currentEmp?.isSuperAdmin == true ||
        currentEmp?.hasPermission('Fund Requester') == true ||
        currentEmp?.hasPermission('Admin') == true;

    showDialog(
      context: context,
      builder: (ctx) => FundRequestDetailsDialog(
        request: request,
        canReview: canReview,
        onApprove: (amt, remarks) async {
          final repo = ref.read(fundRequestRepositoryProvider);
          await repo.approveFundRequest(
            request.id,
            approvedAmount: amt,
            approvedBy: currentEmp?.fullName ?? 'Admin Reviewer',
            remarks: remarks,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Fund Request ${request.requestNumber} approved successfully!'),
                backgroundColor: const Color(0xFF16A34A),
              ),
            );
          }
        },
        onReject: (reason) async {
          final repo = ref.read(fundRequestRepositoryProvider);
          await repo.rejectFundRequest(
            request.id,
            rejectedBy: currentEmp?.fullName ?? 'Admin Reviewer',
            reason: reason,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Fund Request ${request.requestNumber} rejected.'),
                backgroundColor: const Color(0xFFDC2626),
              ),
            );
          }
        },
        onDelete: () => _confirmDelete(request),
      ),
    );
  }

  void _confirmDelete(FundRequest request) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Fund Request?'),
        content: Text(
          'Are you sure you want to delete fund request for project "${request.projectCode}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final repo = ref.read(fundRequestRepositoryProvider);
              await repo.deleteFundRequest(request.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Fund request deleted.'),
                    backgroundColor: Color(0xFF475569),
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredAsync = ref.watch(filteredFundRequestsProvider);
    final allRequestsAsync = ref.watch(allFundRequestsStreamProvider);
    final selectedStatus = ref.watch(fundRequestStatusFilterProvider);
    final selectedCategory = ref.watch(fundRequestCategoryFilterProvider);
    final viewMode = ref.watch(fundRequestViewModeProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = MediaQuery.of(context).size.width < 768;
          if (isMobile) {
            // Floating green plus button matching reference screenshot Image 2, 3, 4, 5
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FloatingActionButton(
                heroTag: 'fundRequesterFab',
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 4,
                onPressed: _openCreatePage,
                tooltip: 'Create Fund Request',
                child: const Icon(Icons.add, size: 30),
              ),
            );
          }
          // Desktop extended floating action button with plus icon and text
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FloatingActionButton.extended(
              heroTag: 'fundRequesterFab',
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.add_rounded, size: 24),
              label: const Text(
                'Request Fund',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.3),
              ),
              onPressed: _openCreatePage,
            ),
          );
        },
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 768;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allFundRequestsStreamProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 24,
                vertical: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Metrics Cards
                  allRequestsAsync.when(
                    loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (all) => _buildMetricsRow(all, isMobile),
                  ),
                  const SizedBox(height: 20),

                  // Filters & Search Bar
                  _buildFilterAndSearchCard(isMobile, selectedStatus, selectedCategory, viewMode),
                  const SizedBox(height: 18),

                  // Data Display: Table View or Mobile Cards View
                  filteredAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (err, _) => Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('Error loading requests: $err', style: TextStyle(color: Colors.red.shade700)),
                    ),
                    data: (requests) {
                      final useTableView = !isMobile && viewMode != FundRequestViewMode.card;

                      if (useTableView) {
                        return FundRequestTableView(
                          requests: requests,
                          onViewDetails: _showDetailsDialog,
                          onDelete: _confirmDelete,
                          onApprove: (FundRequest r) async {
                            final currentEmp = ref.read(currentEmployeeProvider);
                            final repo = ref.read(fundRequestRepositoryProvider);
                            await repo.approveFundRequest(
                              r.id,
                              approvedAmount: r.requestAmount,
                              approvedBy: currentEmp?.fullName ?? 'Manager',
                            );
                          },
                          onReject: (FundRequest r) async {
                            final currentEmp = ref.read(currentEmployeeProvider);
                            final repo = ref.read(fundRequestRepositoryProvider);
                            await repo.rejectFundRequest(
                              r.id,
                              rejectedBy: currentEmp?.fullName ?? 'Manager',
                              reason: 'Rejected during quick table review.',
                            );
                          },
                        );
                      }

                      // Mobile Card View matching Image 5
                      if (requests.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: const [
                              Icon(Icons.inbox_outlined, size: 48, color: Color(0xFF94A3B8)),
                              SizedBox(height: 12),
                              Text(
                                'No fund requests found',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Tap the floating "+" button below to submit a new fund request.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: requests.map((req) {
                          return FundRequestMobileCard(
                            request: req,
                            onTap: () => _showDetailsDialog(req),
                            onDelete: () => _confirmDelete(req),
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 80), // Extra space for FAB
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Metric cards at the top
  Widget _buildMetricsRow(List<FundRequest> all, bool isMobile) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final totalRequested = all.fold<double>(0.0, (acc, r) => acc + r.requestAmount);
    final totalApproved = all.fold<double>(0.0, (acc, r) => acc + r.approvedAmount);
    final pendingCount = all.where((r) => r.status.toLowerCase() == 'pending').length;

    final cards = [
      _buildMetricCard(
        title: 'Total Requests',
        value: '${all.length}',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFF0284C7),
        bgColor: const Color(0xFFE0F2FE),
      ),
      _buildMetricCard(
        title: 'Amount Requested',
        value: currency.format(totalRequested),
        icon: Icons.currency_rupee_rounded,
        color: const Color(0xFFEAB308),
        bgColor: const Color(0xFFFEF9C3),
      ),
      _buildMetricCard(
        title: 'Total Approved',
        value: currency.format(totalApproved),
        icon: Icons.check_circle_outline_rounded,
        color: AppColors.primary,
        bgColor: const Color(0xFFDCFCE7),
      ),
      _buildMetricCard(
        title: 'Pending Review',
        value: '$pendingCount',
        icon: Icons.hourglass_top_rounded,
        color: const Color(0xFFF97316),
        bgColor: const Color(0xFFFFEDD5),
      ),
    ];

    if (isMobile) {
      return GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.6,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: cards,
      );
    }

    return Row(
      children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: c))).toList(),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Search & filter bar
  Widget _buildFilterAndSearchCard(
    bool isMobile,
    String selectedStatus,
    String selectedCategory,
    FundRequestViewMode viewMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search TextField & View Mode Switcher
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by requester, project code, or item...',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(fundRequestSearchQueryProvider.notifier).state = '';
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  onChanged: (val) {
                    ref.read(fundRequestSearchQueryProvider.notifier).state = val;
                  },
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 12),
                // Table View / Card View toggle
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.table_chart_rounded, size: 20),
                        tooltip: 'Table View',
                        color: viewMode != FundRequestViewMode.card ? AppColors.active : const Color(0xFF94A3B8),
                        onPressed: () {
                          ref.read(fundRequestViewModeProvider.notifier).state = FundRequestViewMode.table;
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.grid_view_rounded, size: 20),
                        tooltip: 'Card View',
                        color: viewMode == FundRequestViewMode.card ? AppColors.active : const Color(0xFF94A3B8),
                        onPressed: () {
                          ref.read(fundRequestViewModeProvider.notifier).state = FundRequestViewMode.card;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Status Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusChip('All', selectedStatus),
                _buildStatusChip('Pending', selectedStatus),
                _buildStatusChip('Approved', selectedStatus),
                _buildStatusChip('Rejected', selectedStatus),
                const SizedBox(width: 14),
                // Category Filter (Searchable with Best UI)
                InkWell(
                  onTap: () async {
                    final items = [
                      const SearchableSelectItem<String>(
                        value: 'All',
                        title: 'All Categories',
                        leading: Icon(Icons.all_inclusive_rounded, color: Color(0xFF64748B), size: 18),
                      ),
                      ...FundCategoryConstants.categories.map((c) => SearchableSelectItem<String>(
                            value: c.title,
                            title: c.title,
                            subtitle: '${c.subCategories.length} sub-categories',
                            searchKey: '${c.title} ${c.subCategories.map((s) => s.title).join(" ")}',
                            leading: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: c.primaryColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(c.icon, color: c.primaryColor, size: 16),
                            ),
                          )),
                    ];
                    final selected = await showSearchableSelect<String>(
                      context: context,
                      title: 'Filter by Category',
                      items: items,
                      selectedValue: selectedCategory,
                      searchHint: 'Search categories...',
                    );
                    if (selected != null) {
                      ref.read(fundRequestCategoryFilterProvider.notifier).state = selected;
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: selectedCategory != 'All'
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selectedCategory != 'All' ? AppColors.primary : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 15,
                          color: selectedCategory != 'All' ? AppColors.primary : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          selectedCategory == 'All' ? 'All Categories' : selectedCategory,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selectedCategory != 'All' ? const Color(0xFF1E293B) : const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, String current) {
    final isSelected = current.toLowerCase() == status.toLowerCase();

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(status),
        selected: isSelected,
        showCheckmark: false,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : const Color(0xFF475569),
        ),
        backgroundColor: const Color(0xFFF1F5F9),
        selectedColor: AppColors.active,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? AppColors.active : const Color(0xFFE2E8F0),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        onSelected: (_) {
          ref.read(fundRequestStatusFilterProvider.notifier).state = status;
        },
      ),
    );
  }
}
