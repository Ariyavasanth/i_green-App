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

class IncentiveDetailPage extends ConsumerStatefulWidget {
  final int requestId;

  const IncentiveDetailPage({
    super.key,
    required this.requestId,
  });

  @override
  ConsumerState<IncentiveDetailPage> createState() => _IncentiveDetailPageState();
}

class _IncentiveDetailPageState extends ConsumerState<IncentiveDetailPage> {
  final TextEditingController _verifiedMetersController = TextEditingController();
  final TextEditingController _approvedAmountController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  bool _initialized = false;

  String _formatRequestDate(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
  }

  @override
  void dispose() {
    _verifiedMetersController.dispose();
    _approvedAmountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _initializeControllers(IncentiveRequest req) {
    if (_initialized) return;
    _verifiedMetersController.text = req.verifiedMeters?.toInt().toString() ?? req.meters.toInt().toString();
    _approvedAmountController.text = req.approvedAmount?.toInt().toString() ?? req.amount.toInt().toString();
    _initialized = true;
  }

  void _onVerifiedMetersChanged(String val, double rate) {
    final meters = double.tryParse(val.trim()) ?? 0.0;
    final calcAmount = meters * rate;
    _approvedAmountController.text = calcAmount.toInt().toString();
    setState(() {});
  }

  Future<void> _handleApprove(IncentiveRequest req) async {
    final verifiedMeters = double.tryParse(_verifiedMetersController.text.trim()) ?? (req.verifiedMeters ?? req.meters);
    final approvedAmount = double.tryParse(_approvedAmountController.text.trim()) ?? (verifiedMeters * req.rate);

    try {
      await ref.read(incentiveManagementRepositoryProvider).approveRequest(
            req.id!,
            verifiedMeters,
            approvedAmount,
          );
      ref.invalidate(allManagementRequestsProvider);
      ref.invalidate(incentiveRequestByIdProvider(req.id!));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Incentive request for ${req.employeeName} approved!'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving request: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleReject(IncentiveRequest req) async {
    try {
      await ref.read(incentiveManagementRepositoryProvider).rejectRequest(req.id!);
      ref.invalidate(allManagementRequestsProvider);
      ref.invalidate(incentiveRequestByIdProvider(req.id!));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Incentive request for ${req.employeeName} rejected.'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting request: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final requestAsync = ref.watch(incentiveRequestByIdProvider(widget.requestId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: requestAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Scaffold(
          appBar: AppBar(title: const Text('Incentive Request')),
          body: Center(child: Text('Error loading request details: $err', style: const TextStyle(color: Colors.red))),
        ),
        data: (req) {
          if (req == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Incentive Request')),
              body: const Center(child: Text('Request not found.')),
            );
          }

          _initializeControllers(req);
          final isPending = req.status == 'Pending';
          final empIdCode = req.employeeId != null
              ? 'EMP${req.employeeId.toString().padLeft(3, '0')}'
              : '';

          // Live / saved verified values
          final liveMeters = double.tryParse(_verifiedMetersController.text.trim()) ?? req.verifiedMeters ?? req.meters;
          final liveAmount = double.tryParse(_approvedAmountController.text.trim()) ?? req.approvedAmount ?? req.amount;

          return Column(
            children: [
              // Main scrollable content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row with Back Button & Status Badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, size: 22, color: AppColors.textPrimary),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            onPressed: () => context.pop(),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Incentive request',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$empIdCode · ${req.employeeName} · ${req.site}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildStatusBadge(req.status),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Employee Card
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: const Color(0xFF0D47A1),
                                child: Text(
                                  _getInitials(req.employeeName),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    req.employeeName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${req.designation} · $empIdCode',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Request Details Card (Displays live / approved verified values)
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Request details',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1F36),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildDetailItem(Icons.location_on_outlined, 'Site', req.site),
                              _buildDetailItem(Icons.calendar_today_outlined, 'Request date', _formatRequestDate(req.createdAt)),
                              _buildDetailItem(Icons.layers_outlined, 'Work type', req.productName),
                              _buildDetailItem(
                                Icons.straighten_outlined,
                                (req.status == 'Approved' || req.verifiedMeters != null) ? 'Verified meters' : 'Total meters',
                                '${liveMeters.toInt()} m',
                              ),
                              _buildDetailItem(Icons.monetization_on_outlined, 'Incentive rate', '${formatIndianCurrency(req.rate)} per meter'),
                              _buildDetailItem(
                                Icons.payments_outlined,
                                (req.status == 'Approved' || req.approvedAmount != null) ? 'Approved amount' : 'Requested amount',
                                formatIndianCurrency(liveAmount),
                                isHighlighted: true,
                              ),
                              if (req.approvedAmount != null && req.approvedAmount != req.amount) ...[
                                _buildDetailItem(
                                  Icons.history_outlined,
                                  'Original requested',
                                  formatIndianCurrency(req.amount),
                                ),
                              ],
                              _buildDetailItem(Icons.chat_bubble_outline, 'Remarks', (req.remarks?.isNotEmpty == true && req.remarks != '-') ? req.remarks! : 'None', isLast: true),
                            ],
                          ),
                        ),
                      ),
                      if (req.evidenceImage?.isNotEmpty == true) ...[
                        const SizedBox(height: 16),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Work image', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1F36))),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    base64Decode(req.evidenceImage!.split(',').last),
                                    width: double.infinity,
                                    height: 260,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const SizedBox(height: 100, child: Center(child: Text('Image could not be displayed.'))),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Verify and Approve Card
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Verify and approve',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1F36),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Verified Meters Field
                              const Text(
                                'Verified meters',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _verifiedMetersController,
                                enabled: isPending,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                                  filled: true,
                                  fillColor: isPending ? Colors.white : Colors.grey.shade100,
                                  isDense: true,
                                ),
                                onChanged: (val) => _onVerifiedMetersChanged(val, req.rate),
                              ),
                              const SizedBox(height: 16),

                              // Approved Amount Field
                              const Text(
                                'Approved amount (Rs)',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _approvedAmountController,
                                enabled: isPending,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                                  filled: true,
                                  fillColor: Colors.white,
                                  isDense: true,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 16),

                              // Reason for change Field
                              const Text(
                                'Reason for change (if amount edited)',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _reasonController,
                                enabled: isPending,
                                decoration: InputDecoration(
                                  hintText: 'Optional note',
                                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                                  filled: true,
                                  fillColor: Colors.white,
                                  isDense: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Fixed Action Bar (Approve / Reject buttons pinned at bottom)
              if (isPending)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.grey.shade300)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: ElevatedButton.icon(
                            onPressed: () => _handleReject(req),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Reject', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: ElevatedButton.icon(
                            onPressed: () => _handleApprove(req),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Approve', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFFFF3E0);
    Color fg = const Color(0xFFE65100);

    if (status == 'Approved') {
      bg = const Color(0xFFE8F5E9);
      fg = const Color(0xFF2E7D32);
    } else if (status == 'Rejected') {
      bg = const Color(0xFFFFEBEE);
      fg = const Color(0xFFC62828);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value, {bool isHighlighted = false, bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w600,
                color: isHighlighted ? const Color(0xFF1967D2) : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
