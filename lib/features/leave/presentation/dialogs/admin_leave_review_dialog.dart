import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../employee/domain/employee.dart';
import '../../../employee/providers/employee_providers.dart';
import '../../domain/leave_request.dart';
import '../../providers/leave_providers.dart';

class AdminLeaveReviewDialog extends ConsumerStatefulWidget {
  final LeaveRequest request;

  const AdminLeaveReviewDialog({super.key, required this.request});

  static const Color primaryGreen = Color(0xFF9CC70A);
  static const Color darkNeutral = Color(0xFF414A51);

  @override
  ConsumerState<AdminLeaveReviewDialog> createState() => _AdminLeaveReviewDialogState();
}

class _AdminLeaveReviewDialogState extends ConsumerState<AdminLeaveReviewDialog> {
  final _remarkController = TextEditingController();
  bool _isProcessing = false;
  String _selectedMode = 'as_calculated';

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(leaveRepositoryProvider);
      final currentAdmin = ref.read(currentEmployeeProvider);
      final adminName = currentAdmin != null
          ? '${currentAdmin.firstName} ${currentAdmin.lastName}'
          : 'Admin';

      if (_selectedMode == 'reject') {
        final reason = _remarkController.text.trim().isNotEmpty
            ? _remarkController.text.trim()
            : 'Rejected by Admin';
        await repo.denyLeaveRequest(widget.request.id, adminName, reason: reason);
      } else {
        await repo.approveLeaveRequest(
          widget.request.id,
          adminName,
          approvalMode: _selectedMode,
          overrideReason: _remarkController.text.trim().isNotEmpty
              ? _remarkController.text.trim()
              : null,
        );
      }

      ref.invalidate(allLeaveRequestsProvider);
      ref.invalidate(leaveRequestsProvider);
      ref.invalidate(employeesProvider);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing leave decision: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final employeesAsync = ref.watch(employeesProvider);
    final employees = employeesAsync.value ?? [];
    final matchingEmp = employees.where((e) => e.id == req.employeeId).toList();
    final emp = matchingEmp.isNotEmpty ? matchingEmp.first : null;

    final policy = emp != null && emp.leaveType.isNotEmpty
        ? emp.leaveType
        : (req.leavePolicySnapshot.isNotEmpty ? req.leavePolicySnapshot : 'Monthly Allocation');

    final allowance = emp != null
        ? emp.monthlyLeaveAllowanceVal
        : (req.monthlyAllowanceSnapshot > 0 ? req.monthlyAllowanceSnapshot : 3.0);

    final availLeaves = emp != null ? emp.allowedLeaves : allowance;
    final reqDays = req.requestedDays > 0 ? req.requestedDays : req.numDays;

    double paidRec = 0.0;
    double lopRec = 0.0;

    if (policy == 'As Needed') {
      paidRec = reqDays;
      lopRec = 0.0;
    } else if (policy == 'No Leave') {
      paidRec = 0.0;
      lopRec = reqDays;
    } else {
      paidRec = reqDays.clamp(0.0, availLeaves).toDouble();
      lopRec = (reqDays - paidRec).clamp(0.0, 999.0).toDouble();
    }

