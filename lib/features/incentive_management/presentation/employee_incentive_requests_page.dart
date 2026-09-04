import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../incentive/domain/incentive_request.dart';
import '../providers/incentive_management_providers.dart';

String formatIndianCurrency(num amount, {String symbol = 'Rs '}) {
  final intVal = amount.round();
  final str = intVal.abs().toString();
  if (str.length <= 3) {
    return '$symbol${intVal < 0 ? '-' : ''}$str';
  }
  final last3 = str.substring(str.length - 3);
  final otherNumbers = str.substring(0, str.length - 3);
  final formattedOther = otherNumbers.replaceAllMapped(
    RegExp(r'(\d+?)(?=(\d{2})+$)'),
    (Match m) => '${m[1]},',
  );
  return '$symbol${intVal < 0 ? '-' : ''}$formattedOther,$last3';
}

class EmployeeIncentiveRequestsPage extends ConsumerStatefulWidget {
  final int? employeeId;
  final String employeeName;
  final String designation;
  final String initialStatus;

  const EmployeeIncentiveRequestsPage({
    super.key,
    this.employeeId,
    required this.employeeName,
    this.designation = '',
    this.initialStatus = 'All',
  });

  @override
  ConsumerState<EmployeeIncentiveRequestsPage> createState() => _EmployeeIncentiveRequestsPageState();
}

class _EmployeeIncentiveRequestsPageState extends ConsumerState<EmployeeIncentiveRequestsPage> {
  late String _selectedStatusFilter;

  String _formatRequestDate(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
  }

  Widget _buildEvidenceThumbnail(String image) {
    if (image.startsWith('http://') || image.startsWith('https://')) {
      return Image.network(image, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined));
    }
    try {
      return Image.memory(base64Decode(image.split(',').last), fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined));
    } catch (_) {
      return const Icon(Icons.broken_image_outlined);
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedStatusFilter = widget.initialStatus.isEmpty ? 'All' : widget.initialStatus;
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'EM';
    final parts = name.trim().split(' ');
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length.clamp(0, 2)).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    switch (status.trim().toLowerCase()) {
      case 'approved':
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        break;
      case 'rejected':
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFC62828);
        break;
      case 'pending':
      default:
        bg = const Color(0xFFFFF8E1);
        fg = const Color(0xFFF57F17);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _selectedStatusFilter.toLowerCase() == label.toLowerCase();
    return ChoiceChip(
      label: Text(
        '$label ($count)',
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : AppColors.textPrimary,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF1E293B),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? const Color(0xFF1E293B) : Colors.grey.shade300,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      onSelected: (_) {
        setState(() {
          _selectedStatusFilter = label;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final empRequestsAsync = ref.watch(
      employeeRequestsProvider((
        employeeId: widget.employeeId,
        employeeName: widget.employeeName,
      )),
    );

    final titleName = widget.employeeName.isNotEmpty ? widget.employeeName : 'Employee';
    final empIdStr = widget.employeeId != null && widget.employeeId! > 0
        ? 'EMP${widget.employeeId.toString().padLeft(3, '0')}'
        : '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          "$titleName's Requests",
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: empRequestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading requests: $err')),
        data: (allEmpRequests) {
          final pendingCount = allEmpRequests.where((r) => r.status.trim().toLowerCase() == 'pending').length;
          final approvedCount = allEmpRequests.where((r) => r.status.trim().toLowerCase() == 'approved').length;
          final rejectedCount = allEmpRequests.where((r) => r.status.trim().toLowerCase() == 'rejected').length;
          final allCount = allEmpRequests.length;

          final filteredRequests = _selectedStatusFilter == 'All'
              ? allEmpRequests
              : allEmpRequests.where((r) => r.status.trim().toLowerCase() == _selectedStatusFilter.toLowerCase()).toList();

          final totalFilteredAmount = filteredRequests.fold(0.0, (sum, r) => sum + (r.approvedAmount ?? r.amount));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Employee Summary Banner Card
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFF0D47A1),
                          child: Text(
                            _getInitials(titleName),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                titleName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$empIdStr ${widget.designation.isNotEmpty ? '· ${widget.designation}' : ''}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Total Amount',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatIndianCurrency(totalFilteredAmount),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('All', allCount),
                          const SizedBox(width: 8),
                          _buildFilterChip('Pending', pendingCount),
                          const SizedBox(width: 8),
                          _buildFilterChip('Approved', approvedCount),
                          const SizedBox(width: 8),
                          _buildFilterChip('Rejected', rejectedCount),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Request List Header Count
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${filteredRequests.length} ${_selectedStatusFilter.toLowerCase()} ${filteredRequests.length == 1 ? 'request' : 'requests'}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Request Cards List
              Expanded(
                child: filteredRequests.isEmpty
                    ? Center(
                        child: Text(
                          'No $_selectedStatusFilter requests found for $titleName.',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        itemCount: filteredRequests.length,
                        itemBuilder: (context, index) {
                          final req = filteredRequests[index];
                          final metersVal = (req.verifiedMeters ?? req.meters).toInt();
                          final displayAmount = req.approvedAmount ?? req.amount;

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            clipBehavior: Clip.hardEdge,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            color: Colors.white,
                            child: InkWell(
                              onTap: () => context.push('/incentive-management/detail/${req.id}'),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Row 1: Site + Product name (left) - Status Badge (right)
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${req.site} · ${req.productName}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: AppColors.textPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 2,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildStatusBadge(req.status),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey.shade600),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Request date: ${_formatRequestDate(req.createdAt)}',
                                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Row 2: Meters & Rate
                                    Row(
                                      children: [
                                        Icon(Icons.straighten, size: 16, color: Colors.grey.shade600),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Meters: ${metersVal}m  |  Rate: ${formatIndianCurrency(req.rate)}/m',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (req.evidenceImage?.isNotEmpty == true) ...[
                                      const SizedBox(height: 12),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: SizedBox(
                                          width: double.infinity,
                                          height: 150,
                                          child: _buildEvidenceThumbnail(req.evidenceImage!),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text('Tracker work image', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                    ],
                                    const SizedBox(height: 12),

                                    // Row 3: Amount + Action button
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              req.status.trim().toLowerCase() == 'approved' ? 'Approved Amount' : 'Amount',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              formatIndianCurrency(displayAmount),
                                              style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Spacer(),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: AppColors.active,
                                            elevation: 0,
                                            side: const BorderSide(color: AppColors.active),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          onPressed: () => context.push('/incentive-management/detail/${req.id}'),
                                          child: const Text(
                                            'View Details',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
