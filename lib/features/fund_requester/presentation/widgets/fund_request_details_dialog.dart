import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/features/fund_requester/domain/models/fund_category_constants.dart';
import 'package:flutter_application_1/features/fund_requester/domain/models/fund_request.dart';
import 'image_viewer_dialog.dart';
import 'voice_note_player_widget.dart';

class FundRequestDetailsDialog extends StatefulWidget {
  final FundRequest request;
  final Function(double approvedAmount, String remarks)? onApprove;
  final Function(String reason)? onReject;
  final VoidCallback? onDelete;
  final bool canReview;

  const FundRequestDetailsDialog({
    required this.request,
    this.onApprove,
    this.onReject,
    this.onDelete,
    this.canReview = true,
    super.key,
  });

  @override
  State<FundRequestDetailsDialog> createState() => _FundRequestDetailsDialogState();
}

class _FundRequestDetailsDialogState extends State<FundRequestDetailsDialog> {
  late final TextEditingController _approvedAmountController;
  late final TextEditingController _remarksController;
  final bool _isApproving = false;
  final bool _isRejecting = false;

  @override
  void initState() {
    super.initState();
    _approvedAmountController = TextEditingController(
      text: widget.request.approvedAmount > 0
          ? widget.request.approvedAmount.toStringAsFixed(2)
          : widget.request.requestAmount.toStringAsFixed(2),
    );
    _remarksController = TextEditingController(text: widget.request.approvalRemarks ?? '');
  }

