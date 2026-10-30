import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/features/fund_requester/domain/models/fund_request.dart';

/// Extraordinary desktop & tablet table view for requested funds.
class FundRequestTableView extends StatelessWidget {
  final List<FundRequest> requests;
  final Function(FundRequest) onViewDetails;
  final Function(FundRequest) onDelete;
  final Function(FundRequest) onApprove;
  final Function(FundRequest) onReject;

  const FundRequestTableView({
    required this.requests,
    required this.onViewDetails,
    required this.onDelete,
    required this.onApprove,
    required this.onReject,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.currency_exchange_rounded,
                size: 36,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Fund Requests Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Click the "+ Request Fund" floating button to create your first fund request.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1050),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              headingRowHeight: 52,
              dataRowMinHeight: 64,
              dataRowMaxHeight: 72,
              horizontalMargin: 20,
              columnSpacing: 24,
              dividerThickness: 0.6,
              headingTextStyle: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
              columns: const [
                DataColumn(label: Text('REQUEST ID')),
                DataColumn(label: Text('REQUESTER')),
                DataColumn(label: Text('PROJECT CODE')),
                DataColumn(label: Text('PURPOSE / MESSAGE')),
                DataColumn(label: Text('CATEGORIES')),
                DataColumn(label: Text('REQUEST AMOUNT')),
                DataColumn(label: Text('APPROVED AMOUNT')),
                DataColumn(label: Text('STATUS')),
                DataColumn(label: Text('DATE')),
                DataColumn(label: Text('ACTIONS')),
              ],
              rows: requests.map<DataRow>((req) {
                final isApproved = req.status.toLowerCase() == 'approved';
                final isRejected = req.status.toLowerCase() == 'rejected';
                final isPending = req.status.toLowerCase() == 'pending';

                return DataRow(
                  onSelectChanged: (_) => onViewDetails(req),
                  cells: [
                    // Request ID
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          req.requestNumber.isNotEmpty
                              ? req.requestNumber
                              : '#${req.id.substring(0, req.id.length.clamp(0, 7))}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),

                    // Requester
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                            child: Text(
                              req.employeeName.isNotEmpty
                                  ? req.employeeName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF414A51),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                req.employeeName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              if (req.employeeCustomId.isNotEmpty)
                                Text(
                                  req.employeeCustomId,
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

                    // Project Code
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Text(
                          req.projectCode,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ),

                    // Purpose / Message
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Text(
                          req.message.isNotEmpty ? req.message : '-',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),

                    // Categories
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (req.items.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2F6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                req.items.first.category +
                                    (req.items.length > 1 ? ' +${req.items.length - 1}' : ''),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            )
                          else
                            const Text('-', style: TextStyle(color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ),

                    // Request Amount
                    DataCell(
                      Text(
                        currency.format(req.requestAmount),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),

                    // Approved Amount
                    DataCell(
                      Text(
                        req.approvedAmount > 0
                            ? currency.format(req.approvedAmount)
                            : '₹ 0.00',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: req.approvedAmount > 0
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),

                    // Status
                    DataCell(
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
                          req.status.toUpperCase(),
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
                    ),

                    // Date
                    DataCell(
                      Text(
                        dateFormat.format(req.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),

                    // Actions
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined, size: 20),
                            tooltip: 'View Details',
                            color: const Color(0xFF475569),
                            onPressed: () => onViewDetails(req),
                          ),
                          if (isPending) ...[
                            IconButton(
                              icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                              tooltip: 'Approve Request',
                              color: const Color(0xFF16A34A),
                              onPressed: () => onApprove(req),
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel_outlined, size: 20),
                              tooltip: 'Reject Request',
                              color: const Color(0xFFDC2626),
                              onPressed: () => onReject(req),
                            ),
                          ],
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 20),
                            tooltip: 'Delete Request',
                            color: const Color(0xFF94A3B8),
                            onPressed: () => onDelete(req),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
