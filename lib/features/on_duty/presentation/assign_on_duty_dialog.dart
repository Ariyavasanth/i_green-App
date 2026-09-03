import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../employee/domain/employee.dart';
import '../../employee/providers/employee_providers.dart';
import '../domain/on_duty_assignment.dart';
import '../providers/on_duty_providers.dart';

class AssignOnDutyDialog extends ConsumerStatefulWidget {
  const AssignOnDutyDialog({
    super.key,
    this.preSelectedEmployee,
    this.existingAssignment,
    this.isSelfRequest = false,
  });

  final Employee? preSelectedEmployee;
  final OnDutyAssignment? existingAssignment;
  final bool isSelfRequest;

  @override
  ConsumerState<AssignOnDutyDialog> createState() => _AssignOnDutyDialogState();
}

class _AssignOnDutyDialogState extends ConsumerState<AssignOnDutyDialog> {
  final _formKey = GlobalKey<FormState>();

  Employee? _selectedEmployee;
  String _selectedOdType = 'Customer Visit';
  final _purposeController = TextEditingController();
  final _destinationController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay? _endTime = const TimeOfDay(hour: 16, minute: 0);
  final _notesController = TextEditingController();
  String _afterCompletionOption = 'RETURN_TO_OFFICE';

  bool _isSubmitting = false;

  static const _odTypes = [
    'Customer Visit',
    'Branch Visit',
    'External Meeting',
    'Govt Office',
    'Field Work',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _selectedEmployee = widget.preSelectedEmployee;

    final existing = widget.existingAssignment;
    if (existing != null) {
      _selectedOdType = _odTypes.contains(existing.odType) ? existing.odType : 'Customer Visit';
      _purposeController.text = existing.purpose;
      _destinationController.text = existing.destination;
      _notesController.text = existing.notes;
      _afterCompletionOption = existing.afterCompletionOption;
      _selectedEmployee = Employee.fromMap({
        'id': existing.employeeId,
        'employee_id': existing.employeeId > 0 ? 'EMP-${existing.employeeId.toString().padLeft(3, '0')}' : '',
        'first_name': existing.employeeName,
        'last_name': '',
      });

      try {
        _selectedDate = DateFormat('dd-MM-yyyy').parse(existing.date);
      } catch (_) {}

      try {
        final startParsed = DateFormat('hh:mm a').parse(existing.plannedStartTime);
        _startTime = TimeOfDay(hour: startParsed.hour, minute: startParsed.minute);
      } catch (_) {}

      if (existing.plannedEndTime != null && existing.plannedEndTime!.isNotEmpty) {
        try {
          final endParsed = DateFormat('hh:mm a').parse(existing.plannedEndTime!);
          _endTime = TimeOfDay(hour: endParsed.hour, minute: endParsed.minute);
        } catch (_) {}
      }
    }
  }

  final _searchController = TextEditingController();
  String _employeeSearchQuery = '';

