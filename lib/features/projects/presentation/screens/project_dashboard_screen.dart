import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../tenders/domain/models/company_document_item.dart';
import '../../../tenders/providers/company_document_providers.dart';
import '../../domain/models/site_project.dart';
import '../../providers/project_providers.dart';
import '../widgets/site_projects_dashboard_card.dart';

class ProjectDashboardScreen extends ConsumerWidget {
  const ProjectDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth > 1200
        ? 32.0
        : screenWidth > 650
            ? 24.0
            : 16.0;

    final selectedDivision = ref.watch(selectedDivisionFilterProvider);
    final activeKpi = ref.watch(projectKpiFilterProvider);
    final metrics = ref.watch(divisionMetricsProvider);

    // Labour licence warnings are company-wide from Company Document Vault
    final companyDocsAsync = ref.watch(companyDocumentsStreamProvider);
    final expiringLicences = companyDocsAsync.valueOrNull
            ?.where((d) =>
                (d.docType == CompanyDocType.license ||
                    d.title.toLowerCase().contains('labour') ||
                    d.title.toLowerCase().contains('license')) &&
                (d.isExpiringSoon || d.isExpired))
            .toList() ??
        [];

    final currency = NumberFormat.compactCurrency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 1,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF414A51)),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/module/project');
            }
          },
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.dashboard_rounded,
                size: 20,
                color: Color(0xFF414A51),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'PROJECT DASHBOARD',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF414A51),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF414A51)),
            onPressed: () => context.push('/projects/incentives'),
            icon: const Icon(Icons.military_tech_outlined, size: 18),
            label: const Text(
              'Incentives',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
            ),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF414A51)),
            onPressed: () => context.push('/projects/retention-sd'),
            icon: const Icon(Icons.savings_outlined, size: 18),
            label: const Text(
              'Retention & SD',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE5E8E2), height: 1),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/projects/new'),
        backgroundColor: const Color(0xFF414A51),
        foregroundColor: const Color(0xFF9CC70A),
        elevation: 3,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'NEW PROJECT',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            16,
            horizontalPadding,
            80,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Division Tabs Bar ──
                  _buildDivisionSelector(ref, selectedDivision),
                  const SizedBox(height: 16),

                  // ── Labour Licence Warning Banner (Company-Wide) ──
                  if (expiringLicences.isNotEmpty) ...[
                    Card(
                      color: const Color(0xFFFFFBEB),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFF59E0B)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: Color(0xFFD97706), size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Labour Licence Expiry Warning (Company-Wide)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    expiringLicences
                                        .map((l) =>
                                            '${l.title} (${l.isExpired ? "EXPIRED" : "Expires: ${DateFormat("dd-MM-yyyy").format(l.expiryDate!)}"})')
                                        .join(' • '),
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF78350F),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF92400E)),
                              onPressed: () =>
                                  context.push('/projects/company-documents'),
                              icon: const Icon(Icons.folder_shared_outlined,
                                  size: 16),
                              label: const Text('Open Vault',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── 5 Division KPI Cards ──
                  _buildKpiGrid(
                    context,
                    ref,
                    metrics,
                    activeKpi,
                    expiringLicences.length,
                    currency,
                    screenWidth,
                  ),
                  const SizedBox(height: 20),

                  // ── Site Projects Table (Filtered by Division & Active KPI) ──
                  const SiteProjectsDashboardCard(
                    showTitleHeader: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivisionSelector(WidgetRef ref, String? selectedDivision) {
    final effectiveSelected = selectedDivision ?? 'All';
    final options = ['All', ...ProjectDivisions.values];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E8E2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_city_rounded,
                  size: 16, color: Color(0xFF414A51)),
              SizedBox(width: 8),
              Text(
                'FILTER BY DIVISION',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: Color(0xFF414A51),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: options.map((div) {
                final isSelected = div == effectiveSelected;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      ref.read(selectedDivisionFilterProvider.notifier).state =
                          (div == 'All') ? null : div;
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF414A51)
                            : const Color(0xFFF4F6F3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF414A51)
                              : const Color(0xFFE5E8E2),
                        ),
                      ),
                      child: Text(
                        div,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? const Color(0xFF9CC70A)
                              : const Color(0xFF414A51),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(
    BuildContext context,
    WidgetRef ref,
    DivisionMetrics metrics,
    ProjectKpiFilter activeKpi,
    int labourLicenceCount,
    NumberFormat currency,
    double screenWidth,
  ) {
    final isMobile = screenWidth < 700;

    final cards = [
      _KpiCardData(
        title: 'Live Projects',
        value: '${metrics.liveProjectsCount}',
        subtitle: 'Active execution',
        icon: Icons.play_circle_outline_rounded,
        accentColor: const Color(0xFF16A34A),
        filter: ProjectKpiFilter.live,
        isActive: activeKpi == ProjectKpiFilter.live,
      ),
      _KpiCardData(
        title: 'Pending Bills',
        value: '${metrics.pendingBillsCount}',
        subtitle: metrics.pendingBillsAmount > 0
            ? currency.format(metrics.pendingBillsAmount)
            : 'Awaiting payment',
        icon: Icons.receipt_long_rounded,
        accentColor: const Color(0xFFD97706),
        filter: ProjectKpiFilter.pendingBills,
        isActive: activeKpi == ProjectKpiFilter.pendingBills,
      ),
      _KpiCardData(
        title: 'Retention Due',
        value: currency.format(metrics.retentionDueTotalAmount),
        subtitle: '${metrics.retentionDueCount} project(s) due',
        icon: Icons.account_balance_outlined,
        accentColor: const Color(0xFF0284C7),
        filter: ProjectKpiFilter.retentionDue,
        isActive: activeKpi == ProjectKpiFilter.retentionDue,
      ),
      _KpiCardData(
        title: 'SD / BG Expiring',
        value: '${metrics.bgExpiringCount}',
        subtitle: 'Due within 30 days',
        icon: Icons.notification_important_outlined,
        accentColor: const Color(0xFFEA580C),
        filter: ProjectKpiFilter.bgExpiring,
        isActive: activeKpi == ProjectKpiFilter.bgExpiring,
      ),
      _KpiCardData(
        title: 'Labour Licences',
        value: '$labourLicenceCount',
        subtitle: 'Vault warnings',
        icon: Icons.verified_user_outlined,
        accentColor: const Color(0xFF7C3AED),
        filter: null, // Vault navigation
        isActive: false,
        onTapOverride: () => context.push('/projects/company-documents'),
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
            width: 160,
            child: _buildKpiCard(cards[i], ref),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 950 ? 5 : 3;
        final cardWidth =
            (constraints.maxWidth - ((crossAxisCount - 1) * 12)) /
                crossAxisCount;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards.map((c) {
            return SizedBox(
              width: cardWidth,
              child: _buildKpiCard(c, ref),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildKpiCard(_KpiCardData card, WidgetRef ref) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        onTap: () {
          if (card.onTapOverride != null) {
            card.onTapOverride!();
            return;
          }
          if (card.filter != null) {
            final current = ref.read(projectKpiFilterProvider);
            ref.read(projectKpiFilterProvider.notifier).state =
                current == card.filter ? ProjectKpiFilter.all : card.filter!;
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: card.isActive
                  ? card.accentColor
                  : const Color(0xFFE5E8E2),
              width: card.isActive ? 2 : 1,
            ),
            color: card.isActive
                ? card.accentColor.withValues(alpha: 0.05)
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
              const SizedBox(height: 8),
              Text(
                card.value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: card.accentColor,
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

class _KpiCardData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final ProjectKpiFilter? filter;
  final bool isActive;
  final VoidCallback? onTapOverride;

  _KpiCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.filter,
    required this.isActive,
    this.onTapOverride,
  });
}
