import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/visual_effects.dart';
import '../../domain/books_repository.dart';
import '../../providers/books_providers.dart';
import '../books_pages.dart' show error, money;
import 'sales_order_actions.dart';

/// Mobile-only Sales Order list experience. Reuses [transactionsProvider],
/// [booksSearchQueryProvider] and [BooksRepository.addTransaction] — only
/// presentation (and, for Duplicate, a plain reuse of the existing add-draft
/// call) is new here, no business logic is duplicated.
class SalesOrderMobileView extends ConsumerStatefulWidget {
  const SalesOrderMobileView({required this.onAdd, super.key});

  final VoidCallback onAdd;

  @override
  ConsumerState<SalesOrderMobileView> createState() =>
      _SalesOrderMobileViewState();
}

const _pageSize = 20;

class _SalesOrderMobileViewState extends ConsumerState<SalesOrderMobileView> {
  late final _searchController = TextEditingController(
    text: ref.read(booksSearchQueryProvider),
  );
  final _scrollController = ScrollController();
  String _statusFilter = 'All';
  SalesOrderSort _sort = SalesOrderSort.dateDesc;
  int _visibleCount = _pageSize;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final nearBottom =
        _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 240;
    if (nearBottom) _revealMore();
  }

  void _revealMore() => setState(() => _visibleCount += _pageSize);

  void _resetPaging() => setState(() => _visibleCount = _pageSize);

  @override
  Widget build(BuildContext context) {
    final asyncRows = ref.watch(transactionsProvider(TransactionType.salesOrder));
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onAdd,
        icon: const Icon(Icons.add),
        label: const Text('New Sales Order'),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SalesOrderHeader(count: asyncRows.valueOrNull?.length),
              const SizedBox(height: 12),
              _SalesOrderSearchField(
                controller: _searchController,
                onChanged: (_) => _resetPaging(),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _SalesOrderFilterChips(
                      selected: _statusFilter,
                      onSelected: (v) => setState(() {
                        _statusFilter = v;
                        _resetPaging();
                      }),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _SortButton(
                    selected: _sort,
                    onSelected: (v) => setState(() {
                      _sort = v;
                      _resetPaging();
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: asyncRows.when(
                  loading: () => const ShimmerLoading(),
                  error: error,
                  data: (all) {
                    final q = ref.watch(booksSearchQueryProvider).toLowerCase();
                    var rows = all
                        .where(
                          (r) => '${r.number} ${r.customer} ${r.status} ${r.referenceNumber}'
                              .toLowerCase()
                              .contains(q),
                        )
                        .toList();
                    if (_statusFilter != 'All') {
                      rows = rows
                          .where(
                            (r) =>
                                r.status.toLowerCase() ==
                                _statusFilter.toLowerCase(),
                          )
                          .toList();
                    }
                    rows = sortSalesOrders(rows, _sort);

                    if (all.isEmpty) {
                      return _SalesOrderEmptyState(onAdd: widget.onAdd);
                    }
                    if (rows.isEmpty) {
                      return const _SalesOrderNoResultsState();
                    }
                    final visible = rows.take(_visibleCount).toList();
                    return RefreshIndicator(
                      color: AppColors.active,
                      onRefresh: () => ref.refresh(
                        transactionsProvider(TransactionType.salesOrder).future,
                      ),
                      child: ListView.separated(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: visible.length + (visible.length < rows.length ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          if (i >= visible.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.4),
                                ),
                              ),
                            );
                          }
                          return FadeSlideIn(
                            child: _SalesOrderCard(
                              row: visible[i],
                              onAction: (action) => _handleAction(visible[i], action),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAction(SalesTransaction row, String action) =>
      handleSalesOrderAction(context, ref, row, action);
}

class _SalesOrderHeader extends StatelessWidget {
  const _SalesOrderHeader({required this.count});
  final int? count;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sales Orders', style: AppTextStyles.pageTitle),
            const SizedBox(height: 2),
            Text(
              count == null
                  ? 'Loading…'
                  : '$count sales order${count == 1 ? '' : 's'} total',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    ],
  );
}

class _SalesOrderSearchField extends StatelessWidget {
  const _SalesOrderSearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Consumer(
    builder: (context, ref, _) => TextField(
      controller: controller,
      onChanged: (v) {
        ref.read(booksSearchQueryProvider.notifier).state = v;
        onChanged(v);
      },
      decoration: InputDecoration(
        hintText: 'Search sales orders',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  controller.clear();
                  ref.read(booksSearchQueryProvider.notifier).state = '';
                  onChanged('');
                },
              ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.active, width: 1.5),
        ),
      ),
    ),
  );
}

class _SalesOrderFilterChips extends StatelessWidget {
  const _SalesOrderFilterChips({required this.selected, required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 36,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: salesOrderStatusFilters.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final label = salesOrderStatusFilters[i];
        final isSelected = label == selected;
        return FilterChip(
          label: Text(label),
          selected: isSelected,
          showCheckmark: false,
          labelStyle: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
          backgroundColor: AppColors.surface,
          selectedColor: AppColors.active,
          side: BorderSide(color: isSelected ? AppColors.active : AppColors.divider),
          onSelected: (_) => onSelected(label),
        );
      },
    ),
  );
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.selected, required this.onSelected});
  final SalesOrderSort selected;
  final ValueChanged<SalesOrderSort> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    height: 36,
    width: 36,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.divider),
    ),
    child: PopupMenuButton<SalesOrderSort>(
      tooltip: 'Sort',
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.swap_vert, size: 20, color: AppColors.textSecondary),
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final option in SalesOrderSort.values)
          PopupMenuItem(
            value: option,
            child: Row(
              children: [
                if (option == selected)
                  const Icon(Icons.check, size: 16, color: AppColors.primary)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(option.label),
              ],
            ),
          ),
      ],
    ),
  );
}

