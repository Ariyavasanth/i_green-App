import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/attendance_correction_request.dart';
import '../../domain/attendance_record.dart';
import '../../providers/attendance_correction_providers.dart';
import '../../../employee/domain/employee.dart';

class RequestAccidentalCheckoutDialog extends ConsumerStatefulWidget {
  const RequestAccidentalCheckoutDialog({
    super.key,
    required this.record,
    required this.employee,
    required this.date,
  });

  final AttendanceRecord record;
  final Employee employee;
  final DateTime date;

  @override
  ConsumerState<RequestAccidentalCheckoutDialog> createState() => _RequestAccidentalCheckoutDialogState();
}

class _RequestAccidentalCheckoutDialogState extends ConsumerState<RequestAccidentalCheckoutDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _selectedActivity;
  late TextEditingController _startTimeController;
  late TextEditingController _descriptionController;
  bool _isSubmitting = false;

  final List<String> _activities = [
    'Lunch Break',
    'Tea Break',
    'Coffee Break',
    'Meeting',
    'Accidental Check-Out',
  ];

  @override
  void initState() {
    super.initState();
    _selectedActivity = _activities.first;
    _startTimeController = TextEditingController(
      text: widget.record.formattedCheckOutTime.isNotEmpty
          ? widget.record.formattedCheckOutTime
          : DateFormat('hh:mm a').format(DateTime.now()),
    );
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _startTimeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectStartTime() async {
    TimeOfDay initial = TimeOfDay.now();
    try {
      final text = _startTimeController.text.trim();
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
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF414A51),
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Color(0xFF1E293B),
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null && mounted) {
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
      setState(() {
        _startTimeController.text = DateFormat('hh:mm a').format(dt);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(attendanceCorrectionRepositoryProvider);
      final dateStr = DateFormat('yyyy-MM-dd').format(widget.date);

      final req = AttendanceCorrectionRequest(
        id: '',
        employeeId: widget.employee.id,
        employeeCode: widget.employee.employeeId,
        employeeName: widget.employee.fullName,
        department: widget.employee.department,
        date: dateStr,
        accidentalCheckOutTime: widget.record.checkOutTime,
        activityType: _selectedActivity,
        startTime: _startTimeController.text.trim(),
        description: _descriptionController.text.trim(),
        submittedAt: DateTime.now(),
      );

      await repo.submitRequest(req);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Accidental checkout request submitted to Admin!'),
            backgroundColor: Color(0xFF414A51),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.history_toggle_off, color: Color(0xFF414A51), size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Accidental Checkout Request',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          Text(
                            'Request Admin to reopen shift and set session start time',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
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
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 14),

                // Activity Dropdown
                const Text('Intended Activity / Clocking Option:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedActivity,
                  items: _activities.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedActivity = v);
                  },
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 14),

                // Session Start Time Only
                const Text('Start Time Only (No End Time needed):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _startTimeController,
                  readOnly: true,
                  onTap: _selectStartTime,
                  decoration: InputDecoration(
                    suffixIcon: const Icon(Icons.access_time, size: 20, color: Color(0xFF414A51)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Set the start time of the break/activity. Admin will specify the check-in time upon acceptance.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),

                // Description / Reason
                const Text('Reason / Description:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a brief explanation' : null,
                  decoration: InputDecoration(
                    hintText: 'e.g. Accidentally clicked Check-Out when going to lunch',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 18),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9CC70A),
                        foregroundColor: const Color(0xFF414A51),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isSubmitting ? null : _submit,
                      child: Text(_isSubmitting ? 'Submitting...' : 'Submit Request', style: const TextStyle(fontWeight: FontWeight.bold)),
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
}
