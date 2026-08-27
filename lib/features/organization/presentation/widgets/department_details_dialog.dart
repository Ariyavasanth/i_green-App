import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/department.dart';

class DepartmentDetailsDialog extends StatelessWidget {
  const DepartmentDetailsDialog({required this.department, super.key});

  final Department department;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.remove_red_eye_outlined, color: AppColors.active),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Department Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width < 520
            ? MediaQuery.of(context).size.width * 0.9
            : 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailItem('Organization Name', department.organizationName, isHeader: true),
              const SizedBox(height: 12),
              _buildDetailItem('Department Name', department.departmentName),
              const Divider(height: 20),
              _buildDetailItem('Department Head', department.departmentHead),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildDetailItem('Reporting Hierarchy', department.reportingHierarchy)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildDetailItem('Work Location', department.workLocation)),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value, {bool isHeader = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value.isEmpty ? '-' : value,
          style: TextStyle(
            fontSize: isHeader ? 15 : 13,
            fontWeight: isHeader ? FontWeight.bold : FontWeight.w500,
            color: isHeader ? AppColors.active : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