    final String buttonLabel;
    final Color buttonColor;
    if (_selectedMode == 'as_calculated') {
      buttonLabel = 'Approve Leave';
      buttonColor = AdminLeaveReviewDialog.primaryGreen;
    } else if (_selectedMode == 'all_paid') {
      buttonLabel = 'Approve as Paid';
      buttonColor = const Color(0xFF0D8A4E);
    } else if (_selectedMode == 'all_lop') {
      buttonLabel = 'Approve as LOP';
      buttonColor = Colors.orange.shade800;
    } else {
      buttonLabel = 'Reject Leave';
      buttonColor = Colors.red.shade700;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
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
                  Row(
                    children: [
                      Icon(
                        req.isEmergency ? Icons.warning_amber_rounded : Icons.event_available,
                        color: req.isEmergency ? Colors.orange.shade800 : AdminLeaveReviewDialog.darkNeutral,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        req.isEmergency ? 'Emergency Leave Review' : 'Approve Leave Request',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AdminLeaveReviewDialog.darkNeutral,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),

              // CARD 1 — REQUEST DETAILS
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AdminLeaveReviewDialog.primaryGreen,
                          radius: 18,
                          child: Text(
                            req.employeeName.isNotEmpty ? req.employeeName[0].toUpperCase() : 'E',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                req.employeeName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                '${req.employeeCustomId} • Policy: $policy',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                        if (req.isEmergency)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, size: 12, color: Colors.orange.shade900),
                                const SizedBox(width: 4),
                                Text(
                                  'Emergency',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const Divider(height: 16),
                    _buildRow('Leave Type', req.leaveType),
                    _buildRow('Dates', '${req.fromDate} to ${req.toDate}'),
                    _buildRow('Requested', '${reqDays % 1 == 0 ? reqDays.toInt() : reqDays} Day(s)'),
                    if (req.isHalfDay)
                      _buildRow(
                        'Shift Window',
                        req.halfDayPeriod == 'first_half'
                            ? 'First Half (9:00 AM – 1:30 PM) | Work: 1:30 PM – 6:00 PM'
                            : 'Second Half (1:30 PM – 6:00 PM) | Work: 9:00 AM – 1:30 PM',
                        isBold: true,
                      ),
                    _buildRow('Reason', req.reason),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // CARD 2 — LEAVE BALANCE & SYSTEM RECOMMENDATION
              Container(
                width: double.infinity,
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
                        Icon(Icons.account_balance_wallet_outlined, size: 18, color: Colors.blue.shade900),
                        const SizedBox(width: 6),
                        Text(
                          'Leave Balance & Quota',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue.shade900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (policy == 'As Needed') ...[
                      Wrap(
                        spacing: 16,
                        runSpacing: 4,
                        children: const [
                          Text('• Policy: As Needed', style: TextStyle(fontSize: 12)),
                          Text('• Quota: No Monthly Limit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ] else if (policy == 'No Leave') ...[
                      Wrap(
                        spacing: 16,
                        runSpacing: 4,
                        children: const [
                          Text('• Policy: No Leave', style: TextStyle(fontSize: 12)),
                          Text('• Available Paid Leave: 0 Days', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                        ],
                      ),
                    ] else ...[
                      Wrap(
                        spacing: 14,
                        runSpacing: 4,
                        children: [
                          Text('• Allowance: ${allowance % 1 == 0 ? allowance.toInt() : allowance} Days', style: const TextStyle(fontSize: 12)),
                          Text('• Available: ${availLeaves % 1 == 0 ? availLeaves.toInt() : availLeaves} Days', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('• Requested: ${reqDays % 1 == 0 ? reqDays.toInt() : reqDays} Days', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber.shade900),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              policy == 'As Needed'
                                  ? '💡 System Recommendation: ${reqDays % 1 == 0 ? reqDays.toInt() : reqDays} Days Paid (As Needed Policy)'
                                  : policy == 'No Leave'
                                      ? '💡 System Recommendation: ${reqDays % 1 == 0 ? reqDays.toInt() : reqDays} Days LOP (No Leave Policy)'
                                      : '💡 System Recommendation: ${paidRec % 1 == 0 ? paidRec.toInt() : paidRec} Days Paid${lopRec > 0 ? " + ${lopRec % 1 == 0 ? lopRec.toInt() : lopRec} Day LOP" : ""}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // CARD 3 — ADMIN DECISION & PAYROLL TREATMENT
              const Text(
                'Admin Decision & Payroll Treatment',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AdminLeaveReviewDialog.darkNeutral),
              ),
              const SizedBox(height: 6),

              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: 'as_calculated',
                groupValue: _selectedMode,
                activeColor: AdminLeaveReviewDialog.primaryGreen,
                title: Text(
                  'Approve as Calculated (${paidRec % 1 == 0 ? paidRec.toInt() : paidRec} Paid, ${lopRec % 1 == 0 ? lopRec.toInt() : lopRec} LOP)',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Approve with system-calculated quota split.'),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedMode = val);
                },
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: 'all_paid',
                groupValue: _selectedMode,
                activeColor: const Color(0xFF0D8A4E),
                title: Text(
                  'Approve All as Paid Leave (${reqDays % 1 == 0 ? reqDays.toInt() : reqDays} Days Paid)',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Admin override: Grant all requested days as paid leave.'),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedMode = val);
                },
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: 'all_lop',
                groupValue: _selectedMode,
                activeColor: Colors.orange.shade800,
                title: Text(
                  'Approve All as LOP (${reqDays % 1 == 0 ? reqDays.toInt() : reqDays} Days LOP)',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Leave authorized, but marked as Loss of Pay in Payroll.'),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedMode = val);
                },
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: 'reject',
                groupValue: _selectedMode,
                activeColor: Colors.red.shade700,
                title: const Text(
                  'Reject Leave Request',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Request denied. Leave will not be authorized.'),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedMode = val);
                },
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _remarkController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: _selectedMode == 'reject' ? 'Rejection Reason (Mandatory)' : 'Admin Remark / Note (Optional)',
                  hintText: 'Enter reason or remark...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),

              // ACTION BUTTONS
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isProcessing ? null : () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isProcessing
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              buttonLabel,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: AdminLeaveReviewDialog.darkNeutral,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
