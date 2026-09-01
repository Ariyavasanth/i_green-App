import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_searchable_dropdown.dart';
import '../../domain/designation.dart';
import '../../providers/organization_providers.dart';

class DesignationFormDialog extends ConsumerStatefulWidget {
  const DesignationFormDialog({
    this.designation,
    this.initialOrganization,
    this.initialDepartment,
    super.key,
  });

  final Designation? designation;
  final String? initialOrganization;
  final String? initialDepartment;

  static Future<bool?> show(
    BuildContext context, {
    Designation? designation,
    String? initialOrganization,
    String? initialDepartment,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 640 ||
        MediaQuery.of(context).size.height < 700;
    if (isMobile) {
      return showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: DesignationFormDialog(
            designation: designation,
            initialOrganization: initialOrganization,
            initialDepartment: initialDepartment,
          ),
        ),
      );
    } else {
      return showDialog<bool>(
        context: context,
        builder: (context) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            width: 520,
            child: DesignationFormDialog(
              designation: designation,
              initialOrganization: initialOrganization,
              initialDepartment: initialDepartment,
            ),
          ),
        ),
      );
    }
  }

  @override
  ConsumerState<DesignationFormDialog> createState() =>
      _DesignationFormDialogState();
}

class _DesignationFormDialogState extends ConsumerState<DesignationFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  final List<String> _pendingDesignations = [];
  String? _selectedOrganization;
  String? _selectedDepartment;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.designation;
    _nameController = TextEditingController(text: d?.designationName ?? '');
    _selectedOrganization = (d != null && d.organizationName.isNotEmpty)
        ? d.organizationName
        : (widget.initialOrganization != null && widget.initialOrganization != 'All'
            ? widget.initialOrganization
            : null);
    _selectedDepartment = (d != null && d.departmentName.isNotEmpty)
        ? d.departmentName
        : (widget.initialDepartment != null && widget.initialDepartment != 'All'
            ? widget.initialDepartment
            : null);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addFromInput() {
    final text = _nameController.text.trim();
    if (text.isEmpty) return;

    // Support comma or newline separated inputs (e.g. "HR Executive, HR Manager\nHR Coordinator")
    final items = text
        .split(RegExp(r'[,;\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    setState(() {
      for (final item in items) {
        if (!_pendingDesignations.contains(item)) {
          _pendingDesignations.add(item);
        }
      }
      _nameController.clear();
    });
  }

  List<String> _getAllDesignationNames() {
    if (widget.designation != null) {
      return [_nameController.text.trim()].where((s) => s.isNotEmpty).toList();
    }

    final list = List<String>.from(_pendingDesignations);
    final currentInput = _nameController.text.trim();
    if (currentInput.isNotEmpty) {
      final fromInput = currentInput
          .split(RegExp(r'[,;\n]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty && !list.contains(s));
      list.addAll(fromInput);
    }
    return list;
  }

  Future<void> _submit() async {
    final isEdit = widget.designation != null;
    if (isEdit && !_formKey.currentState!.validate()) return;

    if (_selectedDepartment == null || _selectedDepartment!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Department')),
      );
      return;
    }

    final names = _getAllDesignationNames();
    if (names.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one designation name')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(organizationRepositoryProvider);

      if (isEdit) {
        final item = Designation(
          id: widget.designation!.id,
          organizationName: _selectedOrganization?.trim() ?? '',
          departmentName: _selectedDepartment!.trim(),
          designationName: names.first,
        );
        await repo.updateDesignation(item);
      } else {
        // Add multiple designations
        for (final name in names) {
          final item = Designation(
            id: 0,
            organizationName: _selectedOrganization?.trim() ?? '',
            departmentName: _selectedDepartment!.trim(),
            designationName: name,
          );
          await repo.addDesignation(item);
        }
      }

      ref.invalidate(allDesignationsProvider);
      ref.invalidate(designationsProvider(_selectedDepartment));

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving designation: $e')),
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
    final isEdit = widget.designation != null;
    final orgsAsync = ref.watch(organizationsProvider);
    final deptsAsync = ref.watch(departmentsProvider);
    final allNames = _getAllDesignationNames();
    final count = allNames.length;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.badge_outlined,
                          color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEdit
                          ? 'Edit Designation'
                          : (_pendingDesignations.length > 1
                              ? 'Add Multiple Designations'
                              : 'Add Designation'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF667085)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEAECF0)),

          // Form Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Organization Dropdown
                    orgsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (err, _) => const SizedBox.shrink(),
                      data: (orgs) {
                        final orgNames = orgs.map((o) => o.name).where((s) => s.isNotEmpty).toSet().toList();
                        if (orgNames.isEmpty) {
                          orgNames.add('IGreentec Engg. India Pvt. Ltd.');
                        }
                        if (_selectedOrganization != null && !orgNames.contains(_selectedOrganization)) {
                          orgNames.insert(0, _selectedOrganization!);
                        }
                        if (_selectedOrganization == null && orgNames.isNotEmpty) {
                          _selectedOrganization = orgNames.first;
                        }

                        return AppSearchableDropdown<String>(
                          label: 'Organization *',
                          value: _selectedOrganization,
                          items: orgNames,
                          placeholder: 'Select Organization',
                          searchHint: 'Search organization...',
                          onChanged: (val) {
                            setState(() {
                              _selectedOrganization = val;
                              _selectedDepartment = null;
                            });
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Department Dropdown
                    deptsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (err, _) => Text(
                        'Error loading departments: $err',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                      data: (depts) {
                        var filteredDepts = depts;
                        if (_selectedOrganization != null && _selectedOrganization!.isNotEmpty) {
                          filteredDepts = depts.where((d) => d.organizationName.trim().toLowerCase() == _selectedOrganization!.trim().toLowerCase() || d.organizationName.isEmpty).toList();
                        }
                        final deptNames = (filteredDepts.isNotEmpty ? filteredDepts : depts)
                            .map((d) => d.departmentName)
                            .where((s) => s.isNotEmpty)
                            .toSet()
                            .toList();

                        if (deptNames.isEmpty) {
                          deptNames.addAll([
                            'Human Resources',
                            'Engineering',
                            'Production',
                            'Quality Assurance',
                            'Projects',
                            'Finance & Accounts',
                            'Administration',
                            'Sales & Marketing',
                          ]);
                        }

                        if (_selectedDepartment != null &&
                            !deptNames.contains(_selectedDepartment)) {
                          deptNames.insert(0, _selectedDepartment!);
                        }

                        return AppSearchableDropdown<String>(
                          label: 'Department *',
                          value: _selectedDepartment,
                          items: deptNames,
                          placeholder: 'Select Department',
                          searchHint: 'Search department...',
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Department is required'
                              : null,
                          onChanged: (val) {
                            setState(() => _selectedDepartment = val);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Designation Input (Supports single or multiple comma/newline separated)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isEdit ? 'Designation *' : 'Designation(s) *',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF344054),
                              ),
                            ),
                            if (!isEdit)
                              const Text(
                                'Separate by comma or new line for multiple',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _nameController,
                                maxLines: isEdit ? 1 : 2,
                                minLines: 1,
                                style: const TextStyle(fontSize: 13),
                                validator: (v) {
                                  if (isEdit && (v == null || v.trim().isEmpty)) {
                                    return 'Designation name is required';
                                  }
                                  if (!isEdit && _pendingDesignations.isEmpty && (v == null || v.trim().isEmpty)) {
                                    return 'At least one designation is required';
                                  }
                                  return null;
                                },
                                onFieldSubmitted: (_) {
                                  if (!isEdit) _addFromInput();
                                },
                                decoration: InputDecoration(
                                  hintText: isEdit
                                      ? 'e.g. HR Executive'
                                      : 'e.g. HR Manager, HR Executive, Recruiter',
                                  hintStyle: const TextStyle(
                                      color: Color(0xFF667085), fontSize: 12),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        const BorderSide(color: Color(0xFFD0D5DD)),
                                  ),
                                ),
                              ),
                            ),
                            if (!isEdit) ...[
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  foregroundColor: const Color(0xFF1E293B),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                onPressed: _addFromInput,
                                child: const Text(
                                  '+ Add',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ],
                          ],
                        ),

                        // Render pending tags/chips if multiple
                        if (!isEdit && _pendingDesignations.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Designations to add:',
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF475467)),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: _pendingDesignations.map((dName) {
                              return Container(
                                padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: AppColors.primary.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      dName,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          _pendingDesignations.remove(dName);
                                        });
                                      },
                                      child: const Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Footer
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    side: const BorderSide(color: Color(0xFFD0D5DD)),
                  ),
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel',
                      style: TextStyle(
                          color: Color(0xFF344054),
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          isEdit
                              ? 'Save Changes'
                              : (count > 1
                                  ? 'Add $count Designations'
                                  : 'Add Designation'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