  @override
  void dispose() {
    _purposeController.dispose();
    _destinationController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool _isCandidate(Employee emp) {
    final empIdUpper = emp.employeeId.trim().toUpperCase();
    if (empIdUpper.startsWith('CAN-') ||
        empIdUpper.startsWith('REG-') ||
        empIdUpper.startsWith('PENDING_')) {
      return true;
    }
    final status = emp.status.trim().toLowerCase();
    if (status == 'candidate' ||
        status == 'registration submitted' ||
        status == 'draft') {
      return true;
    }
    return false;
  }

  String _getEmployeeLabel(Employee emp) {
    final name = emp.fullName.trim();
    final empId = emp.employeeId.trim();
    final fallbackId = empId.isNotEmpty ? empId : (emp.id > 0 ? "EMP-${emp.id}" : "EMP");

    final currentEmp = ref.read(currentEmployeeProvider);
    if ((currentEmp != null && emp.id == currentEmp.id) || (widget.preSelectedEmployee != null && emp.id == widget.preSelectedEmployee!.id)) {
      return '$fallbackId (Self)';
    }

    if (name.isNotEmpty) {
      return fallbackId.isNotEmpty ? '$fallbackId - $name' : name;
    }
    if (emp.emailAddress.trim().isNotEmpty) {
      return fallbackId.isNotEmpty ? '$fallbackId - ${emp.emailAddress.trim()}' : emp.emailAddress.trim();
    }
    if (emp.phoneNumber.trim().isNotEmpty) {
      return fallbackId.isNotEmpty ? '$fallbackId - ${emp.phoneNumber.trim()}' : emp.phoneNumber.trim();
    }
    return fallbackId.isNotEmpty ? '$fallbackId - Employee' : 'Employee #${emp.id}';
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
    return DateFormat('hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF9CC70A);
    const darkTextColor = Color(0xFF414A51);

    final employeesAsync = ref.watch(allEmployeesProvider);
    final employees = employeesAsync.valueOrNull ?? employeesAsync.asData?.value ?? [];

    final confirmedEmployees = employees.where((emp) => !_isCandidate(emp)).toList();

    if (widget.preSelectedEmployee != null &&
        !confirmedEmployees.contains(widget.preSelectedEmployee)) {
      confirmedEmployees.insert(0, widget.preSelectedEmployee!);
    }

    final filteredEmployees = confirmedEmployees.where((emp) {
      if (_employeeSearchQuery.isEmpty) return true;
      final q = _employeeSearchQuery.toLowerCase();
      final name = emp.fullName.toLowerCase();
      final empId = emp.employeeId.toLowerCase();
      final phone = emp.phoneNumber.toLowerCase();
      final email = emp.emailAddress.toLowerCase();
      final dept = emp.department.toLowerCase();
      final label = _getEmployeeLabel(emp).toLowerCase();
      return name.contains(q) ||
          empId.contains(q) ||
          phone.contains(q) ||
          email.contains(q) ||
          dept.contains(q) ||
          label.contains(q);
    }).toList();

    if (_selectedEmployee == null && filteredEmployees.isNotEmpty) {
      _selectedEmployee = filteredEmployees.first;
    } else if (_selectedEmployee != null && filteredEmployees.isNotEmpty && !filteredEmployees.contains(_selectedEmployee)) {
      _selectedEmployee = filteredEmployees.first;
    }

    final dateStr = DateFormat('dd-MM-yyyy').format(_selectedDate);
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth * 0.92).clamp(320.0, 520.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: dialogWidth,
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dialog Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.existingAssignment != null
                          ? 'Edit On Duty'
                          : (widget.isSelfRequest ? 'Request On-Duty' : 'Assign On-Duty'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: darkTextColor,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 20, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 8),

                // 1. Select Employee / Self Request Display
                const Text(
                  'Employee *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: darkTextColor),
                ),
                const SizedBox(height: 6),
                if (widget.isSelfRequest && _selectedEmployee != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9CC70A).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF9CC70A).withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person, size: 18, color: Color(0xFF414A51)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getEmployeeLabel(_selectedEmployee!),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF414A51),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Self', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF414A51))),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  InkWell(
                    onTap: () {
                      showDialog<void>(
                        context: context,
                        builder: (ctx) => _EmployeePickerModal(
                          employees: confirmedEmployees,
                          selectedEmployee: _selectedEmployee,
                          getEmployeeLabel: _getEmployeeLabel,
                          onSelected: (emp) {
                            setState(() => _selectedEmployee = emp);
                          },
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _selectedEmployee != null
                                  ? _getEmployeeLabel(_selectedEmployee!)
                                  : 'Select Employee...',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _selectedEmployee != null ? FontWeight.bold : FontWeight.normal,
                                color: _selectedEmployee != null ? darkTextColor : const Color(0xFF94A3B8),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // 2. OD Type
                const Text(
                  'OD Type *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: darkTextColor),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedOdType,
                  isExpanded: true,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                  items: _odTypes.map((type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(
                        type,
                        style: const TextStyle(fontSize: 13, color: darkTextColor),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedOdType = val);
                  },
                ),
                const SizedBox(height: 16),

                // 3. Purpose
                const Text(
                  'Purpose *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: darkTextColor),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _purposeController,
                  decoration: InputDecoration(
                    hintText: 'Customer meeting / Site inspection',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Purpose is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 4. Location / Destination
                const Text(
                  'Location / Destination *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: darkTextColor),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _destinationController,
                  decoration: InputDecoration(
                    hintText: 'ABC Customer, Chennai / Tambaram Site',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Location / Destination is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 5. Date Selector
                const Text(
                  'Date *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: darkTextColor),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: darkTextColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            dateStr,
                            style: const TextStyle(fontSize: 13, color: darkTextColor, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 6. Time Section (Start Time * & End Time *)
                Row(
                  children: [
                    // Start Time
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Start Time *',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: darkTextColor),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _startTime,
                              );
                              if (picked != null) {
                                setState(() => _startTime = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time, size: 16, color: darkTextColor),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _formatTimeOfDay(_startTime),
                                      style: const TextStyle(fontSize: 12.5, color: darkTextColor, fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // End Time *
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'End Time *',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: darkTextColor),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _endTime ?? const TimeOfDay(hour: 16, minute: 0),
                              );
                              if (picked != null) {
                                setState(() => _endTime = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time, size: 16, color: darkTextColor),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _endTime != null ? _formatTimeOfDay(_endTime!) : 'Optional',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: _endTime != null ? darkTextColor : const Color(0xFF94A3B8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 7. After OD Completion Option
                const Text(
                  'After OD Completion',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: darkTextColor),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        title: const Text(
                          'Return to Office',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: darkTextColor),
                        ),
                        subtitle: const Text(
                          'Must return to office GPS location to check out',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        value: 'RETURN_TO_OFFICE',
                        groupValue: _afterCompletionOption,
                        activeColor: primaryColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                        dense: true,
                        onChanged: (val) {
                          if (val != null) setState(() => _afterCompletionOption = val);
                        },
                      ),
                      const Divider(height: 1, indent: 10, endIndent: 10, color: Color(0xFFE2E8F0)),
                      RadioListTile<String>(
                        title: const Text(
                          'Checkout from OD Location',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: darkTextColor),
                        ),
                        subtitle: const Text(
                          'Can check out directly from the OD site',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        value: 'CHECKOUT_FROM_OD',
                        groupValue: _afterCompletionOption,
                        activeColor: primaryColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                        dense: true,
                        onChanged: (val) {
                          if (val != null) setState(() => _afterCompletionOption = val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 8. Notes
                const Text(
                  'Notes',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: darkTextColor),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Meeting details, instructions...',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 9. Balanced Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitAssignment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: darkTextColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: darkTextColor),
                              )
                            : Text(
                                widget.existingAssignment != null
                                    ? 'Update OD'
                                    : (widget.isSelfRequest ? 'Submit OD Request' : 'Assign OD'),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitAssignment() async {
    if (!_formKey.currentState!.validate() || _selectedEmployee == null) return;

    setState(() => _isSubmitting = true);

    try {
      final dateStr = DateFormat('dd-MM-yyyy').format(_selectedDate);
      final startTimeStr = _formatTimeOfDay(_startTime);
      final endTimeStr = _endTime != null ? _formatTimeOfDay(_endTime!) : null;

      final repo = ref.read(onDutyRepositoryProvider);
      final isEditing = widget.existingAssignment != null;

      if (isEditing) {
        final updated = widget.existingAssignment!.copyWith(
          employeeId: _selectedEmployee!.id,
          employeeName: _selectedEmployee!.fullName.trim().isNotEmpty
              ? _selectedEmployee!.fullName
              : _getEmployeeLabel(_selectedEmployee!),
          odType: _selectedOdType,
          purpose: _purposeController.text.trim(),
          destination: _destinationController.text.trim(),
          date: dateStr,
          plannedStartTime: startTimeStr,
          plannedEndTime: endTimeStr,
          notes: _notesController.text.trim(),
          afterCompletionOption: _afterCompletionOption,
        );
        await repo.updateAssignment(updated);
      } else {
        final assignedByVal = widget.isSelfRequest
            ? 'Self (Employee Request)'
            : (widget.preSelectedEmployee != null ? 'Self' : 'Admin');

        final assignment = OnDutyAssignment(
          id: 0,
          employeeId: _selectedEmployee!.id,
          employeeName: _selectedEmployee!.fullName.trim().isNotEmpty
              ? _selectedEmployee!.fullName
              : _getEmployeeLabel(_selectedEmployee!),
          odType: _selectedOdType,
          purpose: _purposeController.text.trim(),
          destination: _destinationController.text.trim(),
          date: dateStr,
          plannedStartTime: startTimeStr,
          plannedEndTime: endTimeStr,
          status: 'ASSIGNED',
          notes: _notesController.text.trim(),
          afterCompletionOption: _afterCompletionOption,
          assignedBy: assignedByVal,
          createdAt: DateTime.now().toIso8601String(),
        );
        await repo.createAssignment(assignment);
      }

      // Invalidate providers
      ref.invalidate(allOnDutyAssignmentsProvider);
      ref.invalidate(activeOnDutyAssignmentProvider(_selectedEmployee!.id));
      ref.invalidate(employeeOnDutyAssignmentsProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing
                ? 'On-Duty updated successfully!'
                : (widget.isSelfRequest ? 'On-Duty request submitted successfully!' : 'On-Duty assigned to ${_getEmployeeLabel(_selectedEmployee!)}!')),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign OD: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _EmployeePickerModal extends StatefulWidget {
  const _EmployeePickerModal({
    required this.employees,
    required this.selectedEmployee,
    required this.getEmployeeLabel,
    required this.onSelected,
  });

  final List<Employee> employees;
  final Employee? selectedEmployee;
  final String Function(Employee emp) getEmployeeLabel;
  final ValueChanged<Employee> onSelected;

  @override
  State<_EmployeePickerModal> createState() => _EmployeePickerModalState();
}

class _EmployeePickerModalState extends State<_EmployeePickerModal> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.employees.where((emp) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      final name = emp.fullName.toLowerCase();
      final empId = emp.employeeId.toLowerCase();
      final phone = emp.phoneNumber.toLowerCase();
      final email = emp.emailAddress.toLowerCase();
      final label = widget.getEmployeeLabel(emp).toLowerCase();
      return name.contains(q) || empId.contains(q) || phone.contains(q) || email.contains(q) || label.contains(q);
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFFF1F5F9),
      child: Container(
        width: 380,
        height: 480,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Employees',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                decoration: InputDecoration(
                  hintText: 'Search employee...',
                  hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF94A3B8)),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18, color: Color(0xFF64748B)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() => _query = val.trim()),
              ),
            ),
            const SizedBox(height: 16),

            // Employee List
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No matching employees found',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final emp = filtered[index];
                        final isSelected = widget.selectedEmployee?.id == emp.id;
                        final label = widget.getEmployeeLabel(emp);

                        return InkWell(
                          onTap: () {
                            widget.onSelected(emp);
                            Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      color: isSelected ? const Color(0xFF9CC70A) : const Color(0xFF334155),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check, size: 20, color: Color(0xFF9CC70A)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
