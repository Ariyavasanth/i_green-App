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
  bool _isSaving = false;

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
    _deptController = TextEditingController(text: emp?.department ?? '');
    _designationController = TextEditingController(text: emp?.designation ?? '');
    _joiningDateController = TextEditingController(
      text: emp?.joiningDate ?? DateTime.now().toString().split(' ')[0],
    );
    if (emp != null) {
      _employmentType = emp.employmentType.isEmpty ? 'Full-Time' : emp.employmentType;
      _status = emp.status.isEmpty ? 'Active' : emp.status;
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
        width: (screenWidth * 0.9).clamp(280.0, 580.0),
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
                  child2: TextFormField(
                    controller: _deptController,
                    decoration: const InputDecoration(
                      labelText: 'Department *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(height: 12),
                _buildFieldPair(
                  isMobile: isMobile,
                  child1: TextFormField(
                    controller: _designationController,
                    decoration: const InputDecoration(
                      labelText: 'Designation *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
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
                    initialValue: _employmentType,
                    decoration: const InputDecoration(
                      labelText: 'Employment Type',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Full-Time', 'Part-Time', 'Contract', 'Intern']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _employmentType = val);
                    },
                  ),
                  child2: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Active', 'Inactive', 'Onboarding', 'Terminated']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _status = val);
                    },
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
