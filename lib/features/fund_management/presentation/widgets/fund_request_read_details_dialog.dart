import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/features/fund_requester/domain/models/fund_category_constants.dart';
import 'package:flutter_application_1/features/fund_requester/domain/models/fund_request.dart';
import 'package:flutter_application_1/features/fund_requester/presentation/widgets/image_viewer_dialog.dart';

class FundRequestReadDetailsDialog extends StatefulWidget {
  final FundRequest request;
  final Function(FundRequest)? onApprove;
  final Function(FundRequest)? onReject;

  const FundRequestReadDetailsDialog({
    super.key,
    required this.request,
    this.onApprove,
    this.onReject,
  });

  static Future<void> show({
    required BuildContext context,
    required FundRequest request,
    Function(FundRequest)? onApprove,
    Function(FundRequest)? onReject,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => FundRequestReadDetailsDialog(
        request: request,
        onApprove: onApprove,
        onReject: onReject,
      ),
    );
  }

  @override
  State<FundRequestReadDetailsDialog> createState() => _FundRequestReadDetailsDialogState();
}

class _FundRequestReadDetailsDialogState extends State<FundRequestReadDetailsDialog> {
  bool _isPlayingAudio = false;
  double _audioProgress = 0.0;

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    final dateFormat = DateFormat('yyyy-MM-dd hh:mm a');

    final isPending = r.status.toLowerCase() == 'pending';
    final isApproved = r.status.toLowerCase() == 'approved';
    final isPartiallyApproved = r.status.toLowerCase() == 'partially approved';
    final isRejected = r.status.toLowerCase() == 'rejected';

    Color statusBgColor;
    Color statusTextColor;
    IconData statusIcon;

    if (isApproved) {
      statusBgColor = const Color(0xFFDCFCE7);
      statusTextColor = const Color(0xFF15803D);
      statusIcon = Icons.check_circle_outline_rounded;
    } else if (isPartiallyApproved) {
      statusBgColor = const Color(0xFFFEF3C7);
      statusTextColor = const Color(0xFFB45309);
      statusIcon = Icons.published_with_changes_rounded;
    } else if (isRejected) {
      statusBgColor = const Color(0xFFFEE2E2);
      statusTextColor = const Color(0xFFB91C1C);
      statusIcon = Icons.cancel_outlined;
    } else {
      statusBgColor = const Color(0xFFFEF9C3);
      statusTextColor = const Color(0xFFA16207);
      statusIcon = Icons.hourglass_top_rounded;
    }

