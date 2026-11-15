import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../projects/domain/models/site_project.dart';
import '../../domain/models/project_incentive_record.dart';
import '../../providers/project_incentive_providers.dart';
import '../widgets/project_incentive_details_dialog.dart';
import '../widgets/project_incentive_kpi_cards.dart';
import '../widgets/project_incentive_settings_dialog.dart';

class ProjectIncentiveEngineScreen extends ConsumerStatefulWidget {
  const ProjectIncentiveEngineScreen({super.key});

  @override
  ConsumerState<ProjectIncentiveEngineScreen> createState() =>
      _ProjectIncentiveEngineScreenState();
}

class _ProjectIncentiveEngineScreenState
    extends ConsumerState<ProjectIncentiveEngineScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isRecalculating = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _recalculateAll() async {
    setState(() => _isRecalculating = true);
    try {
      final repo = ref.read(projectIncentiveRepositoryProvider);
      await repo.recalculateAllIncentives();
      ref.invalidate(liveProjectIncentivesStreamProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All project incentives recalculated successfully!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error recalculating incentives: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRecalculating = false);
    }
  }

  void _showSettingsDialog() {
    final settingsAsync = ref.read(projectIncentiveSettingsStreamProvider);
    final settings = settingsAsync.valueOrNull;
    if (settings != null) {
      showDialog(
        context: context,
        builder: (_) => ProjectIncentiveSettingsDialog(initialSettings: settings),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 850;
    final horizontalPadding = screenWidth > 1200
        ? 32.0
        : screenWidth > 650
            ? 24.0
            : 16.0;

    final records = ref.watch(filteredProjectIncentivesProvider);
    final metrics = ref.watch(projectIncentiveMetricsProvider);
    final activeStatusFilter = ref.watch(incentiveStatusFilterProvider);
    final activeDivision = ref.watch(incentiveDivisionFilterProvider);
    final recordsAsync = ref.watch(liveProjectIncentivesStreamProvider);

    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF9CC70A).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.military_tech_outlined,
                size: 20,
                color: Color(0xFF414A51),
              ),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'PROJECT INCENTIVE ENGINE',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF414A51),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Engine Rules & Settings',
            icon: const Icon(Icons.settings_suggest_rounded, color: Color(0xFF414A51)),
            onPressed: _showSettingsDialog,
          ),
          if (isDesktop)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF414A51),
                foregroundColor: const Color(0xFF9CC70A),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _isRecalculating ? null : _recalculateAll,
              icon: _isRecalculating
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF9CC70A)),
                    )
                  : const Icon(Icons.refresh_rounded, size: 16),
              label: const Text(
                'Recalculate All',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            )
          else
            IconButton(
              tooltip: 'Recalculate All',
              icon: _isRecalculating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF414A51)),
                    )
                  : const Icon(Icons.refresh_rounded, color: Color(0xFF414A51)),
              onPressed: _isRecalculating ? null : _recalculateAll,
            ),
          const SizedBox(width: 12),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE5E8E2), height: 1),
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
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Division Selector ──
                  _buildDivisionSelector(activeDivision),
                  const SizedBox(height: 14),

                  // ── KPI Summary Cards ──
                  ProjectIncentiveKpiCards(
                    metrics: metrics,
                    activeStatusFilter: activeStatusFilter,
                    onSelectFilter: (filter) {
                      ref.read(incentiveStatusFilterProvider.notifier).state = filter;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Search & Status Filters Bar ──
                  _buildSearchAndFilterBar(activeStatusFilter),
                  const SizedBox(height: 16),

                  // ── Projects Table / List ──
                  if (recordsAsync.isLoading && records.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(color: Color(0xFF414A51)),
                      ),
                    )
                  else if (records.isEmpty)
                    _buildEmptyState()
                  else
                    isDesktop
                        ? _buildDesktopTable(records, currency)
                        : _buildMobileCards(records, currency),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivisionSelector(String? selectedDivision) {
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
              Icon(Icons.location_city_rounded, size: 16, color: Color(0xFF414A51)),
              SizedBox(width: 8),
              Text(
                'FILTER BY DIVISION',
                style: TextStyle(
                  fontSize: 11.5,
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
                      ref.read(incentiveDivisionFilterProvider.notifier).state =
                          (div == 'All') ? null : div;
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF414A51) : const Color(0xFFF4F6F3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF414A51) : const Color(0xFFE5E8E2),
                        ),
                      ),
                      child: Text(
                        div,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? const Color(0xFF9CC70A) : const Color(0xFF414A51),
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

  Widget _buildSearchAndFilterBar(String activeStatusFilter) {
    const statusFilters = ['ALL', 'ELIGIBLE', 'DISQUALIFIED', 'ON_HOLD'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E8E2)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          // Search input
          SizedBox(
            width: 320,
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                ref.read(incentiveSearchQueryProvider.notifier).state = val;
              },
              decoration: InputDecoration(
                hintText: 'Search code, client, employee...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF414A51)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(incentiveSearchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF414A51), width: 1.5),
                ),
              ),
            ),
          ),

          // Status Filter Chips
          Row(
            mainAxisSize: MainAxisSize.min,
            children: statusFilters.map((s) {
              final isSelected = activeStatusFilter == s;
              return Padding(
                padding: const EdgeInsets.only(left: 6),
                child: FilterChip(
                  label: Text(s),
                  labelStyle: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF414A51),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF414A51),
                  backgroundColor: const Color(0xFFF4F6F3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF414A51) : const Color(0xFFE5E8E2),
                    ),
                  ),
                  onSelected: (val) {
                    ref.read(incentiveStatusFilterProvider.notifier).state = s;
                  },
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(List<ProjectIncentiveRecord> records, NumberFormat currency) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E8E2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            headingRowHeight: 46,
            dataRowMaxHeight: 64,
            columnSpacing: 20,
            horizontalMargin: 16,
            columns: const [
              DataColumn(label: Text('PROJECT / CODE', style: _headerStyle)),
              DataColumn(label: Text('DAILY PROGRESS', style: _headerStyle)),
              DataColumn(label: Text('TIMELY BILLING', style: _headerStyle)),
              DataColumn(label: Text('PAYMENT COLLECTION', style: _headerStyle)),
              DataColumn(label: Text('INCIDENT STATUS', style: _headerStyle)),
              DataColumn(label: Text('RESTORATION COST', style: _headerStyle)),
              DataColumn(label: Text('NET INCENTIVE', style: _headerStyle)),
              DataColumn(label: Text('ACTIONS', style: _headerStyle)),
            ],
            rows: records.map((r) => _buildDataRow(r, currency)).toList(),
          ),
        ),
      ),
    );
  }

  static const _headerStyle = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w800,
    color: Color(0xFF414A51),
    letterSpacing: 0.5,
  );

  DataRow _buildDataRow(ProjectIncentiveRecord r, NumberFormat currency) {
    return DataRow(
      cells: [
        // Project / Code
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.projectCode,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1E293B)),
              ),
              Text(
                r.projectName,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // Daily Progress
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${r.approvedQuantityDone.toStringAsFixed(1)} / ${r.totalQuantityTarget.toStringAsFixed(1)} ${r.unit}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF1E293B)),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${r.progressCompletionPercentage.toStringAsFixed(0)}% done',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '• ${currency.format(r.baseProgressIncentive)}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Timely Billing
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: r.isBillTimely
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  r.isBillTimely ? 'ON-TIME (+10%)' : 'DELAYED / PENDING (-15%)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: r.isBillTimely ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                r.isBillSubmitted ? 'Bill Submitted' : 'Pending Upload',
                style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),

        // Payment Collection
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currency.format(r.paymentCollectedAmount),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF0284C7)),
              ),
              Text(
                '${r.paymentCollectionPercentage.toStringAsFixed(1)}% collected (${(r.paymentCollectionFactor * 100).toStringAsFixed(0)}% release)',
                style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),

        // Incident Status & Disqualification
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: r.isDisqualified
                  ? const Color(0xFFFEF2F2)
                  : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: r.isDisqualified
                    ? const Color(0xFFF87171)
                    : const Color(0xFF86EFAC),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  r.isDisqualified ? Icons.cancel_rounded : Icons.check_circle_rounded,
                  size: 14,
                  color: r.isDisqualified ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                ),
                const SizedBox(width: 4),
                Text(
                  r.isDisqualified
                      ? 'DISQUALIFIED (${r.incidentCount})'
                      : 'ELIGIBLE (0)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: r.isDisqualified ? const Color(0xFF991B1B) : const Color(0xFF166534),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Restoration Cost (Tracked Separately)
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currency.format(r.totalRestorationCost),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: r.hasRestorationCosts ? const Color(0xFFEA580C) : const Color(0xFF64748B),
                ),
              ),
              const Text(
                'Tracked Separately',
                style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),

        // Net Incentive
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currency.format(r.netPayableIncentive),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                  color: r.isDisqualified
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF15803D),
                ),
              ),
              if (r.isDisqualified)
                const Text(
                  '₹0 due to incident',
                  style: TextStyle(fontSize: 10, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ),

        // Actions
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Calculation Details',
                icon: const Icon(Icons.analytics_outlined, size: 18, color: Color(0xFF414A51)),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => ProjectIncentiveDetailsDialog(record: r),
                  );
                },
              ),
              IconButton(
                tooltip: 'Open Project',
                icon: const Icon(Icons.open_in_new_rounded, size: 17, color: Color(0xFF64748B)),
                onPressed: () => context.push('/projects/manage/${r.projectId}'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileCards(List<ProjectIncentiveRecord> records, NumberFormat currency) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: records.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final r = records[i];
        return Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE5E8E2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.projectCode,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1E293B)),
                          ),
                          Text(
                            r.projectName,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: r.isDisqualified ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: r.isDisqualified ? const Color(0xFFF87171) : const Color(0xFF86EFAC),
                        ),
                      ),
                      child: Text(
                        r.isDisqualified ? 'DISQUALIFIED' : 'ELIGIBLE',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: r.isDisqualified ? const Color(0xFF991B1B) : const Color(0xFF166534),
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16, color: Color(0xFFF1F5F9)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Daily Progress:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    Text('${r.approvedQuantityDone.toStringAsFixed(1)} ${r.unit} (${r.progressCompletionPercentage.toStringAsFixed(0)}%)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Timely Billing:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    Text(
                      r.isBillTimely ? 'On-Time (+10%)' : 'Delayed (-15%)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: r.isBillTimely ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Payment Collection:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    Text('${r.paymentCollectionPercentage.toStringAsFixed(1)}% collected',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0284C7))),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Restoration Cost (Separate):', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    Text(
                      currency.format(r.totalRestorationCost),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: r.hasRestorationCosts ? const Color(0xFFEA580C) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16, color: Color(0xFFF1F5F9)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Net Incentive:', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        Text(
                          currency.format(r.netPayableIncentive),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: r.isDisqualified ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF414A51),
                        side: const BorderSide(color: Color(0xFF414A51)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => ProjectIncentiveDetailsDialog(record: r),
                        );
                      },
                      icon: const Icon(Icons.analytics_outlined, size: 16),
                      label: const Text('View Breakdown'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E8E2)),
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.military_tech_outlined,
                size: 40,
                color: Color(0xFF414A51),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Project Incentive Records Found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Click "Recalculate All" above to compute incentives across all active site projects.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF414A51),
                foregroundColor: const Color(0xFF9CC70A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _recalculateAll,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Recalculate All Projects'),
            ),
          ],
        ),
      ),
    );
  }
}
