import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../tenders/domain/models/tender.dart';
import '../../../tenders/providers/tender_providers.dart';
import '../../domain/models/project_document.dart';
import '../../domain/models/site_project.dart';
import '../../providers/project_providers.dart';

class ManageProjectScreen extends ConsumerStatefulWidget {
  const ManageProjectScreen({
    super.key,
    required this.projectId,
    this.initialProject,
  });

  final String projectId;
  final SiteProject? initialProject;

  @override
  ConsumerState<ManageProjectScreen> createState() =>
      _ManageProjectScreenState();
}

class _ManageProjectScreenState extends ConsumerState<ManageProjectScreen> {
  SiteProject? _loadedProject;
  bool _isLoadingDirect = false;
  int _selectedSectionIndex = 0;

  final _currencyFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹ ',
    decimalDigits: 2,
  );

  static const List<({int number, String title, IconData icon})> _sections = [
    (number: 1, title: 'Project Overview', icon: Icons.info_outline_rounded),
    (number: 2, title: 'Project Assignment', icon: Icons.assignment_ind_outlined),
    (number: 3, title: 'Project Breakdown', icon: Icons.table_chart_outlined),
    (number: 4, title: 'Project Budget', icon: Icons.pie_chart_outline_rounded),
    (number: 5, title: 'Profile Drawings', icon: Icons.architecture_rounded),
    (number: 6, title: 'Billing', icon: Icons.receipt_long_outlined),
    (number: 7, title: 'Payment Received', icon: Icons.payments_outlined),
    (number: 8, title: 'EMD & Retention', icon: Icons.account_balance_outlined),
    (number: 9, title: 'Project Expenses', icon: Icons.receipt_outlined),
    (number: 10, title: 'Project Profit / Loss', icon: Icons.trending_up_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _loadedProject = widget.initialProject;
    _fetchProjectIfMissing();
  }

  Future<void> _fetchProjectIfMissing() async {
    if (_loadedProject != null && _loadedProject!.id == widget.projectId) {
      return;
    }
    setState(() => _isLoadingDirect = true);
    try {
      final p = await ref
          .read(projectRepositoryProvider)
          .getProjectById(widget.projectId);
      if (mounted) {
        setState(() {
          _loadedProject = p;
          _isLoadingDirect = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingDirect = false);
    }
  }

  SiteProject? _resolveProject(List<SiteProject>? streamedList) {
    if (streamedList != null && streamedList.isNotEmpty) {
      final match = streamedList.cast<SiteProject?>().firstWhere(
            (p) => p?.id == widget.projectId,
            orElse: () => null,
          );
      if (match != null) return match;
    }
    return _loadedProject ?? widget.initialProject;
  }

  Future<void> _launchDocumentUrl(String url) async {
    if (url.trim().isEmpty) return;
    final uri = Uri.tryParse(url.trim());
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsStreamProvider);
    final project = _resolveProject(projectsAsync.valueOrNull);

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF414A51)),
          tooltip: 'Back to Project List',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/projects/assigned');
            }
          },
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF414A51).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.dashboard_customize_outlined,
                size: 20,
                color: Color(0xFF414A51),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'MANAGE PROJECT',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF414A51),
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (project != null)
                    Text(
                      project.projectCode.isNotEmpty
                          ? project.projectCode
                          : (project.id.isNotEmpty ? project.id : 'Project'),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (project != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF414A51),
                  side: const BorderSide(color: Color(0xFFCBD2DA)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onPressed: () async {
                  final updated = await context.push<bool>(
                    '/projects/edit/${project.id}',
                    extra: project,
                  );
                  if (updated == true && mounted) {
                    ref.invalidate(projectsStreamProvider);
                    _fetchProjectIfMissing();
                  }
                },
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: Text(
                  isMobile ? 'Edit' : 'Edit Project',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE5E8E2), height: 1),
        ),
      ),
      body: (_isLoadingDirect && project == null)
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF9CC70A),
                strokeWidth: 2.5,
              ),
            )
          : project == null
              ? _buildNotFoundView()
              : _buildMainContent(context, project, isMobile),
    );
  }

  Widget _buildNotFoundView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF414A51).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder_off_outlined,
                size: 48,
                color: Color(0xFF414A51),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Project Not Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF22282D),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Project ID "${widget.projectId}" could not be loaded.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF414A51),
                foregroundColor: Colors.white,
              ),
              onPressed: () => context.go('/projects/assigned'),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Return to Project List'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    SiteProject project,
    bool isMobile,
  ) {
    return Column(
      children: [
        // ── Top Project Identity Banner ──
        _buildProjectHeaderBanner(project, isMobile),

        // ── Section Selector Bar (1 to 10) ──
        _buildSectionTabBar(isMobile),

        // ── Selected Section Body ──
        Expanded(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 24,
              vertical: 18,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: _buildCurrentSectionContent(project, isMobile),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Project Header Banner ──
  Widget _buildProjectHeaderBanner(SiteProject project, bool isMobile) {
    final displayName = project.generalDetails.trim().isNotEmpty
        ? project.generalDetails.trim()
        : (project.projectCode.isNotEmpty
            ? project.projectCode
            : 'Unnamed Project');

    final statusText =
        project.status.trim().isNotEmpty ? project.status.trim() : 'Active';

    final isTenderMapped = project.isMappedToTender.toLowerCase() == 'yes' ||
        project.tenderId.trim().isNotEmpty ||
        project.tenderRefNo.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 24,
        vertical: 14,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E8E2), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumb Trail
          Row(
            children: [
              InkWell(
                onTap: () => context.go('/module/project'),
                borderRadius: BorderRadius.circular(4),
                child: const Text(
                  'New Project',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF414A51),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              InkWell(
                onTap: () => context.go('/projects/assigned'),
                borderRadius: BorderRadius.circular(4),
                child: const Text(
                  'Project List',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF414A51),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              Flexible(
                child: Text(
                  project.projectCode.isNotEmpty
                      ? project.projectCode
                      : displayName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9CC70A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Main Title & Status
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: isMobile ? 17 : 20,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF22282D),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (project.projectCode.isNotEmpty)
                          _buildMetaChip(
                            icon: Icons.tag_rounded,
                            label: project.projectCode,
                          ),
                        if (project.clientName.isNotEmpty)
                          _buildMetaChip(
                            icon: Icons.corporate_fare_rounded,
                            label: project.clientName,
                          ),
                        if (project.place.isNotEmpty ||
                            project.district.isNotEmpty)
                          _buildMetaChip(
                            icon: Icons.location_on_outlined,
                            label: [
                              if (project.place.isNotEmpty) project.place,
                              if (project.district.isNotEmpty) project.district,
                            ].join(', '),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Status Badge & Tender Indicator
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF9CC70A).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF9CC70A),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF414A51),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isTenderMapped ? 'Linked Tender' : 'Independent Project',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isTenderMapped
                          ? const Color(0xFF0284C7)
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF414A51),
          ),
        ),
      ],
    );
  }

  // ── Horizontal Navigation for the 10 Sections ──
  Widget _buildSectionTabBar(bool isMobile) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E8E2), width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: _sections.map((section) {
            final isSelected = _selectedSectionIndex == (section.number - 1);

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () {
                  setState(() => _selectedSectionIndex = section.number - 1);
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF414A51)
                        : const Color(0xFFF4F6F3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF414A51)
                          : const Color(0xFFE5E8E2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? const Color(0xFF9CC70A)
                              : const Color(0xFFCBD2DA).withValues(alpha: 0.6),
                        ),
                        child: Text(
                          '${section.number}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : const Color(0xFF414A51),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        section.icon,
                        size: 15,
                        color: isSelected
                            ? const Color(0xFF9CC70A)
                            : const Color(0xFF414A51),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        section.title,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFF414A51),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Body Routing for Currently Selected Section ──
  Widget _buildCurrentSectionContent(SiteProject project, bool isMobile) {
    switch (_selectedSectionIndex) {
      case 0:
        return _buildSection1Overview(project, isMobile);
      case 1:
        return _buildSection2Assignment(project, isMobile);
      case 2:
        return _buildSection3Breakdown(project, isMobile);
      case 3:
        return _buildSection4Budget(project, isMobile);
      case 4:
        return _buildSection5ProfileDrawings(project, isMobile);
      case 5:
        return _buildSection6Billing(project, isMobile);
      case 6:
        return _buildSection7PaymentReceived(project, isMobile);
      case 7:
        return _buildSection8EmdRetention(project, isMobile);
      case 8:
        return _buildSection9Expenses(project, isMobile);
      case 9:
        return _buildSection10ProfitLoss(project, isMobile);
      default:
        return _buildSection1Overview(project, isMobile);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 1 — PROJECT OVERVIEW
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSection1Overview(SiteProject project, bool isMobile) {
    final isTenderMapped = project.isMappedToTender.toLowerCase() == 'yes' ||
        project.tenderId.trim().isNotEmpty ||
        project.tenderRefNo.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Cards Grid
        LayoutBuilder(
          builder: (context, constraints) {
            final colCount = constraints.maxWidth >= 900 ? 3 : (constraints.maxWidth >= 550 ? 2 : 1);
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _buildInfoKpiCard(
                  title: 'Contract Value (Approx)',
                  value: _currencyFormatter.format(project.approximateProjectValue),
                  icon: Icons.payments_outlined,
                  color: const Color(0xFF414A51),
                  width: (constraints.maxWidth - (colCount - 1) * 14) / colCount,
                ),
                _buildInfoKpiCard(
                  title: 'Actual Project Value',
                  value: _currencyFormatter.format(project.actualProjectValue),
                  icon: Icons.account_balance_wallet_outlined,
                  color: const Color(0xFF9CC70A),
                  width: (constraints.maxWidth - (colCount - 1) * 14) / colCount,
                ),
                _buildInfoKpiCard(
                  title: 'Created Date',
                  value: DateFormat('dd-MM-yyyy').format(project.createdAt),
                  icon: Icons.calendar_today_outlined,
                  color: const Color(0xFF0284C7),
                  width: (constraints.maxWidth - (colCount - 1) * 14) / colCount,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),

        // General Information Card
        _buildContentCard(
          title: 'General Project Information',
          icon: Icons.business_center_outlined,
          children: [
            _buildDetailRow('General Code', project.generalCode.isNotEmpty ? project.generalCode : '—'),
            _buildDetailRow('Project Code', project.projectCode.isNotEmpty ? project.projectCode : '—'),
            _buildDetailRow('Scope / Title', project.generalDetails.isNotEmpty ? project.generalDetails : '—'),
            _buildDetailRow('Client Name', project.clientName.isNotEmpty ? project.clientName : '—'),
            _buildDetailRow('Project Type', project.subOrOwn.isNotEmpty ? project.subOrOwn : 'Main'),
            _buildDetailRow('Created By', project.createdBy.isNotEmpty ? project.createdBy : (project.employeeName.isNotEmpty ? project.employeeName : '—')),
            _buildDetailRow('Status', project.status.isNotEmpty ? project.status : 'Active'),
          ],
        ),
        const SizedBox(height: 18),

        // Linked Tender Information (Preserving relationship without duplicating opening/closing/bqr/emd)
        _buildContentCard(
          title: 'Tender Mapping Details',
          icon: Icons.link_rounded,
          headerTrailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isTenderMapped
                  ? const Color(0xFF0284C7).withValues(alpha: 0.12)
                  : const Color(0xFFE5E8E2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isTenderMapped ? 'Mapped to Tender' : 'Independent Project',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isTenderMapped ? const Color(0xFF0284C7) : const Color(0xFF718096),
              ),
            ),
          ),
          children: isTenderMapped
              ? [
                  if (project.tenderId.isNotEmpty)
                    Consumer(
                      builder: (context, ref, _) {
                        final tenderAsync = ref.watch(tenderByIdProvider(project.tenderId));
                        return tenderAsync.when(
                          data: (tender) {
                            if (tender == null) {
                              return _buildDetailRow('Tender ID', project.tenderId);
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildDetailRow('Linked Tender ID', tender.id),
                                if (tender.title.isNotEmpty)
                                  _buildDetailRow('Tender Title', tender.title),
                                if (tender.tenderRefNo.isNotEmpty)
                                  _buildDetailRow('Tender Ref No', tender.tenderRefNo),
                                if (tender.clientName.isNotEmpty)
                                  _buildDetailRow('Tender Authority', tender.clientName),
                              ],
                            );
                          },
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                          error: (_, _) => _buildDetailRow('Tender ID', project.tenderId),
                        );
                      },
                    )
                  else ...[
                    _buildDetailRow('Tender Ref No', project.tenderRefNo.isNotEmpty ? project.tenderRefNo : '—'),
                  ],
                  if (project.tenderType.isNotEmpty)
                    _buildDetailRow('Tender Type', project.tenderType),
                  if (project.tenderCategory.isNotEmpty)
                    _buildDetailRow('Tender Category', project.tenderCategory),
                  if (project.tenderAmount > 0)
                    _buildDetailRow('Tender Amount', _currencyFormatter.format(project.tenderAmount)),
                  if (project.wrpoRemark.isNotEmpty)
                    _buildDetailRow('WRPO Remarks', project.wrpoRemark),
                ]
              : [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'This site project was created independently and is not mapped to any tender record.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
        ),
        const SizedBox(height: 18),

        // Site Location Details
        _buildContentCard(
          title: 'Location & Area Details',
          icon: Icons.map_outlined,
          children: [
            _buildDetailRow('Place / Site', project.place.isNotEmpty ? project.place : '—'),
            _buildDetailRow('Area', project.area.isNotEmpty ? project.area : '—'),
            _buildDetailRow('District', project.district.isNotEmpty ? project.district : '—'),
            _buildDetailRow('State', project.state.isNotEmpty ? project.state : '—'),
          ],
        ),
        const SizedBox(height: 18),

        // Work Order & Attached Documents Card
        _buildContentCard(
          title: 'Work Order & LOA Documents',
          icon: Icons.attachment_rounded,
          children: [
            if (project.workOrderRemark.isNotEmpty)
              _buildDetailRow('Work Order Remarks', project.workOrderRemark),
            const SizedBox(height: 6),
            if (project.workOrderDocuments.isEmpty && project.wrpoDocuments.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No work order or contract documents uploaded yet.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else ...[
              if (project.workOrderDocuments.isNotEmpty)
                _buildDocumentsList('Work Order / LOA Documents', project.workOrderDocuments),
              if (project.wrpoDocuments.isNotEmpty)
                _buildDocumentsList('WRPO Documents', project.wrpoDocuments),
            ],
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 2 — PROJECT ASSIGNMENT (Embedded Section)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSection2Assignment(SiteProject project, bool isMobile) {
    final teamNames = project.assignedToEmployeeNames;
    final teamIds = project.assignedToEmployeeIds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildContentCard(
          title: 'Project Assignment & Team Allocation',
          icon: Icons.assignment_ind_outlined,
          headerTrailing: FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF9CC70A).withValues(alpha: 0.15),
              foregroundColor: const Color(0xFF414A51),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final res = await context.push<bool>(
                '/projects/edit/${project.id}',
                extra: project,
              );
              if (res == true && mounted) {
                ref.invalidate(projectsStreamProvider);
                _fetchProjectIfMissing();
              }
            },
            icon: const Icon(Icons.manage_accounts_outlined, size: 16),
            label: const Text('Update Assignment', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
          children: [
            _buildDetailRow(
              'Assigned Lead / Name',
              project.assignedToEmployeeName.isNotEmpty
                  ? project.assignedToEmployeeName
                  : (teamNames.isNotEmpty ? teamNames.first : 'Unassigned'),
            ),
            _buildDetailRow(
              'Role / Designation',
              project.assignedToDesignation.isNotEmpty ? project.assignedToDesignation : '—',
            ),
            _buildDetailRow(
              'Contact Number',
              project.assignedToContactNumber.isNotEmpty ? project.assignedToContactNumber : '—',
            ),
            _buildDetailRow(
              'Official Email',
              project.assignedToEmail.isNotEmpty ? project.assignedToEmail : '—',
            ),
            _buildDetailRow(
              'Assignment Date',
              project.assignedDate != null
                  ? DateFormat('dd-MM-yyyy').format(project.assignedDate!)
                  : '—',
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE5E8E2)),
            const SizedBox(height: 12),
            const Text(
              'Assigned Team Members',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF22282D),
              ),
            ),
            const SizedBox(height: 8),
            if (teamNames.isEmpty)
              const Text(
                'No additional team members currently assigned.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(teamNames.length, (index) {
                  final name = teamNames[index];
                  final id = index < teamIds.length ? teamIds[index] : '';
                  return Chip(
                    avatar: const CircleAvatar(
                      backgroundColor: Color(0xFF414A51),
                      child: Icon(Icons.person, size: 14, color: Colors.white),
                    ),
                    label: Text(
                      id.isNotEmpty ? '$name ($id)' : name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF22282D),
                      ),
                    ),
                    backgroundColor: const Color(0xFFF4F6F3),
                    side: const BorderSide(color: Color(0xFFE5E8E2)),
                  );
                }),
              ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 3 — PROJECT BREAKDOWN (Reusing Breakdown Integration)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSection3Breakdown(SiteProject project, bool isMobile) {
    final materials = project.breakdownMaterials;
    final services = project.breakdownServices;
    final totalMaterials = materials.fold<double>(0.0, (sum, item) => sum + item.amount);
    final totalServices = services.fold<double>(0.0, (sum, item) => sum + item.amount);
    final totalBreakdown = totalMaterials + totalServices;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final colCount = constraints.maxWidth >= 900 ? 3 : (constraints.maxWidth >= 550 ? 2 : 1);
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _buildInfoKpiCard(
                  title: 'Total Breakdown Value',
                  value: _currencyFormatter.format(totalBreakdown),
                  icon: Icons.table_chart_outlined,
                  color: const Color(0xFF414A51),
                  width: (constraints.maxWidth - (colCount - 1) * 14) / colCount,
                ),
                _buildInfoKpiCard(
                  title: 'Materials Total (${materials.length} items)',
                  value: _currencyFormatter.format(totalMaterials),
                  icon: Icons.inventory_2_outlined,
                  color: const Color(0xFF0284C7),
                  width: (constraints.maxWidth - (colCount - 1) * 14) / colCount,
                ),
                _buildInfoKpiCard(
                  title: 'Services Total (${services.length} items)',
                  value: _currencyFormatter.format(totalServices),
                  icon: Icons.handyman_outlined,
                  color: const Color(0xFF9CC70A),
                  width: (constraints.maxWidth - (colCount - 1) * 14) / colCount,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _buildContentCard(
          title: 'Project Breakdown Summary',
          icon: Icons.account_tree_outlined,
          headerTrailing: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              await context.push('/projects/breakdown/${project.id}', extra: project);
              if (mounted) {
                ref.invalidate(projectsStreamProvider);
                _fetchProjectIfMissing();
              }
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Open Breakdown Editor', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
          children: [
            _buildDetailRow('Materials Listed', '${materials.length} line items'),
            _buildDetailRow('Services Listed', '${services.length} line items'),
            _buildDetailRow('Contract Value', _currencyFormatter.format(project.actualProjectValue > 0 ? project.actualProjectValue : project.approximateProjectValue)),
            const SizedBox(height: 10),
            Text(
              materials.isEmpty && services.isEmpty
                  ? 'No breakdown items added yet. Click "Open Breakdown Editor" to configure Materials and Services breakdown.'
                  : 'Breakdown is active. Use the Breakdown Editor to manage individual rates, quantities, and descriptions.',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 4 — PROJECT BUDGET (Reusing Budget Integration)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSection4Budget(SiteProject project, bool isMobile) {
    final budget = project.budget;
    final totalBudget = budget?.totalBudget ?? 0.0;
    final contractVal = project.actualProjectValue > 0
        ? project.actualProjectValue
        : project.approximateProjectValue;
    final margin = contractVal > 0 ? contractVal - totalBudget : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final colCount = constraints.maxWidth >= 900 ? 3 : (constraints.maxWidth >= 550 ? 2 : 1);
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _buildInfoKpiCard(
                  title: 'Allocated Budget',
                  value: _currencyFormatter.format(totalBudget),
                  icon: Icons.pie_chart_outline_rounded,
                  color: const Color(0xFF0D9488),
                  width: (constraints.maxWidth - (colCount - 1) * 14) / colCount,
                ),
                _buildInfoKpiCard(
                  title: 'Contract Value',
                  value: _currencyFormatter.format(contractVal),
                  icon: Icons.account_balance_outlined,
                  color: const Color(0xFF414A51),
                  width: (constraints.maxWidth - (colCount - 1) * 14) / colCount,
                ),
                _buildInfoKpiCard(
                  title: 'Projected Margin',
                  value: _currencyFormatter.format(margin),
                  icon: Icons.trending_up_rounded,
                  color: margin >= 0 ? const Color(0xFF9CC70A) : Colors.red,
                  width: (constraints.maxWidth - (colCount - 1) * 14) / colCount,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _buildContentCard(
          title: 'Project Budget & Cost Allocation',
          icon: Icons.savings_outlined,
          headerTrailing: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              await context.push('/projects/budget/${project.id}', extra: project);
              if (mounted) {
                ref.invalidate(projectsStreamProvider);
                _fetchProjectIfMissing();
              }
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Open Budget Editor', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
          children: [
            _buildDetailRow('Budget Status', budget != null ? budget.status.name.toUpperCase() : 'NOT CONFIGURED'),
            _buildDetailRow('Revision Number', budget != null ? 'Rev ${budget.revision}' : '—'),
            _buildDetailRow('Total Cost Items', budget != null ? '${budget.items.length} items' : '0 items'),
            _buildDetailRow('Last Updated', budget != null && budget.updatedAt != null ? DateFormat('dd-MM-yyyy hh:mm a').format(budget.updatedAt!) : '—'),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 5 — PROFILE DRAWINGS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSection5ProfileDrawings(SiteProject project, bool isMobile) {
    return _buildContentCard(
      title: 'Profile Drawings',
      icon: Icons.architecture_rounded,
      children: [
        if (project.profileDrawingRemark.isNotEmpty)
          _buildDetailRow('Remarks', project.profileDrawingRemark),
        const SizedBox(height: 6),
        if (project.profileDrawingDocuments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No profile drawings uploaded for this project yet.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          _buildDocumentsList('Drawing Documents', project.profileDrawingDocuments),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 6 — BILLING
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSection6Billing(SiteProject project, bool isMobile) {
    return _buildContentCard(
      title: 'Billing Details & Progress Bills',
      icon: Icons.receipt_long_outlined,
      children: [
        if (project.billingDetailsRemark.isNotEmpty)
          _buildDetailRow('Remarks', project.billingDetailsRemark),
        if (project.flowOfBillsStatus.isNotEmpty)
          _buildDetailRow('Flow of Bills Status', project.flowOfBillsStatus),
        const SizedBox(height: 6),
        if (project.billingDetailsDocuments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No billing documents or progress invoices uploaded yet.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          _buildDocumentsList('Billing Documents', project.billingDetailsDocuments),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 7 — PAYMENT RECEIVED
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSection7PaymentReceived(SiteProject project, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildContentCard(
          title: 'Payment Received & Deductions',
          icon: Icons.payments_outlined,
          children: [
            _buildDetailRow('Total Payment Received', _currencyFormatter.format(project.paymentAmount)),
            if (project.paymentReceivedRemark.isNotEmpty)
              _buildDetailRow('Payment Remarks', project.paymentReceivedRemark),
            const SizedBox(height: 10),
            const Text(
              'Recorded Deductions',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF22282D),
              ),
            ),
            const SizedBox(height: 6),
            if (project.deductions.isEmpty)
              const Text(
                'No deductions recorded.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Column(
                children: project.deductions.map((d) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(d.deductionType, style: const TextStyle(fontSize: 13, color: Color(0xFF414A51))),
                        Text(_currencyFormatter.format(d.deductionAmount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF22282D))),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 8 — EMD & RETENTION
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSection8EmdRetention(SiteProject project, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildContentCard(
          title: 'EMD Retention & SD Retention Receivables',
          icon: Icons.account_balance_outlined,
          children: [
            _buildDetailRow('EMD Retention Amount', _currencyFormatter.format(project.emdRetentionAmount)),
            _buildDetailRow('EMD Retention Date', project.emdRetentionDate != null ? DateFormat('dd-MM-yyyy').format(project.emdRetentionDate!) : '—'),
            if (project.emdRetentionRemark.isNotEmpty)
              _buildDetailRow('EMD Retention Remarks', project.emdRetentionRemark),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE5E8E2)),
            const SizedBox(height: 12),
            _buildDetailRow('SD Retention Amount', _currencyFormatter.format(project.sdRetentionAmount)),
            _buildDetailRow('SD Retention Date', project.sdRetentionDate != null ? DateFormat('dd-MM-yyyy').format(project.sdRetentionDate!) : '—'),
            if (project.sdRetentionRemark.isNotEmpty)
              _buildDetailRow('SD Retention Remarks', project.sdRetentionRemark),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 9 — PROJECT EXPENSES
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSection9Expenses(SiteProject project, bool isMobile) {
    return _buildContentCard(
      title: 'Project Expenses',
      icon: Icons.receipt_outlined,
      children: [
        _buildDetailRow('Site Project Code', project.projectCode),
        _buildDetailRow('Place / Site', project.place.isNotEmpty ? project.place : '—'),
        const SizedBox(height: 10),
        const Text(
          'Project expense entries and site vouchers are tracked under this section.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 10 — PROJECT PROFIT / LOSS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSection10ProfitLoss(SiteProject project, bool isMobile) {
    final contractVal = project.actualProjectValue > 0
        ? project.actualProjectValue
        : project.approximateProjectValue;
    final totalBudget = project.budget?.totalBudget ?? 0.0;
    final payments = project.paymentAmount;
    final netReceivable = contractVal > 0 ? (contractVal - payments) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final colCount = constraints.maxWidth >= 900 ? 3 : (constraints.maxWidth >= 550 ? 2 : 1);
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _buildInfoKpiCard(
                  title: 'Contract Revenue',
                  value: _currencyFormatter.format(contractVal),
                  icon: Icons.receipt_long_outlined,
                  color: const Color(0xFF414A51),
                  width: (constraints.maxWidth - (colCount - 1) * 14) / colCount,
                ),
                _buildInfoKpiCard(
                  title: 'Collected Revenue',
                  value: _currencyFormatter.format(payments),
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xFF9CC70A),
                  width: (constraints.maxWidth - (colCount - 1) * 14) / colCount,
                ),
                _buildInfoKpiCard(
                  title: 'Net Receivables',
                  value: _currencyFormatter.format(netReceivable),
                  icon: Icons.pending_actions_outlined,
                  color: const Color(0xFF0284C7),
                  width: (constraints.maxWidth - (colCount - 1) * 14) / colCount,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _buildContentCard(
          title: 'Financial Health & Profitability',
          icon: Icons.trending_up_rounded,
          children: [
            _buildDetailRow('Contract Value', _currencyFormatter.format(contractVal)),
            _buildDetailRow('Allocated Project Budget', _currencyFormatter.format(totalBudget)),
            _buildDetailRow('Total Payment Received', _currencyFormatter.format(payments)),
            _buildDetailRow('Projected Net Margin', _currencyFormatter.format(contractVal - totalBudget)),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARED UI HELPER WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildInfoKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E8E2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF22282D),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard({
    required String title,
    required IconData icon,
    Widget? headerTrailing,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E8E2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAF8),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E8E2), width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFF414A51)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF414A51),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (headerTrailing != null) headerTrailing,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF22282D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsList(String categoryTitle, List<ProjectDocument> docs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          categoryTitle,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF414A51),
          ),
        ),
        const SizedBox(height: 6),
        ...docs.map((doc) {
          final hasUrl = doc.downloadUrl.isNotEmpty;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E8E2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.description_outlined, size: 18, color: Color(0xFF414A51)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    doc.name,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF22282D),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasUrl)
                  IconButton(
                    icon: const Icon(Icons.download_rounded, size: 18, color: Color(0xFF0284C7)),
                    tooltip: 'Open / Download File',
                    onPressed: () => _launchDocumentUrl(doc.downloadUrl),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
