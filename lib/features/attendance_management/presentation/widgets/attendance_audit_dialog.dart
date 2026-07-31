import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/attendance_management_providers.dart';

class AttendanceAuditDialog extends ConsumerWidget {
  const AttendanceAuditDialog({super.key, this.employeeId});

  final int? employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attemptsAsync = ref.watch(attendanceManagementAuditProvider(employeeId));

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          const Icon(Icons.history, color: AppColors.active),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              employeeId != null ? 'Employee Verification Audit' : 'All Biometric & GPS Audit Logs',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 380,
        child: attemptsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error loading audit logs: $e')),
          data: (attempts) {
            if (attempts.isEmpty) {
              return const Center(
                child: Text('No biometric or GPS attempts logged in Firestore.'),
              );
            }

            return ListView.separated(
              itemCount: attempts.length,
              separatorBuilder: (_, index) => const Divider(),
              itemBuilder: (context, index) {
                final attempt = attempts[index];
                final status = attempt['verification_status'] as String? ?? 'Unknown';
                final isSuccess = status.contains('Verified') || status.contains('Checked Out');

                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: (isSuccess ? const Color(0xFF2E7D32) : const Color(0xFFC62828)).withValues(alpha: 0.1),
                    child: Icon(
                      isSuccess ? Icons.check_circle : Icons.warning_amber_rounded,
                      color: isSuccess ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                      size: 18,
                    ),
                  ),
                  title: Text(
                    '${attempt['employee_name'] ?? 'Employee'} - ${attempt['date']} (${attempt['time']})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  subtitle: Text(
                    'Verification: $status | Score: ${(attempt['similarity_score'] as num?)?.toStringAsFixed(2) ?? '0.0'}\n${attempt['message'] ?? ''}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
