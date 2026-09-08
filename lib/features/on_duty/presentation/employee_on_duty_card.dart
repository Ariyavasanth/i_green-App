import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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
  Timer? _gpsCheckTimer;
  Duration _elapsed = Duration.zero;
  bool _isActionLoading = false;
  bool _isCheckingGps = false;

  // Real-time Geofence validation state
  double? _distanceToDestinationMeters;
  bool _isAtDestination = false;
  String? _gpsStatusMessage;

  @override
  void initState() {
    super.initState();
    if (widget.assignment.status == 'IN_PROGRESS' || widget.assignment.status == 'ACTIVE') {
      _startLiveTimer();
      _checkDestinationGeofence();
      _startPeriodicGpsCheck();
    }
  }

  @override
  void didUpdateWidget(covariant EmployeeOnDutyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isInProgress = widget.assignment.status == 'IN_PROGRESS' || widget.assignment.status == 'ACTIVE';
    if (isInProgress && _timer == null) {
      _startLiveTimer();
      _checkDestinationGeofence();
      _startPeriodicGpsCheck();
    } else if (!isInProgress) {
      _timer?.cancel();
      _gpsCheckTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _gpsCheckTimer?.cancel();
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

  void _startPeriodicGpsCheck() {
    _gpsCheckTimer?.cancel();
    // Re-check destination geofence periodically every 30 seconds
    _gpsCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && (widget.assignment.status == 'IN_PROGRESS' || widget.assignment.status == 'ACTIVE')) {
        _checkDestinationGeofence(silent: true);
      }
    });
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

  Future<void> _checkDestinationGeofence({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _isCheckingGps = true);
    }

    try {
      final pos = await _getGpsPosition();
      if (pos == null) {
        if (mounted) {
          setState(() {
            _gpsStatusMessage = 'GPS unavailable. Please enable device location.';
            _isCheckingGps = false;
          });
        }
        return;
      }

      final targetLat = widget.assignment.effectiveDestinationLatitude;
      final targetLng = widget.assignment.effectiveDestinationLongitude;
      final targetRadius = widget.assignment.destinationRadius > 0
          ? widget.assignment.destinationRadius
          : 100;

      if (targetLat != null && targetLng != null && targetLat != 0 && targetLng != 0) {
        final dist = Geolocator.distanceBetween(
          targetLat,
          targetLng,
          pos.latitude,
          pos.longitude,
        );

        final atDest = dist <= targetRadius;

        if (mounted) {
          setState(() {
            _distanceToDestinationMeters = dist;
            _isAtDestination = atDest;
            _gpsStatusMessage = atDest
                ? 'Destination reached ✓ (${dist.round()}m away, within ${targetRadius}m)'
                : 'Outside destination (${dist.round()}m away, required within ${targetRadius}m)';
            _isCheckingGps = false;
          });
        }
      } else {
        // No strict geofence configured
        if (mounted) {
          setState(() {
            _isAtDestination = true;
            _distanceToDestinationMeters = 0;
            _gpsStatusMessage = 'GPS Active ✓';
            _isCheckingGps = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _gpsStatusMessage = 'Error reading GPS: $e';
          _isCheckingGps = false;
        });
      }
    }
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

  Future<void> _openMap(double latitude, double longitude) async {
    final query = '$latitude,$longitude';
    final Uri googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(googleMapsUrl, mode: LaunchMode.platformDefault);
      }
    } catch (_) {}
  }

  Future<void> _handleStartOd() async {
    final attendanceRepo = ref.read(attendanceRepositoryProvider);
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final empIdInt = widget.assignment.employeeId > 0 ? widget.assignment.employeeId : 1;

    // 1. Check if employee is currently checked in at the Office
    final todayRecord = await attendanceRepo.getAttendanceRecordForDate(empIdInt, todayStr) ??
        await attendanceRepo.getAttendanceRecordForDate(1, todayStr);

    final activeSession = todayRecord?.sessions.where((s) => s.isActive).firstOrNull;
    final isOfficeActive = activeSession != null && activeSession.isOffice;

    if (isOfficeActive) {
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
                    'Office Check-Out Required',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ),
              ],
            ),
            content: const Text(
              'You are currently checked in at the Office. Please check out of the office before starting your On-Duty session.',
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
    final empIdStr = 'EMP-${widget.assignment.employeeId.toString().padLeft(3, '0')}';
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
      final nowTime24 = '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}';

      // 3. Start OD Attendance Session
      final sessionResult = await attendanceRepo.startOdAttendanceSession(
        employeeId: empIdInt,
        employeeName: widget.assignment.employeeName,
        date: todayStr,
        time: nowTime24,
        assignmentId: widget.assignment.id,
        purpose: widget.assignment.purpose,
        destination: widget.assignment.destination,
        destinationAddress: widget.assignment.destinationAddress,
        latitude: position?.latitude,
        longitude: position?.longitude,
        destinationLatitude: widget.assignment.effectiveDestinationLatitude,
        destinationLongitude: widget.assignment.effectiveDestinationLongitude,
        destinationRadius: widget.assignment.destinationRadius,
        notes: 'On Duty: ${widget.assignment.odType} (${widget.assignment.destination})',
      );

      if (!sessionResult.allowed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(sessionResult.message), backgroundColor: Colors.red),
          );
        }
        return;
      }

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
      ref.invalidate(attendanceRecordsProvider(empIdInt));
      ref.invalidate(todayAttendanceRecordProvider(empIdInt));
      ref.invalidate(allAttendanceRecordsProvider);
      _startLiveTimer();
      _checkDestinationGeofence();
      _startPeriodicGpsCheck();
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

  Future<void> _handleCompleteOd() async {
    // 1. Verify Destination Geofence
    await _checkDestinationGeofence();

    final targetLat = widget.assignment.effectiveDestinationLatitude;
    final targetLng = widget.assignment.effectiveDestinationLongitude;
    final targetRadius = widget.assignment.destinationRadius > 0
        ? widget.assignment.destinationRadius
        : 100;

    if (targetLat != null && targetLng != null && targetLat != 0 && targetLng != 0) {
      if (!_isAtDestination) {
        final dist = _distanceToDestinationMeters?.round() ?? 0;
        if (mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.location_off_rounded, color: Colors.orange, size: 24),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Outside Destination Area',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'You are not at the selected destination.',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Please reach the destination before completing OD.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Current Distance: $dist m', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF991B1B), fontSize: 12)),
                        Text('Allowed: $targetRadius m', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF991B1B), fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (targetLat != 0 && targetLng != 0) {
                      _openMap(targetLat, targetLng);
                    }
                  },
                  child: const Text('View on Map'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9CC70A),
                    foregroundColor: const Color(0xFF414A51),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _checkDestinationGeofence();
                  },
                  child: const Text('Re-check GPS', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
        return;
      }
    }

    setState(() => _isActionLoading = true);
    try {
      final position = await _getGpsPosition();
      final nowStr = DateFormat('hh:mm a').format(DateTime.now());
      final nowTime24 = '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}';
      final empIdInt = widget.assignment.employeeId > 0 ? widget.assignment.employeeId : 1;
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

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

      // 2. Complete OD Attendance Session
      final attendanceRepo = ref.read(attendanceRepositoryProvider);
      final completeResult = await attendanceRepo.completeOdAttendanceSession(
        employeeId: empIdInt,
        employeeName: widget.assignment.employeeName,
        date: todayStr,
        time: nowTime24,
        assignmentId: widget.assignment.id,
        latitude: position?.latitude,
        longitude: position?.longitude,
        destinationLatitude: widget.assignment.effectiveDestinationLatitude,
        destinationLongitude: widget.assignment.effectiveDestinationLongitude,
        destinationRadius: widget.assignment.destinationRadius,
        afterCompletionOption: widget.assignment.afterCompletionOption,
      );

      if (!completeResult.allowed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(completeResult.message), backgroundColor: Colors.red),
          );
        }
        return;
      }

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
      ref.invalidate(attendanceRecordsProvider(empIdInt));
      ref.invalidate(todayAttendanceRecordProvider(empIdInt));
      ref.invalidate(allAttendanceRecordsProvider);
      _timer?.cancel();
      _gpsCheckTimer?.cancel();
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

  Future<void> _handleCheckoutFromOdLocation() async {
    setState(() => _isActionLoading = true);
    try {
      final empIdInt = widget.assignment.employeeId > 0 ? widget.assignment.employeeId : 1;
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final nowTime24 = '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}';

      final attendanceRepo = ref.read(attendanceRepositoryProvider);
      final position = await _getGpsPosition();

      await attendanceRepo.completeOdAttendanceSession(
        employeeId: empIdInt,
        employeeName: widget.assignment.employeeName,
        date: todayStr,
        time: nowTime24,
        assignmentId: widget.assignment.id,
        latitude: position?.latitude,
        longitude: position?.longitude,
        destinationLatitude: widget.assignment.effectiveDestinationLatitude,
        destinationLongitude: widget.assignment.effectiveDestinationLongitude,
        destinationRadius: widget.assignment.destinationRadius,
        afterCompletionOption: 'CHECKOUT_FROM_OD',
      );

      ref.invalidate(attendanceRecordsProvider(empIdInt));
      ref.invalidate(todayAttendanceRecordProvider(empIdInt));
      ref.invalidate(allAttendanceRecordsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance Completed — Checked out from OD Location!'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to check out from OD Location: $e')),
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
    } else if (status == 'IN_PROGRESS' || status == 'ACTIVE') {
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
    final destLat = widget.assignment.effectiveDestinationLatitude;
    final destLng = widget.assignment.effectiveDestinationLongitude;
    final hasDestCoords = destLat != null && destLng != null && destLat != 0 && destLng != 0;

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
                // Destination Name & Address
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.assignment.effectiveDestinationTitle,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
                          ),
                          if (widget.assignment.destinationAddress.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.assignment.destinationAddress,
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (hasDestCoords)
                      IconButton(
                        icon: const Icon(Icons.map_outlined, color: Color(0xFF414A51), size: 22),
                        tooltip: 'View Destination on Map',
                        onPressed: () => _openMap(destLat, destLng),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Geofence & Coordinates Tag
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.pin_drop, size: 13, color: Color(0xFF414A51)),
                          const SizedBox(width: 4),
                          Text(
                            hasDestCoords
                                ? 'Target: ${destLat.toStringAsFixed(3)}°, ${destLng.toStringAsFixed(3)}° (Within ${widget.assignment.destinationRadius}m)'
                                : 'Destination Target Set ✓',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                        : const Icon(Icons.play_arrow_rounded, size: 22),
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
  // Card View 2: IN_PROGRESS State (Live Geofence)
  // ==========================================
  Widget _buildInProgressCard() {
    final destLat = widget.assignment.effectiveDestinationLatitude;
    final destLng = widget.assignment.effectiveDestinationLongitude;
    final destRadius = widget.assignment.destinationRadius > 0 ? widget.assignment.destinationRadius : 100;
    final hasDestCoords = destLat != null && destLng != null && destLat != 0 && destLng != 0;
    final dist = _distanceToDestinationMeters?.round();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isAtDestination ? const Color(0xFF16A34A) : const Color(0xFFD97706),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (_isAtDestination ? const Color(0xFF16A34A) : const Color(0xFFD97706)).withValues(alpha: 0.08),
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
            decoration: BoxDecoration(
              color: _isAtDestination ? const Color(0xFF16A34A) : const Color(0xFFD97706),
              borderRadius: const BorderRadius.only(
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
                      'OD IN PROGRESS (${widget.assignment.odType.toUpperCase()})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
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
                // Destination Info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.assignment.effectiveDestinationTitle,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
                          ),
                          if (widget.assignment.destinationAddress.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.assignment.destinationAddress,
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (hasDestCoords)
                      IconButton(
                        icon: const Icon(Icons.directions, color: Color(0xFF414A51), size: 24),
                        tooltip: 'Navigate / View on Map',
                        onPressed: () => _openMap(destLat, destLng),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Text(
                      'Started: ${widget.assignment.actualStartTime ?? "Just now"}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF414A51), fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: _isCheckingGps
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh, size: 18, color: Color(0xFF414A51)),
                      tooltip: 'Refresh GPS Status',
                      onPressed: _isCheckingGps ? null : () => _checkDestinationGeofence(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Real-Time Destination Geofence Card
                if (hasDestCoords) ...[
                  if (_isAtDestination) ...[
                    // State: At Destination ✓
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Destination reached ✓',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dist != null
                                      ? 'Distance: $dist m • Within $destRadius m allowed geofence'
                                      : 'You are within the allowed destination radius',
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF166534)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // State: Outside Destination ⚠
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '⚠ You are outside the destination area.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF991B1B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                dist != null ? 'Distance: $dist m' : 'Checking GPS...',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7F1D1D)),
                              ),
                              const Text('  •  ', style: TextStyle(color: Color(0xFF991B1B))),
                              Text(
                                'Required: Within $destRadius m',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (_gpsStatusMessage != null && _gpsStatusMessage!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _gpsStatusMessage!,
                              style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C), fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 16),

                // Complete OD Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isActionLoading
                        ? null
                        : (_isAtDestination ? _handleCompleteOd : () => _handleCompleteOd()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isAtDestination ? const Color(0xFF16A34A) : Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: _isAtDestination ? 2 : 0,
                    ),
                    icon: _isActionLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline, size: 20),
                    label: Text(
                      _isAtDestination ? '[ COMPLETE OD ]' : '[ COMPLETE OD (Disabled - Outside Site) ]',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
    final isReturnToOffice = widget.assignment.afterCompletionOption == 'RETURN_TO_OFFICE';

    final empIdInt = widget.assignment.employeeId > 0 ? widget.assignment.employeeId : 1;
    final todayAttendanceAsync = ref.watch(todayAttendanceRecordProvider(empIdInt));
    final todayAttendance = todayAttendanceAsync.valueOrNull;
    final isCheckedOut = todayAttendance != null &&
        todayAttendance.checkOutTime.trim().isNotEmpty &&
        todayAttendance.checkOutTime != '--:--';

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
              widget.assignment.effectiveDestinationTitle,
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
            const SizedBox(height: 12),

            if (isReturnToOffice) ...[
              // Option 1: Return to Office Instruction
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.location_city_rounded, color: Color(0xFFD97706), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'OD Completed — Please return to the office to check out.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Option 2: Checkout from OD Location Action
              if (isCheckedOut) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Attendance Completed ✓ (Checked out at ${todayAttendance.checkOutTime})',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF14532D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isActionLoading ? null : _handleCheckoutFromOdLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9CC70A),
                      foregroundColor: const Color(0xFF414A51),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 1,
                    ),
                    icon: _isActionLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF414A51)),
                          )
                        : const Icon(Icons.output_rounded, size: 18),
                    label: const Text(
                      'Check Out from OD Location',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                  ),
                ),
              ],
            ],
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
}
