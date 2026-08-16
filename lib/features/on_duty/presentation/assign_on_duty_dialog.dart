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
  });

  final Employee? preSelectedEmployee;

  @override
  ConsumerState<AssignOnDutyDialog> createState() => _AssignOnDutyDialogState();
}

class _AssignOnDutyDialogState extends ConsumerState<AssignOnDutyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _destinationController = TextEditingController();
  final _taskController = TextEditingController();

  Employee? _selectedEmployee;
  bool _allowCheckoutFromDestination = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedEmployee = widget.preSelectedEmployee;
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _taskController.dispose();
    super.dispose();
  }

  String _getStartingLocation(Employee emp) {
    if (emp.department.isNotEmpty && emp.department.contains('Site')) {
      return emp.department;
    }
    return 'Tambaram Site';
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF9CC70A);
    const darkTextColor = Color(0xFF414A51);

    final employeesAsync = ref.watch(allEmployeesProvider);
    final employees = employeesAsync.asData?.value ?? [];

    if (_selectedEmployee == null && employees.isNotEmpty) {
      _selectedEmployee = employees.first;
    }

    final startingLocation = _selectedEmployee != null
        ? _getStartingLocation(_selectedEmployee!)
        : 'Tambaram Site';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
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
                      const Text(
                        'Assign On-Duty Task',
                        style: TextStyle(
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

                  // 1. Select Active Employee
                  const Text(
                    'Select Active Employee *',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: darkTextColor),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<Employee>(
                    value: _selectedEmployee,
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                    items: employees.map((emp) {
                      final site = _getStartingLocation(emp);
                      final label = '${emp.fullName} (${emp.employeeId.isNotEmpty ? emp.employeeId : "EMP-${emp.id}"}) - At $site';
                      return DropdownMenuItem<Employee>(
                        value: emp,
                        child: Text(
                          label,
                          style: const TextStyle(fontSize: 13, color: darkTextColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedEmployee = val);
                      }
                    },
                    validator: (val) => val == null ? 'Please select an employee' : null,
                  ),
                  const SizedBox(height: 16),

                  // 2. Starting From (Auto-detected)
                  const Text(
                    'Starting From',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: darkTextColor),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '📍 $startingLocation (Auto-detected from Check-in)',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Destination Location
                  const Text(
                    'Destination Location *',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: darkTextColor),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _destinationController,
                    decoration: InputDecoration(
                      hintText: 'Enter destination, e.g., Perambur Site / Office',
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
                        return 'Destination location is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // 4. Task Description
                  const Text(
                    'Task Description *',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: darkTextColor),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _taskController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Deliver tool kit to Kumar',
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
                        return 'Task description is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // 5. Outcome Radio Options
                  const Text(
                    'After Completing This On-Duty:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: darkTextColor),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => setState(() => _allowCheckoutFromDestination = false),
                    child: Row(
                      children: [
                        Radio<bool>(
                          value: false,
                          groupValue: _allowCheckoutFromDestination,
                          activeColor: primaryColor,
                          onChanged: (val) {
                            if (val != null) setState(() => _allowCheckoutFromDestination = val);
                          },
                        ),
                        Expanded(
                          child: Text(
                            'Return and continue regular shift at $startingLocation',
                            style: const TextStyle(fontSize: 12.5, color: darkTextColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _allowCheckoutFromDestination = true),
                    child: Row(
                      children: [
                        Radio<bool>(
                          value: true,
                          groupValue: _allowCheckoutFromDestination,
                          activeColor: primaryColor,
                          onChanged: (val) {
                            if (val != null) setState(() => _allowCheckoutFromDestination = val);
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'Allow direct checkout from destination',
                            style: TextStyle(fontSize: 12.5, color: darkTextColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 6. Completion Proof Requirement Note
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.camera_alt_outlined, color: Color(0xFF2563EB), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '📷 Completion Proof: Mandatory Photo required',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submitAssignment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: darkTextColor,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: darkTextColor),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        label: const Text(
                          'Assign Duty',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
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

  Future<void> _submitAssignment() async {
    if (!_formKey.currentState!.validate() || _selectedEmployee == null) return;

    setState(() => _isSubmitting = true);

    try {
      final now = DateTime.now();
      final dateStr = DateFormat('dd-MM-yyyy').format(now);
      final timeStr = DateFormat('hh:mm a').format(now);
      final startingLocation = _getStartingLocation(_selectedEmployee!);

      final assignment = OnDutyAssignment(
        id: 0,
        employeeId: _selectedEmployee!.id,
        employeeName: _selectedEmployee!.fullName,
        fromLocation: startingLocation,
        destination: _destinationController.text.trim(),
        task: _taskController.text.trim(),
        assignedBy: 'Supervisor',
        assignedTime: timeStr,
        allowCheckoutFromDestination: _allowCheckoutFromDestination,
        status: 'assigned',
        date: dateStr,
        createdAt: now.toIso8601String(),
      );

      final repo = ref.read(onDutyRepositoryProvider);
      await repo.createAssignment(assignment);

      // Invalidate providers
      ref.invalidate(allOnDutyAssignmentsProvider);
      ref.invalidate(activeOnDutyAssignmentProvider(_selectedEmployee!.id));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('On-Duty task assigned to ${_selectedEmployee!.fullName}!'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign task: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
