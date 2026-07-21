import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/layout/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/books_repository.dart';
import 'books_pages.dart' show money;

/// Replaces the old "Financial Overview" card with the Cash Flow,
/// Income and Expense, Projects and Bank & Credit Cards
/// widgets, reflowing between a stacked mobile layout and a grid on
/// larger viewports.
class DashboardSections extends StatelessWidget {
  const DashboardSections({required this.metrics, super.key});
  final DashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
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
            const _ProjectsCard(),
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
    Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
    Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
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
                                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
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
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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
                height: 210,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 62,
                        sections: [
                          PieChartSectionData(
                            value: income,
                            color: AppColors.primary,
                            showTitle: false,
                            radius: 30,
                          ),
                          PieChartSectionData(
                            value: expense,
                            color: AppColors.active,
                            showTitle: false,
                            radius: 30,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Net Profit', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        Text(
                          money.format(metrics.netProfit),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
            child: Text(status, style: TextStyle(fontSize: 10, color: _statusColor(status), fontWeight: FontWeight.w600)),
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

  // Deep-to-vivid diagonal gradients stand in for the textured card artwork.
  static const _hdfcGradient = [Color(0xFF4A0404), Color(0xFFB71C1C), Color(0xFF7A0E0E)];
  static const _iciciGradient = [Color(0xFF071B33), Color(0xFF1565C0), Color(0xFF0D47A1)];

  static const _accounts = [
    ('HDFC Bank', '•••• 4321', 245320.50, _hdfcGradient),
    ('ICICI Bank', '•••• 7765', 96840.00, _iciciGradient),
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
              final cards = [
                for (final (name, number, balance, gradient) in _accounts)
                  _bankCard(name, number, balance, gradient),
              ];
              if (constraints.maxWidth < AppBreakpoints.tablet) {
                return Column(
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      cards[i],
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: cards[i]),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    ),
  );

  static Widget _bankCard(String name, String number, double balance, List<Color> gradient) => Container(
    height: 176,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
      boxShadow: [
        BoxShadow(color: gradient.last.withValues(alpha: .35), blurRadius: 16, offset: const Offset(0, 8)),
      ],
    ),
    child: Stack(
      children: [
        // Faint circular highlights approximate a textured card surface.
        Positioned(
          right: -30,
          top: -30,
          child: _circle(140, Colors.white.withValues(alpha: .06)),
        ),
        Positioned(left: -20, bottom: -40, child: _circle(120, Colors.black.withValues(alpha: .12))),
        // Bottom-weighted dark overlay keeps text legible over the texture.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: .25)],
              ),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              number,
              style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 12, letterSpacing: 1.2),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  money.format(balance),
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const Text('Available balance', style: TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  static Widget _circle(double size, Color color) =>
      Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
}
