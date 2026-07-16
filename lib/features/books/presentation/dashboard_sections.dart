import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/layout/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/books_repository.dart';
import '../providers/books_providers.dart';
import 'books_pages.dart' show money;

/// Replaces the old "Financial Overview" card with the Cash Flow,
/// Income and Expense, Top Expenses, Projects and Bank & Credit Cards
/// widgets, reflowing between a stacked mobile layout and a grid on
/// larger viewports.
class DashboardSections extends ConsumerWidget {
  const DashboardSections({required this.metrics, super.key});
  final DashboardMetrics metrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(itemsProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= AppBreakpoints.tablet;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _responsiveRow(wide, [
              (3, _CashFlowCard(metrics: metrics)),
              (2, _IncomeExpenseCard(metrics: metrics)),
            ]),
            const SizedBox(height: 12),
            _responsiveRow(wide, [
              (1, _TopExpensesCard(items: items)),
              (1, const _ProjectsCard()),
            ]),
            const SizedBox(height: 12),
            const _BankAndCreditCardsCard(),
          ],
        );
      },
    );
  }

  static Widget _responsiveRow(bool wide, List<(int, Widget)> children) {
    if (!wide) {
      return Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            children[i].$2,
          ],
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(flex: children[i].$1, child: children[i].$2),
          ],
        ],
      ),
    );
  }
}

Widget _cardTitle(String title, String subtitle) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
    Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
  ],
);

Widget _emptyState(IconData icon, String message) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 24),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 40, color: AppColors.textSecondary),
      const SizedBox(height: 10),
      Text(message, style: const TextStyle(color: AppColors.textSecondary)),
    ],
  ),
);

class _CashFlowCard extends StatelessWidget {
  const _CashFlowCard({required this.metrics});
  final DashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final months = List.generate(
      6,
      (i) => DateFormat('MMM').format(DateTime(DateTime.now().year, DateTime.now().month - 5 + i)),
    );
    final inflowAvg = metrics.revenue / 6;
    final outflowAvg = metrics.payables / 6;
    const inflowShape = [.72, .85, 1.05, .93, 1.18, 1.0];
    const outflowShape = [.8, .7, .95, 1.05, .9, 1.0];
    final inflow = [for (final f in inflowShape) inflowAvg * f];
    final outflow = [for (final f in outflowShape) outflowAvg * f];
    final maxY = [...inflow, ...outflow].fold(0.0, (a, b) => a > b ? a : b) * 1.2;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle('Cash Flow', 'Last 6 months'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [_legendDot(AppColors.primary, 'Money In'), _legendDot(AppColors.active, 'Money Out')],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: maxY <= 0
                  ? _emptyState(Icons.show_chart, 'No cash flow data to display')
                  : LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: maxY,
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 24,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                final i = value.round();
                                if (i < 0 || i >= months.length) return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    months[i],
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        lineTouchData: const LineTouchData(enabled: true),
                        lineBarsData: [_series(inflow, AppColors.primary), _series(outflow, AppColors.active)],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static LineChartBarData _series(List<double> values, Color color) => LineChartBarData(
    spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
    isCurved: true,
    color: color,
    barWidth: 2.5,
    dotData: const FlDotData(show: false),
    belowBarData: BarAreaData(show: true, color: color.withValues(alpha: .08)),
  );

  static Widget _legendDot(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    ],
  );
}

class _IncomeExpenseCard extends StatelessWidget {
  const _IncomeExpenseCard({required this.metrics});
  final DashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final income = metrics.revenue;
    final rawExpense = metrics.revenue - metrics.netProfit;
    final expense = rawExpense < 0 ? 0.0 : rawExpense;
    final total = income + expense;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle('Income and Expense', 'This fiscal year'),
            const SizedBox(height: 16),
            if (total <= 0)
              _emptyState(Icons.pie_chart_outline, 'No income or expense data')
            else
              SizedBox(
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 44,
                        sections: [
                          PieChartSectionData(
                            value: income,
                            color: AppColors.primary,
                            showTitle: false,
                            radius: 22,
                          ),
                          PieChartSectionData(
                            value: expense,
                            color: AppColors.active,
                            showTitle: false,
                            radius: 22,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Net Profit', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        Text(
                          money.format(metrics.netProfit),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            _amountRow(AppColors.primary, 'Income', income),
            const SizedBox(height: 8),
            _amountRow(AppColors.active, 'Expense', expense),
          ],
        ),
      ),
    );
  }

  static Widget _amountRow(Color color, String label, double value) => Row(
    children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
      Text(money.format(value), style: const TextStyle(fontWeight: FontWeight.w600)),
    ],
  );
}

