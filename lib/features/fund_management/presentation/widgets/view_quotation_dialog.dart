import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/features/fund_requester/domain/models/fund_request.dart';

class ViewQuotationDialog extends StatelessWidget {
  final FundRequest request;

  const ViewQuotationDialog({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fund Request Details',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF22282D),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Request No: ${request.requestNumber.isNotEmpty ? request.requestNumber : request.id}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF69737A),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Color(0xFF69737A)),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Overview Grid
              _buildDetailRow('Employee Name', '${request.employeeName} (ID: ${request.employeeCustomId.isNotEmpty ? request.employeeCustomId : request.employeeId})'),
              _buildDetailRow('Department', request.department.isNotEmpty ? request.department : 'Operations'),
              _buildDetailRow('Project Code', request.projectCode),
              if (request.projectName.isNotEmpty)
                _buildDetailRow('Project Name', request.projectName),
              _buildDetailRow('Request Date', dateFormat.format(request.createdAt)),
              _buildDetailRow('Total Requested Amount', currency.format(request.requestAmount), isBold: true),
              _buildDetailRow('Status', request.status, isStatus: true),
              if (request.status != 'Pending') ...[
                _buildDetailRow('Approved Amount', currency.format(request.approvedAmount), isBold: true),
                if (request.approvedBy != null && request.approvedBy!.isNotEmpty)
                  _buildDetailRow('Reviewed By', request.approvedBy!),
                if (request.approvalRemarks != null && request.approvalRemarks!.isNotEmpty)
                  _buildDetailRow(
                    request.status == 'Rejected' ? 'Rejection Reason' : 'Approval Remarks',
                    request.approvalRemarks!,
                  ),
              ],
              if (request.message.isNotEmpty)
                _buildDetailRow('Message From Employee', request.message),

              const SizedBox(height: 16),

              // Items breakdown if present
              if (request.items.isNotEmpty) ...[
                const Text(
                  'Itemized Breakdown',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF22282D),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: request.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final item = request.items[idx];
                      return ListTile(
                        dense: true,
                        title: Text(
                          '${item.category} ${item.subCategory.isNotEmpty ? "- ${item.subCategory}" : ""}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        subtitle: item.comments.isNotEmpty ? Text(item.comments, style: const TextStyle(fontSize: 12)) : null,
                        trailing: Text(
                          currency.format(item.amount),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Attached Bills / Quotations
              const Text(
                'Attached Quotations / Bills',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF22282D),
                ),
              ),
              const SizedBox(height: 8),
              if (request.billUrls.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Text(
                    'Quotation N/A (No external bills attached)',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: request.billUrls.map((url) {
                    final fileName = url.split('/').last.split('?').first;
                    return ActionChip(
                      avatar: const Icon(Icons.description, size: 16, color: Color(0xFF414A51)),
                      label: Text(
                        fileName.length > 25 ? '${fileName.substring(0, 22)}...' : fileName,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () async {
                        final uri = Uri.tryParse(url);
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    );
                  }).toList(),
                ),

              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.active,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: const Text('CLOSE'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, bool isStatus = false}) {
    Color valColor = isBold ? const Color(0xFF0F172A) : const Color(0xFF334155);
    if (isStatus) {
      if (value == 'Approved') valColor = const Color(0xFF16A34A);
      else if (value == 'Partially Approved') valColor = const Color(0xFFD97706);
      else if (value == 'Rejected') valColor = const Color(0xFFDC2626);
      else valColor = const Color(0xFF2563EB);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold || isStatus ? FontWeight.bold : FontWeight.w500,
                color: valColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

