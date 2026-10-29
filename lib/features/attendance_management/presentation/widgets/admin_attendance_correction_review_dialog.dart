import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../attendance/domain/attendance_correction_request.dart';
import '../../../attendance/providers/attendance_correction_providers.dart';
import '../../../attendance/providers/attendance_providers.dart';
import '../../../attendance_management/providers/attendance_management_providers.dart';

class AdminAttendanceCorrectionReviewDialog extends ConsumerStatefulWidget {
  const AdminAttendanceCorrectionReviewDialog({
    super.key,
    required this.request,
  });

  final AttendanceCorrectionRequest request;

  @override
  ConsumerState<AdminAttendanceCorrectionReviewDialog> createState() =>
      _AdminAttendanceCorrectionReviewDialogState();
}

class _AdminAttendanceCorrectionReviewDialogState
    extends ConsumerState<AdminAttendanceCorrectionReviewDialog> {
  late TextEditingController _resumedTimeController;
  late TextEditingController _finalCheckOutTimeController;
  late TextEditingController _adminCommentController;
  bool _isProcessing = false;
  bool _isPastDay = false;

  @override
  void initState() {
    super.initState();
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _isPastDay = widget.request.date != todayStr &&
        widget.request.date.replaceAll('-', '') != todayStr.replaceAll('-', '');

    _resumedTimeController = TextEditingController(
      text: DateFormat('hh:mm a').format(DateTime.now()),
    );
    _finalCheckOutTimeController = TextEditingController(text: '06:00 PM');
    _adminCommentController = TextEditingController();
  }

  @override
  void dispose() {
    _resumedTimeController.dispose();
    _finalCheckOutTimeController.dispose();
    _adminCommentController.dispose();
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
        controller.text = DateFormat('hh:mm a').format(dt);
      });
    }
  }

  Future<void> _approve() async {
    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(attendanceCorrectionRepositoryProvider);
      await repo.approveAndReopenShift(
        request: widget.request,
        resumedCheckInTime: _resumedTimeController.text.trim(),
        finalCheckOutTime: _isPastDay ? _finalCheckOutTimeController.text.trim() : null,
        adminComment: _adminCommentController.text.trim(),
        reviewedBy: 'Admin',
      );

      // Invalidate all attendance providers
      ref.invalidate(todayAttendanceRecordProvider(widget.request.employeeId));
      ref.invalidate(attendanceRecordsProvider(widget.request.employeeId));
      ref.invalidate(allAttendanceRecordsProvider);
      ref.invalidate(attendanceManagementRecordsProvider);
      ref.invalidate(attendanceManagementStatsProvider);
      ref.invalidate(pendingCorrectionRequestsProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isPastDay
                ? 'Attendance record finalized for ${widget.request.employeeName}!'
                : 'Shift reopened successfully for ${widget.request.employeeName}!'),
            backgroundColor: const Color(0xFF414A51),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _reject() async {
    final reason = _adminCommentController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an admin comment/reason for rejection.')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(attendanceCorrectionRepositoryProvider);
      await repo.rejectRequest(
        requestId: widget.request.id,
        reason: reason,
        reviewedBy: 'Admin',
      );

      ref.invalidate(pendingCorrectionRequestsProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request rejected for ${widget.request.employeeName}.'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9CC70A).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.admin_panel_settings_outlined, color: Color(0xFF414A51), size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Review Request: ${req.employeeName}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          Text(
                            'Code: ${req.employeeCode} • Date: ${req.date}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
                const SizedBox(height: 12),

                // Request Details Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Accidental Check-Out:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          Text(req.accidentalCheckOutTime, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC62828))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Intended Activity:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          Text('${req.activityType} (${req.startTime})', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text('Employee Reason:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      const SizedBox(height: 2),
                      Text('"${req.description}"', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF334155))),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Input: Resumed Check-In Time
                const Text('Set New Check-In / Session Start Time:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const SizedBox(height: 4),
                const Text('The break will be logged up to this time, and an active office session will start.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _resumedTimeController,
                  readOnly: true,
                  onTap: () => _selectTime(_resumedTimeController),
                  decoration: InputDecoration(
                    suffixIcon: const Icon(Icons.access_time, size: 20, color: Color(0xFF414A51)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),

                // Past Day Notice & Final Check Out Time picker
                if (_isPastDay) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Color(0xFFB45309)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This request is for a past date. Please also specify the final Check-Out time for that shift to finalize the record.',
                            style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Final Shift Check-Out Time:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _finalCheckOutTimeController,
                    readOnly: true,
                    onTap: () => _selectTime(_finalCheckOutTimeController),
                    decoration: InputDecoration(
                      suffixIcon: const Icon(Icons.access_time, size: 20, color: Color(0xFF414A51)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                // Admin Notes
                const Text('Admin Comment (Optional):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _adminCommentController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'e.g. Approved. Accidental check-out reversed.',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 18),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFFE53935)),
                      onPressed: _isProcessing ? null : _reject,
                      child: const Text('Reject Request', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Row(
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
                          onPressed: _isProcessing ? null : _approve,
                          child: Text(
                            _isProcessing
                                ? 'Processing...'
                                : (_isPastDay ? 'Accept & Finalize' : 'Accept & Reopen Shift'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
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

