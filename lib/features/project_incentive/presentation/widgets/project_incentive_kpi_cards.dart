import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../providers/project_incentive_providers.dart';

class ProjectIncentiveKpiCards extends StatelessWidget {
  const ProjectIncentiveKpiCards({
    super.key,
    required this.metrics,
    required this.activeStatusFilter,
    required this.onSelectFilter,
  });

  final ProjectIncentiveMetrics metrics;
  final String activeStatusFilter;
  final ValueChanged<String> onSelectFilter;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;

    final cards = [
      _KpiCardItem(
        title: 'Net Payable Incentive',
        value: currency.format(metrics.totalNetPayable),
        subtitle: '${metrics.eligibleCount} eligible project(s)',
        icon: Icons.payments_rounded,
        color: const Color(0xFF9CC70A),
        textColor: const Color(0xFF414A51),
        filterKey: 'ELIGIBLE',
        isActive: activeStatusFilter == 'ELIGIBLE',
      ),
      _KpiCardItem(
        title: 'Disqualified Projects',
        value: '${metrics.disqualifiedCount}',
        subtitle: '${metrics.totalIncidentsRecorded} incident(s) logged',
        icon: Icons.cancel_outlined,
        color: const Color(0xFFDC2626),
        textColor: const Color(0xFF991B1B),
        filterKey: 'DISQUALIFIED',
        isActive: activeStatusFilter == 'DISQUALIFIED',
      ),
      _KpiCardItem(
        title: 'Restoration Costs (Separate)',
        value: currency.format(metrics.totalRestorationCostTracked),
        subtitle: 'Dedicated damage tracker',
        icon: Icons.handyman_outlined,
        color: const Color(0xFFEA580C),
        textColor: const Color(0xFFC2410C),
        filterKey: 'ALL',
        isActive: false,
        badgeText: 'SEPARATE',
      ),
      _KpiCardItem(
        title: 'Timely Billing Rate',
        value: '${metrics.timelyBillComplianceRate.toStringAsFixed(1)}%',
        subtitle: 'Billed on schedule',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFF414A51),
        textColor: const Color(0xFF414A51),
        filterKey: 'ALL',
        isActive: false,
      ),
      _KpiCardItem(
        title: 'Avg Collection Rate',
        value: '${metrics.averagePaymentCollectionRate.toStringAsFixed(1)}%',
        subtitle: 'Client payment received',
        icon: Icons.account_balance_wallet_outlined,
        color: const Color(0xFF0284C7),
        textColor: const Color(0xFF0369A1),
        filterKey: 'ALL',
        isActive: false,
      ),
    ];

    if (isMobile) {
      return SizedBox(
        height: 110,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: cards.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (ctx, i) => SizedBox(
            width: 180,
            child: _buildCard(context, cards[i]),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1000 ? 5 : 3;
        final cardWidth =
            (constraints.maxWidth - ((crossAxisCount - 1) * 12)) /
                crossAxisCount;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards.map((c) {
            return SizedBox(
              width: cardWidth,
              child: _buildCard(context, c),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCard(BuildContext context, _KpiCardItem card) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        onTap: () {
          if (card.filterKey == activeStatusFilter) {
            onSelectFilter('ALL');
          } else {
            onSelectFilter(card.filterKey);
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: card.isActive
                  ? card.color
                  : const Color(0xFFE5E8E2),
              width: card.isActive ? 2 : 1,
            ),
            color: card.isActive
                ? card.color.withValues(alpha: 0.06)
                : Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      card.title,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF414A51),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (card.badgeText != null)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: card.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        card.badgeText!,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: card.color,
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: card.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(card.icon, size: 16, color: card.color),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                card.value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: card.textColor,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                card.subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiCardItem {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color textColor;
  final String filterKey;
  final bool isActive;
  final String? badgeText;

  _KpiCardItem({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.textColor,
    required this.filterKey,
    required this.isActive,
    this.badgeText,
  });
}