    final empId = r.employeeCustomId.isNotEmpty ? r.employeeCustomId : r.employeeId;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 860),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Modal Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              decoration: const BoxDecoration(
                color: Color(0xFF414A51),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              r.requestNumber.isNotEmpty
                                  ? 'Fund Request: ${r.requestNumber}'
                                  : 'Fund Request Details',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusBgColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(statusIcon, size: 13, color: statusTextColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    r.status.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: statusTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Created on ${dateFormat.format(r.createdAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Employee Info & Project Card
                    _buildEmployeeCard(r, empId),
                    const SizedBox(height: 16),

                    // Financial Summary Cards
                    _buildFinancialSummary(r, currency),
                    const SizedBox(height: 16),

                    // Review Remarks or Rejection Reason (if any)
                    if (r.approvalRemarks != null && r.approvalRemarks!.isNotEmpty) ...[
                      _buildRemarksCard(r, isRejected),
                      const SizedBox(height: 16),
                    ],

                    // Purpose / Message
                    if (r.message.isNotEmpty) ...[
                      _buildMessageCard(r.message),
                      const SizedBox(height: 16),
                    ],

                    // Itemized Expenses Breakdown
                    _buildItemizedBreakdown(r, currency),
                    const SizedBox(height: 18),

                    // Attached Bills / Quotations Gallery
                    _buildBillsGallery(r),
                    const SizedBox(height: 18),

                    // Attached Voice Note
                    _buildVoiceNoteSection(r),
                  ],
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total: ${currency.format(r.requestAmount)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF414A51),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        ),
                        child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      if (isPending && widget.onReject != null) ...[
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onReject!(r);
                          },
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Reject'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            elevation: 0,
                          ),
                        ),
                      ],
                      if (isPending && widget.onApprove != null) ...[
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onApprove!(r);
                          },
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeCard(FundRequest r, String empId) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF414A51),
                child: Text(
                  r.employeeName.isNotEmpty ? r.employeeName[0].toUpperCase() : 'E',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.employeeName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'ID: $empId',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                        if (r.department.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            '• ${r.department}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.business_center_outlined, size: 18, color: Color(0xFF414A51)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PROJECT CODE',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      r.projectCode,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    if (r.projectName.isNotEmpty)
                      Text(
                        r.projectName,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary(FundRequest r, NumberFormat currency) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'REQUESTED AMOUNT',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currency.format(r.requestAmount),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: r.status == 'Approved' || r.status == 'Partially Approved'
                  ? const Color(0xFFF0FDF4)
                  : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: r.status == 'Approved' || r.status == 'Partially Approved'
                    ? const Color(0xFFBBF7D0)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'APPROVED AMOUNT',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  r.status == 'Approved' || r.status == 'Partially Approved'
                      ? currency.format(r.approvedAmount)
                      : '-',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: r.status == 'Approved' || r.status == 'Partially Approved'
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRemarksCard(FundRequest r, bool isRejected) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isRejected ? const Color(0xFFFEF2F2) : const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isRejected ? const Color(0xFFFECACA) : const Color(0xFFBAE6FD),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isRejected ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            size: 18,
            color: isRejected ? const Color(0xFFDC2626) : const Color(0xFF0284C7),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRejected ? 'Rejection Reason' : 'Reviewer Remarks',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isRejected ? const Color(0xFF991B1B) : const Color(0xFF0369A1),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  r.approvalRemarks!,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isRejected ? const Color(0xFF7F1D1D) : const Color(0xFF0C4A6E),
                  ),
                ),
                if (r.approvedBy != null && r.approvedBy!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Reviewed by: ${r.approvedBy!}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isRejected ? const Color(0xFF991B1B) : const Color(0xFF0369A1),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.chat_bubble_outline_rounded, size: 15, color: Color(0xFF64748B)),
              SizedBox(width: 6),
              Text(
                'PURPOSE / MESSAGE FROM EMPLOYEE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1E293B),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemizedBreakdown(FundRequest r, NumberFormat currency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.category_outlined, size: 16, color: Color(0xFF414A51)),
            SizedBox(width: 6),
            Text(
              'Itemized Category Expenses',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (r.items.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Text(
              'No item breakdown available',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Column(
                children: [
                  Container(
                    color: const Color(0xFFF1F5F9),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    child: const Row(
                      children: [
                        Expanded(flex: 4, child: Text('CATEGORY / SUB-CATEGORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                        Expanded(flex: 4, child: Text('COMMENTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                        Expanded(flex: 3, child: Text('AMOUNT', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      ],
                    ),
                  ),
                  ...r.items.map((item) {
                    final catIcon = FundCategoryConstants.getCategoryIcon(item.category);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(catIcon, size: 14, color: const Color(0xFF414A51)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.category,
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                      ),
                                      if (item.subCategory.isNotEmpty)
                                        Text(
                                          item.subCategory,
                                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Text(
                              item.comments.isNotEmpty ? item.comments : '-',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              currency.format(item.amount),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBillsGallery(FundRequest r) {
    final hasBills = r.billUrls.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_outlined, size: 16, color: Color(0xFF414A51)),
                const SizedBox(width: 6),
                Text(
                  'Attached Bills & Invoices (${r.billUrls.length})',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            if (hasBills)
              TextButton.icon(
                onPressed: () => _openFullscreenGallery(r, 0),
                icon: const Icon(Icons.fullscreen_rounded, size: 16),
                label: const Text('View Fullscreen', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (!hasBills)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 15, color: Color(0xFF94A3B8)),
                SizedBox(width: 8),
                Text(
                  'No bill or receipt images attached to this request.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                ),
              ],
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: r.billUrls.asMap().entries.map((entry) {
                final idx = entry.key;
                final url = entry.value;
                return _buildBillThumbnail(
                  url: url,
                  index: idx,
                  onTap: () => _openFullscreenGallery(r, idx),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildBillThumbnail({required String url, required int index, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: url.startsWith('http')
                    ? Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image, color: Color(0xFF94A3B8), size: 24),
                        ),
                      )
                    : const Center(
                        child: Icon(Icons.description_outlined, color: Color(0xFF64748B), size: 28),
                      ),
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                ),
              ),
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '#${index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFullscreenGallery(FundRequest r, int initialIdx) {
    final List<BillImageItem> items = [];
    for (int i = 0; i < r.billUrls.length; i++) {
      items.add(BillImageItem(
        title: 'Bill #${i + 1}',
        url: r.billUrls[i],
      ));
    }

    if (items.isNotEmpty) {
      ImageViewerDialog.show(
        context: context,
        images: items,
        initialIndex: initialIdx,
      );
    }
  }

  Widget _buildVoiceNoteSection(FundRequest r) {
    final hasAudio = r.audioNoteUrl != null && r.audioNoteUrl!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.mic_none_rounded, size: 16, color: Color(0xFF414A51)),
            SizedBox(width: 6),
            Text(
              'Attached Voice Note',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!hasAudio)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 15, color: Color(0xFF94A3B8)),
                SizedBox(width: 8),
                Text(
                  'No voice recording attached to this request.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDDD6FE)),
            ),
            child: Row(
              children: [
                // Play / Pause button
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isPlayingAudio = !_isPlayingAudio;
                    });
                  },
                  icon: Icon(
                    _isPlayingAudio ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    size: 36,
                    color: const Color(0xFF7C3AED),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Employee Voice Message',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5B21B6),
                            ),
                          ),
                          Text(
                            _isPlayingAudio ? 'Playing...' : 'Audio Ready',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF7C3AED)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Waveform visualizer
                      Row(
                        children: List.generate(24, (i) {
                          final heights = [10, 16, 22, 14, 28, 18, 12, 24, 30, 20, 14, 26, 18, 22, 12, 28, 20, 16, 24, 14, 18, 10, 14, 8];
                          final h = heights[i % heights.length].toDouble();
                          final isActive = (i / 24) <= (_isPlayingAudio ? 0.6 : 0.2);
                          return Expanded(
                            child: Container(
                              height: h * 0.7,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: isActive ? const Color(0xFF7C3AED) : const Color(0xFFDDD6FE),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                if (r.audioNoteUrl != null && r.audioNoteUrl!.startsWith('http')) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Open in new tab / download',
                    icon: const Icon(Icons.open_in_new_rounded, size: 18, color: Color(0xFF7C3AED)),
                    onPressed: () async {
                      final uri = Uri.tryParse(r.audioNoteUrl!);
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

