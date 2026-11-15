import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/features/retention_sd/providers/retention_sd_providers.dart';

class RetentionSdKpiCards extends StatelessWidget {
  const RetentionSdKpiCards({
    super.key,
    required this.metrics,
    required this.activeStatusFilter,
    required this.onSelectFilter,
    required this.screenWidth,
  });

  final RetentionSdMetrics metrics;
  final String activeStatusFilter;
  final void Function(String statusFilter) onSelectFilter;
  final double screenWidth;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.compactCurrency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 1,
    );

    final cards = [
      _KpiCardItem(
        title: 'Total Tracked',
        value: currency.format(metrics.totalRetentionAmount + metrics.totalSdAmount),
        subtitle: '${metrics.totalRecordsCount} projects tracked',
        icon: Icons.account_balance_wallet_outlined,
        accentColor: const Color(0xFF414A51),
        filterKey: 'All',
        isActive: activeStatusFilter == 'All',
      ),
      _KpiCardItem(
        title: 'Pending Claims',
        value: currency.format(metrics.pendingAmount),
        subtitle: '${metrics.pendingCount} claim(s) pending',
        icon: Icons.hourglass_top_rounded,
        accentColor: const Color(0xFFD97706),
        filterKey: 'Pending',
        isActive: activeStatusFilter == 'Pending',
      ),
      _KpiCardItem(
        title: 'Claims Submitted',
        value: currency.format(metrics.submittedAmount),
        subtitle: '${metrics.submittedCount} awaiting release',
        icon: Icons.send_rounded,
        accentColor: const Color(0xFF0284C7),
        filterKey: 'Claim Submitted',
        isActive: activeStatusFilter == 'Claim Submitted',
      ),
      _KpiCardItem(
        title: 'Released Amount',
        value: currency.format(metrics.releasedAmount),
        subtitle: '${metrics.releasedCount} claim(s) released',
        icon: Icons.check_circle_outline_rounded,
        accentColor: const Color(0xFF16A34A),
        filterKey: 'Released',
        isActive: activeStatusFilter == 'Released',
      ),
      _KpiCardItem(
        title: 'BG Expiring (≤30d)',
        value: '${metrics.bgExpiringSoonCount + metrics.bgExpiredCount}',
        subtitle: metrics.bgExpiredCount > 0
            ? '${metrics.bgExpiredCount} expired • ${metrics.bgExpiringSoonCount} due'
            : currency.format(metrics.bgExpiringSoonAmount),
        icon: Icons.notification_important_rounded,
        accentColor: const Color(0xFFEA580C),
        filterKey: 'BG Expiring',
        isActive: activeStatusFilter == 'BG Expiring',
        isWarningCard: (metrics.bgExpiringSoonCount + metrics.bgExpiredCount) > 0,
      ),
    ];

    if (screenWidth < 750) {
      return SizedBox(
        height: 110,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: cards.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (ctx, i) => SizedBox(
            width: 175,
            child: _buildCardWidget(cards[i]),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1050 ? 5 : 3;
        final cardWidth =
            (constraints.maxWidth - ((crossAxisCount - 1) * 12)) /
                crossAxisCount;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards.map((c) {
            return SizedBox(
              width: cardWidth,
              child: _buildCardWidget(c),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCardWidget(_KpiCardItem card) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        onTap: () => onSelectFilter(card.filterKey),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: card.isActive
                  ? card.accentColor
                  : (card.isWarningCard
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFE5E8E2)),
              width: card.isActive ? 2 : 1,
            ),
            color: card.isActive
                ? card.accentColor.withValues(alpha: 0.05)
                : (card.isWarningCard
                    ? const Color(0xFFFFFBEB)
                    : Colors.white),
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
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF414A51),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: card.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(card.icon, size: 16, color: card.accentColor),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                card.value,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF22282D),
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                card.subtitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: card.isWarningCard
                      ? const Color(0xFFB45309)
                      : const Color(0xFF69737A),
                ),
                maxLines: 1,
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
  const _KpiCardItem({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.filterKey,
    required this.isActive,
    this.isWarningCard = false,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final String filterKey;
  final bool isActive;
  final bool isWarningCard;
}
