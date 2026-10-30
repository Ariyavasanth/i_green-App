import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/features/fund_requester/domain/models/fund_request.dart';
import 'image_viewer_dialog.dart';
import 'voice_note_player_widget.dart';

/// Requested funds mobile card matching reference screenshot (Image 5).
class FundRequestMobileCard extends StatelessWidget {
  final FundRequest request;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const FundRequestMobileCard({
    required this.request,
    required this.onTap,
    required this.onDelete,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    final isApproved = request.status.toLowerCase() == 'approved';
    final isRejected = request.status.toLowerCase() == 'rejected';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top row with status badge and delete icon (matching Image 5)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isApproved
                            ? const Color(0xFFDCFCE7)
                            : isRejected
                                ? const Color(0xFFFEE2E2)
                                : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        request.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: isApproved
                              ? const Color(0xFF15803D)
                              : isRejected
                                  ? const Color(0xFFB91C1C)
                                  : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFF475569),
                        size: 24,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Delete Request',
                      onPressed: onDelete,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Key-value rows matching Image 5:
                // Name, Message, Project Code, Approved Amount, Request Message
                _buildInfoRow('Name', request.employeeName),
                const SizedBox(height: 8),
                _buildInfoRow('Message', request.message.isNotEmpty ? request.message : '-'),
                const SizedBox(height: 8),
                _buildInfoRow('Project Code', request.projectCode),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Approved Amount',
                  request.approvedAmount > 0
                      ? currency.format(request.approvedAmount)
                      : '0.00',
                  highlightColor: request.approvedAmount > 0 ? const Color(0xFF15803D) : null,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Request Message',
                  currency.format(request.requestAmount),
                  highlightColor: AppColors.active,
                  isBold: true,
                ),

                const SizedBox(height: 14),
                const Divider(color: Color(0xFFE2E8F0), thickness: 1, height: 1),
                const SizedBox(height: 14),

                // Category items list (matching Image 5: Category: Amount, Sub Category, Comments)
                if (request.items.isEmpty)
                  _buildInfoRow('Category', 'General Fund Request')
                else
                  ...request.items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (index > 0) ...[
                          const SizedBox(height: 10),
                          const Divider(color: Color(0xFFF1F5F9), thickness: 1, height: 1),
                          const SizedBox(height: 10),
                        ],
                        _buildInfoRow(
                          item.category.isNotEmpty ? item.category : 'Item',
                          NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(item.amount),
                          isBold: true,
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          'Sub Category',
                          item.subCategory.isNotEmpty ? item.subCategory : '-',
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          'Comments',
                          item.comments.isNotEmpty ? item.comments : '-',
                        ),
                      ],
                    );
                  }),

                // Attachments indicator
                if (request.billUrls.isNotEmpty || (request.audioNoteUrl != null && request.audioNoteUrl!.isNotEmpty)) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (request.billUrls.isNotEmpty)
                        InkWell(
                          onTap: () {
                            final billItems = request.billUrls.asMap().entries.map((e) {
                              return BillImageItem(
                                title: 'Bill #${e.key + 1}',
                                url: e.value,
                              );
                            }).toList();
                            ImageViewerDialog.show(
                              context: context,
                              images: billItems,
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.image_outlined, size: 14, color: Color(0xFF2563EB)),
                                const SizedBox(width: 4),
                                Text(
                                  'View Bills (${request.billUrls.length})',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (request.audioNoteUrl != null && request.audioNoteUrl!.isNotEmpty)
                        InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => Dialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                                            'Attached Voice Note',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.close_rounded),
                                            onPressed: () => Navigator.of(ctx).pop(),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Recorded for project ${request.projectCode}',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      ),
                                      const SizedBox(height: 14),
                                      VoiceNotePlayerWidget(
                                        isRecording: false,
                                        hasVoiceNote: true,
                                        audioUrl: request.audioNoteUrl,
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
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F3FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFDDD6FE)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.play_circle_outline_rounded, size: 14, color: Color(0xFF7C3AED)),
                                SizedBox(width: 4),
                                Text(
                                  'Play Voice Note',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF7C3AED),
                                  ),
                                ),
                              ],
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
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    Color? highlightColor,
    bool isBold = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 135,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
        const Text(
          ':  ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
              color: highlightColor ?? const Color(0xFF334155),
            ),
          ),
        ),
      ],
    );
  }
}
