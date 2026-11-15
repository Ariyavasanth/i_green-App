import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/features/projects/domain/models/site_project.dart';
import 'package:flutter_application_1/features/projects/providers/project_providers.dart';
import 'package:flutter_application_1/features/retention_sd/domain/models/retention_sd_record.dart';
import 'package:flutter_application_1/features/retention_sd/presentation/widgets/retention_bg_dialog.dart';
import 'package:flutter_application_1/features/retention_sd/presentation/widgets/retention_claim_update_dialog.dart';
import 'package:flutter_application_1/features/retention_sd/presentation/widgets/retention_sd_alert_banner.dart';
import 'package:flutter_application_1/features/retention_sd/presentation/widgets/retention_sd_kpi_cards.dart';
import 'package:flutter_application_1/features/retention_sd/providers/retention_sd_providers.dart';

class RetentionSdFollowUpScreen extends ConsumerStatefulWidget {
  const RetentionSdFollowUpScreen({super.key});

  @override
  ConsumerState<RetentionSdFollowUpScreen> createState() =>
      _RetentionSdFollowUpScreenState();
}

class _RetentionSdFollowUpScreenState
    extends ConsumerState<RetentionSdFollowUpScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    // Auto-sync existing site projects on initial load to ensure zero data gap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerSyncProjects(silent: true);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _triggerSyncProjects({bool silent = false}) async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      final projects =
          await ref.read(projectRepositoryProvider).getProjects();
      await ref.read(retentionSdRepositoryProvider).syncWithSiteProjects(projects);
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Retention & SD records synchronized with Site Projects.'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showUpdateClaimModal(RetentionSdRecord record) {
    showDialog(
      context: context,
      builder: (_) => RetentionClaimUpdateDialog(record: record),
    );
  }

  void _showBgModal(RetentionSdRecord record) {
    showDialog(
      context: context,
      builder: (_) => RetentionBgDialog(record: record),
    );
  }

  void _showDetailsModal(RetentionSdRecord record) {
    final dateFormatter = DateFormat('dd-MM-yyyy');
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.assignment_outlined,
                color: Color(0xFF414A51),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.projectCode,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF22282D),
                    ),
                  ),
                  Text(
                    record.projectName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF69737A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Claim Status Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: record.claimStatus.badgeBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: record.claimStatus.badgeColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        record.claimStatus.icon,
                        color: record.claimStatus.badgeColor,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Claim Status: ${record.claimStatus.label}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: record.claimStatus.badgeColor,
                        ),
                      ),
                      const Spacer(),
                      if (record.claimSubmissionDate != null)
                        Text(
                          'Submitted: ${dateFormatter.format(record.claimSubmissionDate!)}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF414A51),
                          ),
                        ),
                      if (record.releasedDate != null)
                        Text(
                          'Released: ${dateFormatter.format(record.releasedDate!)}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Retention Section
                _buildModalSectionHeader('RETENTION MONEY DETAILS', Icons.savings_outlined),
                const SizedBox(height: 8),
                _buildModalInfoRow('Retention Amount', currency.format(record.retentionAmount)),
                _buildModalInfoRow(
                  'Retention Due Date',
                  record.retentionDueDate != null
                      ? '${dateFormatter.format(record.retentionDueDate!)} (${record.daysUntilRetentionDue ?? 0} days remaining)'
                      : '—',
                ),
                if (record.retentionRemarks.isNotEmpty)
                  _buildModalInfoRow('Retention Remarks', record.retentionRemarks),
                const SizedBox(height: 16),

                // SD Section
                _buildModalSectionHeader('SECURITY DEPOSIT (SD) DETAILS', Icons.lock_outline_rounded),
                const SizedBox(height: 8),
                _buildModalInfoRow('SD Amount', currency.format(record.sdAmount)),
                _buildModalInfoRow(
                  'SD Due / Agreement Date',
                  record.sdDueDate != null
                      ? dateFormatter.format(record.sdDueDate!)
                      : '—',
                ),
                if (record.sdAgreementNo.isNotEmpty)
                  _buildModalInfoRow('SD Agreement / Ref No', record.sdAgreementNo),
                if (record.sdRemarks.isNotEmpty)
                  _buildModalInfoRow('SD Remarks', record.sdRemarks),
                const SizedBox(height: 16),

                // Bank Guarantee Section
                _buildModalSectionHeader('BANK GUARANTEE (BG) DETAILS', Icons.shield_outlined),
                const SizedBox(height: 8),
                if (record.hasBg && record.bg != null) ...[
                  _buildModalInfoRow('BG Number', record.bg!.bgNumber),
                  _buildModalInfoRow('Issuing Bank', '${record.bg!.bankName} (${record.bg!.branchName})'),
                  _buildModalInfoRow('BG Amount', currency.format(record.bg!.bgAmount)),
                  _buildModalInfoRow(
                    'BG Expiry Date',
                    record.bg!.expiryDate != null
                        ? '${dateFormatter.format(record.bg!.expiryDate!)} • ${record.bg!.expiryStatusLabel}'
                        : '—',
                  ),
                  if (record.bg!.claimExpiryDate != null)
                    _buildModalInfoRow('Claim Expiry Date', dateFormatter.format(record.bg!.claimExpiryDate!)),
                  _buildModalInfoRow('BG Status', record.bg!.status),
                  if (record.bg!.remarks.isNotEmpty)
                    _buildModalInfoRow('BG Remarks', record.bg!.remarks),
                ] else ...[
                  const Text(
                    'No Bank Guarantee recorded for this project.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF69737A)),
                  ),
                ],
                const SizedBox(height: 16),

                // Claim Lifecycle Details
                _buildModalSectionHeader('CLAIM & SETTLEMENT DETAILS', Icons.history_rounded),
                const SizedBox(height: 8),
                if (record.claimReferenceNo.isNotEmpty)
                  _buildModalInfoRow('Claim Ref / Outward No', record.claimReferenceNo),
                if (record.claimRemarks.isNotEmpty)
                  _buildModalInfoRow('Claim Remarks', record.claimRemarks),
                if (record.releasedAmount > 0)
                  _buildModalInfoRow('Amount Released', currency.format(record.releasedAmount)),
                if (record.releaseRemarks.isNotEmpty)
                  _buildModalInfoRow('Release Remarks', record.releaseRemarks),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showBgModal(record);
            },
            icon: const Icon(Icons.shield_outlined, size: 16),
            label: const Text('BG Details'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF414A51),
              foregroundColor: const Color(0xFF9CC70A),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _showUpdateClaimModal(record);
            },
            icon: const Icon(Icons.track_changes_rounded, size: 16),
            label: const Text('Update Claim'),
          ),
        ],
      ),
    );
  }

  Widget _buildModalSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF414A51)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: Color(0xFF414A51),
          ),
        ),
      ],
    );
  }

  Widget _buildModalInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF22282D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddCustomRecordDialog() async {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final clientCtrl = TextEditingController();
    final retAmtCtrl = TextEditingController();
    final sdAmtCtrl = TextEditingController();
    final bgNoCtrl = TextEditingController();
    DateTime? retDueDate;
    DateTime? sdDueDate;
    DateTime? bgExpiryDate;
    String division = ProjectDivisions.values.first;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'New Retention / SD Follow-up Record',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Project Code *',
                      hintText: 'e.g. PRJ-2024-001',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Project Name / Description *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: clientCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Client Name *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: division,
                    decoration: const InputDecoration(labelText: 'Division'),
                    items: ProjectDivisions.values
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (v) => setDlgState(() => division = v ?? division),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: retAmtCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Retention Amount (₹)',
                            prefixText: '₹ ',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: sdAmtCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'SD Amount (₹)',
                            prefixText: '₹ ',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: bgNoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'BG Number (if Bank Guarantee provided)',
                      hintText: 'e.g. BG-SBI-2024-99',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF414A51),
                foregroundColor: const Color(0xFF9CC70A),
              ),
              onPressed: () async {
                final code = codeCtrl.text.trim();
                final name = nameCtrl.text.trim();
                if (code.isEmpty || name.isEmpty) return;

                final rAmt = double.tryParse(retAmtCtrl.text.trim()) ?? 0.0;
                final sAmt = double.tryParse(sdAmtCtrl.text.trim()) ?? 0.0;
                final bgNo = bgNoCtrl.text.trim();

                BankGuaranteeDetail? bg;
                if (bgNo.isNotEmpty || sAmt > 0) {
                  bg = BankGuaranteeDetail(
                    bgNumber: bgNo,
                    bgAmount: sAmt,
                    status: 'Active',
                  );
                }

                final newRecord = RetentionSdRecord(
                  id: '',
                  projectId: code,
                  projectCode: code,
                  projectName: name,
                  clientName: clientCtrl.text.trim(),
                  division: division,
                  retentionAmount: rAmt,
                  retentionDueDate: retDueDate,
                  sdAmount: sAmt,
                  sdDueDate: sdDueDate,
                  sdAgreementNo: bgNo,
                  hasBg: bg != null,
                  bg: bg,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                await ref.read(retentionSdRepositoryProvider).saveRecord(newRecord);
                if (mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Follow-up record created successfully'),
                      backgroundColor: Color(0xFF16A34A),
                    ),
                  );
                }
              },
              child: const Text('Create Record'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth > 1200
        ? 32.0
        : screenWidth > 650
            ? 24.0
            : 14.0;

    final selectedDivision = ref.watch(retentionDivisionFilterProvider);
    final statusFilter = ref.watch(retentionClaimStatusFilterProvider);
    final metrics = ref.watch(retentionSdMetricsProvider);
    final recordsAsync = ref.watch(filteredRetentionRecordsProvider);

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
              context.go('/projects/dashboard');
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
                Icons.savings_outlined,
                size: 20,
                color: Color(0xFF414A51),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'RETENTION CUM SD FOLLOW-UP',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF414A51),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sync with Site Projects',
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded, color: Color(0xFF414A51)),
            onPressed: _isSyncing ? null : () => _triggerSyncProjects(),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE5E8E2), height: 1),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCustomRecordDialog,
        backgroundColor: const Color(0xFF414A51),
        foregroundColor: const Color(0xFF9CC70A),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'NEW FOLLOW-UP',
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
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Division Selector ──
                  _buildDivisionSelector(selectedDivision),
                  const SizedBox(height: 16),

                  // ── 30-Day BG Expiry Alert Banner ──
                  RetentionSdAlertBanner(
                    expiringRecords: metrics.expiringBgs,
                    onRecordTap: (r) => _showBgModal(r),
                  ),

                  // ── KPI Summary Cards ──
                  RetentionSdKpiCards(
                    metrics: metrics,
                    activeStatusFilter: statusFilter,
                    onSelectFilter: (newFilter) {
                      ref
                          .read(retentionClaimStatusFilterProvider.notifier)
                          .state = newFilter;
                    },
                    screenWidth: screenWidth,
                  ),
                  const SizedBox(height: 18),

                  // ── Search & Filter Tabs Bar ──
                  _buildFilterAndSearchBar(statusFilter),
                  const SizedBox(height: 16),

                  // ── Centralized Follow-up Data Table / Cards ──
                  recordsAsync.when(
                    data: (records) {
                      if (records.isEmpty) {
                        return _buildEmptyState();
                      }
                      return _buildFollowUpTableOrCards(records, screenWidth);
                    },
                    loading: () => Container(
                      padding: const EdgeInsets.all(40),
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    ),
                    error: (e, _) => Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text('Error loading records: $e'),
                    ),
                  ),
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
                      ref.read(retentionDivisionFilterProvider.notifier).state =
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

  Widget _buildFilterAndSearchBar(String activeStatusFilter) {
    const filters = [
      'All',
      'Pending',
      'Claim Submitted',
      'Released',
      'BG Expiring',
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E8E2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) {
                    ref.read(retentionSearchQueryProvider.notifier).state = val;
                  },
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText:
                        'Search by project code, client, BG number, or bank...',
                    prefixIcon:
                        const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              ref
                                  .read(retentionSearchQueryProvider.notifier)
                                  .state = '';
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((f) {
                final isSelected = activeStatusFilter == f;
                Color chipAccent = const Color(0xFF414A51);
                if (f == 'Pending') chipAccent = const Color(0xFFD97706);
                if (f == 'Claim Submitted') chipAccent = const Color(0xFF0284C7);
                if (f == 'Released') chipAccent = const Color(0xFF16A34A);
                if (f == 'BG Expiring') chipAccent = const Color(0xFFEA580C);

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      f == 'BG Expiring' ? 'BG Expiring (≤30d)' : f,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF414A51),
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (_) {
                      ref
                          .read(retentionClaimStatusFilterProvider.notifier)
                          .state = f;
                    },
                    backgroundColor: const Color(0xFFF4F6F3),
                    selectedColor: chipAccent,
                    checkmarkColor:
                        f == 'BG Expiring' ? Colors.white : const Color(0xFF9CC70A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? chipAccent
                            : const Color(0xFFE5E8E2),
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

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E8E2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.savings_outlined,
              size: 40,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Retention or SD Follow-up Records Found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF22282D),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Sync site projects or create a new follow-up entry to begin tracking claims and Bank Guarantee expiry dates.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF69737A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF414A51),
                  foregroundColor: const Color(0xFF9CC70A),
                ),
                onPressed: () => _triggerSyncProjects(),
                icon: const Icon(Icons.sync_rounded, size: 18),
                label: const Text('Sync Projects from Sites'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _showAddCustomRecordDialog,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New Follow-up'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpTableOrCards(
      List<RetentionSdRecord> records, double screenWidth) {
    if (screenWidth < 900) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: records.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) => _buildMobileCard(records[i]),
      );
    }

    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final dateFormatter = DateFormat('dd-MM-yyyy');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E8E2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2.5), // Project & Client
            1: FlexColumnWidth(1.2), // Division
            2: FlexColumnWidth(2.0), // Retention (Amt & Due)
            3: FlexColumnWidth(2.0), // SD (Amt & Due)
            4: FlexColumnWidth(2.5), // BG Details & Expiry
            5: FlexColumnWidth(1.8), // Claim Status
            6: FlexColumnWidth(1.8), // Actions
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            // Header Row
            TableRow(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: Color(0xFFE5E8E2))),
              ),
              children: [
                _buildTableHeader('PROJECT & CLIENT'),
                _buildTableHeader('DIVISION'),
                _buildTableHeader('RETENTION (AMT / DUE)'),
                _buildTableHeader('SD (AMT / DUE)'),
                _buildTableHeader('BANK GUARANTEE (BG)'),
                _buildTableHeader('CLAIM STATUS'),
                _buildTableHeader('ACTIONS'),
              ],
            ),
            // Data Rows
            ...records.map((r) {
              final bg = r.bg;
              final isBgExpiring = r.isBgExpiringSoon;
              final isBgExpired = r.isBgExpired;

              return TableRow(
                decoration: BoxDecoration(
                  border: const Border(
                      bottom: BorderSide(color: Color(0xFFF1F5F9))),
                  color: isBgExpired
                      ? const Color(0xFFFEF2F2).withValues(alpha: 0.5)
                      : (isBgExpiring
                          ? const Color(0xFFFFFBEB).withValues(alpha: 0.5)
                          : null),
                ),
                children: [
                  // Col 0: Project & Client
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.projectCode,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF22282D),
                          ),
                        ),
                        Text(
                          r.projectName,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF475569),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          r.clientName,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Col 1: Division
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        r.division.isNotEmpty ? r.division : 'General',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                  // Col 2: Retention (Amount & Due Date)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currency.format(r.retentionAmount),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF22282D),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 11,
                              color: r.isRetentionOverdue
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              r.retentionDueDate != null
                                  ? dateFormatter.format(r.retentionDueDate!)
                                  : 'Not set',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: r.isRetentionOverdue
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                                color: r.isRetentionOverdue
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Col 3: SD (Amount & Due Date)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currency.format(r.sdAmount),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF22282D),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.event_note_rounded,
                                size: 11, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(
                              r.sdDueDate != null
                                  ? dateFormatter.format(r.sdDueDate!)
                                  : 'Not set',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Col 4: Bank Guarantee (BG Details & Expiry)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: bg != null && bg.bgNumber.isNotEmpty
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${bg.bankName.isNotEmpty ? bg.bankName : "BG"}: ${bg.bgNumber}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF22282D),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              if (isBgExpired) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: const Color(0xFFEF4444)),
                                  ),
                                  child: Text(
                                    bg.expiryStatusLabel,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                              ] else if (isBgExpiring) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: const Color(0xFFF59E0B)),
                                  ),
                                  child: Text(
                                    bg.expiryStatusLabel,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFD97706),
                                    ),
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  bg.expiryDate != null
                                      ? 'Exp: ${dateFormatter.format(bg.expiryDate!)}'
                                      : 'No Expiry',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ],
                          )
                        : TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(50, 30),
                            ),
                            onPressed: () => _showBgModal(r),
                            icon: const Icon(Icons.add_circle_outline, size: 14),
                            label: const Text('+ Add BG',
                                style: TextStyle(fontSize: 11.5)),
                          ),
                  ),

                  // Col 5: Claim Status
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 12),
                    child: InkWell(
                      onTap: () => _showUpdateClaimModal(r),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: r.claimStatus.badgeBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                r.claimStatus.badgeColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              r.claimStatus.icon,
                              size: 13,
                              color: r.claimStatus.badgeColor,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                r.claimStatus.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: r.claimStatus.badgeColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Col 6: Actions
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Update Claim Status',
                          icon: const Icon(Icons.track_changes_rounded,
                              size: 18, color: Color(0xFF0284C7)),
                          onPressed: () => _showUpdateClaimModal(r),
                        ),
                        IconButton(
                          tooltip: 'BG Details',
                          icon: const Icon(Icons.shield_outlined,
                              size: 18, color: Color(0xFFEA580C)),
                          onPressed: () => _showBgModal(r),
                        ),
                        IconButton(
                          tooltip: 'Full Details',
                          icon: const Icon(Icons.info_outline_rounded,
                              size: 18, color: Color(0xFF414A51)),
                          onPressed: () => _showDetailsModal(r),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _buildMobileCard(RetentionSdRecord r) {
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final dateFormatter = DateFormat('dd-MM-yyyy');
    final bg = r.bg;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: r.isBgExpired
              ? const Color(0xFFEF4444)
              : (r.isBgExpiringSoon
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFFE5E8E2)),
          width: (r.isBgExpiringSoon || r.isBgExpired) ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  r.projectCode,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF22282D),
                  ),
                ),
              ),
              InkWell(
                onTap: () => _showUpdateClaimModal(r),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: r.claimStatus.badgeBackground,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(r.claimStatus.icon,
                          size: 12, color: r.claimStatus.badgeColor),
                      const SizedBox(width: 4),
                      Text(
                        r.claimStatus.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: r.claimStatus.badgeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Text(
            '${r.projectName} • ${r.clientName}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Retention & SD rows
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Retention Amount',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    Text(
                      currency.format(r.retentionAmount),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      r.retentionDueDate != null
                          ? 'Due: ${dateFormatter.format(r.retentionDueDate!)}'
                          : 'No due date',
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SD Amount',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    Text(
                      currency.format(r.sdAmount),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      r.sdDueDate != null
                          ? 'Due: ${dateFormatter.format(r.sdDueDate!)}'
                          : 'No due date',
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // BG Alert if applicable
          if (bg != null && bg.bgNumber.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: r.isBgExpired
                    ? const Color(0xFFFEE2E2)
                    : (r.isBgExpiringSoon
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 16,
                    color: r.isBgExpired
                        ? const Color(0xFFDC2626)
                        : (r.isBgExpiringSoon
                            ? const Color(0xFFD97706)
                            : const Color(0xFF414A51)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'BG: ${bg.bgNumber} • ${bg.expiryStatusLabel}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: r.isBgExpired
                            ? const Color(0xFF991B1B)
                            : (r.isBgExpiringSoon
                                ? const Color(0xFF92400E)
                                : const Color(0xFF334155)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _showBgModal(r),
                icon: const Icon(Icons.shield_outlined, size: 14),
                label: const Text('BG Details', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF414A51),
                  foregroundColor: const Color(0xFF9CC70A),
                ),
                onPressed: () => _showUpdateClaimModal(r),
                icon: const Icon(Icons.track_changes_rounded, size: 14),
                label: const Text('Update Claim', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