class _TopExpensesCard extends StatelessWidget {
  const _TopExpensesCard({required this.items});
  final AsyncValue<List<BookItem>> items;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Top Expenses', 'By inventory cost'),
          const SizedBox(height: 12),
          items.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, s) => _emptyState(Icons.error_outline, 'Unable to load expenses'),
            data: (all) {
              final ranked =
                  all.where((r) => r.costPrice > 0 && r.stockOnHand > 0).map((r) => (r, r.costPrice * r.stockOnHand)).toList()
                    ..sort((a, b) => b.$2.compareTo(a.$2));
              final top = ranked.take(5).toList();
              if (top.isEmpty) return _emptyState(Icons.trending_down, 'No expense data to display');
              final maxValue = top.first.$2;
              return Column(
                children: [
                  for (final (item, value) in top) ...[
                    _expenseRow(item.name, value, maxValue),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    ),
  );

  static Widget _expenseRow(String name, double value, double maxValue) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
          Text(money.format(value), style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: maxValue == 0 ? 0 : value / maxValue,
          minHeight: 6,
          backgroundColor: AppColors.canvas,
          color: AppColors.primary,
        ),
      ),
    ],
  );
}

class _ProjectsCard extends StatelessWidget {
  const _ProjectsCard();

  static const _projects = [
    ('Website Redesign', 'In Progress', .65),
    ('Warehouse Automation', 'On Track', .4),
    ('Client Portal Rollout', 'At Risk', .2),
  ];

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Projects', 'Active projects'),
          const SizedBox(height: 12),
          for (final (name, status, progress) in _projects) ...[
            _projectRow(name, status, progress),
            const SizedBox(height: 14),
          ],
        ],
      ),
    ),
  );

  static Widget _projectRow(String name, String status, double progress) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _statusColor(status).withValues(alpha: .12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(status, style: TextStyle(fontSize: 11, color: _statusColor(status), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 6,
          backgroundColor: AppColors.canvas,
          color: _statusColor(status),
        ),
      ),
    ],
  );

  static Color _statusColor(String status) => switch (status) {
    'At Risk' => const Color(0xFFDB4437),
    'On Track' => AppColors.primary,
    _ => AppColors.active,
  };
}

class _BankAndCreditCardsCard extends StatelessWidget {
  const _BankAndCreditCardsCard();

  static const _accounts = [
    ('HDFC Bank · Current A/c', '•••• 4321', 245320.50, false),
    ('ICICI Bank · Savings', '•••• 7765', 96840.00, false),
    ('HDFC Credit Card', '•••• 9087', 18560.75, true),
  ];

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Bank and Credit Cards', 'Linked accounts'),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= AppBreakpoints.laptop
                  ? 3
                  : constraints.maxWidth >= AppBreakpoints.tablet
                  ? 2
                  : 1;
              final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final (name, number, balance, isCredit) in _accounts)
                    SizedBox(width: width, child: _accountTile(name, number, balance, isCredit)),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );

  static Widget _accountTile(String name, String number, double balance, bool isCredit) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.canvas,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isCredit ? Icons.credit_card : Icons.account_balance_outlined,
              size: 18,
              color: AppColors.active,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(number, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        Text(
          money.format(balance),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isCredit ? const Color(0xFFDB4437) : AppColors.textPrimary,
          ),
        ),
        Text(
          isCredit ? 'Outstanding' : 'Available balance',
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}
