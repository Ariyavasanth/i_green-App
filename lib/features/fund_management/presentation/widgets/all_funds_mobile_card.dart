import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:flutter_application_1/features/fund_requester/domain/models/fund_request.dart';
import 'view_quotation_dialog.dart';

class AllFundsMobileCard extends StatelessWidget {
  final FundRequest request;

  const AllFundsMobileCard({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    final dateFormat = DateFormat('yyyy-MM-dd');

    Color statusBg;
    Color statusFg;
    if (request.status == 'Approved') {
      statusBg = const Color(0xFFDCFCE7);
      statusFg = const Color(0xFF15803D);
    } else if (request.status == 'Partially Approved') {
      statusBg = const Color(0xFFFEF3C7);
      statusFg = const Color(0xFFB45309);
    } else if (request.status == 'Rejected') {
      statusBg = const Color(0xFFFEE2E2);
      statusFg = const Color(0xFFB91C1C);
    } else {
      statusBg = const Color(0xFFE2E8F0);
      statusFg = const Color(0xFF334155);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'ID: ${request.employeeCustomId.isNotEmpty ? request.employeeCustomId : request.employeeId}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          request.employeeName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    request.status,
                    style: TextStyle(
                      color: statusFg,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              request.projectCode,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Requested', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    Text(
                      currency.format(request.requestAmount),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                if (request.status == 'Approved' || request.status == 'Partially Approved')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Approved', style: TextStyle(fontSize: 11, color: Color(0xFF16A34A))),
                      Text(
                        currency.format(request.approvedAmount),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                      ),
                    ],
                  ),
                Text(
                  dateFormat.format(request.createdAt),
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
            if (request.approvalRemarks != null && request.approvalRemarks!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Remark: ${request.approvalRemarks!}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                ),
              ),
            ],
            const Divider(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => ViewQuotationDialog(request: request),
                  );
                },
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('View Full Details', style: TextStyle(fontSize: 12.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

