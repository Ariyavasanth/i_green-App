import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../attendance/providers/attendance_providers.dart';
import '../../employee/domain/employee.dart';
import '../../employee/providers/employee_providers.dart';
import '../../task_management/providers/task_providers.dart';
import '../../time_clocking/providers/clocking_providers.dart';
import '../domain/on_duty_assignment.dart';
import '../domain/on_duty_site.dart';
import '../providers/on_duty_providers.dart';
import 'widgets/add_site_dialog.dart';

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
  DateTime _selectedDate = DateTime.now();
  final _notesController = TextEditingController();
  String _afterCompletionOption = 'RETURN_TO_OFFICE';

  List<OnDutySite> _addedSites = [];
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
      _notesController.text = existing.notes;
      _afterCompletionOption = existing.afterCompletionOption;
      _selectedEmployee = Employee.fromMap({
        'id': existing.employeeId,
        'employee_id': existing.employeeId > 0 ? 'EMP-${existing.employeeId.toString().padLeft(3, '0')}' : '',
        'first_name': existing.employeeName,
        'last_name': '',
      });

      _addedSites = List<OnDutySite>.from(existing.sites);
      if (_addedSites.isEmpty && existing.effectiveDestinationLatitude != null) {
        _addedSites.add(OnDutySite(
          siteId: '1',
          siteName: existing.effectiveDestinationTitle,
          purpose: existing.purpose,
          destination: existing.destination,
          destinationAddress: existing.destinationAddress,
          latitude: existing.effectiveDestinationLatitude,
          longitude: existing.effectiveDestinationLongitude,
          radius: existing.destinationRadius > 0 ? existing.destinationRadius : 100,
        ));
      }

      try {
        _selectedDate = DateFormat('dd-MM-yyyy').parse(existing.date);
      } catch (_) {}
    }
  }

  final _searchController = TextEditingController();
  String _employeeSearchQuery = '';

  @override
  void dispose() {
    _purposeController.dispose();
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

  Future<Position?> _getGpsPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } catch (_) {
      return null;
    }
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
    final dialogWidth = (screenWidth * 0.94).clamp(340.0, 560.0);

    final isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) == DateFormat('yyyy-MM-dd').format(DateTime.now());
    final isImmediateStartAction = widget.isSelfRequest && isToday && widget.existingAssignment == null;

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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.pin_drop_outlined, color: darkTextColor, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          widget.existingAssignment != null
                              ? 'Edit On Duty'
                              : (widget.isSelfRequest ? 'Start On-Duty' : 'Assign On-Duty'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: darkTextColor,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 20, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 6),

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
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: primaryColor.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person, size: 18, color: darkTextColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getEmployeeLabel(_selectedEmployee!),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: darkTextColor,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Self', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: darkTextColor)),
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

                // 3. Overall Purpose
                const Text(
                  'Purpose *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: darkTextColor),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _purposeController,
                  decoration: InputDecoration(
                    hintText: 'Customer meeting / Site inspection / Project review',
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

                // 4. Added Sites Section (+ Add Site)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Added Sites *',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: darkTextColor),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final newSite = await showDialog<OnDutySite>(
                          context: context,
                          builder: (ctx) => AddSiteDialog(siteNumber: _addedSites.length + 1),
                        );
                        if (newSite != null) {
                          setState(() {
                            _addedSites.add(newSite);
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: darkTextColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add_location_alt_rounded, size: 16),
                      label: const Text('+ Add Site', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_addedSites.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.add_location_alt_outlined, size: 32, color: Color(0xFF94A3B8)),
                        SizedBox(height: 6),
                        Text(
                          'No sites added yet.',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Click "+ Add Site" above to add visit destinations.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _addedSites.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, index) {
                      final site = _addedSites[index];
                      final isFirst = index == 0;
                      final isLocked = !isFirst && _addedSites[index - 1].isPending;

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isLocked ? Colors.grey.shade50 : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isLocked ? Colors.grey.shade300 : primaryColor.withValues(alpha: 0.6),
                            width: isLocked ? 1.0 : 1.5,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isLocked ? Colors.grey.shade300 : primaryColor,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isLocked ? Colors.grey.shade700 : darkTextColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          site.effectiveName,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isLocked ? Colors.grey.shade600 : darkTextColor,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: site.isCompleted
                                              ? Colors.green.shade100
                                              : (isLocked ? Colors.grey.shade200 : primaryColor.withValues(alpha: 0.2)),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          site.isCompleted
                                              ? 'Completed ✓'
                                              : (isLocked ? 'Locked' : 'Pending'),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: site.isCompleted
                                                ? Colors.green.shade800
                                                : (isLocked ? Colors.grey.shade600 : darkTextColor),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (site.purpose.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Purpose: ${site.purpose}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                    ),
                                  ],
                                  if (site.destinationAddress.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      site.destinationAddress,
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    'Geofence Radius: ${site.radius}m',
                                    style: TextStyle(fontSize: 11, color: primaryColor.withValues(alpha: 0.9), fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.existingAssignment == null || widget.existingAssignment!.isAssigned) ...[
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
                                onPressed: () async {
                                  final edited = await showDialog<OnDutySite>(
                                    context: context,
                                    builder: (ctx) => AddSiteDialog(siteNumber: index + 1, existingSite: site),
                                  );
                                  if (edited != null) {
                                    setState(() {
                                      _addedSites[index] = edited;
                                    });
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                onPressed: () {
                                  setState(() {
                                    _addedSites.removeAt(index);
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      );
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

                // 6. After OD Completion Option
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
                          'Can check out directly from the verified OD site',
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

                // 7. Notes
                const Text(
                  'Notes',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: darkTextColor),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Meeting details, instructions, contacts...',
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

                // 8. Balanced Action Buttons
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
                        onPressed: _isSubmitting
                            ? null
                            : (isImmediateStartAction ? _handleStartOdDirectly : _submitAssignment),
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
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (isImmediateStartAction) ...[
                                    const Icon(Icons.play_arrow_rounded, size: 18),
                                    const SizedBox(width: 4),
                                    const Text('[ START OD ]', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ] else ...[
                                    Text(
                                      widget.existingAssignment != null
                                          ? 'Update OD'
                                          : (widget.isSelfRequest ? 'Submit OD' : 'Assign OD'),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ],
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

  Future<void> _handleStartOdDirectly() async {
    if (!_formKey.currentState!.validate() || _selectedEmployee == null) return;

    if (_addedSites.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one site destination before starting OD.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final primarySite = _addedSites.first;

    final empIdInt = _selectedEmployee!.id > 0 ? _selectedEmployee!.id : 1;
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final attendanceRepo = ref.read(attendanceRepositoryProvider);

    // 1. Check if employee is currently checked in at the Office
    final todayRecord = await attendanceRepo.getAttendanceRecordForDate(empIdInt, todayStr) ??
        await attendanceRepo.getAttendanceRecordForDate(1, todayStr);

    final activeSession = todayRecord?.sessions.where((s) => s.isActive).firstOrNull;
    final isOfficeActive = activeSession != null && activeSession.isOffice;

    if (isOfficeActive) {
      bool shouldAutoCheckOut = false;
      if (mounted) {
        shouldAutoCheckOut = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Office Check-Out Required',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                    ),
                  ],
                ),
                content: const Text(
                  'You are currently checked in at the Office. Would you like to check out of the office now and start your On-Duty session?',
                  style: TextStyle(fontSize: 14, color: Color(0xFF334155)),
                ),
                actions: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9CC70A),
                      foregroundColor: const Color(0xFF414A51),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Check-Out & Continue', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ) ??
            false;
      }

      if (shouldAutoCheckOut) {
        final nowTimeStr = DateFormat('hh:mm a').format(DateTime.now());
        await attendanceRepo.checkOut(
          employeeId: empIdInt,
          date: todayStr,
          checkOutTime: nowTimeStr,
          verificationStatus: 'AUTO_OFFICE_CHECKOUT_FOR_OD',
          similarityScore: 1.0,
        );
      } else {
        return;
      }
    }

    // 2. Check if another task or clocking activity is running
    final empIdStr = 'EMP-${_selectedEmployee!.id.toString().padLeft(3, '0')}';
    final taskRepo = ref.read(taskRepositoryProvider);
    final runningTasks = await taskRepo.getTasks(assignedTo: empIdStr, status: 'IN_PROGRESS');
    final activeTask = runningTasks.firstOrNull;

    final clockRepo = ref.read(clockingRepositoryProvider);
    final activeClockEntry = await clockRepo.getActiveEntry(empIdStr);

    if (activeTask != null || activeClockEntry != null) {
      final runningName = activeTask != null ? 'Task "${activeTask.title}"' : 'Activity "${activeClockEntry?.entryType}"';
      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Task Currently Running',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ),
              ],
            ),
            content: Text(
              '$runningName is currently running.\n\nPlease finish the active task before starting On-Duty.',
              style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9CC70A),
                  foregroundColor: const Color(0xFF414A51),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final position = await _getGpsPosition();
      final nowStr = DateFormat('hh:mm a').format(DateTime.now());
      final nowTime24 = '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}';

      final repo = ref.read(onDutyRepositoryProvider);

      // Set first site as traveling
      final updatedSites = List<OnDutySite>.from(_addedSites);
      if (updatedSites.isNotEmpty) {
        updatedSites[0] = updatedSites[0].copyWith(
          status: 'TRAVELING',
          travelStartTime: nowStr,
          startLatitude: position?.latitude,
          startLongitude: position?.longitude,
        );
      }

      final newAssignment = OnDutyAssignment(
        id: 0,
        employeeId: _selectedEmployee!.id,
        employeeName: _selectedEmployee!.fullName.trim().isNotEmpty
            ? _selectedEmployee!.fullName
            : _getEmployeeLabel(_selectedEmployee!),
        odType: _selectedOdType,
        purpose: _purposeController.text.trim(),
        destination: primarySite.effectiveName,
        destinationName: primarySite.effectiveName,
        destinationAddress: primarySite.destinationAddress,
        destinationLatitude: primarySite.latitude,
        destinationLongitude: primarySite.longitude,
        destinationRadius: primarySite.radius,
        sites: updatedSites,
        date: DateFormat('dd-MM-yyyy').format(DateTime.now()),
        actualStartTime: nowStr,
        travelStartTime: nowStr,
        startTripLatitude: position?.latitude,
        startTripLongitude: position?.longitude,
        startLatitude: position?.latitude,
        startLongitude: position?.longitude,
        status: 'TRAVELING_TO_DESTINATION',
        notes: _notesController.text.trim(),
        afterCompletionOption: _afterCompletionOption,
        assignedBy: 'Self (Employee Request)',
        createdAt: DateTime.now().toIso8601String(),
      );

      final createdId = await repo.createAssignment(newAssignment);

      // Start OD Attendance Session
      final sessionResult = await attendanceRepo.startOdAttendanceSession(
        employeeId: empIdInt,
        employeeName: _selectedEmployee!.fullName,
        date: todayStr,
        time: nowTime24,
        assignmentId: createdId > 0 ? createdId : DateTime.now().millisecondsSinceEpoch,
        purpose: _purposeController.text.trim(),
        destination: primarySite.effectiveName,
        destinationAddress: primarySite.destinationAddress,
        latitude: position?.latitude,
        longitude: position?.longitude,
        destinationLatitude: primarySite.latitude,
        destinationLongitude: primarySite.longitude,
        destinationRadius: primarySite.radius,
        notes: 'On Duty: $_selectedOdType (${primarySite.effectiveName})',
      );

      if (!sessionResult.allowed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(sessionResult.message), backgroundColor: Colors.red),
          );
        }
        return;
      }

      ref.invalidate(allOnDutyAssignmentsProvider);
      ref.invalidate(activeOnDutyAssignmentProvider(_selectedEmployee!.id));
      ref.invalidate(employeeOnDutyAssignmentsProvider);
      ref.invalidate(attendanceRecordsProvider(empIdInt));
      ref.invalidate(todayAttendanceRecordProvider(empIdInt));
      ref.invalidate(allAttendanceRecordsProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('On-Duty session started! GPS captured successfully.'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start On-Duty: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitAssignment() async {
    if (!_formKey.currentState!.validate() || _selectedEmployee == null) return;

    if (_addedSites.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one site destination.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final primarySite = _addedSites.first;

    setState(() => _isSubmitting = true);

    try {
      final dateStr = DateFormat('dd-MM-yyyy').format(_selectedDate);
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
          destination: primarySite.effectiveName,
          destinationName: primarySite.effectiveName,
          destinationAddress: primarySite.destinationAddress,
          destinationLatitude: primarySite.latitude,
          destinationLongitude: primarySite.longitude,
          destinationRadius: primarySite.radius,
          sites: _addedSites,
          date: dateStr,
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
          destination: primarySite.effectiveName,
          destinationName: primarySite.effectiveName,
          destinationAddress: primarySite.destinationAddress,
          destinationLatitude: primarySite.latitude,
          destinationLongitude: primarySite.longitude,
          destinationRadius: primarySite.radius,
          sites: _addedSites,
          date: dateStr,
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
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Employee',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, ID, phone...',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              onChanged: (val) => setState(() => _query = val),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No employees found', style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final emp = filtered[i];
                        final isSel = widget.selectedEmployee?.id == emp.id;
                        return Container(
                          decoration: BoxDecoration(
                            color: isSel ? const Color(0xFF9CC70A).withValues(alpha: 0.15) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSel ? const Color(0xFF9CC70A) : const Color(0xFFE2E8F0),
                              width: isSel ? 1.5 : 1.0,
                            ),
                          ),
                          child: ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFF414A51),
                              child: Text(
                                emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : 'E',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              widget.getEmployeeLabel(emp),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            subtitle: emp.department.isNotEmpty
                                ? Text(emp.department, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))
                                : null,
                            trailing: isSel ? const Icon(Icons.check_circle, color: Color(0xFF9CC70A), size: 18) : null,
                            onTap: () {
                              widget.onSelected(emp);
                              Navigator.pop(context);
                            },
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
