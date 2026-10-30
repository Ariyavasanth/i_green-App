import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/features/fund_requester/domain/models/fund_request.dart';
import 'view_quotation_dialog.dart';

class PendingFundsTableView extends StatelessWidget {
  final List<FundRequest> requests;
  final Function(FundRequest) onApprove;
  final Function(FundRequest) onReject;

  const PendingFundsTableView({
    super.key,
    required this.requests,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
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
                Icons.task_alt,
                size: 32,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No Pending Fund Requests',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'All employee fund requests have been approved or processed.',
              style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

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
            constraints: const BoxConstraints(minWidth: 1280),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFF414A51)),
              headingRowHeight: 56,
              dataRowMinHeight: 70,
              dataRowMaxHeight: 92,
              horizontalMargin: 16,
              columnSpacing: 20,
              dividerThickness: 0.8,
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: const Color(0xFFE5E7EB),
                  width: 0.8,
                ),
              ),
              columns: [
                _buildHeaderColumn('Employee Id', hasFilter: true),
                _buildHeaderColumn('Employee Name', hasFilter: true),
                _buildHeaderColumn('Project Code', hasFilter: true),
                _buildHeaderColumn('Request To'),
                _buildHeaderColumn('Amount'),
                _buildHeaderColumn('Message From Employee'),
                _buildHeaderColumn('Request Date', hasFilter: true),
                _buildHeaderColumn('Images'),
                _buildHeaderColumn('Audio File'),
                _buildHeaderColumn('View Details'),
                _buildHeaderColumn('Approve'),
                _buildHeaderColumn('Reject'),
              ],
              rows: List.generate(requests.length, (index) {
                final r = requests[index];
                final isEven = index % 2 == 0;
                final rowColor = isEven ? Colors.white : const Color(0xFFF9FAFB);

                return DataRow(
                  color: WidgetStateProperty.all(rowColor),
                  cells: [
                    // Employee Id
                    DataCell(
                      Center(
                        child: Text(
                          r.employeeCustomId.isNotEmpty ? r.employeeCustomId : r.employeeId,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF1F2937),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                    // Employee Name
                    DataCell(
                      Text(
                        r.employeeName,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF1F2937),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    // Project Code
                    DataCell(
                      Container(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: Text(
                          r.projectCode,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF374151),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),

                    // Request To
                    DataCell(
                      const Center(
                        child: Text(
                          '1',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ),
                    ),

                    // Amount
                    DataCell(
                      Text(
                        r.requestAmount.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),

                    // Message From Employee
                    DataCell(
                      Container(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Text(
                          r.message.isNotEmpty ? r.message : '-',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF4B5563),
                          ),
                        ),
                      ),
                    ),

                    // Request Date
                    DataCell(
                      Text(
                        dateFormat.format(r.createdAt),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF374151),
                          height: 1.25,
                        ),
                      ),
                    ),

                    // Images
                    DataCell(
                      Center(
                        child: r.billUrls.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.image_outlined, color: Color(0xFF414A51), size: 20),
                                tooltip: 'View ${r.billUrls.length} image(s)',
                                onPressed: () {
                                  ViewQuotationDialog.show(
                                    context: context,
                                    request: r,
                                    onApprove: onApprove,
                                    onReject: onReject,
                                  );
                                },
                              )
                            : const Text('-', style: TextStyle(color: Color(0xFF9CA3AF))),
                      ),
                    ),

                    // Audio File
                    DataCell(
                      Center(
                        child: r.audioNoteUrl != null && r.audioNoteUrl!.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.audiotrack, color: Color(0xFF7C3AED), size: 20),
                                tooltip: 'Play Audio Note',
                                onPressed: () {
                                  ViewQuotationDialog.show(
                                    context: context,
                                    request: r,
                                    onApprove: onApprove,
                                    onReject: onReject,
                                  );
                                },
                              )
                            : const Text('-', style: TextStyle(color: Color(0xFF9CA3AF))),
                      ),
                    ),

                    // View Details
                    DataCell(
                      Center(
                        child: OutlinedButton(
                          onPressed: () {
                            ViewQuotationDialog.show(
                              context: context,
                              request: r,
                              onApprove: onApprove,
                              onReject: onReject,
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

                    // Approve
                    DataCell(
                      Center(
                        child: SizedBox(
                          height: 34,
                          child: ElevatedButton(
                            onPressed: () => onApprove(r),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5CB85C),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'APPROVE',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Reject
                    DataCell(
                      Center(
                        child: SizedBox(
                          height: 34,
                          child: ElevatedButton(
                            onPressed: () => onReject(r),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD9534F),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'REJECT',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
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

  DataColumn _buildHeaderColumn(String label, {bool hasFilter = false}) {
    return DataColumn(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
          if (hasFilter) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.filter_alt,
              size: 14,
              color: Color(0xFFCBD5E1),
            ),
          ],
        ],
      ),
    );
  }
}

