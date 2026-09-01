import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../leave/providers/leave_providers.dart';
import '../../employee/providers/employee_providers.dart';
import '../domain/permission_enums.dart';
import '../domain/permission_request.dart';
import '../providers/permission_providers.dart';

class PermissionDetailsPage extends ConsumerWidget {
  final PermissionRequest request;

  const PermissionDetailsPage({super.key, required this.request});

  static const Color primaryGreen = Color(0xFF9CC70A);
  static const Color darkNeutral = Color(0xFF414A51);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color statusColor;
    switch (request.status) {
      case PermissionStatus.approved:
        statusColor = Colors.green.shade700;
        break;
      case PermissionStatus.rejected:
        statusColor = Colors.red.shade700;
        break;
      case PermissionStatus.emergencyPending:
        statusColor = Colors.orange.shade800;
        break;
      case PermissionStatus.cancelled:
        statusColor = Colors.grey.shade600;
        break;
      case PermissionStatus.pending:
      default:
        statusColor = Colors.blue.shade700;
        break;
    }

    final dateStr = DateFormat('dd MMMM yyyy').format(request.date);
    final submittedStr = DateFormat('dd MMM yyyy, hh:mm a').format(request.submittedAt);
    final reviewedStr = request.reviewedAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(request.reviewedAt!)
        : null;

    final currentEmp = ref.watch(currentEmployeeProvider);
    final isPending = request.status == PermissionStatus.pending ||
        request.status == PermissionStatus.emergencyPending;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Status Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      request.isEmergency
                          ? 'Emergency: ${request.status.label.toUpperCase()}'
                          : request.status.label.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${request.durationMinutes} Minutes',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: darkNeutral,
                    ),
                  ),
                  Text(
                    '${request.fromTime} – ${request.toTime}',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Request Details Section
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Request Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: darkNeutral,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildDetailRow('Employee Name', request.employeeName),
                  _buildDetailRow('Employee ID', request.employeeCode),
                  _buildDetailRow('Department', request.department),
                  _buildDetailRow('Date', dateStr),
                  _buildDetailRow('Permission Type', request.permissionType.label),
                  _buildDetailRow('Reason', request.reason),
                  _buildDetailRow('Submitted At', submittedStr),
                  if (request.isEmergency && request.emergencyReason != null)
                    _buildDetailRow('Emergency Reason', request.emergencyReason!),
                  if (request.attachmentUrl != null && request.attachmentUrl!.isNotEmpty)
                    _buildDetailRow('Attachment / Link', request.attachmentUrl!),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Approval & Classification Details Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Approval & Treatment Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: darkNeutral,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildDetailRow('Status', request.status.label, valueColor: statusColor),
                  if (request.reviewedBy != null) ...[
                    _buildDetailRow('Reviewed By', request.reviewedBy!),
                    if (reviewedStr != null) _buildDetailRow('Reviewed At', reviewedStr),
                  ],
                  if (request.adminComment != null && request.adminComment!.isNotEmpty)
                    _buildDetailRow('Admin Remarks', request.adminComment!),
                  const Divider(height: 24),
                  _buildDetailRow(
                    'Attendance Treatment',
                    request.status == PermissionStatus.approved
                        ? 'Authorized Permission'
                        : (request.status == PermissionStatus.rejected ? 'Unauthorized Late / Absence' : 'Pending Review'),
                    valueColor: request.status == PermissionStatus.approved ? primaryGreen : darkNeutral,
                  ),
                  _buildDetailRow(
                    'Payroll Treatment',
                    request.payrollTreatment.label,
                    valueColor: request.payrollTreatment == PayrollTreatment.paid ? primaryGreen : Colors.orange.shade800,
                  ),
                  if (request.paidDurationMinutes > 0)
                    _buildDetailRow('Paid Duration', '${request.paidDurationMinutes} minutes'),
                  if (request.lopDurationMinutes > 0)
                    _buildDetailRow('LOP Duration', '${request.lopDurationMinutes} minutes', valueColor: Colors.red.shade700),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Cancel Button (if pending)
            if (isPending)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Cancel Permission Request?'),
                        content: const Text('Are you sure you want to cancel this permission request?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, Cancel')),
                        ],
                      ),
                    );

                    if (confirm == true && request.id != null) {
                      final repo = ref.read(permissionRepositoryProvider);
                      final empName = currentEmp != null ? '${currentEmp.firstName} ${currentEmp.lastName}' : 'Employee';
                      await repo.cancelRequest(request.id!, empName);
                      if (context.mounted) {
                        ref.invalidate(myPermissionRequestsProvider(request.employeeId));
                        ref.invalidate(employeePermissionBalanceProvider(request.employeeId));
                        context.go('/permission');
                      }
                    }
                  },
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  label: const Text('Cancel Request', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor ?? darkNeutral,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
