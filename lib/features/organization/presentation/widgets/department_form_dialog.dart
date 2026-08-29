import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/department.dart';
import '../../domain/organization.dart';
import '../../providers/organization_providers.dart';

class DepartmentFormDialog extends ConsumerStatefulWidget {
  const DepartmentFormDialog({this.department, super.key});

  final Department? department;

  static Future<bool?> show(BuildContext context, {Department? department}) {
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
          child: DepartmentFormDialog(department: department),
        ),
      );
    } else {
      return showDialog<bool>(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            width: 500,
            child: DepartmentFormDialog(department: department),
          ),
        ),
      );
    }
  }

  @override
  ConsumerState<DepartmentFormDialog> createState() => _DepartmentFormDialogState();
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
    'Chennai Head Office',
    'Chennai Manufacturing Plant',
    'Bangalore Branch',
    'Hyderabad Branch',
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

    _reportingHierarchy = (dept != null && hierarchyOptions.contains(dept.reportingHierarchy))
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSingleColumn = screenWidth < 540;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle for bottom sheet
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
          // Header Row
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
                    isEdit ? Icons.edit_note : Icons.account_tree,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isEdit ? 'Edit Department' : 'Add Department',
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
                    _buildOrgDropdown(orgsAsync),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Department Name *',
                      controller: _nameController,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                      hint: 'e.g. Engineering',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Department Head *',
                      controller: _headController,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Head is required' : null,
                      hint: 'e.g. Arun Kumar',
                    ),
                    const SizedBox(height: 16),
                    if (isSingleColumn) ...[
                      _buildHierarchyDropdown(),
                      const SizedBox(height: 16),
                      _buildLocationDropdown(),
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildHierarchyDropdown()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildLocationDropdown()),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Sticky Footer Action Buttons
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
                      : Text(isEdit ? 'Save Changes' : 'Add Department', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHierarchyDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reporting Hierarchy',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF344054)),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _reportingHierarchy,
          isDense: true,
          isExpanded: true,
          decoration: _inputDecoration(),
          items: hierarchyOptions
              .map((opt) => DropdownMenuItem(value: opt, child: Text(opt, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => _reportingHierarchy = val);
          },
        ),
      ],
    );
  }

  Widget _buildLocationDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Work Location',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF344054)),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _workLocation,
          isDense: true,
          isExpanded: true,
          decoration: _inputDecoration(),
          items: locationOptions
              .map((opt) => DropdownMenuItem(value: opt, child: Text(opt, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => _workLocation = val);
          },
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
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF344054)),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          style: const TextStyle(fontSize: 13),
          decoration: _inputDecoration(hint: hint),
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
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF344054)),
        ),
        const SizedBox(height: 6),
        orgsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (err, _) => Text('Error loading organizations: $err', style: const TextStyle(color: Colors.red, fontSize: 12)),
          data: (orgs) {
            final orgNames = orgs.map((o) => o.name).toList();
            if (_selectedOrganization != null && !orgNames.contains(_selectedOrganization)) {
              _selectedOrganization = null;
            }

            return DropdownButtonFormField<String>(
              initialValue: _selectedOrganization,
              isDense: true,
              isExpanded: true,
              hint: const Text('Select Organization', style: TextStyle(fontSize: 12, color: Color(0xFF667085))),
              validator: (v) => v == null || v.trim().isEmpty ? 'Organization is required' : null,
              decoration: _inputDecoration(),
              items: orgs
                  .map(
                    (org) => DropdownMenuItem(
                      value: org.name,
                      child: Text(org.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
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

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
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
    );
  }
}
