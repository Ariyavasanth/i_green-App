import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/books_repository.dart';
import '../providers/books_providers.dart';

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
        data: (m) => ListView(
          padding: const EdgeInsets.all(16),
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
            _metric(
              'Total Receivables',
              'Current ${money.format(m.currentReceivables)}',
              money.format(m.receivables),
              'Overdue ${money.format(m.overdueReceivables)}',
            ),
            const SizedBox(height: 12),
            _metric(
              'Total Payables',
              'Current ${money.format(m.currentPayables)}',
              money.format(m.payables),
              'Overdue ${money.format(m.overduePayables)}',
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Financial Overview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _line('Revenue', money.format(m.revenue)),
                    _line('Net Profit', money.format(m.netProfit)),
                    _line('Inventory at Risk', '${m.inventoryAtRisk} items'),
                    const SizedBox(height: 18),
                    const Text('Cash Flow · Last 6 Months'),
                    const SizedBox(height: 12),
                    const SizedBox(height: 110, child: _CashFlowChart()),
                  ],
                ),
              ),
            ),
          ],
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(current), Text(overdue)],
          ),
        ],
      ),
    ),
  );
  static Widget _line(String label, String value) => ListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    title: Text(label),
    trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
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
                  trailing: Text(money.format(r.rate)),
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
                  trailing: Text(money.format(r.receivables)),
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
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.number,
                          style: const TextStyle(
                            color: AppColors.active,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(money.format(r.amount)),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Row(
                      children: [
                        Expanded(child: Text(r.customer)),
                        Text(DateFormat('dd/MM/yyyy').format(r.date)),
                        const SizedBox(width: 8),
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
                      trailing: Text(r.status),
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
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                ),
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
      ?header,
      const Divider(height: 1),
      Expanded(child: child),
    ],
  );
}

Widget loading() => const Center(child: CircularProgressIndicator());
Widget error(Object e, StackTrace s) =>
    Center(child: Text('Unable to load data\n$e', textAlign: TextAlign.center));

class _CashFlowChart extends StatelessWidget {
  const _CashFlowChart();
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _CashPainter(), child: const SizedBox.expand());
}

class _CashPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final inside = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final outside = Paint()
      ..color = AppColors.active
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final a = [120, 140, 180, 150, 200, 170], b = [80, 90, 100, 110, 130, 95];
    Path path(List<int> values) {
      final p = Path();
      for (var i = 0; i < values.length; i++) {
        final x = s.width * i / (values.length - 1),
            y = s.height - (values[i] / 220 * s.height);
        i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
      }
      return p;
    }

    c.drawPath(path(a), inside);
    c.drawPath(path(b), outside);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
