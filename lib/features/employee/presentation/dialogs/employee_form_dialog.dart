import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/employee.dart';
import '../../providers/employee_providers.dart';

class EmployeeFormDialog extends ConsumerStatefulWidget {
  const EmployeeFormDialog({this.employee, super.key});

  final Employee? employee;

  @override
  ConsumerState<EmployeeFormDialog> createState() => _EmployeeFormDialogState();
}

class _EmployeeFormDialogState extends ConsumerState<EmployeeFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _empIdController;
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _orgController;
  late final TextEditingController _deptController;
  late final TextEditingController _designationController;
  late final TextEditingController _joiningDateController;

  String _employmentType = 'Full-Time';
  String _status = 'Active';
  String _leaveType = 'As Needed';
  bool _isSaving = false;
  late Set<String> _selectedPermissions;

  @override
  void initState() {
    super.initState();
    final emp = widget.employee;
    _empIdController = TextEditingController(text: emp?.employeeId ?? '');
    _firstNameController = TextEditingController(text: emp?.firstName ?? '');
    _lastNameController = TextEditingController(text: emp?.lastName ?? '');
    _emailController = TextEditingController(text: emp?.emailAddress ?? '');
    _phoneController = TextEditingController(text: emp?.phoneNumber ?? '');
    _orgController = TextEditingController(text: emp?.organizationName ?? '');
    _deptController = TextEditingController(
      text: (emp?.department ?? '').isNotEmpty
          ? emp!.department
          : Employee.departmentOptions.first,
    );
    _designationController = TextEditingController(
      text: (emp?.designation ?? '').isNotEmpty
          ? emp!.designation
          : Employee.designationOptions.first,
    );
    _joiningDateController = TextEditingController(
      text: emp?.joiningDate ?? DateTime.now().toString().split(' ')[0],
    );
    if (emp != null) {
      _employmentType = emp.employmentType.isEmpty ? 'Full-Time' : emp.employmentType;
      _status = emp.status.isEmpty ? 'Active' : emp.status;
      _leaveType = emp.leaveType.isEmpty ? 'As Needed' : emp.leaveType;
      _selectedPermissions = emp.accessPermissions.isNotEmpty
          ? Set<String>.from(emp.accessPermissions)
          : Set<String>.from(Employee.allSidebarPermissions);
    } else {
      _selectedPermissions = Set<String>.from(Employee.allSidebarPermissions);
    }
  }

  @override
  void dispose() {
    _empIdController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _orgController.dispose();
    _deptController.dispose();
    _designationController.dispose();
    _joiningDateController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final repo = ref.read(employeeRepositoryProvider);
      final isEdit = widget.employee != null;

      final updatedEmployee = (widget.employee ??
              Employee(
                id: 0,
                employeeId: _empIdController.text.trim(),
                firstName: _firstNameController.text.trim(),
                lastName: _lastNameController.text.trim(),
                emailAddress: _emailController.text.trim(),
                phoneNumber: _phoneController.text.trim(),
                gender: 'Male',
                dob: '',
                organizationName: _orgController.text.trim(),
                department: _deptController.text.trim(),
                designation: _designationController.text.trim(),
                employmentType: _employmentType,
                joiningDate: _joiningDateController.text.trim(),
                status: _status,
                accessPermissions: _selectedPermissions.toList(),
              ))
          .copyWith(
        employeeId: _empIdController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        emailAddress: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        organizationName: _orgController.text.trim(),
        department: _deptController.text.trim(),
        designation: _designationController.text.trim(),
        employmentType: _employmentType,
        joiningDate: _joiningDateController.text.trim(),
        status: _status,
        leaveType: _leaveType,
        accessPermissions: _selectedPermissions.toList(),
      );

      if (isEdit) {
        await repo.updateEmployee(updatedEmployee);
      } else {
        await repo.addEmployee(updatedEmployee);
      }

      ref.invalidate(employeesProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save employee: $e')),
        );
      }
    }
  }

  Widget _buildFieldPair({
    required Widget child1,
    required Widget child2,
    required bool isMobile,
  }) {
    if (isMobile) {
      return Column(
        children: [
          child1,
          const SizedBox(height: 12),
          child2,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: child1),
        const SizedBox(width: 12),
        Expanded(child: child2),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.employee != null;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    final employmentTypeItems = {
      'Full-Time',
      'Part-Time',
      'Contract',
      'Intern',
      if (_employmentType.isNotEmpty) _employmentType,
    }.toList();

    final statusItems = {
      'Active',
      'Inactive',
      'Onboarding',
      'Terminated',
      'Accepted',
      'Pending',
      'Rejected',
      if (_status.isNotEmpty) _status,
    }.toList();

    return AlertDialog(
      title: Row(
        children: [
          Icon(isEdit ? Icons.edit : Icons.person_add, color: AppColors.active),
          const SizedBox(width: 8),
          Text(
            isEdit ? 'Edit Employee Details' : 'Add Employee Manually',
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
        width: (screenWidth * 0.9).clamp(280.0, 640.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFieldPair(
                  isMobile: isMobile,
                  child1: TextFormField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'First Name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  child2: TextFormField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Last Name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(height: 12),
                _buildFieldPair(
                  isMobile: isMobile,
                  child1: TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email Address *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  child2: TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(height: 12),
                _buildFieldPair(
                  isMobile: isMobile,
                  child1: TextFormField(
                    controller: _orgController,
                    decoration: const InputDecoration(
                      labelText: 'Organization Name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  child2: DropdownButtonFormField<String>(
                    initialValue: {
                      ...Employee.departmentOptions,
                      if (_deptController.text.isNotEmpty) _deptController.text,
                    }.contains(_deptController.text)
                        ? _deptController.text
                        : Employee.departmentOptions.first,
                    decoration: const InputDecoration(
                      labelText: 'Department *',
                      border: OutlineInputBorder(),
                    ),
                    items: {
                      ...Employee.departmentOptions,
                      if (_deptController.text.isNotEmpty) _deptController.text,
                    }.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _deptController.text = val);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _buildFieldPair(
                  isMobile: isMobile,
                  child1: DropdownButtonFormField<String>(
                    initialValue: {
                      ...Employee.designationOptions,
                      if (_designationController.text.isNotEmpty) _designationController.text,
                    }.contains(_designationController.text)
                        ? _designationController.text
                        : Employee.designationOptions.first,
                    decoration: const InputDecoration(
                      labelText: 'Designation *',
                      border: OutlineInputBorder(),
                    ),
                    items: {
                      ...Employee.designationOptions,
                      if (_designationController.text.isNotEmpty) _designationController.text,
                    }.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _designationController.text = val);
                    },
                  ),
                  child2: TextFormField(
                    controller: _joiningDateController,
                    decoration: const InputDecoration(
                      labelText: 'Joining Date (YYYY-MM-DD)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildFieldPair(
                  isMobile: isMobile,
                  child1: DropdownButtonFormField<String>(
                    initialValue: employmentTypeItems.contains(_employmentType)
                        ? _employmentType
                        : employmentTypeItems.first,
                    decoration: const InputDecoration(
                      labelText: 'Employment Type',
                      border: OutlineInputBorder(),
                    ),
                    items: employmentTypeItems
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _employmentType = val);
                    },
                  ),
                  child2: DropdownButtonFormField<String>(
                    initialValue: statusItems.contains(_status)
                        ? _status
                        : statusItems.first,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: statusItems
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _status = val);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: Employee.leaveTypeOptions.contains(_leaveType)
                      ? _leaveType
                      : Employee.leaveTypeOptions.first,
                  decoration: const InputDecoration(
                    labelText: 'Leave Type',
                    border: OutlineInputBorder(),
                  ),
                  items: Employee.leaveTypeOptions
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _leaveType = val);
                  },
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.security, size: 20, color: AppColors.active),
                    const SizedBox(width: 8),
                    const Text(
                      'Access Permissions',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedPermissions.length ==
                              Employee.allSidebarPermissions.length) {
                            _selectedPermissions.clear();
                          } else {
                            _selectedPermissions =
                                Set<String>.from(Employee.allSidebarPermissions);
                          }
                        });
                      },
                      child: Text(
                        _selectedPermissions.length ==
                                Employee.allSidebarPermissions.length
                            ? 'Deselect All'
                            : 'Select All',
                        style: const TextStyle(color: AppColors.active),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Select sidebar menu options accessible by this employee upon login:',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: Employee.sidebarPermissionsByCategory.entries.map((entry) {
                      final categoryName = entry.key;
                      final categoryPermissions = entry.value;
                      final isFirst = entry.key == Employee.sidebarPermissionsByCategory.keys.first;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(
                              top: isFirst ? 0.0 : 12.0,
                              bottom: 6.0,
                            ),
                            child: Text(
                              categoryName,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF667085),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: categoryPermissions.map((permission) {
                              final isSelected = _selectedPermissions.contains(permission);
                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedPermissions.remove(permission);
                                    } else {
                                      _selectedPermissions.add(permission);
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  width: isMobile ? double.infinity : 260,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: Checkbox(
                                          value: isSelected,
                                          activeColor: AppColors.active,
                                          onChanged: (val) {
                                            setState(() {
                                              if (val == true) {
                                                _selectedPermissions.add(permission);
                                              } else {
                                                _selectedPermissions.remove(permission);
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          permission,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.active),
          onPressed: _isSaving ? null : _save,
          child: Text(_isSaving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}
