import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/organization.dart';

class OrganizationDetailsDialog extends StatelessWidget {
  const OrganizationDetailsDialog({required this.organization, super.key});

  final Organization organization;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.remove_red_eye_outlined, color: AppColors.active),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Organization Details',
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
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailItem('Organization Name', organization.name, isHeader: true),
              const Divider(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildDetailItem('Business Type', organization.businessType)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildDetailItem('Industry Type', organization.industryType)),
                ],
              ),
              const SizedBox(height: 12),
              _buildDetailItem('Business Unit(s)', organization.businessUnits),
              const SizedBox(height: 12),
              _buildDetailItem('Location(s)', organization.locations),
              const SizedBox(height: 12),
              _buildDetailItem('Address', organization.address),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildDetailItem('Phone Number', organization.phoneNumber)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildDetailItem('Email Address', organization.emailAddress)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildDetailItem('Website', organization.website)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildDetailItem('Tax ID', organization.taxId)),
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
