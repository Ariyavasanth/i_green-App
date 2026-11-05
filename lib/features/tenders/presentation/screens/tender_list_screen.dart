import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../projects/presentation/screens/new_project_form_screen.dart';
import '../../domain/models/tender.dart';
import '../../providers/tender_providers.dart';
import 'tender_form_screen.dart';
import 'update_tender_result_dialog.dart';
import '../widgets/tender_document_actions.dart';

class TenderListScreen extends ConsumerStatefulWidget {
  const TenderListScreen({super.key});

  @override
  ConsumerState<TenderListScreen> createState() => _TenderListScreenState();
}

class _TenderListScreenState extends ConsumerState<TenderListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'All';

  static const _filterOptions = [
    'All',
    'Submitted',
    'Under evaluation',
    'Won',
    'Lost',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'N/A';
    if (dt.hour == 0 && dt.minute == 0) {
      return DateFormat('dd MMM yyyy').format(dt);
    }
    return DateFormat('dd MMM yyyy, HH:mm').format(dt);
  }

  String _formatDaysLeft(DateTime? closingDate) {
    if (closingDate == null) return '';
    final now = DateTime.now();
    final diff = closingDate.difference(now);
    if (diff.isNegative) {
      return 'Expired';
    }
    if (diff.inDays == 0) {
      return '${diff.inHours}h left';
    }
    return '${diff.inDays} days left';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Won':
        return const Color(0xFF9CC70A);
      case 'Rejected':
      case 'Lost':
        return Colors.red.shade600;
      case 'Under Evaluation':
      case 'Under evaluation':
        return const Color(0xFFD97706);
      case 'Submitted':
      default:
        return const Color(0xFF414A51);
    }
  }

  Future<void> _confirmDeleteTender(Tender tender) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Tender',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to delete "${tender.tenderId}"? This action cannot be undone.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF4A5568)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF718096))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(tenderRepositoryProvider).deleteTender(tender.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tender ${tender.tenderId} deleted'),
            backgroundColor: const Color(0xFF414A51),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete tender: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tendersAsync = ref.watch(tendersStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF414A51)),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/module/project');
            }
          },
        ),
        title: const Text(
          'Tenders',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF414A51),
            letterSpacing: 0.2,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF9CC70A),
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const TenderFormScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add, size: 20),
        label: const Text(
          'New tender',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                // Rounded Search Bar matching reference
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF2D3748)),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search,
                        color: Color(0xFF718096), size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    hintText: 'Search tender ID, title or client',
                    hintStyle: const TextStyle(
                        fontSize: 13, color: Color(0xFFA0AEC0)),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: const BorderSide(
                          color: Color(0xFF9CC70A), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Filter Pills matching reference
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filterOptions.map((status) {
                      final isSelected = _statusFilter == status;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () => setState(() => _statusFilter = status),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF9CC70A)
                                  : const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF9CC70A)
                                    : const Color(0xFFCBD5E1),
                                width: 1.0,
                              ),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? const Color(0xFF414A51)
                                    : const Color(0xFF718096),
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
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // List of Tenders
          Expanded(
            child: tendersAsync.when(
              data: (tenders) {
                final filtered = tenders.where((t) {
                  // Filter by status tab
                  if (_statusFilter == 'Under evaluation') {
                    if (t.status.toLowerCase() != 'under evaluation') {
                      return false;
                    }
                  } else if (_statusFilter == 'Lost') {
                    if (t.status.toLowerCase() != 'rejected' &&
                        t.status.toLowerCase() != 'lost') {
                      return false;
                    }
                  } else if (_statusFilter != 'All') {
                    if (t.status.toLowerCase() != _statusFilter.toLowerCase()) {
                      return false;
                    }
                  }

                  // Filter by search text
                  if (_searchQuery.isEmpty) return true;
                  final q = _searchQuery.toLowerCase();
                  return t.tenderId.toLowerCase().contains(q) ||
                      t.tenderRefNo.toLowerCase().contains(q) ||
                      t.title.toLowerCase().contains(q) ||
                      t.clientName.toLowerCase().contains(q) ||
                      t.tenderType.toLowerCase().contains(q) ||
                      t.status.toLowerCase().contains(q);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_outlined,
                            size: 60, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isEmpty && _statusFilter == 'All'
                              ? 'No Tenders Created Yet'
                              : 'No matching tenders found',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_searchQuery.isEmpty && _statusFilter == 'All')
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9CC70A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const TenderFormScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('CREATE FIRST TENDER'),
                          ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _buildReferenceTenderCard(context, item);
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF9CC70A)),
              ),
              error: (err, _) => Center(
                child: Text('Error loading tenders: $err'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Mobile-optimized card strictly following the uploaded layout reference
  Widget _buildReferenceTenderCard(BuildContext context, Tender tender) {
    final currencyFmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final daysLeftText = _formatDaysLeft(tender.closingDate);
    final statusColor = _getStatusColor(tender.status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showTenderDetailsDialog(context, tender),
        borderRadius: BorderRadius.circular(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Accent Indicator Strip
                Container(
                  width: 4.5,
                  color: statusColor,
                ),

                // Card Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      // Header Row: Tender ID, Status badge, 3-dots menu
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            tender.tenderId,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF414A51),
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildReferenceStatusBadge(tender.status),
                          const Spacer(),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert,
                                size: 20, color: Color(0xFF718096)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onSelected: (val) {
                              if (val == 'view') {
                                _showTenderDetailsDialog(context, tender);
                              } else if (val == 'edit') {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        TenderFormScreen(tender: tender),
                                  ),
                                );
                              } else if (val == 'result') {
                                UpdateTenderResultDialog.show(context, tender);
                              } else if (val == 'create_project') {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => NewProjectFormScreen(
                                        initialTender: tender),
                                  ),
                                );
                              } else if (val == 'delete') {
                                _confirmDeleteTender(tender);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'view',
                                child: Row(
                                  children: [
                                    Icon(Icons.visibility_outlined,
                                        size: 17, color: Color(0xFF414A51)),
                                    SizedBox(width: 10),
                                    Text('View details'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined,
                                        size: 17, color: Color(0xFF414A51)),
                                    SizedBox(width: 10),
                                    Text('Edit tender'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'result',
                                child: Row(
                                  children: [
                                    Icon(Icons.rate_review_outlined,
                                        size: 17, color: Color(0xFF414A51)),
                                    SizedBox(width: 10),
                                    Text('Update result'),
                                  ],
                                ),
                              ),
                              if (tender.status == 'Won')
                                const PopupMenuItem(
                                  value: 'create_project',
                                  child: Row(
                                    children: [
                                      Icon(Icons.add_task_rounded,
                                          size: 17, color: Color(0xFF9CC70A)),
                                      SizedBox(width: 10),
                                      Text('Create project'),
                                    ],
                                  ),
                                ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline,
                                        size: 17, color: Colors.red),
                                    SizedBox(width: 10),
                                    Text('Delete tender',
                                        style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Tender Title
                      Text(
                        tender.title.isNotEmpty
                            ? tender.title
                            : (tender.clientName.isNotEmpty
                                ? tender.clientName
                                : 'Untitled Tender'),
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A202C),
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Client Name with institution icon
                      if (tender.clientName.isNotEmpty) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(Icons.account_balance_outlined,
                                size: 14, color: Color(0xFF718096)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                tender.clientName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF718096),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],

                      // Tender Reference No.
                      if (tender.tenderRefNo.isNotEmpty) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              '#',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF718096),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Ref: ${tender.tenderRefNo}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF718096),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],

                      // Tender Amount (if entered)
                      if (tender.tenderAmount > 0) ...[
                        Row(
                          children: [
                            const Text(
                              'Amount: ',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF718096),
                              ),
                            ),
                            Text(
                              currencyFmt.format(tender.tenderAmount),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF9CC70A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],

                      const SizedBox(height: 8),

                      // Two-Column Opens & Closes Date Row (matching reference)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Opens',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFFA0AEC0),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatDateTime(tender.openingDate),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2D3748),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Closes',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFFA0AEC0),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatDateTime(tender.closingDate),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2D3748),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Badges / Tags Row (Days left, EMD, Notice PDF)
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Countdown Badge
                          if (daysLeftText.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.access_time_rounded,
                                      size: 12.5, color: Color(0xFF414A51)),
                                  const SizedBox(width: 4),
                                  Text(
                                    daysLeftText,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF414A51),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // EMD Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: tender.isEmdExempted == 'Yes'
                                  ? const Color(0xFF9CC70A)
                                      .withValues(alpha: 0.15)
                                  : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  tender.isEmdExempted == 'Yes'
                                      ? Icons.verified_user_outlined
                                      : Icons.account_balance_wallet_outlined,
                                  size: 12.5,
                                  color: tender.isEmdExempted == 'Yes'
                                      ? const Color(0xFF414A51)
                                      : const Color(0xFF92400E),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  tender.isEmdExempted == 'Yes'
                                      ? 'EMD exempted'
                                      : (tender.emdAmount > 0
                                          ? 'EMD ₹${NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: 0).format(tender.emdAmount).trim()}'
                                          : 'EMD required'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: tender.isEmdExempted == 'Yes'
                                        ? const Color(0xFF414A51)
                                        : const Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Notice PDF (Clickable)
                          if (tender.tenderNoticeDocuments.isNotEmpty)
                            InkWell(
                              onTap: () => TenderDocumentActions.viewDocument(
                                context,
                                tender.tenderNoticeDocuments.first,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.picture_as_pdf_outlined,
                                        size: 12.5, color: Color(0xFF414A51)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Notice (PDF)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF414A51),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildReferenceStatusBadge(String status) {
    Color bg = const Color(0xFFEEF2F6);
    Color fg = const Color(0xFF414A51);

    switch (status) {
      case 'Won':
        bg = const Color(0xFF9CC70A).withValues(alpha: 0.18);
        fg = const Color(0xFF414A51);
        break;
      case 'Rejected':
      case 'Lost':
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        break;
      case 'Under Evaluation':
      case 'Under evaluation':
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade900;
        break;
      case 'Submitted':
      default:
        bg = const Color(0xFF414A51).withValues(alpha: 0.1);
        fg = const Color(0xFF414A51);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  void _showTenderDetailsDialog(BuildContext context, Tender t) {
    final currencyFmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final dateTimeFmt = DateFormat('dd/MM/yyyy HH:mm');

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${t.tenderId}  DETAILS',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF414A51),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 14),
                  _buildDetailRow('Tender Title', t.title),
                  _buildDetailRow('Client / Authority', t.clientName),
                  _buildDetailRow('Tender Ref No.',
                      t.tenderRefNo.isNotEmpty ? t.tenderRefNo : 'N/A'),
                  _buildDetailRow('Tender Type', t.tenderType),
                  _buildDetailRow('Tender Amount',
                      t.tenderAmount > 0 ? currencyFmt.format(t.tenderAmount) : '₹0'),
                  _buildDetailRow('Status', t.status),
                  if (t.openingDate != null)
                    _buildDetailRow(
                        'Opening Date & Time', dateTimeFmt.format(t.openingDate!)),
                  if (t.closingDate != null)
                    _buildDetailRow(
                        'Closing Date & Time', dateTimeFmt.format(t.closingDate!)),
                  _buildDetailRow(
                      'EMD Exemption',
                      t.isEmdExempted == 'Yes'
                          ? 'Yes (Exempted)'
                          : 'No (EMD: ${t.emdAmount > 0 ? currencyFmt.format(t.emdAmount) : "N/A"})'),
                  if (t.bqrRemark.isNotEmpty)
                    _buildDetailRow('BQR Details', t.bqrRemark),
                  if (t.tenderSpecRemark.isNotEmpty)
                    _buildDetailRow('Spec Remarks', t.tenderSpecRemark),
                  if (t.noticeUploadedAt != null)
                    _buildDetailRow('Notice Upload Time',
                        dateTimeFmt.format(t.noticeUploadedAt!)),
                  if (t.createdBy.isNotEmpty)
                    _buildDetailRow('Entered By', t.createdBy),
                  if (t.updatedAt != null)
                    _buildDetailRow(
                        'Last Modified', dateTimeFmt.format(t.updatedAt)),

                  // Attached Documents Section (View & Download)
                  ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 12),
                    const Text('ATTACHED DOCUMENTS (VIEW / DOWNLOAD)',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF414A51),
                            letterSpacing: 0.3)),
                    const SizedBox(height: 10),
                    if (t.tenderNoticeDocuments.isEmpty &&
                        t.tenderSpecDocuments.isEmpty &&
                        t.bqrDocuments.isEmpty &&
                        t.emdDocuments.isEmpty &&
                        t.emdExemptionDocuments.isEmpty &&
                        t.awardDocuments.isEmpty)
                      const Text(
                        'No documents attached to this tender.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF718096)),
                      ),
                    for (final doc in t.tenderNoticeDocuments)
                      TenderDocumentChip(document: doc, showDelete: false),
                    for (final doc in t.tenderSpecDocuments)
                      TenderDocumentChip(document: doc, showDelete: false),
                    for (final doc in t.bqrDocuments)
                      TenderDocumentChip(document: doc, showDelete: false),
                    for (final doc in t.emdDocuments)
                      TenderDocumentChip(document: doc, showDelete: false),
                    for (final doc in t.emdExemptionDocuments)
                      TenderDocumentChip(document: doc, showDelete: false),
                    for (final doc in t.awardDocuments)
                      TenderDocumentChip(document: doc, showDelete: false),
                  ],

                  // Won Details
                  if (t.status == 'Won') ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 10),
                    const Text('AWARD DETAILS',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF9CC70A))),
                    const SizedBox(height: 8),
                    _buildDetailRow('Document Type', t.awardDocType),
                    _buildDetailRow('Document Number', t.awardDocNumber),
                    if (t.awardDate != null)
                      _buildDetailRow('Award Date',
                          DateFormat('dd/MM/yyyy').format(t.awardDate!)),
                    _buildDetailRow('Awarded Value',
                        currencyFmt.format(t.awardedValue)),
                  ],

                  // Rejected Details
                  if (t.status == 'Rejected' || t.status == 'Lost') ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 10),
                    const Text('COMPETITOR & LOSS DETAILS',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.red)),
                    const SizedBox(height: 8),
                    _buildDetailRow('Competitor Name', t.competitorName),
                    _buildDetailRow('Competitor Quoted',
                        currencyFmt.format(t.competitorQuotedValue)),
                    _buildDetailRow('Our Quoted',
                        currencyFmt.format(t.ourQuotedValue)),
                    _buildDetailRow('Reason for Loss', t.reasonForLoss),
                  ],

                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('CLOSE'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF718096),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF414A51),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
