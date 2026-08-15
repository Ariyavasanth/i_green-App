import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../employee/domain/employee.dart';
import '../../../employee/providers/employee_providers.dart';
import '../../../on_duty/domain/on_duty_assignment.dart';
import '../../../on_duty/providers/on_duty_providers.dart';
import '../../../site_visit_attendance/domain/site_visit_record.dart';

class AssignOnDutyDialog extends ConsumerStatefulWidget {
  const AssignOnDutyDialog({
    super.key,
    this.initialEmployee,
    this.initialVisit,
  });

  final Employee? initialEmployee;
  final SiteVisitRecord? initialVisit;

  @override
  ConsumerState<AssignOnDutyDialog> createState() => _AssignOnDutyDialogState();
}

class _AssignOnDutyDialogState extends ConsumerState<AssignOnDutyDialog> {
  final _formKey = GlobalKey<FormState>();
  
  Employee? _selectedEmployee;
  SiteVisitRecord? _currentVisit;

  String _destination = 'Perambur Site';
  final _customDestinationController = TextEditingController();
  final _taskController = TextEditingController();
  final _instructionsController = TextEditingController();
  bool _allowCheckoutFromDestination = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedEmployee = widget.initialEmployee;
    _currentVisit = widget.initialVisit;
  }

  @override
  void dispose() {
    _customDestinationController.dispose();
    _taskController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final employees = ref.watch(employeesProvider).valueOrNull ?? [];
    final companySites = ref.watch(companySitesProvider);

    final fromLocation = _currentVisit?.siteName.isNotEmpty == true
        ? _currentVisit!.siteName
        : (_currentVisit?.address.isNotEmpty == true ? _currentVisit!.address : 'Tambaram');
    final fromLat = _currentVisit?.latitude ?? 12.9249;
    final fromLng = _currentVisit?.longitude ?? 80.1000;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
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
                              color: const Color(0xFF9CC70A).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.assignment_ind_rounded,
                              color: Color(0xFF414A51),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'ASSIGN ON-DUTY',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF414A51),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.grey),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Employee Dropdown
                  const Text(
                    'Employee *',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF414A51)),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<Employee>(
                    value: _selectedEmployee ?? (employees.isNotEmpty ? employees.first : null),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    items: employees.map((emp) {
                      return DropdownMenuItem<Employee>(
                        value: emp,
                        child: Text(emp.name, style: const TextStyle(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (emp) {
                      setState(() {
                        _selectedEmployee = emp;
                      });
                    },
                    validator: (val) => val == null ? 'Please select an employee' : null,
                  ),
                  const SizedBox(height: 16),

                  // Current Work Location Card
                  const Text(
                    'Current Work Location',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF414A51)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('📍 ', style: TextStyle(fontSize: 16)),
                            Text(
                              fromLocation,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF414A51)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Latitude: ${fromLat.toStringAsFixed(4)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                        Text(
                          'Longitude: ${fromLng.toStringAsFixed(4)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Destination Dropdown
                  const Text(
                    'Destination *',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF414A51)),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: companySites.contains(_destination) ? _destination : companySites.first,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: companySites.map((site) {
                      return DropdownMenuItem<String>(
                        value: site,
                        child: Text(site, style: const TextStyle(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _destination = val;
                        });
                      }
                    },
                  ),
                  if (_destination == 'Other Location') ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _customDestinationController,
                      decoration: InputDecoration(
                        hintText: 'Enter custom destination name',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (val) {
                        if (_destination == 'Other Location' && (val == null || val.trim().isEmpty)) {
                          return 'Please enter custom location';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Work / Task
                  const Text(
                    'Work / Task *',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF414A51)),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _taskController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Deliver tool to Kumar',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Task is required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Instructions
                  const Text(
                    'Instructions',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF414A51)),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _instructionsController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'e.g. Take the tool and deliver it to Kumar.',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // After Work Radio options
                  const Text(
                    'After Work',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF414A51)),
                  ),
                  const SizedBox(height: 4),
                  RadioListTile<bool>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFF9CC70A),
                    title: const Text('Continue working', style: TextStyle(fontSize: 13)),
                    value: false,
                    groupValue: _allowCheckoutFromDestination,
                    onChanged: (val) {
                      if (val != null) setState(() => _allowCheckoutFromDestination = val);
                    },
                  ),
                  RadioListTile<bool>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFF9CC70A),
                    title: const Text('Can check out from destination', style: TextStyle(fontSize: 13)),
                    value: true,
                    groupValue: _allowCheckoutFromDestination,
                    onChanged: (val) {
                      if (val != null) setState(() => _allowCheckoutFromDestination = val);
                    },
                  ),
                  const SizedBox(height: 20),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: Color(0xFF414A51))),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9CC70A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Assign', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final emp = _selectedEmployee;
    if (emp == null) return;

    setState(() => _submitting = true);

    try {
      final now = DateTime.now();
      final dateStr = DateFormat('dd-MM-yyyy').format(now);
      final timeStr = DateFormat('hh:mm a').format(now);

      final finalDestination = _destination == 'Other Location'
          ? _customDestinationController.text.trim()
          : _destination;

      final fromLocName = _currentVisit?.siteName.isNotEmpty == true
          ? _currentVisit!.siteName
          : (_currentVisit?.address.isNotEmpty == true ? _currentVisit!.address : 'Tambaram');

      final assignment = OnDutyAssignment(
        id: 0,
        employeeId: emp.id,
        employeeName: emp.name,
        attendanceId: _currentVisit?.id,
        fromLocation: fromLocName,
        fromLatitude: _currentVisit?.latitude ?? 12.9249,
        fromLongitude: _currentVisit?.longitude ?? 80.1000,
        destination: finalDestination,
        task: _taskController.text.trim(),
        instructions: _instructionsController.text.trim(),
        assignedBy: 'Supervisor',
        assignedTime: timeStr,
        allowCheckoutFromDestination: _allowCheckoutFromDestination,
        status: 'assigned',
        date: dateStr,
        createdAt: now.toIso8601String(),
      );

      final repository = ref.read(onDutyRepositoryProvider);
      await repository.createAssignment(assignment);

      // Refresh providers
      ref.invalidate(allOnDutyAssignmentsProvider);
      ref.invalidate(activeOnDutyAssignmentProvider(emp.id));

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('On-Duty assigned successfully to ${emp.name}'),
            backgroundColor: const Color(0xFF9CC70A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to assign On-Duty: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
