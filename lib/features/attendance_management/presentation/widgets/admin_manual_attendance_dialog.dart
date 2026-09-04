import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../attendance/domain/attendance_record.dart';
import '../../../employee/providers/employee_providers.dart';
import '../../providers/attendance_management_providers.dart';

class AdminManualAttendanceDialog extends ConsumerStatefulWidget {
  const AdminManualAttendanceDialog({
    super.key,
    this.existingRecord,
    this.initialEmployeeId,
    this.initialDate,
    required this.onSaved,
  });

  final AttendanceRecord? existingRecord;
  final int? initialEmployeeId;
  final String? initialDate;
  final VoidCallback onSaved;

  @override
  ConsumerState<AdminManualAttendanceDialog> createState() => _AdminManualAttendanceDialogState();
}

class _AdminManualAttendanceDialogState extends ConsumerState<AdminManualAttendanceDialog> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedEmployeeId;
  String _selectedEmployeeCode = '';
  String _selectedEmployeeName = '';
  late TextEditingController _dateController;
  late TextEditingController _checkInController;
  late TextEditingController _checkOutController;
  late TextEditingController _notesController;
  String _status = 'Present';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final rec = widget.existingRecord;
    _selectedEmployeeId = rec?.employeeId ?? widget.initialEmployeeId;
    _selectedEmployeeCode = rec?.employeeCode ?? '';
    _selectedEmployeeName = rec?.employeeName ?? '';
    _dateController = TextEditingController(
      text: rec?.date ?? widget.initialDate ?? DateFormat('dd-MM-yyyy').format(DateTime.now()),
    );
    _checkInController = TextEditingController(text: rec?.effectiveCheckInTime ?? '');
    _checkOutController = TextEditingController(text: rec?.checkOutTime ?? '');
    _notesController = TextEditingController(text: rec?.notes ?? '');
    if (rec != null) _status = rec.status;
  }

  @override
  void dispose() {
    _dateController.dispose();
    _checkInController.dispose();
    _checkOutController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmployeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an employee.')));
      return;
    }
    setState(() => _saving = true);

    try {
      final repo = ref.read(attendanceManagementRepositoryProvider);
      final record = AttendanceRecord(
        id: widget.existingRecord?.id ?? 0,
        employeeId: _selectedEmployeeId!,
        employeeCode: _selectedEmployeeCode,
        employeeName: _selectedEmployeeName,
        date: _dateController.text.trim(),
        time: _checkInController.text.trim(),
        status: _status,
        verificationStatus: 'Admin Override (Firestore)',
        similarityScore: 1.0,
        checkInTime: _checkInController.text.trim(),
        checkOutTime: _checkOutController.text.trim(),
        checkInVerificationStatus: 'Admin Override (Firestore)',
        checkOutVerificationStatus: _checkOutController.text.trim().isNotEmpty ? 'Admin Override (Firestore)' : '',
        checkInSimilarityScore: 1.0,
        checkOutSimilarityScore: _checkOutController.text.trim().isNotEmpty ? 1.0 : 0.0,
        totalHours: 0.0,
        notes: _notesController.text.trim(),
        markedAt: widget.existingRecord?.markedAt ?? DateTime.now().toIso8601String(),
      );

      await repo.saveOrOverrideAttendance(record);
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance record updated in Firestore!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving record: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobileModal = screenWidth < 500;

    final timeFields = isMobileModal
        ? Column(
            children: [
              TextFormField(
                controller: _checkInController,
                decoration: const InputDecoration(
                  labelText: 'Check In Time (HH:mm:ss) *',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Check in time required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _checkOutController,
                decoration: const InputDecoration(
                  labelText: 'Check Out Time (HH:mm:ss)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ],
          )
        : Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _checkInController,
                  decoration: const InputDecoration(
                    labelText: 'Check In Time (HH:mm:ss) *',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Check in time required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _checkOutController,
                  decoration: const InputDecoration(
                    labelText: 'Check Out Time (HH:mm:ss)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
            ],
          );

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.edit_calendar, color: AppColors.active, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.existingRecord != null ? 'Edit / Override Attendance' : 'Manual Attendance Entry',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: isMobileModal ? (screenWidth * 0.88) : 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                employeesAsync.maybeWhen(
                  data: (employees) {
                    if (_selectedEmployeeId != null && _selectedEmployeeName.isEmpty) {
                      final match = employees.where((e) => e.id == _selectedEmployeeId).toList();
                      if (match.isNotEmpty) {
                        _selectedEmployeeName = match.first.fullName;
                        _selectedEmployeeCode = match.first.employeeId;
                      }
                    }
                    return DropdownButtonFormField<int>(
                      initialValue: _selectedEmployeeId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Select Employee *',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: employees
                          .map((e) => DropdownMenuItem(
                                value: e.id,
                                child: Text(
                                  '${e.fullName} (${e.employeeId})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedEmployeeId = val;
                            final match = employees.firstWhere((e) => e.id == val);
                            _selectedEmployeeName = match.fullName;
                            _selectedEmployeeCode = match.employeeId;
                          });
                        }
                      },
                      validator: (v) => v == null ? 'Employee is required' : null,
                    );
                  },
                  orElse: () => const CircularProgressIndicator(),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _dateController,
                  decoration: const InputDecoration(
                    labelText: 'Date (DD-MM-YYYY) *',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Date is required' : null,
                ),
                const SizedBox(height: 14),
                timeFields,
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Attendance Status *',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Present', child: Text('Present', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'Late', child: Text('Late', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'Checked Out', child: Text('Checked Out', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'Missing Check-Out', child: Text('Missing Check-Out', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'Absent', child: Text('Absent', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _status = val);
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Admin Override Notes',
                    hintText: 'e.g. Regularized by Admin, Approved travel day...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.active,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save to Firestore', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
