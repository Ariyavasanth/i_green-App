import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/employee.dart';
import '../../providers/employee_providers.dart';
import '../../../organization/providers/organization_providers.dart';

import '../employee_registration_page.dart';
import '../../../../core/widgets/app_searchable_dropdown.dart';

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
  String _userType = 'EMPLOYEE';
  String _leaveType = 'As Needed';
  String _leaveAllocationFrequency = 'Monthly';
  String _bloodGroup = 'B+';
  String _bloodGroupDocFileName = 'No file chosen';
  bool _hasCriminalCases = false;
  late final TextEditingController _criminalCaseDetailsController;
  String _workScheduleType = 'Fixed Schedule';
  late final TextEditingController _requiredWorkingHoursController;
  late final TextEditingController _inTimeController;
  late final TextEditingController _outTimeController;
  late final TextEditingController _allowedLeavesController;
  late final TextEditingController _leaveEffectiveDateController;
  bool _isSaving = false;
  late Set<String> _selectedPermissions;
  String _phoneCountryCode = '+91';

  (String, String) _parsePhoneAndCountryCode(String fullPhone) {
    final trimmed = fullPhone.trim();
    if (trimmed.isEmpty) return ('+91', '');
    
    final sortedCodes = EmployeeRegistrationPage.allWorldCountryCodes.map((e) => e['code']!).toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final code in sortedCodes) {
      if (trimmed.startsWith(code)) {
        return (code, trimmed.substring(code.length).trim());
      }
    }
    if (trimmed.startsWith('+')) {
      final spaceIdx = trimmed.indexOf(' ');
      if (spaceIdx > 0) {
        return (trimmed.substring(0, spaceIdx), trimmed.substring(spaceIdx + 1).trim());
      }
    }
    return ('+91', trimmed);
  }

  String _formatPhoneWithCountryCode(String countryCode, String phoneDigits) {
    final digits = phoneDigits.trim();
    if (digits.isEmpty) return '';
    if (digits.startsWith('+')) return digits;
    return '$countryCode $digits';
  }

  @override
  void initState() {
    super.initState();
    final emp = widget.employee;
    _empIdController = TextEditingController(text: emp?.employeeId ?? '');
    _firstNameController = TextEditingController(text: emp?.firstName ?? '');
    _lastNameController = TextEditingController(text: emp?.lastName ?? '');
    _emailController = TextEditingController(text: emp?.emailAddress ?? '');
    final (cc, phoneNum) = _parsePhoneAndCountryCode(emp?.phoneNumber ?? '');
    _phoneCountryCode = cc;
    _phoneController = TextEditingController(text: phoneNum);
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
    _leaveAllocationFrequency = emp?.leaveAllocationFrequency ?? 'Monthly';
    _inTimeController = TextEditingController(text: emp?.inTime ?? '');
    _outTimeController = TextEditingController(text: emp?.outTime ?? '');
    _allowedLeavesController = TextEditingController(text: emp?.allowedLeaves.toString() ?? '1.0');
    _leaveEffectiveDateController = TextEditingController(text: emp?.effectiveDate ?? '');
    _bloodGroup = (emp?.bloodGroup.isNotEmpty ?? false) ? emp!.bloodGroup : 'B+';
    _bloodGroupDocFileName = (emp?.bloodGroupReport.isNotEmpty ?? false) ? emp!.bloodGroupReport : 'No file chosen';
    _hasCriminalCases = emp?.hasCriminalCases ?? false;
    _criminalCaseDetailsController = TextEditingController(text: emp?.criminalCaseDetails ?? '');

    if (emp != null) {
      if (emp.isDynamicEmployee || (emp.inTime.isEmpty && emp.outTime.isEmpty && !emp.isStaticEmployee)) {
        _workScheduleType = 'Flexible Schedule';
      } else {
        _workScheduleType = 'Fixed Schedule';
      }
      _requiredWorkingHoursController = TextEditingController(
        text: '${emp.requiredWorkingHours > 0 ? emp.requiredWorkingHours.toStringAsFixed(0) : "9"} Hours',
      );
      _employmentType = emp.employmentType.isEmpty ? 'Full-Time' : emp.employmentType;
      _status = emp.status.isEmpty ? 'Active' : emp.status;
      _userType = emp.userType.isEmpty ? 'EMPLOYEE' : emp.userType;
      _leaveType = (emp.leaveType.isEmpty || emp.leaveType == 'Once a Month')
          ? (emp.leaveType == 'Once a Month' ? 'Manual Allocation' : 'As Needed')
          : emp.leaveType;
      _selectedPermissions = emp.accessPermissions.isNotEmpty
          ? Set<String>.from(emp.accessPermissions)
          : Set<String>.from(Employee.allSidebarPermissions);
    } else {
      _workScheduleType = 'Fixed Schedule';
      _requiredWorkingHoursController = TextEditingController(text: '9 Hours');
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
    _requiredWorkingHoursController.dispose();
    _inTimeController.dispose();
    _outTimeController.dispose();
    _allowedLeavesController.dispose();
    _leaveEffectiveDateController.dispose();
    _criminalCaseDetailsController.dispose();
    super.dispose();
  }

  Future<void> _pickBloodGroupDocFile() async {
    try {
      final res = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      );
      if (res != null && res.files.single.name.isNotEmpty) {
        setState(() {
          _bloodGroupDocFileName = res.files.single.name;
        });
      }
    } catch (_) {}
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
                phoneNumber: _formatPhoneWithCountryCode(_phoneCountryCode, _phoneController.text),
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
        phoneNumber: _formatPhoneWithCountryCode(_phoneCountryCode, _phoneController.text),
        organizationName: _orgController.text.trim(),
        department: _deptController.text.trim(),
        designation: _designationController.text.trim(),
        employmentType: _employmentType,
        joiningDate: _joiningDateController.text.trim(),
        status: _status,
        userType: _userType,
        bloodGroup: _bloodGroup,
        bloodGroupReport: _bloodGroupDocFileName,
        hasCriminalCases: _hasCriminalCases,
        criminalCaseDetails: _hasCriminalCases ? _criminalCaseDetailsController.text.trim() : '',
        leaveType: _leaveType,
        leaveAllocationFrequency: _leaveType == 'Manual Allocation' ? _leaveAllocationFrequency : '',
        inTime: _workScheduleType == 'Fixed Schedule' ? _inTimeController.text.trim() : '',
        outTime: _workScheduleType == 'Fixed Schedule' ? _outTimeController.text.trim() : '',
        requiredWorkingHours: double.tryParse(_requiredWorkingHoursController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 9.0,
        allowedLeaves: _leaveType == 'Manual Allocation' ? (double.tryParse(_allowedLeavesController.text.trim()) ?? 0.0) : 0.0,
        effectiveDate: _leaveEffectiveDateController.text.trim(),
        accessPermissions: _selectedPermissions.toList(),
        isStaticEmployee: _workScheduleType == 'Fixed Schedule',
        isDynamicEmployee: _workScheduleType == 'Flexible Schedule',
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
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s.\-']"))],
                    onChanged: (val) {
                      final sanitized = val.replaceAll(RegExp(r"[^a-zA-Z\s.\-']"), '');
                      if (sanitized != val) {
                        _firstNameController.value = _firstNameController.value.copyWith(
                          text: sanitized,
                          selection: TextSelection.collapsed(offset: sanitized.length),
                        );
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'First Name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (RegExp(r'[0-9]').hasMatch(v)) return 'Numbers not allowed';
                      if (RegExp(r"[^a-zA-Z\s.\-']").hasMatch(v)) return 'Special symbols not allowed';
                      return null;
                    },
                  ),
                  child2: TextFormField(
                    controller: _lastNameController,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s.\-']"))],
                    onChanged: (val) {
                      final sanitized = val.replaceAll(RegExp(r"[^a-zA-Z\s.\-']"), '');
                      if (sanitized != val) {
                        _lastNameController.value = _lastNameController.value.copyWith(
                          text: sanitized,
                          selection: TextSelection.collapsed(offset: sanitized.length),
                        );
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Last Name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (RegExp(r'[0-9]').hasMatch(v)) return 'Numbers not allowed';
                      if (RegExp(r"[^a-zA-Z\s.\-']").hasMatch(v)) return 'Special symbols not allowed';
                      return null;
                    },
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
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    onChanged: (val) {
                      final sanitized = val.replaceAll(RegExp(r'[^0-9]'), '');
                      if (sanitized != val) {
                        _phoneController.value = _phoneController.value.copyWith(
                          text: sanitized,
                          selection: TextSelection.collapsed(offset: sanitized.length),
                        );
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Phone Number *',
                      border: const OutlineInputBorder(),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                      prefixIcon: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.only(left: 8, right: 4),
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(color: Color(0xFFD0D5DD), width: 0.8),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: EmployeeRegistrationPage.allWorldCountryCodes.any((c) => c['code'] == _phoneCountryCode)
                                ? _phoneCountryCode
                                : '+91',
                            isDense: true,
                            menuMaxHeight: 300,
                            style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
                            icon: const Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.black54),
                            items: EmployeeRegistrationPage.allWorldCountryCodes.map((item) {
                              return DropdownMenuItem<String>(
                                value: item['code'],
                                child: Text(
                                  item['label']!,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _phoneCountryCode = val);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (RegExp(r'[^0-9]').hasMatch(v.trim())) {
                        return 'Alphabets/symbols are not allowed. Numbers only.';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _buildFieldPair(
                  isMobile: isMobile,
                  child1: DropdownButtonFormField<String>(
                    initialValue: ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-', 'A1+', 'A1-', 'A2+', 'A2-', 'A1B+', 'A1B-', 'A2B+', 'A2B-', 'Bombay Blood Group (hh)', "Other / Don't Know"].contains(_bloodGroup)
                        ? _bloodGroup
                        : 'B+',
                    decoration: const InputDecoration(
                      labelText: 'Blood Group',
                      border: OutlineInputBorder(),
                    ),
                    items: ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-', 'A1+', 'A1-', 'A2+', 'A2-', 'A1B+', 'A1B-', 'A2B+', 'A2B-', 'Bombay Blood Group (hh)', "Other / Don't Know"]
                        .map((bg) => DropdownMenuItem(value: bg, child: Text(bg)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _bloodGroup = val);
                    },
                  ),
                  child2: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Blood Group Certificate / Test Report Document',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF2F4F7),
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                                side: const BorderSide(color: Color(0xFFD0D5DD)),
                              ),
                            ),
                            onPressed: _pickBloodGroupDocFile,
                            child: const Text('Choose file', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _bloodGroupDocFileName,
                              style: TextStyle(
                                fontSize: 11,
                                color: _bloodGroupDocFileName == 'No file chosen' ? Colors.black54 : AppColors.active,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
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
                  child2: Builder(
                    builder: (context) {
                      final dbDepts = ref.watch(departmentsProvider).valueOrNull ?? [];
                      final deptItems = {
                        ...dbDepts.map((d) => d.departmentName),
                        ...Employee.departmentOptions,
                        if (_deptController.text.isNotEmpty) _deptController.text,
                      }.where((s) => s.isNotEmpty).toList();

                      return AppSearchableDropdown<String>(
                        label: 'Department *',
                        value: deptItems.contains(_deptController.text)
                            ? _deptController.text
                            : (deptItems.isNotEmpty ? deptItems.first : null),
                        items: deptItems,
                        searchHint: 'Search department...',
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _deptController.text = val;
                              _designationController.text = '';
                            });
                          }
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _buildFieldPair(
                  isMobile: isMobile,
                  child1: Builder(
                    builder: (context) {
                      final currentDept = _deptController.text.trim();
                      final desigsAsync = ref.watch(designationsProvider(currentDept.isEmpty ? null : currentDept));
                      final desigItems = desigsAsync.valueOrNull?.map((d) => d.designationName).where((s) => s.isNotEmpty).toSet().toList() ?? [];
                      if (desigItems.isEmpty) {
                        desigItems.addAll(Employee.designationOptions);
                      }
                      if (_designationController.text.isNotEmpty && !desigItems.contains(_designationController.text)) {
                        desigItems.insert(0, _designationController.text);
                      }
                      if (_designationController.text.isEmpty && desigItems.isNotEmpty) {
                        _designationController.text = desigItems.first;
                      }

                      return AppSearchableDropdown<String>(
                        label: 'Designation *',
                        value: desigItems.contains(_designationController.text)
                            ? _designationController.text
                            : (desigItems.isNotEmpty ? desigItems.first : null),
                        items: desigItems,
                        searchHint: 'Search designation...',
                        onChanged: (val) {
                          if (val != null) setState(() => _designationController.text = val);
                        },
                      );
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
                  child1: AppSearchableDropdown<String>(
                    label: 'User Role *',
                    value: {
                      'SUPER_ADMIN', 'ADMIN', 'EMPLOYEE', 'HR', 'MANAGER',
                      if (_userType.isNotEmpty) _userType,
                    }.contains(_userType)
                        ? _userType
                        : 'EMPLOYEE',
                    items: const ['SUPER_ADMIN', 'ADMIN', 'EMPLOYEE', 'HR', 'MANAGER'],
                    searchHint: 'Search role...',
                    onChanged: (val) {
                      if (val != null) setState(() => _userType = val);
                    },
                  ),
                  child2: AppSearchableDropdown<String>(
                    label: 'Employment Type',
                    value: employmentTypeItems.contains(_employmentType)
                        ? _employmentType
                        : employmentTypeItems.first,
                    items: employmentTypeItems,
                    searchHint: 'Search employment type...',
                    onChanged: (val) {
                      if (val != null) setState(() => _employmentType = val);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _buildFieldPair(
                  isMobile: isMobile,
                  child1: AppSearchableDropdown<String>(
                    label: 'Status',
                    value: statusItems.contains(_status)
                        ? _status
                        : statusItems.first,
                    items: statusItems,
                    searchHint: 'Search status...',
                    onChanged: (val) {
                      if (val != null) setState(() => _status = val);
                    },
                  ),
                  child2: const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
                _buildFieldPair(
                  isMobile: isMobile,
                  child1: AppSearchableDropdown<String>(
                    label: 'Leave Type',
                    value: ['As Needed', 'Manual Allocation', 'No Leave'].contains(_leaveType)
                        ? _leaveType
                        : 'As Needed',
                    items: const ['As Needed', 'Manual Allocation', 'No Leave'],
                    searchHint: 'Search leave type...',
                    onChanged: (val) {
                      if (val != null) setState(() => _leaveType = val);
                    },
                  ),
                  child2: _leaveType == 'Manual Allocation'
                      ? AppSearchableDropdown<String>(
                          label: 'Allocation Frequency',
                          value: _leaveAllocationFrequency,
                          items: const ['Monthly', 'Quarterly', 'Yearly'],
                          searchHint: 'Search frequency...',
                          onChanged: (val) {
                            if (val != null) setState(() => _leaveAllocationFrequency = val);
                          },
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
                _buildFieldPair(
                  isMobile: isMobile,
                  child1: AppSearchableDropdown<String>(
                    label: 'Work Schedule Type',
                    value: _workScheduleType,
                    items: const ['Fixed Schedule', 'Flexible Schedule'],
                    searchHint: 'Search schedule type...',
                    onChanged: (val) {
                      if (val != null) setState(() => _workScheduleType = val);
                    },
                  ),
                  child2: _workScheduleType == 'Fixed Schedule'
                      ? TextFormField(
                          controller: _inTimeController,
                          decoration: const InputDecoration(
                            labelText: 'In Time',
                            hintText: '09:00 AM',
                            border: OutlineInputBorder(),
                          ),
                        )
                      : TextFormField(
                          controller: _requiredWorkingHoursController,
                          decoration: const InputDecoration(
                            labelText: 'Required Working Hours',
                            hintText: 'e.g. 9 Hours',
                            border: OutlineInputBorder(),
                          ),
                        ),
                ),
                if (_workScheduleType == 'Fixed Schedule') ...[
                  const SizedBox(height: 12),
                  _buildFieldPair(
                    isMobile: isMobile,
                    child1: TextFormField(
                      controller: _outTimeController,
                      decoration: const InputDecoration(
                        labelText: 'Out Time',
                        hintText: '06:00 PM',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    child2: const SizedBox.shrink(),
                  ),
                ],
                const SizedBox(height: 12),
                _buildFieldPair(
                  isMobile: isMobile,
                  child1: _leaveType == 'Manual Allocation'
                      ? TextFormField(
                          controller: _allowedLeavesController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Allowed Leaves',
                            border: OutlineInputBorder(),
                          ),
                        )
                      : TextFormField(
                          controller: _leaveEffectiveDateController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Effective Date',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              _leaveEffectiveDateController.text =
                                  '${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}';
                            }
                          },
                        ),
                  child2: _leaveType == 'Manual Allocation'
                      ? TextFormField(
                          controller: _leaveEffectiveDateController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Effective Date',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              _leaveEffectiveDateController.text =
                                  '${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}';
                            }
                          },
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _hasCriminalCases,
                            activeColor: AppColors.active,
                            onChanged: (val) {
                              setState(() => _hasCriminalCases = val ?? false);
                            },
                          ),
                          const Expanded(
                            child: Text(
                              'Does the employee have any criminal cases or legal history?',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      if (_hasCriminalCases) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _criminalCaseDetailsController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Criminal Case Details / Description *',
                            hintText: 'Enter details about the criminal case...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ],
                  ),
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
