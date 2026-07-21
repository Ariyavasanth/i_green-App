import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/layout/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/visual_effects.dart';
import '../domain/books_repository.dart';
import '../providers/books_providers.dart';
import 'dashboard_sections.dart';
import 'item_details_screen.dart';
import 'items_desktop_view.dart';
import 'widgets/quote_mobile_view.dart';
import 'widgets/sales_order_desktop_view.dart';
import 'widgets/sales_order_mobile_view.dart';

final money = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);

class HomePage extends ConsumerWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(dashboardMetricsProvider)
      .when(
        loading: loading,
        error: error,
        data: (m) => FadeSlideIn(
          child: LayoutBuilder(
            builder: (context, constraints) => ResponsiveContent(
              child: ListView(
                padding: EdgeInsets.all(AppLayout.gutter(constraints.maxWidth)),
                children: [
                  const Text(
                    'Here’s your business overview',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  // Dashboard cards reflow without duplicating their data or behavior.
                  LayoutBuilder(
                    builder: (context, cardConstraints) {
                      final receivables = _metric(
                        'Total Receivables',
                        'Current ${money.format(m.currentReceivables)}',
                        money.format(m.receivables),
                        'Overdue ${money.format(m.overdueReceivables)}',
                        backgroundColor:
                            cardConstraints.maxWidth < AppBreakpoints.tablet
                            ? const Color(0xFFD1E3E1)
                            : null,
                      );
                      final payables = _metric(
                        'Total Payables',
                        'Current ${money.format(m.currentPayables)}',
                        money.format(m.payables),
                        'Overdue ${money.format(m.overduePayables)}',
                        backgroundColor:
                            cardConstraints.maxWidth < AppBreakpoints.tablet
                            ? const Color(0xFFFFD6EA)
                            : null,
                      );
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: receivables),
                          const SizedBox(width: 16),
                          Expanded(child: payables),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  DashboardSections(metrics: m),
                ],
              ),
            ),
          ),
        ),
      );
  static Widget _metric(
    String title,
    String current,
    String value,
    String overdue, {
    Color? backgroundColor,
  }) => Card(
    color: backgroundColor,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const Divider(height: 28),
          Text(
            value,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 16,
            runSpacing: 6,
            children: [Text(current), Text(overdue)],
          ),
        ],
      ),
    ),
  );
}

class ItemsPage extends ConsumerWidget {
  const ItemsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => LayoutBuilder(
    builder: (context, constraints) {
      final items = ref.watch(itemsProvider);
      if (constraints.maxWidth >= AppBreakpoints.laptop) {
        return items.when(
          loading: loading,
          error: error,
          data: (all) => ItemsDesktopView(
            items: all,
            onAdd: () => context.push('/items/new'),
            onRequestMaterial: () => context.push('/items/request-material'),
            onReturn: () => context.push('/items/return'),
            onOpen: (item) => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ItemDetailsScreen(item: item)),
            ),
          ),
        );
      }

      // The mobile layout intentionally remains the original compact list.
      return Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/items/new'),
          icon: const Icon(Icons.add),
          label: const Text('New Item'),
        ),
        body: PageFrame(
          title: 'Active Items',
          headerAction: Wrap(
            spacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => context.push('/items/request-material'),
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: const Text('Request Material'),
              ),
              ElevatedButton.icon(
                onPressed: () => context.push('/items/return'),
                icon: const Icon(Icons.assignment_return_outlined, size: 18),
                label: const Text('Return'),
              ),
            ],
          ),
          child: items.when(
            loading: loading,
            error: error,
            data: (all) {
              final q = ref.watch(booksSearchQueryProvider).toLowerCase();
              final rows = all
                  .where((r) => '${r.name} ${r.sku}'.toLowerCase().contains(q))
                  .toList();
              return ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final r = rows[i];
                  return ListTile(
                    minVerticalPadding: 14,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ItemDetailsScreen(item: r),
                      ),
                    ),
                    leading: Container(
                      width: 48,
                      height: 48,
                      color: AppColors.canvas,
                      child: const Icon(Icons.image_outlined),
                    ),
                    title: Text(
                      r.name,
                      style: const TextStyle(
                        color: AppColors.active,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${r.type} · Stock ${r.stockOnHand.toStringAsFixed(0)}',
                    ),
                    trailing: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(
                        money.format(r.rate),
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      );
    },
  );
}

