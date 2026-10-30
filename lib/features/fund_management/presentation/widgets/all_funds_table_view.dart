import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/features/fund_requester/domain/models/fund_request.dart';
import 'view_quotation_dialog.dart';

class AllFundsTableView extends StatelessWidget {
  final List<FundRequest> requests;
  final Function(FundRequest) onViewDetails;

  const AllFundsTableView({
    super.key,
    required this.requests,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder_open,
                size: 32,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No Fund Records Found',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'No matching fund requests found for this filter.',
              style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    final dateFormat = DateFormat('yyyy-MM-dd\nHH:mm:ss');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFD1D5DB), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1250),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFF414A51)),
              headingRowHeight: 56,
              dataRowMinHeight: 70,
              dataRowMaxHeight: 90,
              horizontalMargin: 16,
              columnSpacing: 18,
              dividerThickness: 0.8,
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: const Color(0xFFE5E7EB),
                  width: 0.8,
                ),
              ),
              columns: const [
                DataColumn(label: Text('Employee Id', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Employee Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Project Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Requested Amt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Approved Amt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Request Date', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Reviewed By', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Remarks / Reason', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Action', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              ],
              rows: List.generate(requests.length, (index) {
                final r = requests[index];
                final isEven = index % 2 == 0;
                final rowColor = isEven ? Colors.white : const Color(0xFFF9FAFB);

                return DataRow(
                  color: WidgetStateProperty.all(rowColor),
                  cells: [
                    DataCell(
                      Center(
                        child: Text(
                          r.employeeCustomId.isNotEmpty ? r.employeeCustomId : r.employeeId,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(r.employeeName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                    DataCell(
                      Container(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Text(
                          r.projectCode,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF374151), height: 1.3),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        currency.format(r.requestAmount),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataCell(
                      Text(
                        r.status == 'Approved' || r.status == 'Partially Approved'
                            ? currency.format(r.approvedAmount)
                            : '-',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: r.status == 'Approved'
                              ? const Color(0xFF16A34A)
                              : r.status == 'Partially Approved'
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    DataCell(_buildStatusBadge(r.status)),
                    DataCell(
                      Text(dateFormat.format(r.createdAt), style: const TextStyle(fontSize: 12, height: 1.25)),
                    ),
                    DataCell(
                      Text(
                        r.approvedBy != null && r.approvedBy!.isNotEmpty ? r.approvedBy! : '-',
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF4B5563)),
                      ),
                    ),
                    DataCell(
                      Container(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Text(
                          r.approvalRemarks != null && r.approvalRemarks!.isNotEmpty
                              ? r.approvalRemarks!
                              : (r.message.isNotEmpty ? r.message : '-'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
                        ),
                      ),
                    ),
                    DataCell(
                      Center(
                        child: OutlinedButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => ViewQuotationDialog(request: r),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF414A51)),
                            foregroundColor: const Color(0xFF414A51),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    if (status == 'Approved') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
    } else if (status == 'Partially Approved') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
    } else if (status == 'Rejected') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
    } else {
      bg = const Color(0xFFE2E8F0);
      fg = const Color(0xFF334155);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: fg,
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

