import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../domain/payroll.dart';
import '../providers/payroll_providers.dart';
import '../../leave/providers/leave_providers.dart';
import 'widgets/access_denied_view.dart';

class PayrollHistoryScreen extends ConsumerStatefulWidget {
  const PayrollHistoryScreen({super.key});

  @override
  ConsumerState<PayrollHistoryScreen> createState() => _PayrollHistoryScreenState();
}

class _PayrollHistoryScreenState extends ConsumerState<PayrollHistoryScreen> {
  bool _showChart = false;

  @override
  Widget build(BuildContext context) {
    final payrollHistoryAsync = ref.watch(allPayrollRecordsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < AppBreakpoints.tablet;
          final gutter = AppLayout.gutter(constraints.maxWidth);

          return SingleChildScrollView(
            padding: EdgeInsets.all(gutter),
            child: ResponsiveContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title + toggle controls
                  _buildHeader(),
                  const SizedBox(height: 24),

                  // Data render
                  payrollHistoryAsync.when(
                    data: (records) {
                      if (records.isEmpty) {
                        return _buildEmptyState();
                      }

                      // Aggregate records by month
                      final Map<String, List<PayrollRecord>> monthlyGroups = {};
                      // Sort months chronologically or reverse order
                      for (final r in records) {
                        monthlyGroups.putIfAbsent(r.month, () => []).add(r);
                      }

                      final sortedMonths = monthlyGroups.keys.toList();
                      // Simple chronological sorting check for seeded dates: 'July 2026', 'August 2026'
                      sortedMonths.sort((a, b) {
                        try {
                          final dateA = DateFormat('MMMM yyyy').parse(a);
                          final dateB = DateFormat('MMMM yyyy').parse(b);
                          return dateB.compareTo(dateA); // Reverse chronological
                        } catch (_) {
                          return b.compareTo(a);
                        }
                      });

                      if (_showChart) {
                        return _buildBarChartView(sortedMonths, monthlyGroups, isMobile);
                      }

                      return isMobile
                          ? _buildMobileCardList(sortedMonths, monthlyGroups)
                          : _buildDesktopTable(sortedMonths, monthlyGroups);
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Error loading history: $err'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payroll History', style: AppTextStyles.pageTitle),
            const SizedBox(height: 4),
            const Text(
              'View aggregates and track financial payroll trends',
              style: AppTextStyles.caption,
            ),
          ],
        ),
        // Toggle Buttons
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.table_chart_outlined),
                color: !_showChart ? AppColors.primary : AppColors.textSecondary,
                tooltip: 'Table View',
                onPressed: () {
                  setState(() {
                    _showChart = false;
                  });
                },
              ),
              Container(width: 1, height: 24, color: AppColors.divider),
              IconButton(
                icon: const Icon(Icons.bar_chart_outlined),
                color: _showChart ? AppColors.primary : AppColors.textSecondary,
                tooltip: 'Chart View',
                onPressed: () {
                  setState(() {
                    _showChart = true;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopTable(
    List<String> months,
    Map<String, List<PayrollRecord>> groups,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(2),
          2: FlexColumnWidth(2.5),
          3: FlexColumnWidth(2),
          4: FlexColumnWidth(2.5),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            children: [
              _buildTableHeader('Payroll Period'),
              _buildTableHeader('Employees Count'),
              _buildTableHeader('Total Paid Amount'),
              _buildTableHeader('Payment Status'),
              _buildTableHeader('Actions'),
            ],
          ),
          for (final month in months) ...[
            () {
              final records = groups[month] ?? [];
              final totalPaid = records.fold(0.0, (sum, r) => sum + r.netSalary);
              
              // If any record is Processed/Pending, status is processed. If all paid, status is Paid.
              final isAllPaid = records.every((r) => r.status == 'Paid');
              final statusText = isAllPaid ? 'Paid' : 'Processed';

              return TableRow(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                children: [
                  _buildTableCell(Text(month, style: const TextStyle(fontWeight: FontWeight.bold))),
                  _buildTableCell(Text('${records.length} Employees')),
                  _buildTableCell(Text(
                    NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(totalPaid),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  )),
                  _buildTableCell(_buildStatusBadge(statusText)),
                  _buildTableCell(
                    ElevatedButton.icon(
                      onPressed: () {
                        // Set selected month and navigate to Dashboard
                        ref.read(selectedPayrollMonthProvider.notifier).state = month;
                        context.go('/payroll');
                      },
                      icon: const Icon(Icons.arrow_forward, size: 14),
                      label: const Text('View Month', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.active,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                ],
              );
            }()
          ]
        ],
      ),
    );
  }

  Widget _buildMobileCardList(
    List<String> months,
    Map<String, List<PayrollRecord>> groups,
  ) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: months.length,
      itemBuilder: (context, index) {
        final month = months[index];
        final records = groups[month] ?? [];
        final totalPaid = records.fold(0.0, (sum, r) => sum + r.netSalary);
        final isAllPaid = records.every((r) => r.status == 'Paid');
        final statusText = isAllPaid ? 'Paid' : 'Processed';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.divider),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(month, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '${records.length} Employees processed',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Paid', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                            Text(
                              NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(totalPaid),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: () {
                            ref.read(selectedPayrollMonthProvider.notifier).state = month;
                            context.go('/payroll');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.active,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: const Text('View', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: _buildStatusBadge(statusText),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBarChartView(
    List<String> months,
    Map<String, List<PayrollRecord>> groups,
    bool isMobile,
  ) {
    // Collect data points (sort chronological for graph: past months left to right)
    final graphMonths = List<String>.from(months).reversed.toList();
    final List<BarChartGroupData> barGroups = [];
    double maxVal = 100000.0;

    for (var i = 0; i < graphMonths.length; i++) {
      final month = graphMonths[i];
      final records = groups[month] ?? [];
      final totalPaid = records.fold(0.0, (sum, r) => sum + r.netSalary);

      if (totalPaid > maxVal) {
        maxVal = totalPaid;
      }

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: totalPaid,
              color: AppColors.primary,
              width: isMobile ? 18 : 28,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
          ],
        ),
      );
    }

    // round maxY upwards
    final maxY = maxVal * 1.25;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Total Monthly Payroll Spending',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Comparison chart of cumulative employee net salary payouts by month.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 36),
            SizedBox(
              height: 280,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => AppColors.active,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          NumberFormat.currency(
                            locale: 'en_IN',
                            symbol: '₹',
                            decimalDigits: 0,
                          ).format(rod.toY),
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 64,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const Text('₹0', style: TextStyle(fontSize: 10));
                          // Format in Lakhs (L) or thousands (K)
                          String formatted = '';
                          if (value >= 100000) {
                            formatted = '${(value / 100000).toStringAsFixed(1)}L';
                          } else {
                            formatted = '${(value / 1000).toStringAsFixed(0)}K';
                          }
                          return Text(
                            '₹$formatted',
                            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < graphMonths.length) {
                            final dateStr = graphMonths[idx];
                            // Show abbreviated month name: e.g. "Aug 2026"
                            final split = dateStr.split(' ');
                            final label = split.length >= 2 ? '${split[0].substring(0, 3)} ${split[1]}' : dateStr;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawHorizontalLine: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 5,
                    getDrawingHorizontalLine: (value) => const FlLine(
                      color: Color(0xFFE5E7EB),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 48, horizontal: 16),
        child: Column(
          children: [
            Icon(Icons.history, size: 48, color: AppColors.textSecondary),
            SizedBox(height: 16),
            Text(
              'No Payroll History',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Payroll records generated in past months will be cataloged here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildTableCell(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: child,
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isPaid = status == 'Paid';
    final color = isPaid ? Colors.green[700]! : Colors.orange[700]!;
    final bgColor = isPaid ? Colors.green[50]! : Colors.orange[50]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
