import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../attendance/domain/attendance_record.dart';
import '../../../attendance/domain/attendance_status_helper.dart';
import '../../../employee/domain/employee.dart';

/// Step #3A: Attendance Correction UI Dialog
/// Presents side-by-side current vs corrected attendance fields with mandatory reason validation.
class AttendanceCorrectionDialog extends StatefulWidget {
  const AttendanceCorrectionDialog({
    super.key,
    required this.employee,
    required this.date,
    this.record,
    this.statusInfo,
    required this.onSubmitted,
  });

  final Employee employee;
  final DateTime date;
  final AttendanceRecord? record;
  final AttendanceStatusInfo? statusInfo;

  /// Callback when correction UI is validated and submitted
  final void Function({
    required String correctedCheckIn,
    required String correctedCheckOut,
    required String correctedStatus,
    required String reason,
  }) onSubmitted;

  @override
  State<AttendanceCorrectionDialog> createState() => _AttendanceCorrectionDialogState();
}

class _AttendanceCorrectionDialogState extends State<AttendanceCorrectionDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _checkInController;
  late TextEditingController _checkOutController;
  late TextEditingController _reasonController;
  late String _selectedStatus;

  @override
  void initState() {
    super.initState();
    final rec = widget.record;
    final initialIn = rec?.effectiveCheckInTime.isNotEmpty == true
        ? rec!.effectiveCheckInTime
        : (widget.employee.inTime.trim().isNotEmpty ? widget.employee.inTime.trim() : '');
    final initialOut = rec?.checkOutTime.isNotEmpty == true
        ? rec!.checkOutTime
        : (widget.employee.outTime.trim().isNotEmpty ? widget.employee.outTime.trim() : '');

    _checkInController = TextEditingController(text: initialIn);
    _checkOutController = TextEditingController(text: initialOut);
    _reasonController = TextEditingController();

    _selectedStatus = widget.statusInfo?.label ?? rec?.status ?? 'Present';
  }

  @override
  void dispose() {
    _checkInController.dispose();
    _checkOutController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(TextEditingController controller) async {
    TimeOfDay initial = TimeOfDay.now();
    try {
      final text = controller.text.trim();
      if (text.isNotEmpty) {
        final parts = text.replaceAll(RegExp(r'[^0-9:]'), '').split(':');
        if (parts.length >= 2) {
          int h = int.parse(parts[0]);
          int m = int.parse(parts[1]);
          if (text.toUpperCase().contains('PM') && h < 12) h += 12;
          if (text.toUpperCase().contains('AM') && h == 12) h = 0;
          initial = TimeOfDay(hour: h, minute: m);
        }
      }
    } catch (_) {}

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF414A51),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
      final formattedStr = DateFormat('hh:mm a').format(dt);
      setState(() {
        controller.text = formattedStr;
      });
    }
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;

    widget.onSubmitted(
      correctedCheckIn: _checkInController.text.trim(),
      correctedCheckOut: _checkOutController.text.trim(),
      correctedStatus: _selectedStatus,
      reason: _reasonController.text.trim(),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 550;
    final dateStr = DateFormat('EEEE, dd MMMM yyyy').format(widget.date);
    final empCode = widget.employee.employeeId.isNotEmpty
        ? widget.employee.employeeId
        : 'EMP${widget.employee.id.toString().padLeft(3, '0')}';

    final expectedCheckIn = widget.employee.inTime.trim().isNotEmpty ? widget.employee.inTime.trim() : '--:--';
    final expectedCheckOut = widget.employee.outTime.trim().isNotEmpty ? widget.employee.outTime.trim() : '--:--';
    final scheduleType = widget.employee.workScheduleType.isNotEmpty
        ? widget.employee.workScheduleType
        : (widget.employee.isDynamicEmployee ? 'Flexible' : 'Fixed Schedule');

    final rec = widget.record;
    final origCheckIn = rec?.effectiveCheckInTime.isNotEmpty == true ? rec!.effectiveCheckInTime : '--:--';
    final origCheckOut = rec?.checkOutTime.isNotEmpty == true ? rec!.checkOutTime : '--:--';
    final origStatusLabel = widget.statusInfo != null
        ? '${widget.statusInfo!.code} - ${widget.statusInfo!.label}'
        : (rec?.status.isNotEmpty == true ? rec!.status : 'Not Marked');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? size.width * 0.95 : 540,
          maxHeight: size.height * 0.90,
        ),
        child: Container(
          padding: EdgeInsets.all(isMobile ? 14 : 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9CC70A).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit_calendar_outlined, color: Color(0xFF414A51), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attendance Correction',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          'Step #3A — Correction Form & Reason',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 12),

              // Scrollable Body
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Employee Summary Banner
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFF9CC70A).withValues(alpha: 0.25),
                                child: Text(
                                  widget.employee.fullName.isNotEmpty ? widget.employee.fullName[0].toUpperCase() : 'E',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF414A51), fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${widget.employee.fullName} ($empCode)',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                                    ),
                                    const SizedBox(height: 2),
                                    Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 6,
                                      children: [
                                        Text(
                                          dateStr,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                                        ),
                                        if (expectedCheckIn != '--:--' || expectedCheckOut != '--:--')
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                            child: Text(
                                              'Shift: $expectedCheckIn - $expectedCheckOut',
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF414A51)),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Section Title: Current vs Corrected
                        const Text(
                          'ATTENDANCE COMPARISON',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Expected Values Card (From Employee Management)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9CC70A).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF9CC70A).withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.schedule, size: 14, color: Color(0xFF414A51)),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Expected Shift (Employee Management)',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFF9CC70A).withValues(alpha: 0.6)),
                                    ),
                                    child: Text(
                                      scheduleType,
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.login, size: 13, color: Color(0xFF16A34A)),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'Expected In: ',
                                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                        ),
                                        Text(
                                          expectedCheckIn,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.logout, size: 13, color: Color(0xFFEA580C)),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'Expected Out: ',
                                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                        ),
                                        Text(
                                          expectedCheckOut,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Original Values Card
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.history_outlined, size: 14, color: Color(0xFF414A51)),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Current Attendance Record',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Text(
                                      origStatusLabel,
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Check-in: $origCheckIn',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Check-out: $origCheckOut',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Corrected Values Inputs
                        const Text(
                          'CORRECTED VALUES',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Check-in & Check-out inputs side-by-side
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _checkInController,
                                readOnly: true,
                                onTap: () => _selectTime(_checkInController),
                                decoration: InputDecoration(
                                  labelText: 'Correct Check-in *',
                                  helperText: 'Expected: $expectedCheckIn',
                                  helperStyle: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                  labelStyle: const TextStyle(fontSize: 12),
                                  prefixIcon: const Icon(Icons.login, size: 16, color: Color(0xFF16A34A)),
                                  suffixIcon: const Icon(Icons.access_time, size: 16, color: Color(0xFF64748B)),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                                validator: (v) {
                                  if (_selectedStatus == 'Absent' || _selectedStatus == 'On Leave') {
                                    return null;
                                  }
                                  return (v == null || v.trim().isEmpty) ? 'Check-in required' : null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _checkOutController,
                                readOnly: true,
                                onTap: () => _selectTime(_checkOutController),
                                decoration: InputDecoration(
                                  labelText: 'Correct Check-out',
                                  helperText: 'Expected: $expectedCheckOut',
                                  helperStyle: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                  labelStyle: const TextStyle(fontSize: 12),
                                  prefixIcon: const Icon(Icons.logout, size: 16, color: Color(0xFFEA580C)),
                                  suffixIcon: const Icon(Icons.access_time, size: 16, color: Color(0xFF64748B)),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Status Selection
                        DropdownButtonFormField<String>(
                          value: ['Present', 'Late', 'Missing Check-Out', 'Absent', 'On Leave', 'On Duty'].contains(_selectedStatus)
                              ? _selectedStatus
                              : 'Present',
                          decoration: InputDecoration(
                            labelText: 'Corrected Attendance Status *',
                            labelStyle: const TextStyle(fontSize: 12),
                            prefixIcon: const Icon(Icons.swap_horiz, size: 18, color: Color(0xFF414A51)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Present', child: Text('Present (P)')),
                            DropdownMenuItem(value: 'Late', child: Text('Late (L)')),
                            DropdownMenuItem(value: 'Missing Check-Out', child: Text('Missing Check-Out (MC)')),
                            DropdownMenuItem(value: 'Absent', child: Text('Absent (A)')),
                            DropdownMenuItem(value: 'On Leave', child: Text('On Leave (OL)')),
                            DropdownMenuItem(value: 'On Duty', child: Text('On Duty (OD)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedStatus = val);
                          },
                        ),
                        const SizedBox(height: 12),

                        // Mandatory Correction Reason
                        TextFormField(
                          controller: _reasonController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Correction Reason (Mandatory) *',
                            labelStyle: const TextStyle(fontSize: 12),
                            hintText: 'e.g. Forgot to mark checkout, System regularized by Admin...',
                            hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.edit_note, size: 18, color: Color(0xFF414A51)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Mandatory correction reason required for audit tracking';
                            }
                            if (val.trim().length < 5) {
                              return 'Reason must be at least 5 characters long';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF414A51),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9CC70A),
                      foregroundColor: const Color(0xFF21273E),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Submit Correction', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: _handleSubmit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
