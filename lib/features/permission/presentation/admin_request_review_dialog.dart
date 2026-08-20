import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../leave/providers/leave_providers.dart';
import '../domain/permission_enums.dart';
import '../domain/permission_request.dart';
import '../providers/permission_providers.dart';

class AdminRequestReviewDialog extends ConsumerStatefulWidget {
  final PermissionRequest request;

  const AdminRequestReviewDialog({super.key, required this.request});

  static const Color primaryGreen = Color(0xFF9CC70A);
  static const Color darkNeutral = Color(0xFF414A51);

  @override
  ConsumerState<AdminRequestReviewDialog> createState() => _AdminRequestReviewDialogState();
}

class _AdminRequestReviewDialogState extends ConsumerState<AdminRequestReviewDialog> {
  final _commentController = TextEditingController();
  final _rejectionReasonController = TextEditingController();
  bool _isProcessing = false;

  // Selected decision for Emergency: 'paid', 'lop', 'reject'
  String _emergencyDecision = 'paid';

  @override
  void dispose() {
    _commentController.dispose();
    _rejectionReasonController.dispose();
    super.dispose();
  }

  Future<void> _handleApproveNormal() async {
    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(permissionRepositoryProvider);
      final currentAdmin = ref.read(currentEmployeeProvider);
      final adminName = currentAdmin != null
          ? '${currentAdmin.firstName} ${currentAdmin.lastName}'
          : 'Admin';

      await repo.approveNormalRequest(
        widget.request.id!,
        adminName,
        comment: _commentController.text.trim().isNotEmpty
            ? _commentController.text.trim()
            : 'Approved as Normal Paid Permission',
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error approving request: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleReject() async {
    if (_rejectionReasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter rejection reason'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(permissionRepositoryProvider);
      final currentAdmin = ref.read(currentEmployeeProvider);
      final adminName = currentAdmin != null
          ? '${currentAdmin.firstName} ${currentAdmin.lastName}'
          : 'Admin';

      await repo.rejectRequest(
        widget.request.id!,
        adminName,
        _rejectionReasonController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error rejecting request: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleReviewEmergency() async {
    if (_emergencyDecision == 'reject' && _rejectionReasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter rejection reason'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(permissionRepositoryProvider);
      final currentAdmin = ref.read(currentEmployeeProvider);
      final adminName = currentAdmin != null
          ? '${currentAdmin.firstName} ${currentAdmin.lastName}'
          : 'Admin';

      if (_emergencyDecision == 'reject') {
        await repo.rejectRequest(
          widget.request.id!,
          adminName,
          _rejectionReasonController.text.trim(),
        );
      } else {
        final treatment = _emergencyDecision == 'paid'
            ? PayrollTreatment.paid
            : PayrollTreatment.lop;

        await repo.reviewEmergencyRequest(
          widget.request.id!,
          adminName,
          decision: treatment,
          comment: _commentController.text.trim().isNotEmpty
              ? _commentController.text.trim()
              : (_emergencyDecision == 'paid'
                  ? 'Approved as Paid Emergency'
                  : 'Approved as LOP Emergency'),
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reviewing emergency request: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balanceAsync = ref.watch(
      employeePermissionBalanceProvider(widget.request.employeeId),
    );

    final req = widget.request;
    final isEmergency = req.isEmergency || req.status == PermissionStatus.emergencyPending;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          isEmergency ? Icons.warning_amber_rounded : Icons.fact_check_outlined,
                          color: isEmergency ? Colors.orange.shade800 : AdminRequestReviewDialog.darkNeutral,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isEmergency ? 'Emergency Permission Review' : 'Permission Request Review',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AdminRequestReviewDialog.darkNeutral,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),

              // Employee Info Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AdminRequestReviewDialog.primaryGreen,
                      child: Text(
                        req.employeeName.isNotEmpty ? req.employeeName[0].toUpperCase() : 'E',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            req.employeeName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            '${req.employeeCode} • ${req.department}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Request Information
              const Text(
                'Request Details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AdminRequestReviewDialog.darkNeutral),
              ),
              const SizedBox(height: 8),
              _buildRow('Date', '${req.date.year}-${req.date.month.toString().padLeft(2, '0')}-${req.date.day.toString().padLeft(2, '0')}'),
              _buildRow('Type', req.permissionType.label),
              _buildRow('Time Range', '${req.fromTime} – ${req.toTime}'),
              _buildRow('Duration', '${req.durationMinutes} minutes'),
              _buildRow('Reason', req.reason),
              if (req.emergencyReason != null && req.emergencyReason!.isNotEmpty)
                _buildRow('Emergency Justification', req.emergencyReason!, isBold: true),
              const SizedBox(height: 16),

              // Employee Balance Context
              balanceAsync.maybeWhen(
                data: (bal) => Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: Colors.blue.shade900),
                          const SizedBox(width: 6),
                          Text(
                            'Employee Usage Context',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Text('• Daily Limit: ${bal.todayLimitHours.toStringAsFixed(1)}h', style: const TextStyle(fontSize: 12)),
                          Text('• Used Today: ${bal.todayUsedMinutes}m', style: const TextStyle(fontSize: 12)),
                          Text('• Rem. Today: ${bal.todayRemainingMinutes}m', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Text('• Monthly Limit: ${bal.monthlyLimitHours.toStringAsFixed(1)}h', style: const TextStyle(fontSize: 12)),
                          Text('• Used Month: ${bal.monthlyUsedHours.toStringAsFixed(1)}h', style: const TextStyle(fontSize: 12)),
                          Text('• Rem. Month: ${bal.monthlyRemainingHours.toStringAsFixed(1)}h', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),

              // Decision Controls Section
              if (isEmergency) ...[
                const Text(
                  'Emergency Decision & Payroll Treatment',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AdminRequestReviewDialog.darkNeutral),
                ),
                const SizedBox(height: 8),
                RadioListTile<String>(
                  value: 'paid',
                  groupValue: _emergencyDecision,
                  activeColor: AdminRequestReviewDialog.primaryGreen,
                  title: const Text('Approve as Paid Permission'),
                  subtitle: const Text('Full duration authorized as paid working time (No salary deduction).'),
                  onChanged: (val) {
                    if (val != null) setState(() => _emergencyDecision = val);
                  },
                ),
                RadioListTile<String>(
                  value: 'lop',
                  groupValue: _emergencyDecision,
                  activeColor: Colors.orange.shade800,
                  title: const Text('Approve as Loss of Pay (LOP)'),
                  subtitle: const Text('Attendance authorized, but duration marked as LOP in Payroll.'),
                  onChanged: (val) {
                    if (val != null) setState(() => _emergencyDecision = val);
                  },
                ),
                RadioListTile<String>(
                  value: 'reject',
                  groupValue: _emergencyDecision,
                  activeColor: Colors.red.shade700,
                  title: const Text('Reject Emergency Request'),
                  subtitle: const Text('Request rejected. Time marked as unauthorized late/absence.'),
                  onChanged: (val) {
                    if (val != null) setState(() => _emergencyDecision = val);
                  },
                ),
                const SizedBox(height: 12),
                if (_emergencyDecision == 'reject') ...[
                  TextFormField(
                    controller: _rejectionReasonController,
                    decoration: const InputDecoration(
                      labelText: 'Rejection Reason (Mandatory)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ] else ...[
                  TextFormField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      labelText: 'Admin Remarks (Optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _handleReviewEmergency,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _emergencyDecision == 'reject'
                          ? Colors.red.shade700
                          : (_emergencyDecision == 'paid'
                              ? AdminRequestReviewDialog.primaryGreen
                              : Colors.orange.shade800),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isProcessing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Confirm Emergency Decision',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
              ] else ...[
                // Normal Request Decision (Approve vs Reject)
                TextFormField(
                  controller: _commentController,
                  decoration: const InputDecoration(
                    labelText: 'Admin Remarks (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _rejectionReasonController,
                  decoration: const InputDecoration(
                    labelText: 'Rejection Reason (Required if Rejecting)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isProcessing ? null : _handleReject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade700),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _handleApproveNormal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminRequestReviewDialog.primaryGreen,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Approve (Paid)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: AdminRequestReviewDialog.darkNeutral,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
