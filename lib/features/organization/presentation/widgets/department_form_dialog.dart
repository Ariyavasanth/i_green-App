import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/department.dart';
import '../../domain/organization.dart';
import '../../providers/organization_providers.dart';

class DepartmentFormDialog extends ConsumerStatefulWidget {
  const DepartmentFormDialog({this.department, super.key});

  final Department? department;

  @override
  ConsumerState<DepartmentFormDialog> createState() =>
      _DepartmentFormDialogState();
}

class _DepartmentFormDialogState extends ConsumerState<DepartmentFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _headController;
  String? _selectedOrganization;
  late String _reportingHierarchy;
  late String _workLocation;

  bool _isSaving = false;

  static const List<String> hierarchyOptions = [
    'Manager',
    'Supervisor',
    'Employee',
  ];

  static const List<String> locationOptions = [
    'Factory',
    'Office',
    'Remote',
  ];

  @override
  void initState() {
    super.initState();
    final dept = widget.department;
    _nameController = TextEditingController(text: dept?.departmentName ?? '');
    _headController = TextEditingController(text: dept?.departmentHead ?? '');
    _selectedOrganization = (dept != null && dept.organizationName.isNotEmpty)
        ? dept.organizationName
        : null;

    _reportingHierarchy = (dept != null &&
            hierarchyOptions.contains(dept.reportingHierarchy))
        ? dept.reportingHierarchy
        : hierarchyOptions.first;

    _workLocation = (dept != null && locationOptions.contains(dept.workLocation))
        ? dept.workLocation
        : locationOptions.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _headController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(organizationRepositoryProvider);
      final dept = Department(
        id: widget.department?.id ?? 0,
        organizationName: _selectedOrganization ?? '',
        departmentName: _nameController.text.trim(),
        departmentHead: _headController.text.trim(),
        reportingHierarchy: _reportingHierarchy,
        workLocation: _workLocation,
      );

      if (widget.department == null) {
        await repo.addDepartment(dept);
      } else {
        await repo.updateDepartment(dept);
      }

      ref.invalidate(departmentsProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving department: $e')),
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
    final isEdit = widget.department != null;
    final orgsAsync = ref.watch(organizationsProvider);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isEdit ? Icons.edit_note : Icons.account_tree,
            color: AppColors.active,
          ),
          const SizedBox(width: 8),
          Text(
            isEdit ? 'Edit Department' : 'Add Department',
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
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrgDropdown(orgsAsync),
                const SizedBox(height: 12),
                _buildTextField(
                  label: 'Department Name *',
                  controller: _nameController,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Name is required' : null,
                  hint: 'e.g. Information Technology (IT)',
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  label: 'Department Head *',
                  controller: _headController,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Head is required' : null,
                  hint: 'e.g. John Doe',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reporting Hierarchy',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            initialValue: _reportingHierarchy,
                            isDense: true,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide:
                                    const BorderSide(color: AppColors.divider),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide:
                                    const BorderSide(color: AppColors.active),
                              ),
                            ),
                            items: hierarchyOptions
                                .map(
                                  (opt) => DropdownMenuItem(
                                    value: opt,
                                    child: Text(opt,
                                        style: const TextStyle(fontSize: 13)),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _reportingHierarchy = val);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Work Location',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            initialValue: _workLocation,
                            isDense: true,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide:
                                    const BorderSide(color: AppColors.divider),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide:
                                    const BorderSide(color: AppColors.active),
                              ),
                            ),
                            items: locationOptions
                                .map(
                                  (opt) => DropdownMenuItem(
                                    value: opt,
                                    child: Text(opt,
                                        style: const TextStyle(fontSize: 13)),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _workLocation = val);
                              }
                            },
                          ),
                        ],
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
              : Text(isEdit ? 'Save Changes' : 'Add Department'),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? Function(String?)? validator,
    String? hint,
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

  Widget _buildOrgDropdown(AsyncValue<List<Organization>> orgsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Organization Name *',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        orgsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (err, _) => Text(
            'Error loading organizations: $err',
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
          data: (orgs) {
            final orgNames = orgs.map((o) => o.name).toList();
            if (_selectedOrganization != null &&
                !orgNames.contains(_selectedOrganization)) {
              _selectedOrganization = null;
            }

            return DropdownButtonFormField<String>(
              initialValue: _selectedOrganization,
              isDense: true,
              hint: const Text(
                'Select Organization',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Organization is required' : null,
              decoration: InputDecoration(
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
              items: orgs
                  .map(
                    (org) => DropdownMenuItem(
                      value: org.name,
                      child: Text(
                        org.name,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                setState(() => _selectedOrganization = val);
              },
            );
          },
        ),
      ],
    );
  }
}
