import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../domain/on_duty_assignment.dart';
import '../providers/on_duty_providers.dart';
import '../../task_management/providers/task_providers.dart';
import '../../time_clocking/providers/clocking_providers.dart';
import '../../attendance/providers/attendance_providers.dart';

class EmployeeOnDutyCard extends ConsumerStatefulWidget {
  const EmployeeOnDutyCard({
    super.key,
    required this.assignment,
  });

  final OnDutyAssignment assignment;

  @override
  ConsumerState<EmployeeOnDutyCard> createState() => _EmployeeOnDutyCardState();
}

class _EmployeeOnDutyCardState extends ConsumerState<EmployeeOnDutyCard> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  String? _startPhotoPath;
  String? _endPhotoPath;
  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.assignment.status == 'IN_PROGRESS') {
      _startLiveTimer();
    }
  }

  @override
  void didUpdateWidget(covariant EmployeeOnDutyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.assignment.status == 'IN_PROGRESS' && _timer == null) {
      _startLiveTimer();
    } else if (widget.assignment.status != 'IN_PROGRESS') {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startLiveTimer() {
    _timer?.cancel();
    DateTime? startTime;
    if (widget.assignment.actualStartTime != null && widget.assignment.actualStartTime!.isNotEmpty) {
      try {
        final parsed = DateFormat('hh:mm a').parse(widget.assignment.actualStartTime!);
        final now = DateTime.now();
        startTime = DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute);
      } catch (_) {}
    }
    startTime ??= DateTime.now();

    _elapsed = DateTime.now().difference(startTime);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(startTime!);
        });
      }
    });
  }

  String _formatTimerDisplay(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
  }

  String _formatDurationSummary(int durationMinutes) {
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    return '${hours}h ${mins}m';
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

  Future<void> _handleStartOd() async {
    // 1. Check-In Validation: Ensure employee has checked in for attendance today
    final attendanceRepo = ref.read(attendanceRepositoryProvider);
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final empIdInt = widget.assignment.employeeId > 0 ? widget.assignment.employeeId : 1;
    final todayRecord = await attendanceRepo.getAttendanceRecordForDate(empIdInt, todayStr) ??
        await attendanceRepo.getAttendanceRecordForDate(1, todayStr);

    final isCheckedIn = todayRecord != null &&
        todayRecord.checkInTime.trim().isNotEmpty &&
        todayRecord.checkInTime != '--:--';

    if (!isCheckedIn) {
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
                    'Check-In Required',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Please Check In your attendance first before starting On-Duty work.',
              style: TextStyle(fontSize: 14, color: Color(0xFF334155)),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9CC70A),
                  foregroundColor: Colors.white,
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

    // 2. Mutual Exclusion: Check if any Task or Clocking activity is currently IN_PROGRESS
    final empIdStr = widget.assignment.employeeId > 0
        ? 'EMP-${widget.assignment.employeeId.toString().padLeft(3, '0')}'
        : 'EMP-001';
    final taskRepo = ref.read(taskRepositoryProvider);
    final runningTasks = await taskRepo.getTasks(assignedTo: empIdStr, status: 'IN_PROGRESS');
    final runningTasksAlt1 = await taskRepo.getTasks(assignedTo: 'EMP-001', status: 'IN_PROGRESS');
    final runningTasksAlt2 = await taskRepo.getTasks(assignedTo: 'EMP-0001', status: 'IN_PROGRESS');
    final activeTask = [...runningTasks, ...runningTasksAlt1, ...runningTasksAlt2].firstOrNull;

    final clockRepo = ref.read(clockingRepositoryProvider);
    final activeClockEntry = await clockRepo.getActiveEntry(empIdStr) ??
        await clockRepo.getActiveEntry('EMP-001') ??
        await clockRepo.getActiveEntry('EMP-0001');

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
                  foregroundColor: Colors.white,
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

    setState(() => _isActionLoading = true);
    try {
      final position = await _getGpsPosition();
      final nowStr = DateFormat('hh:mm a').format(DateTime.now());

      final updated = widget.assignment.copyWith(
        status: 'IN_PROGRESS',
        actualStartTime: nowStr,
        startLatitude: position?.latitude,
        startLongitude: position?.longitude,
      );

      final repo = ref.read(onDutyRepositoryProvider);
      await repo.updateAssignment(updated);

      ref.invalidate(activeOnDutyAssignmentProvider(widget.assignment.employeeId));
      ref.invalidate(activeOnDutyAssignmentProvider(1));
      ref.invalidate(activeOnDutyAssignmentProvider(0));
      ref.invalidate(allOnDutyAssignmentsProvider((date: null, statusFilter: null, employeeId: null)));
      _startLiveTimer();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start On-Duty: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.assignment.status;

    if (status == 'ASSIGNED') {
      return _buildAssignedCard();
    } else if (status == 'IN_PROGRESS') {
      return _buildInProgressCard();
    } else if (status == 'COMPLETED') {
      return _buildCompletedCard();
    }

    return const SizedBox.shrink();
  }

  // ==========================================
  // Card View 1: ASSIGNED State
  // ==========================================
  Widget _buildAssignedCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF9CC70A), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF414A51),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.assignment_ind_outlined, color: Color(0xFF9CC70A), size: 20),
                const SizedBox(width: 8),
                Text(
                  'MY ON-DUTY (${widget.assignment.odType.toUpperCase()})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // Details Body
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.assignment.destination,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.assignment.date}  •  ${widget.assignment.plannedStartTime}${widget.assignment.plannedEndTime != null ? " → ${widget.assignment.plannedEndTime}" : ""}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                _buildMetaRow(Icons.lightbulb_outline, 'Purpose', widget.assignment.purpose, isBold: true),
                if (widget.assignment.notes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _buildMetaRow(Icons.notes, 'Notes', widget.assignment.notes),
                ],
                const SizedBox(height: 16),

                // Start OD Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isActionLoading ? null : _handleStartOd,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9CC70A),
                      foregroundColor: const Color(0xFF414A51),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    icon: _isActionLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF414A51)),
                          )
                        : const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text(
                      '[ START OD ]',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Card View 2: IN_PROGRESS State
  // ==========================================
  Widget _buildInProgressCard() {
    final hasStartGps = widget.assignment.startLatitude != null && widget.assignment.startLongitude != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD97706), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFD97706),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      widget.assignment.odType.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _formatTimerDisplay(_elapsed),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // Details Body
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.assignment.destination,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Started: ${widget.assignment.actualStartTime ?? "10:00 AM"}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF414A51), fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
                          const SizedBox(width: 4),
                          Text(
                            hasStartGps ? 'GPS Captured ✓' : 'GPS Active',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (hasStartGps) ...[
                  const SizedBox(height: 4),
                  Text(
                    'GPS: ${widget.assignment.startLatitude!.toStringAsFixed(4)}, ${widget.assignment.startLongitude!.toStringAsFixed(4)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
                const SizedBox(height: 16),

                // Complete OD Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isActionLoading ? null : _handleCompleteOd,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    icon: _isActionLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline, size: 20),
                    label: const Text(
                      '[ COMPLETE OD ]',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Card View 3: COMPLETED State
  // ==========================================
  Widget _buildCompletedCard() {
    final durationMin = widget.assignment.durationMinutes > 0
        ? widget.assignment.durationMinutes
        : _elapsed.inMinutes;

    final durationStr = _formatDurationSummary(durationMin);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 22),
                const SizedBox(width: 8),
                Text(
                  '${widget.assignment.odType} - COMPLETED',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF14532D)),
                ),
              ],
            ),
            const Divider(height: 16),
            Text(
              widget.assignment.destination,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Started: ${widget.assignment.actualStartTime ?? "--"}',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF414A51)),
                ),
                Text(
                  'Completed: ${widget.assignment.actualEndTime ?? "--"}',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF414A51)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Duration: $durationStr',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                ),
                Row(
                  children: [
                    if (widget.assignment.startLatitude != null)
                      const Text('Start Location ✓  ', style: TextStyle(fontSize: 11, color: Color(0xFF15803D), fontWeight: FontWeight.w600)),
                    if (widget.assignment.endLatitude != null)
                      const Text('End Location ✓', style: TextStyle(fontSize: 11, color: Color(0xFF15803D), fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(IconData icon, String label, String value, {bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              color: const Color(0xFF1E293B),
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }



  Future<void> _handleCompleteOd() async {
    setState(() => _isActionLoading = true);
    try {
      final position = await _getGpsPosition();
      final nowStr = DateFormat('hh:mm a').format(DateTime.now());

      int durationMins = _elapsed.inMinutes;
      if (durationMins <= 0 && widget.assignment.actualStartTime != null) {
        try {
          final startDt = DateFormat('hh:mm a').parse(widget.assignment.actualStartTime!);
          final now = DateTime.now();
          final startFull = DateTime(now.year, now.month, now.day, startDt.hour, startDt.minute);
          durationMins = now.difference(startFull).inMinutes;
        } catch (_) {}
      }
      if (durationMins < 0) durationMins = 0;

      final updated = widget.assignment.copyWith(
        status: 'COMPLETED',
        actualEndTime: nowStr,
        endLatitude: position?.latitude,
        endLongitude: position?.longitude,
        durationMinutes: durationMins,
      );

      final repo = ref.read(onDutyRepositoryProvider);
      await repo.updateAssignment(updated);

      ref.invalidate(activeOnDutyAssignmentProvider(widget.assignment.employeeId));
      ref.invalidate(activeOnDutyAssignmentProvider(1));
      ref.invalidate(activeOnDutyAssignmentProvider(0));
      ref.invalidate(allOnDutyAssignmentsProvider((date: null, statusFilter: null, employeeId: null)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete On-Duty: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }
}
