import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../organization/domain/business_unit.dart';
import '../../../organization/domain/department.dart';
import '../../../organization/domain/designation.dart';
import '../../../organization/domain/location.dart';
import '../../../organization/domain/organization.dart';
import '../../../organization/providers/organization_providers.dart';
import '../../domain/employee.dart';
import '../../domain/registration_link.dart';
import '../../providers/employee_providers.dart';

class CandidateConversionDialog extends ConsumerStatefulWidget {
  const CandidateConversionDialog({
    required this.link,
    this.candidateEmployee,
    super.key,
  });

  final RegistrationLink link;
  final Employee? candidateEmployee;

  @override
  ConsumerState<CandidateConversionDialog> createState() =>
      _CandidateConversionDialogState();
}

class _CandidateConversionDialogState
    extends ConsumerState<CandidateConversionDialog> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedOrg;
  String? _selectedBU;
  String? _selectedLocation;
  String? _selectedDepartment;
  String? _selectedDesignation;
  String? _selectedReportingManagerId;
  String _selectedReportingManagerName = '';
  String _selectedWorkSchedule = 'Fixed Schedule';
  final _joiningDateController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final todayStr = DateFormat('dd-MMM-yyyy').format(DateTime.now());
    _joiningDateController.text = widget.candidateEmployee?.joiningDate.isNotEmpty == true
        ? widget.candidateEmployee!.joiningDate
        : todayStr;

    if (widget.candidateEmployee != null) {
      final emp = widget.candidateEmployee!;
      if (emp.organizationName.isNotEmpty) _selectedOrg = emp.organizationName;
      if (emp.businessUnit.isNotEmpty) _selectedBU = emp.businessUnit;
      if (emp.workLocation.isNotEmpty) _selectedLocation = emp.workLocation;
      if (emp.department.isNotEmpty) _selectedDepartment = emp.department;
      if (emp.designation.isNotEmpty) _selectedDesignation = emp.designation;
      if (emp.reportingManagerId.isNotEmpty) _selectedReportingManagerId = emp.reportingManagerId;
      if (emp.reportingManager.isNotEmpty) _selectedReportingManagerName = emp.reportingManager;
      if (emp.workScheduleType.isNotEmpty) _selectedWorkSchedule = emp.workScheduleType;
    }
  }

  @override
  void dispose() {
    _joiningDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final candidateName = widget.candidateEmployee?.fullName.isNotEmpty == true
        ? widget.candidateEmployee!.fullName
        : (widget.link.employeeName.isNotEmpty ? widget.link.employeeName : widget.link.linkId);
    final candidateId = widget.candidateEmployee?.employeeId.isNotEmpty == true
        ? widget.candidateEmployee!.employeeId
        : (widget.link.employeeId.isNotEmpty ? widget.link.employeeId : widget.link.linkId);

    final orgsAsync = ref.watch(organizationsProvider);
    final busAsync = ref.watch(businessUnitsProvider(_selectedOrg));
    final locsAsync = ref.watch(locationsProvider(LocationFilter(organizationName: _selectedOrg, businessUnitName: _selectedBU)));
    final deptsAsync = ref.watch(filteredDepartmentsProvider(DepartmentFilter(organizationName: _selectedOrg, businessUnitName: _selectedBU, workLocation: _selectedLocation)));
    final desigsAsync = ref.watch(designationsProvider(_selectedDepartment));
    final employeesAsync = ref.watch(allEmployeesProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: 520,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'EMPLOYEE ORGANIZATIONAL ASSIGNMENT',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Color(0xFF101828),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Candidate Info Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE9ECEF)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.active,
                      child: Text(
                        candidateName.isNotEmpty ? candidateName[0].toUpperCase() : 'C',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            candidateName,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Candidate ID: $candidateId',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Organization Dropdown
                      orgsAsync.when(
                        data: (orgList) {
                          if (_selectedOrg == null && orgList.isNotEmpty) {
                            _selectedOrg = orgList.first.name;
                          }
                          return _buildDropdownField<String>(
                            label: 'Organization *',
                            value: _selectedOrg,
                            items: orgList.map((o) => DropdownMenuItem(value: o.name, child: Text(o.name, style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedOrg = val;
                                _selectedBU = null;
                                _selectedLocation = null;
                                _selectedDepartment = null;
                                _selectedDesignation = null;
                                _selectedReportingManagerId = null;
                              });
                            },
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const Text('Failed to load organizations', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                      const SizedBox(height: 12),

                      // Business Unit Dropdown
                      busAsync.when(
                        data: (buList) {
                          return _buildDropdownField<String>(
                            label: 'Business Unit *',
                            value: buList.any((b) => b.unitName == _selectedBU) ? _selectedBU : null,
                            hint: 'Select Business Unit...',
                            items: buList.map((b) => DropdownMenuItem(value: b.unitName, child: Text(b.unitName, style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedBU = val;
                                _selectedLocation = null;
                                _selectedDepartment = null;
                                _selectedDesignation = null;
                                _selectedReportingManagerId = null;
                              });
                            },
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const SizedBox(),
                      ),
                      const SizedBox(height: 12),

                      // Location Dropdown
                      locsAsync.when(
                        data: (locList) {
                          return _buildDropdownField<String>(
                            label: 'Work Location *',
                            value: locList.any((l) => l.locationName == _selectedLocation) ? _selectedLocation : null,
                            hint: 'Select Work Location...',
                            items: locList.map((l) => DropdownMenuItem(value: l.locationName, child: Text(l.locationName, style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedLocation = val;
                                _selectedDepartment = null;
                                _selectedDesignation = null;
                                _selectedReportingManagerId = null;
                              });
                            },
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const SizedBox(),
                      ),
                      const SizedBox(height: 12),

                      // Department Dropdown
                      deptsAsync.when(
                        data: (deptList) {
                          return _buildDropdownField<String>(
                            label: 'Department *',
                            value: deptList.any((d) => d.departmentName == _selectedDepartment) ? _selectedDepartment : null,
                            hint: 'Select Department...',
                            items: deptList.map((d) => DropdownMenuItem(value: d.departmentName, child: Text(d.departmentName, style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedDepartment = val;
                                _selectedDesignation = null;
                                _selectedReportingManagerId = null;
                              });
                            },
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const SizedBox(),
                      ),
                      const SizedBox(height: 12),

                      // Designation Dropdown
                      desigsAsync.when(
                        data: (desigList) {
                          return _buildDropdownField<String>(
                            label: 'Designation *',
                            value: desigList.any((d) => d.designationName == _selectedDesignation) ? _selectedDesignation : null,
                            hint: 'Select Designation...',
                            items: desigList.map((d) => DropdownMenuItem(
                              value: d.designationName,
                              child: Text('${d.designationName} (${d.hierarchyLevel.label})', style: const TextStyle(fontSize: 13)),
                            )).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedDesignation = val;
                                _selectedReportingManagerId = null;
                              });
                            },
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const SizedBox(),
                      ),
                      const SizedBox(height: 12),

                      // Reporting Manager Dropdown
                      employeesAsync.when(
                        data: (allEmps) {
                          final eligibleManagers = allEmps.where((emp) {
                            if (_selectedOrg != null && _selectedOrg!.isNotEmpty && emp.organizationName.isNotEmpty && emp.organizationName != _selectedOrg) {
                              return false;
                            }
                            return true;
                          }).toList();

                          return _buildDropdownField<String>(
                            label: 'Reporting Manager *',
                            value: eligibleManagers.any((e) => e.employeeId == _selectedReportingManagerId)
                                ? _selectedReportingManagerId
                                : null,
                            hint: 'Select Reporting Manager...',
                            items: eligibleManagers.map((emp) {
                              final label = '${emp.fullName} — ${emp.designation.isNotEmpty ? emp.designation : "Manager"}';
                              return DropdownMenuItem(
                                value: emp.employeeId,
                                child: Text(label, style: const TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              final mgr = eligibleManagers.firstWhere((e) => e.employeeId == val, orElse: () => eligibleManagers.first);
                              setState(() {
                                _selectedReportingManagerId = val;
                                _selectedReportingManagerName = mgr.fullName;
                              });
                            },
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const SizedBox(),
                      ),
                      const SizedBox(height: 12),

                      // Work Schedule
                      _buildDropdownField<String>(
                        label: 'Work Schedule *',
                        value: _selectedWorkSchedule,
                        items: ['Fixed Schedule', 'General Shift (09:00 AM - 06:00 PM)', 'Flexible Schedule']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedWorkSchedule = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Joining Date
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Joining Date *',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _joiningDateController,
                            readOnly: true,
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Select Joining Date...',
                              suffixIcon: const Icon(Icons.calendar_today, size: 16),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                setState(() {
                                  _joiningDateController.text = DateFormat('dd-MMM-yyyy').format(picked);
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: Colors.black87)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.active,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                    onPressed: _isSubmitting ? null : _submitConversion,
                    child: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Create Employee', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    String? hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<T>(
          value: value,
          hint: hint != null ? Text(hint, style: const TextStyle(fontSize: 13)) : null,
          isDense: true,
          decoration: InputDecoration(
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Future<void> _submitConversion() async {
    if (_selectedOrg == null || _selectedDepartment == null || _selectedDesignation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Organization, Department, and Designation.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(employeeRepositoryProvider);

      // Fetch base employee candidate or construct
      final baseEmp = widget.candidateEmployee ?? Employee(
        id: 0,
        employeeId: widget.link.employeeId.isNotEmpty ? widget.link.employeeId : 'EMP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        firstName: widget.link.employeeName.isNotEmpty ? widget.link.employeeName : 'Candidate',
        lastName: '',
        emailAddress: widget.candidateEmployee?.emailAddress ?? '',
        phoneNumber: widget.candidateEmployee?.phoneNumber ?? '',
        gender: 'Male',
        dob: '',
        organizationName: _selectedOrg ?? '',
        department: _selectedDepartment ?? '',
        designation: _selectedDesignation ?? '',
        employmentType: 'Full-Time',
        joiningDate: _joiningDateController.text,
        status: 'Active',
      );

      final updatedEmployee = baseEmp.copyWith(
        organizationName: _selectedOrg ?? baseEmp.organizationName,
        businessUnit: _selectedBU ?? baseEmp.businessUnit,
        workLocation: _selectedLocation ?? baseEmp.workLocation,
        department: _selectedDepartment ?? baseEmp.department,
        designation: _selectedDesignation ?? baseEmp.designation,
        reportingManager: _selectedReportingManagerName.isNotEmpty ? _selectedReportingManagerName : baseEmp.reportingManager,
        reportingManagerId: _selectedReportingManagerId ?? baseEmp.reportingManagerId,
        workScheduleType: _selectedWorkSchedule,
        joiningDate: _joiningDateController.text,
        status: 'Active',
      );

      if (baseEmp.id != 0) {
        await repo.updateEmployee(updatedEmployee);
      } else {
        await repo.addEmployee(updatedEmployee);
      }

      // Update link status
      if (widget.link.id != 0 && widget.link.linkId.isNotEmpty) {
        await repo.updateRegistrationLinkStatus(
          linkId: widget.link.linkId,
          linkStatus: 'Converted',
        );
      }

      ref.invalidate(allEmployeesProvider);
      ref.invalidate(registrationLinksProvider);
      ref.invalidate(candidateResponsesProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully created Employee profile for ${updatedEmployee.fullName}!'),
            backgroundColor: const Color(0xFF28A745),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error converting candidate: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
