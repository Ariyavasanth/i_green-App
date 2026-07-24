import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/organization.dart';
import '../../providers/organization_providers.dart';

class OrganizationFormDialog extends ConsumerStatefulWidget {
  const OrganizationFormDialog({this.organization, super.key});

  final Organization? organization;

  @override
  ConsumerState<OrganizationFormDialog> createState() =>
      _OrganizationFormDialogState();
}

class _OrganizationFormDialogState
    extends ConsumerState<OrganizationFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _businessTypeController;
  late final TextEditingController _industryTypeController;
  late final TextEditingController _businessUnitsController;
  late final TextEditingController _locationsController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _websiteController;
  late final TextEditingController _taxIdController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final org = widget.organization;
    _nameController = TextEditingController(text: org?.name ?? '');
    _businessTypeController =
        TextEditingController(text: org?.businessType ?? 'Private Limited');
    _industryTypeController =
        TextEditingController(text: org?.industryType ?? 'Information Technology');
    _businessUnitsController =
        TextEditingController(text: org?.businessUnits ?? '');
    _locationsController = TextEditingController(text: org?.locations ?? '');
    _addressController = TextEditingController(text: org?.address ?? '');
    _phoneController = TextEditingController(text: org?.phoneNumber ?? '');
    _emailController = TextEditingController(text: org?.emailAddress ?? '');
    _websiteController = TextEditingController(text: org?.website ?? '');
    _taxIdController = TextEditingController(text: org?.taxId ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _businessTypeController.dispose();
    _industryTypeController.dispose();
    _businessUnitsController.dispose();
    _locationsController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _taxIdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(organizationRepositoryProvider);
      final org = Organization(
        id: widget.organization?.id ?? 0,
        name: _nameController.text.trim(),
        businessType: _businessTypeController.text.trim(),
        industryType: _industryTypeController.text.trim(),
        businessUnits: _businessUnitsController.text.trim(),
        locations: _locationsController.text.trim(),
        address: _addressController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        emailAddress: _emailController.text.trim(),
        website: _websiteController.text.trim(),
        taxId: _taxIdController.text.trim(),
      );

      if (widget.organization == null) {
        await repo.addOrganization(org);
      } else {
        await repo.updateOrganization(org);
      }

      ref.invalidate(organizationsProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving organization: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.organization != null;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isEdit ? Icons.edit_note : Icons.add_business,
            color: AppColors.active,
          ),
          const SizedBox(width: 8),
          Text(
            isEdit ? 'Edit Organization' : 'Add Organization',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildField(
                  label: 'Organization Name *',
                  controller: _nameController,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Name is required' : null,
                  hint: 'e.g. Acme Corporation',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        label: 'Business Type',
                        controller: _businessTypeController,
                        hint: 'e.g. Private Limited, Partnership',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildField(
                        label: 'Industry Type',
                        controller: _industryTypeController,
                        hint: 'e.g. Information Technology',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        label: 'Business Unit(s)',
                        controller: _businessUnitsController,
                        hint: 'e.g. Cloud, Manufacturing',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildField(
                        label: 'Location(s)',
                        controller: _locationsController,
                        hint: 'e.g. HQ, Regional Office',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildField(
                  label: 'Address',
                  controller: _addressController,
                  hint: 'e.g. 100 Tech Park, Suite 400',
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        label: 'Phone Number',
                        controller: _phoneController,
                        hint: 'e.g. +1 800 555 0199',
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildField(
                        label: 'Email Address',
                        controller: _emailController,
                        hint: 'e.g. contact@acme.com',
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        label: 'Website',
                        controller: _websiteController,
                        hint: 'e.g. https://www.acme.com',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildField(
                        label: 'Tax Identification Number (GST/VAT/TIN)',
                        controller: _taxIdController,
                        hint: 'e.g. GSTIN33AAACI1234F1Z1',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.active),
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(isEdit ? 'Save Changes' : 'Add Organization'),
        ),
      ],
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    String? Function(String?)? validator,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.active),
            ),
          ),
        ),
      ],
    );
  }
}