class CustomersPage extends ConsumerWidget {
  const CustomersPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PageFrame(
    title: 'All Customers',
    child: ref
        .watch(customersProvider)
        .when(
          loading: loading,
          error: error,
          data: (all) {
            final q = ref.watch(booksSearchQueryProvider).toLowerCase();
            final rows = all
                .where(
                  (r) => '${r.name} ${r.company} ${r.email}'
                      .toLowerCase()
                      .contains(q),
                )
                .toList();
            return ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final r = rows[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(child: Text(r.name[0])),
                  title: Text(
                    r.name,
                    style: const TextStyle(
                      color: AppColors.active,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text('${r.company}\n${r.gstTreatment}'),
                  isThreeLine: true,
                  trailing: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      money.format(r.receivables),
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
            );
          },
        ),
  );
}

class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({required this.type, super.key});
  final TransactionType type;
  String get title => switch (type) {
    TransactionType.quote => 'All Quotes',
    TransactionType.salesOrder => 'All Sales Orders',
    TransactionType.invoice => 'All Invoices',
  };
  String get path => switch (type) {
    TransactionType.quote => 'quotes',
    TransactionType.salesOrder => 'sales-orders',
    TransactionType.invoice => 'invoices',
  };
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Quotes get a redesigned mobile-only experience; tablet/desktop keeps
    // the existing PageFrame + ListTile layout. Sales Orders get a full
    // redesign on every width (mobile cards vs. a desktop-native data
    // table). Invoices keep the original layout everywhere.
    if (type == TransactionType.quote) {
      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < AppBreakpoints.tablet) {
            return QuoteMobileView(
              onAdd: () => context.push('/$path/new'),
              onAction: (row, action) => _act(ref, row, action),
            );
          }
          return _frame(context, ref);
        },
      );
    }
    if (type == TransactionType.salesOrder) {
      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < AppBreakpoints.tablet) {
            return SalesOrderMobileView(
              onAdd: () => context.push('/$path/new'),
            );
          }
          return SalesOrderDesktopView(onAdd: () => context.push('/$path/new'));
        },
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // Invoice enhancements are mobile-only so existing tablet/desktop UI stays intact.
        if (constraints.maxWidth < AppBreakpoints.tablet) {
          return _InvoiceMobileView(
            onAdd: () => context.push('/$path/new'),
            onAction: (row, action) => _act(ref, row, action),
          );
        }
        return _frame(context, ref);
      },
    );
  }

  Widget _frame(BuildContext context, WidgetRef ref) => PageFrame(
    title: title,
    onAdd: () => context.push('/$path/new'),
    child: ref
        .watch(transactionsProvider(type))
        .when(
          loading: loading,
          error: error,
          data: (all) {
            final q = ref.watch(booksSearchQueryProvider).toLowerCase();
            final rows = all
                .where(
                  (r) => '${r.number} ${r.customer} ${r.status}'
                      .toLowerCase()
                      .contains(q),
                )
                .toList();
            return ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final r = rows[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  title: Text(
                    r.number,
                    style: const TextStyle(
                      color: AppColors.active,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(r.customer),
                        Text(
                          money.format(r.amount),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(DateFormat('dd/MM/yyyy').format(r.date)),
                        Text(
                          r.status,
                          style: TextStyle(
                            color: r.status == 'Paid' || r.status == 'Accepted'
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) => _act(ref, r, action),
                    itemBuilder: (_) => [
                      if (type == TransactionType.invoice && r.status != 'Paid')
                        const PopupMenuItem(
                          value: 'paid',
                          child: Text('Record Paid'),
                        ),
                      if (type == TransactionType.quote) ...const [
                        PopupMenuItem(
                          value: 'order',
                          child: Text('Convert to Sales Order'),
                        ),
                        PopupMenuItem(
                          value: 'invoice',
                          child: Text('Convert to Invoice'),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
  );
  Future<void> _act(WidgetRef ref, SalesTransaction row, String action) async {
    final repo = ref.read(booksRepositoryProvider);
    if (action == 'paid') await repo.recordInvoicePaid(row.id);
    if (action == 'order') {
      await repo.convertQuote(row.id, TransactionType.salesOrder);
    }
    if (action == 'invoice') {
      await repo.convertQuote(row.id, TransactionType.invoice);
    }
    ref.invalidate(transactionsProvider);
    ref.invalidate(customersProvider);
    ref.invalidate(dashboardMetricsProvider);
  }
}

enum _InvoiceSort { newest, dueDate, amountHigh, customer }

class _InvoiceMobileView extends ConsumerStatefulWidget {
  const _InvoiceMobileView({required this.onAdd, required this.onAction});
  final VoidCallback onAdd;
  final Future<void> Function(SalesTransaction, String) onAction;

  @override
  ConsumerState<_InvoiceMobileView> createState() => _InvoiceMobileViewState();
}

class _InvoiceMobileViewState extends ConsumerState<_InvoiceMobileView> {
  final _search = TextEditingController();
  String _status = 'All';
  _InvoiceSort _sort = _InvoiceSort.newest;
  int _visibleCount = 10;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Invoices'),
      actions: [
        IconButton(
          tooltip: 'New invoice',
          onPressed: widget.onAdd,
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: ref
        .watch(transactionsProvider(TransactionType.invoice))
        .when(
          loading: loading,
          error: error,
          data: (all) {
            final rows = _filtered(all);
            final shown = rows.take(_visibleCount).toList();
            return RefreshIndicator(
              onRefresh: () => ref.refresh(
                transactionsProvider(TransactionType.invoice).future,
              ),
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                    sliver: SliverToBoxAdapter(child: _summary(all)),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    sliver: SliverToBoxAdapter(child: _controls()),
                  ),
                  if (shown.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _InvoiceEmptyState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
                      sliver: SliverList.separated(
                        itemCount:
                            shown.length + (shown.length < rows.length ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          if (index == shown.length) {
                            return OutlinedButton(
                              onPressed: () =>
                                  setState(() => _visibleCount += 10),
                              child: const Text('Load more invoices'),
                            );
                          }
                          return _InvoiceCard(
                            row: shown[index],
                            onAction: (action) =>
                                _handleAction(shown[index], action),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: widget.onAdd,
      icon: const Icon(Icons.add),
      label: const Text('New Invoice'),
    ),
  );

  Widget _summary(List<SalesTransaction> rows) {
    final now = DateTime.now();
    final unpaid = rows.where((r) => r.status.toLowerCase() != 'paid');
    final outstanding = unpaid.fold<double>(0, (sum, r) => sum + r.amount);
    final dueToday = unpaid
        .where((r) => r.dueDate != null && DateUtils.isSameDay(r.dueDate, now))
        .fold<double>(0, (s, r) => s + r.amount);
    final within30 = unpaid
        .where(
          (r) =>
              r.dueDate != null &&
              r.dueDate!.isAfter(now) &&
              r.dueDate!.isBefore(now.add(const Duration(days: 31))),
        )
        .fold<double>(0, (s, r) => s + r.amount);
    final overdue = unpaid
        .where(
          (r) =>
              r.dueDate != null &&
              r.dueDate!.isBefore(DateTime(now.year, now.month, now.day)),
        )
        .fold<double>(0, (s, r) => s + r.amount);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Summary',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            Text(
              money.format(outstanding),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const Text(
              'Total Outstanding Receivables',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _SummaryValue('Due Today', money.format(dueToday)),
                ),
                Expanded(
                  child: _SummaryValue(
                    'Due in 30 Days',
                    money.format(within30),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SummaryValue(
                    'Overdue',
                    money.format(overdue),
                    warning: overdue > 0,
                  ),
                ),
                const Expanded(child: _SummaryValue('Avg. Days to Pay', '—')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _controls() => Column(
    children: [
      SearchBar(
        controller: _search,
        hintText: 'Search invoices or customers',
        leading: const Icon(Icons.search),
        trailing: _search.text.isEmpty
            ? null
            : [
                IconButton(
                  onPressed: () {
                    _search.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
        onChanged: (_) => setState(() {
          _visibleCount = 10;
        }),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.filter_list),
                labelText: 'Status',
              ),
              items: const [
                'All',
                'Draft',
                'Sent',
                'Paid',
                'Overdue',
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() {
                _status = v ?? 'All';
                _visibleCount = 10;
              }),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<_InvoiceSort>(
              initialValue: _sort,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.sort),
                labelText: 'Sort',
              ),
              items: const [
                DropdownMenuItem(
                  value: _InvoiceSort.newest,
                  child: Text('Newest'),
                ),
                DropdownMenuItem(
                  value: _InvoiceSort.dueDate,
                  child: Text('Due date'),
                ),
                DropdownMenuItem(
                  value: _InvoiceSort.amountHigh,
                  child: Text('Amount'),
                ),
                DropdownMenuItem(
                  value: _InvoiceSort.customer,
                  child: Text('Customer'),
                ),
              ],
              onChanged: (v) => setState(() => _sort = v ?? _sort),
            ),
          ),
        ],
      ),
    ],
  );

  List<SalesTransaction> _filtered(List<SalesTransaction> all) {
    final q = _search.text.trim().toLowerCase();
    final rows = all.where((r) {
      final matchesText = '${r.number} ${r.customer} ${r.referenceNumber}'
          .toLowerCase()
          .contains(q);
      final matchesStatus =
          _status == 'All' ||
          _effectiveStatus(r).toLowerCase() == _status.toLowerCase();
      return matchesText && matchesStatus;
    }).toList();
    rows.sort(
      (a, b) => switch (_sort) {
        _InvoiceSort.newest => b.date.compareTo(a.date),
        _InvoiceSort.dueDate => (a.dueDate ?? DateTime(9999)).compareTo(
          b.dueDate ?? DateTime(9999),
        ),
        _InvoiceSort.amountHigh => b.amount.compareTo(a.amount),
        _InvoiceSort.customer => a.customer.toLowerCase().compareTo(
          b.customer.toLowerCase(),
        ),
      },
    );
    return rows;
  }

  Future<void> _handleAction(SalesTransaction row, String action) async {
    if (action == 'paid') return widget.onAction(row, action);
    // These commands need repository APIs that do not exist yet; never fake mutations.
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$action is not available in the current API.')),
      );
  }
}

String _effectiveStatus(SalesTransaction row) {
  if (row.status.toLowerCase() != 'paid' &&
      row.dueDate?.isBefore(DateTime.now()) == true)
    return 'Overdue';
  final value = row.status.toLowerCase();
  return value.isEmpty
      ? 'Draft'
      : '${value[0].toUpperCase()}${value.substring(1)}';
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue(this.label, this.value, {this.warning = false});
  final String label, value;
  final bool warning;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: warning ? Colors.red.shade700 : null,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    ],
  );
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.row, required this.onAction});
  final SalesTransaction row;
  final ValueChanged<String> onAction;
  @override
  Widget build(BuildContext context) {
    final status = _effectiveStatus(row);
    final balance = status == 'Paid' ? 0.0 : row.amount;
    final statusColor = status == 'Paid'
        ? AppColors.primary
        : status == 'Overdue'
        ? Colors.red.shade700
        : AppColors.active;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.number,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.active,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        row.customer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Invoice actions',
                  onSelected: onAction,
                  itemBuilder: (_) => [
                    if (status != 'Paid')
                      const PopupMenuItem(
                        value: 'paid',
                        child: ListTile(
                          leading: Icon(Icons.payments_outlined),
                          title: Text('Record Paid'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ...const [
                      PopupMenuItem(
                        value: 'Edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'Share',
                        child: ListTile(
                          leading: Icon(Icons.share_outlined),
                          title: Text('Share'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'Duplicate',
                        child: ListTile(
                          leading: Icon(Icons.copy_outlined),
                          title: Text('Duplicate'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'Delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('Delete'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _InvoiceDetail(
                    'Invoice date',
                    DateFormat('dd MMM yyyy').format(row.date),
                  ),
                ),
                Expanded(
                  child: _InvoiceDetail(
                    'Due date',
                    row.dueDate == null
                        ? '—'
                        : DateFormat('dd MMM yyyy').format(row.dueDate!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (row.referenceNumber.isNotEmpty) ...[
              _InvoiceDetail('Order number', row.referenceNumber),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: _InvoiceDetail(
                    'Invoice amount',
                    money.format(row.amount),
                  ),
                ),
                Expanded(
                  child: _InvoiceDetail(
                    'Balance due',
                    money.format(balance),
                    strong: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Expanded(child: _InvoiceDetail('Currency', 'INR')),
                Expanded(child: _InvoiceDetail('Salesperson', '—')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceDetail extends StatelessWidget {
  const _InvoiceDetail(this.label, this.value, {this.strong = false});
  final String label, value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    ],
  );
}

class _InvoiceEmptyState extends StatelessWidget {
  const _InvoiceEmptyState();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 54,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: 14),
          Text(
            'No invoices found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6),
          Text(
            'Try changing your search or filters.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );
}

class InventoryAdjustmentsPage extends ConsumerWidget {
  const InventoryAdjustmentsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PageFrame(
    title: 'Inventory Adjustments',
    onAdd: () => context.push('/inventory-adjustments/new'),
    header: const Padding(
      padding: EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        children: [
          Chip(label: Text('Type: Quantity')),
          Chip(label: Text('Period: All')),
        ],
      ),
    ),
    child: ref
        .watch(adjustmentsProvider)
        .when(
          loading: loading,
          error: error,
          data: (rows) => rows.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 46,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(height: 12),
                      Text('No data to display'),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final r = rows[i];
                    return ListTile(
                      title: Text(
                        r.referenceNumber,
                        style: const TextStyle(
                          color: AppColors.active,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${r.reason} · ${DateFormat('dd/MM/yyyy').format(r.date)}',
                      ),
                      trailing: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 100),
                        child: Text(
                          r.status,
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  },
                ),
        ),
  );
}

class PageFrame extends StatelessWidget {
  const PageFrame({
    required this.title,
    required this.child,
    this.onAdd,
    this.header,
    this.headerAction,
    super.key,
  });
  final String title;
  final Widget child;
  final VoidCallback? onAdd;
  final Widget? header;
  final Widget? headerAction;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final gutter = AppLayout.gutter(constraints.maxWidth);
      return ResponsiveContent(
        child: Padding(
          padding: EdgeInsets.fromLTRB(gutter, 18, gutter, gutter),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 10,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (headerAction != null) headerAction!,
                    if (headerAction == null && onAdd != null)
                      ElevatedButton.icon(
                        onPressed: onAdd,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('New'),
                      ),
                  ],
                ),
              ),
              if (header != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: header,
                ),
              Expanded(
                child: GlassPanel(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: FadeSlideIn(child: child),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget loading() => const ShimmerLoading();
Widget error(Object e, StackTrace s) =>
    Center(child: Text('Unable to load data\n$e', textAlign: TextAlign.center));