  @override
  void dispose() {
    _approvedAmountController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    final isApproved = widget.request.status.toLowerCase() == 'approved';
    final isRejected = widget.request.status.toLowerCase() == 'rejected';
    final isPending = widget.request.status.toLowerCase() == 'pending';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 780),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.currency_exchange_rounded,
                      color: Color(0xFF414A51),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.request.requestNumber.isNotEmpty
                              ? 'Fund Request ${widget.request.requestNumber}'
                              : 'Fund Request Details',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Created on ${DateFormat('dd MMM yyyy, hh:mm a').format(widget.request.createdAt)}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isApproved
                          ? const Color(0xFFDCFCE7)
                          : isRejected
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      widget.request.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isApproved
                            ? const Color(0xFF15803D)
                            : isRejected
                                ? const Color(0xFFB91C1C)
                                : const Color(0xFFB45309),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Overview summary
                    _buildSectionHeader('Request Overview'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow('Requester Name', widget.request.employeeName),
                          const SizedBox(height: 8),
                          _buildDetailRow('Project Code', widget.request.projectCode),
                          const SizedBox(height: 8),
                          _buildDetailRow('Message / Purpose', widget.request.message.isNotEmpty ? widget.request.message : '-'),
                          const SizedBox(height: 8),
                          _buildDetailRow('Requested Amount', currency.format(widget.request.requestAmount), isBold: true),
                          const SizedBox(height: 8),
                          _buildDetailRow(
                            'Approved Amount',
                            widget.request.approvedAmount > 0
                                ? currency.format(widget.request.approvedAmount)
                                : '0.00',
                            color: widget.request.approvedAmount > 0 ? const Color(0xFF16A34A) : null,
                          ),
                          if (widget.request.approvedBy != null) ...[
                            const SizedBox(height: 8),
                            _buildDetailRow('Reviewed By', widget.request.approvedBy!),
                          ],
                          if (widget.request.approvalRemarks != null &&
                              widget.request.approvalRemarks!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildDetailRow('Review Remarks', widget.request.approvalRemarks!),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    _buildSectionHeader('Requested Items Breakdown'),
                    const SizedBox(height: 12),

                    // Items Table
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Column(
                          children: [
                            Container(
                              color: const Color(0xFFF1F5F9),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: const Row(
                                children: [
                                  Expanded(flex: 3, child: Text('CATEGORY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                                  Expanded(flex: 3, child: Text('SUB CATEGORY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                                  Expanded(flex: 4, child: Text('COMMENTS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                                  Expanded(flex: 3, child: Text('AMOUNT', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                                ],
                              ),
                            ),
                            ...widget.request.items.map((item) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: const BoxDecoration(
                                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(flex: 3, child: Text(item.category, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                                    Expanded(flex: 3, child: Text(item.subCategory.isNotEmpty ? item.subCategory : '-', style: const TextStyle(fontSize: 13))),
                                    Expanded(flex: 4, child: Text(item.comments.isNotEmpty ? item.comments : '-', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)))),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        currency.format(item.amount),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            Container(
                              color: const Color(0xFFF8FAFC),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('TOTAL REQUESTED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
                                  Text(
                                    currency.format(widget.request.requestAmount),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Attachments Section
                    if (widget.request.billUrls.isNotEmpty ||
                        widget.request.audioNoteUrl != null) ...[
                      const SizedBox(height: 24),
                      _buildSectionHeader('Attachments & Proofs'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          if (widget.request.billUrls.isNotEmpty)
                            InkWell(
                              onTap: () {
                                final List<BillImageItem> items = [];
                                for (int i = 0; i < widget.request.billUrls.length; i++) {
                                  items.add(BillImageItem(
                                    title: 'Bill #${i + 1}',
                                    url: widget.request.billUrls[i],
                                  ));
                                }
                                if (items.isNotEmpty) {
                                  ImageViewerDialog.show(
                                    context: context,
                                    images: items,
                                  );
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.image_outlined, color: Color(0xFF2563EB), size: 24),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${widget.request.billUrls.length} Bill Receipt(s)',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E3A8A)),
                                        ),
                                        const Text(
                                          'Tap to view fullscreen',
                                          style: TextStyle(fontSize: 11, color: Color(0xFF3B82F6)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.fullscreen_rounded, size: 18, color: Color(0xFF2563EB)),
                                  ],
                                ),
                              ),
                            ),
                          if (widget.request.audioNoteUrl != null && widget.request.audioNoteUrl!.isNotEmpty)
                            InkWell(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => Dialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    child: Container(
                                      padding: const EdgeInsets.all(20),
                                      constraints: const BoxConstraints(maxWidth: 420),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                'Employee Voice Note',
                                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.close_rounded),
                                                onPressed: () => Navigator.of(ctx).pop(),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Attached to ${widget.request.requestNumber.isNotEmpty ? widget.request.requestNumber : widget.request.projectCode}',
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                          ),
                                          const SizedBox(height: 14),
                                          VoiceNotePlayerWidget(
                                            isRecording: false,
                                            hasVoiceNote: true,
                                            audioUrl: widget.request.audioNoteUrl,
                                            onStartRecord: () {},
                                            onStopRecord: () {},
                                            onDelete: () => Navigator.of(ctx).pop(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F3FF),
                                  border: Border.all(color: const Color(0xFFDDD6FE)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.mic_rounded, color: Color(0xFF7C3AED), size: 24),
                                    SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Voice Note Attached',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF5B21B6)),
                                        ),
                                        Text(
                                          'Tap to listen & play',
                                          style: TextStyle(fontSize: 11, color: Color(0xFF7C3AED)),
                                        ),
                                      ],
                                    ),
                                    SizedBox(width: 6),
                                    Icon(Icons.play_circle_outline_rounded, size: 18, color: Color(0xFF7C3AED)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],

                    // Review Form (If Pending & canReview)
                    if (isPending && widget.canReview) ...[
                      const SizedBox(height: 28),
                      _buildSectionHeader('Review & Approval Decision'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _approvedAmountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Approved Amount (₹)',
                                prefixIcon: const Icon(Icons.currency_rupee_rounded),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _remarksController,
                              decoration: InputDecoration(
                                labelText: 'Decision Remarks (Optional)',
                                prefixIcon: const Icon(Icons.notes_rounded),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.onDelete != null)
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                      label: const Text('Delete', style: TextStyle(color: Color(0xFFDC2626))),
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onDelete!();
                      },
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Close'),
                      ),
                      if (isPending && widget.canReview) ...[
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: _isRejecting
                              ? null
                              : () {
                                  final reason = _remarksController.text.trim().isNotEmpty
                                      ? _remarksController.text.trim()
                                      : 'Fund request rejected by manager';
                                  Navigator.of(context).pop();
                                  widget.onReject?.call(reason);
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                            side: const BorderSide(color: Color(0xFFDC2626)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Reject'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _isApproving
                              ? null
                              : () {
                                  final amt = double.tryParse(_approvedAmountController.text.trim()) ??
                                      widget.request.requestAmount;
                                  Navigator.of(context).pop();
                                  widget.onApprove?.call(amt, _remarksController.text.trim());
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Approve Fund'),
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

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1E293B),
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        const Text(':  ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color ?? const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}
