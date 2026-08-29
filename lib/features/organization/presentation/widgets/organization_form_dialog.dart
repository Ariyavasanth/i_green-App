import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/organization.dart';
import '../../providers/organization_providers.dart';

class OrganizationFormDialog extends ConsumerStatefulWidget {
  const OrganizationFormDialog({this.organization, super.key});

  final Organization? organization;

  static Future<bool?> show(BuildContext context, {Organization? organization}) {
    final isMobile = MediaQuery.of(context).size.width < 640 || MediaQuery.of(context).size.height < 700;
    if (isMobile) {
      return showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: OrganizationFormDialog(organization: organization),
        ),
      );
    } else {
      return showDialog<bool>(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            width: 580,
            child: OrganizationFormDialog(organization: organization),
          ),
        ),
      );
    }
  }

  @override
  ConsumerState<OrganizationFormDialog> createState() => _OrganizationFormDialogState();
}

class _OrganizationFormDialogState extends ConsumerState<OrganizationFormDialog> {
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
    _businessTypeController = TextEditingController(text: org?.businessType ?? 'Private Limited');
    _industryTypeController = TextEditingController(text: org?.industryType ?? 'Information Technology');
    _businessUnitsController = TextEditingController(text: org?.businessUnits ?? '');
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSingleColumn = screenWidth < 540;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD0D5DD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isEdit ? Icons.edit_note : Icons.add_business,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isEdit ? 'Edit Organization' : 'Add Organization',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF101828),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF667085)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEAECF0)),

          // Scrollable Form Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildField(
                      label: 'Organization Name *',
                      controller: _nameController,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                      hint: 'e.g. Acme Corporation',
                    ),
                    const SizedBox(height: 16),
                    _buildResponsiveRow(
                      isSingleColumn: isSingleColumn,
                      left: _buildField(
                        label: 'Business Type',
                        controller: _businessTypeController,
                        hint: 'e.g. Private Limited',
                      ),
                      right: _buildField(
                        label: 'Industry Type',
                        controller: _industryTypeController,
                        hint: 'e.g. Engineering & Manufacturing',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildResponsiveRow(
                      isSingleColumn: isSingleColumn,
                      left: _buildField(
                        label: 'Business Unit(s)',
                        controller: _businessUnitsController,
                        hint: 'e.g. Cloud, Manufacturing',
                      ),
                      right: _buildField(
                        label: 'Location(s)',
                        controller: _locationsController,
                        hint: 'e.g. HQ, Regional Office',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      label: 'Address',
                      controller: _addressController,
                      hint: 'e.g. 100 Tech Park, Suite 400',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    _buildResponsiveRow(
                      isSingleColumn: isSingleColumn,
                      left: _buildField(
                        label: 'Phone Number',
                        controller: _phoneController,
                        hint: 'e.g. +1 800 555 0199',
                        keyboardType: TextInputType.phone,
                      ),
                      right: _buildField(
                        label: 'Email Address',
                        controller: _emailController,
                        hint: 'e.g. contact@acme.com',
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildResponsiveRow(
                      isSingleColumn: isSingleColumn,
                      left: _buildField(
                        label: 'Website',
                        controller: _websiteController,
                        hint: 'e.g. https://www.acme.com',
                      ),
                      right: _buildField(
                        label: 'Tax Identification Number (GST/VAT/TIN)',
                        controller: _taxIdController,
                        hint: 'e.g. 33ABCDE1234F1Z5',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Sticky Footer Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFEAECF0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: const BorderSide(color: Color(0xFFD0D5DD)),
                  ),
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF344054), fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(isEdit ? 'Save Changes' : 'Add Organization', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveRow({
    required bool isSingleColumn,
    required Widget left,
    required Widget right,
  }) {
    if (isSingleColumn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          left,
          const SizedBox(height: 16),
          right,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
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
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF344054)),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF667085), fontSize: 12),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