class _SalesOrderCard extends StatelessWidget {
  const _SalesOrderCard({required this.row, required this.onAction});
  final SalesTransaction row;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.divider),
      boxShadow: const [
        BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 4)),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.number,
                      style: const TextStyle(
                        color: AppColors.active,
                        fontWeight: FontWeight.w700,
                        fontSize: 16.5,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _StatusBadge(status: row.status),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.customer,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    money.format(row.amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15.5,
                      color: AppColors.active,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _MetaChip(
                    icon: Icons.calendar_today_outlined,
                    label: DateFormat('dd/MM/yyyy').format(row.date),
                  ),
                  if (row.dueDate != null)
                    _MetaChip(
                      icon: Icons.local_shipping_outlined,
                      label: 'Ships ${DateFormat('dd/MM/yyyy').format(row.dueDate!)}',
                    ),
                  const _MetaChip(icon: Icons.currency_rupee, label: 'INR'),
                ],
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'More options',
          onSelected: onAction,
          itemBuilder: (_) => salesOrderMenuItems(),
        ),
      ],
    ),
  );
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: AppColors.textSecondary),
      const SizedBox(width: 3),
      Text(label, style: AppTextStyles.caption),
    ],
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = salesOrderStatusColor(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SalesOrderEmptyState extends StatelessWidget {
  const _SalesOrderEmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 56,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          const Text('No Sales Orders Found', style: AppTextStyles.heading),
          const SizedBox(height: 6),
          const Text(
            'Create your first sales order to start fulfilling customer orders.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create Sales Order'),
          ),
        ],
      ),
    ),
  );
}

class _SalesOrderNoResultsState extends StatelessWidget {
  const _SalesOrderNoResultsState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.filter_alt_off_outlined, size: 40, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Text('No sales orders match your search or filter', style: AppTextStyles.caption),
        ],
      ),
    ),
  );
}
