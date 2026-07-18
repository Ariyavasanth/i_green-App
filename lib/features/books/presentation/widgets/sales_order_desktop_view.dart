import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/books_repository.dart';
import '../../providers/books_providers.dart';
import '../books_pages.dart' show PageFrame, error, loading, money;
import 'sales_order_actions.dart';

/// Desktop/tablet Sales Order list — full feature parity with the mobile
/// list ([SalesOrderMobileView]) but laid out as a proper data table inside
/// the app's standard [PageFrame] chrome (the same shell Items/Customers use)
/// instead of stacked cards. Reuses [transactionsProvider],
/// [booksSearchQueryProvider] and the shared [handleSalesOrderAction] —
/// only presentation differs from the mobile view.
class SalesOrderDesktopView extends ConsumerStatefulWidget {
  const SalesOrderDesktopView({required this.onAdd, super.key});

  final VoidCallback onAdd;

  @override
  ConsumerState<SalesOrderDesktopView> createState() => _SalesOrderDesktopViewState();
}

class _SalesOrderDesktopViewState extends ConsumerState<SalesOrderDesktopView> {
  late final _searchController = TextEditingController(
    text: ref.read(booksSearchQueryProvider),
  );
  String _statusFilter = 'All';
  SalesOrderSort _sort = SalesOrderSort.dateDesc;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncRows = ref.watch(transactionsProvider(TransactionType.salesOrder));
    return PageFrame(
      title: 'All Sales Orders',
      onAdd: widget.onAdd,
      header: _DesktopToolbar(
        searchController: _searchController,
        statusFilter: _statusFilter,
        onStatusChanged: (v) => setState(() => _statusFilter = v),
        sort: _sort,
        onSortChanged: (v) => setState(() => _sort = v),
      ),
      child: asyncRows.when(
        loading: loading,
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
                .where((r) => r.status.toLowerCase() == _statusFilter.toLowerCase())
                .toList();
          }
          rows = sortSalesOrders(rows, _sort);

          if (all.isEmpty) {
            return _DesktopEmptyState(onAdd: widget.onAdd);
          }
          if (rows.isEmpty) {
            return const _DesktopNoResultsState();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _TableHeader(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () =>
                      ref.refresh(transactionsProvider(TransactionType.salesOrder).future),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) => _DesktopRow(
                      row: rows[i],
                      onAction: (action) =>
                          handleSalesOrderAction(context, ref, rows[i], action),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DesktopToolbar extends StatelessWidget {
  const _DesktopToolbar({
    required this.searchController,
    required this.statusFilter,
    required this.onStatusChanged,
    required this.sort,
    required this.onSortChanged,
  });

  final TextEditingController searchController;
  final String statusFilter;
  final ValueChanged<String> onStatusChanged;
  final SalesOrderSort sort;
  final ValueChanged<SalesOrderSort> onSortChanged;

  @override
  Widget build(BuildContext context) => Consumer(
    builder: (context, ref, _) => Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: searchController,
            onChanged: (v) => ref.read(booksSearchQueryProvider.notifier).state = v,
            decoration: InputDecoration(
              hintText: 'Search sales orders',
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        searchController.clear();
                        ref.read(booksSearchQueryProvider.notifier).state = '';
                      },
                    ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<String>(
            initialValue: statusFilter,
            isDense: true,
            decoration: const InputDecoration(labelText: 'Status'),
            items: salesOrderStatusFilters
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => onStatusChanged(v ?? statusFilter),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<SalesOrderSort>(
            initialValue: sort,
            isDense: true,
            decoration: const InputDecoration(labelText: 'Sort by'),
            items: SalesOrderSort.values
                .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                .toList(),
            onChanged: (v) => onSortChanged(v ?? sort),
          ),
        ),
      ],
    ),
  );
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();
  static const _style = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.3,
  );

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: const BoxDecoration(
      color: AppColors.canvas,
      border: Border(bottom: BorderSide(color: AppColors.divider)),
    ),
    child: const Row(
      children: [
        Expanded(flex: 3, child: Text('NUMBER', style: _style)),
        Expanded(flex: 3, child: Text('CUSTOMER', style: _style)),
        Expanded(flex: 2, child: Text('ORDER DATE', style: _style)),
        Expanded(flex: 2, child: Text('EXPECTED SHIP DATE', style: _style)),
        Expanded(flex: 2, child: Text('AMOUNT', textAlign: TextAlign.right, style: _style)),
        Expanded(flex: 2, child: Text('STATUS', style: _style)),
        SizedBox(width: 48),
      ],
    ),
  );
}

class _DesktopRow extends StatelessWidget {
  const _DesktopRow({required this.row, required this.onAction});
  final SalesTransaction row;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            row.number,
            style: const TextStyle(color: AppColors.active, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row.customer, overflow: TextOverflow.ellipsis),
              if (row.referenceNumber.isNotEmpty)
                Text(
                  'Ref: ${row.referenceNumber}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        Expanded(flex: 2, child: Text(DateFormat('dd/MM/yyyy').format(row.date))),
        Expanded(
          flex: 2,
          child: Text(
            row.dueDate == null ? '—' : DateFormat('dd/MM/yyyy').format(row.dueDate!),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            money.format(row.amount),
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(flex: 2, child: _StatusChip(status: row.status)),
        SizedBox(
          width: 48,
          child: PopupMenuButton<String>(
            tooltip: 'More options',
            onSelected: onAction,
            itemBuilder: (_) => salesOrderMenuItems(),
          ),
        ),
      ],
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
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

class _DesktopEmptyState extends StatelessWidget {
  const _DesktopEmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.receipt_long_outlined, size: 56, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          const Text(
            'No Sales Orders Found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create your first sales order to start fulfilling customer orders.',
            style: TextStyle(color: AppColors.textSecondary),
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

class _DesktopNoResultsState extends StatelessWidget {
  const _DesktopNoResultsState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.filter_alt_off_outlined, size: 40, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Text('No sales orders match your search or filter', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    ),
  );
}
