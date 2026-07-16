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
                    'Hello, iGreenTec Engineering India Pvt. Ltd.,',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
                  ),
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
                      );
                      final payables = _metric(
                        'Total Payables',
                        'Current ${money.format(m.currentPayables)}',
                        money.format(m.payables),
                        'Overdue ${money.format(m.overduePayables)}',
                      );
                      if (cardConstraints.maxWidth < AppBreakpoints.tablet) {
                        return Column(
                          children: [
                            receivables,
                            const SizedBox(height: 12),
                            payables,
                          ],
                        );
                      }
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
    String overdue,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const Divider(height: 28),
          Text(
            value,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Container(height: 8, color: const Color(0xFFFF8618)),
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
  Widget build(BuildContext context, WidgetRef ref) => PageFrame(
    title: 'Active Items',
    onAdd: () => context.push('/items/new'),
    child: ref
        .watch(itemsProvider)
        .when(
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
  Widget build(BuildContext context, WidgetRef ref) => PageFrame(
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
                            fontSize: 11,
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
    super.key,
  });
  final String title;
  final Widget child;
  final VoidCallback? onAdd;
  final Widget? header;
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
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (onAdd != null)
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
