import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/on_duty_assignment.dart';
import '../providers/on_duty_providers.dart';
import 'widgets/on_duty_camera_page.dart';
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
  Duration _activeElapsed = Duration.zero;
  bool _isActionLoading = false;
  bool _isCheckingGps = false;

  // Real-time Geofence validation state
  double? _distanceToDestinationMeters;
  bool _isAtDestination = false;
  String? _gpsStatusMessage;

  @override
  void initState() {
    super.initState();
    _initCardState();
  }

  @override
  void didUpdateWidget(covariant EmployeeOnDutyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assignment.status != widget.assignment.status ||
        oldWidget.assignment.actualStartTime != widget.assignment.actualStartTime ||
        oldWidget.assignment.reachedTime != widget.assignment.reachedTime ||
        oldWidget.assignment.returnStartTime != widget.assignment.returnStartTime) {
      _initCardState();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _gpsCheckTimer?.cancel();
    super.dispose();
  }

  void _initCardState() {
    _timer?.cancel();
    _gpsCheckTimer?.cancel();

    final status = widget.assignment.status;
    if (status == 'TRAVELING_TO_DESTINATION' ||
        status == 'IN_PROGRESS' ||
        status == 'ACTIVE' ||
        status == 'REACHED_DESTINATION' ||
        status == 'RETURNING_TO_OFFICE') {
      _startLiveTimer();
      _checkDestinationGeofence();
      _startPeriodicGpsCheck();
    }
  }

  DateTime _parseTimeString(String? timeStr) {
    if (timeStr != null && timeStr.isNotEmpty) {
      try {
        final parsed = DateFormat('hh:mm a').parse(timeStr);
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute);
      } catch (_) {}
    }
    return DateTime.now();
  }

  void _startLiveTimer() {
    _timer?.cancel();
    final status = widget.assignment.status;
    DateTime startTime;

    if (status == 'REACHED_DESTINATION') {
      // On-site work timer
      startTime = _parseTimeString(widget.assignment.reachedTime ?? widget.assignment.actualStartTime);
    } else if (status == 'RETURNING_TO_OFFICE') {
      // Return travel timer
      startTime = _parseTimeString(widget.assignment.returnStartTime);
    } else {
      // Travel to destination timer
      startTime = _parseTimeString(widget.assignment.travelStartTime ?? widget.assignment.actualStartTime);
    }

    _activeElapsed = DateTime.now().difference(startTime);
    if (_activeElapsed.isNegative) _activeElapsed = Duration.zero;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          final diff = DateTime.now().difference(startTime);
          _activeElapsed = diff.isNegative ? Duration.zero : diff;
        });
      }
    });
  }

  void _startPeriodicGpsCheck() {
    _gpsCheckTimer?.cancel();
    _gpsCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && widget.assignment.isOngoing) {
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
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatMinutes(int minutes) {
    if (minutes <= 0) return '0m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0) {
      return m > 0 ? '${h}h ${m}m' : '${h}h';
    }
    return '${m}m';
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

  /// Direct Live Camera Capture (No gallery / storage access)
  Future<String?> _captureLivePhoto({required String title, required String subtitle}) async {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => OnDutyCameraPage(
          title: title,
          subtitle: subtitle,
        ),
      ),
    );
  }

  void _invalidateProviders() {
    ref.invalidate(activeOnDutyAssignmentProvider);
    ref.invalidate(allOnDutyAssignmentsProvider);
    ref.invalidate(employeeOnDutyAssignmentsProvider);
    ref.invalidate(attendanceRecordsProvider);
    ref.invalidate(todayAttendanceRecordProvider);
    ref.invalidate(todayAttendanceRecordProvider(widget.assignment.employeeId));
    ref.invalidate(todayAttendanceRecordProvider(1));
    ref.invalidate(attendanceRecordsProvider(widget.assignment.employeeId));
    ref.invalidate(attendanceRecordsProvider(1));
    ref.invalidate(allAttendanceRecordsProvider);
  }

  // =========================================================================
  // STEP 1: START OD TRIP
  // =========================================================================
  Future<void> _handleStartOdTrip() async {
    final attendanceRepo = ref.read(attendanceRepositoryProvider);
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final empIdInt = widget.assignment.employeeId > 0 ? widget.assignment.employeeId : 1;

    // Check office check-in
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
              'You are currently checked in at the Office. Please check out of the office before starting your On-Duty trip.',
              style: TextStyle(fontSize: 14, color: Color(0xFF334155)),
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

    // Mutual Exclusion: Tasks or Clock entries
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
              '$runningName is currently running.\n\nPlease finish the active task before starting On-Duty trip.',
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

    setState(() => _isActionLoading = true);
    try {
      final position = await _getGpsPosition();
      final nowStr = DateFormat('hh:mm a').format(DateTime.now());
      final nowTime24 = '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}';

      // Start Attendance OD Session
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
        status: 'TRAVELING_TO_DESTINATION',
        travelStartTime: nowStr,
        actualStartTime: nowStr,
        startTripLatitude: position?.latitude,
        startTripLongitude: position?.longitude,
        startLatitude: position?.latitude,
        startLongitude: position?.longitude,
      );

      final repo = ref.read(onDutyRepositoryProvider);
      await repo.updateAssignment(updated);

      _invalidateProviders();
      _startLiveTimer();
      _checkDestinationGeofence();
      _startPeriodicGpsCheck();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OD Trip Started! Traveling to destination...'),
            backgroundColor: Color(0xFF414A51),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start OD trip: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  // =========================================================================
  // STEP 2: REACHED DESTINATION
  // =========================================================================
  Future<void> _handleReachedDestination() async {
    // 1. Capture Camera Photo
    final photo = await _captureLivePhoto(
      title: 'Arrival Live Photo Proof',
      subtitle: 'Please capture a clear photo of yourself at the site to verify your arrival.',
    );
    if (photo == null) return;

    setState(() => _isActionLoading = true);
    try {
      final position = await _getGpsPosition();
      final nowStr = DateFormat('hh:mm a').format(DateTime.now());

      // Calculate travel to site duration
      int travelMins = _activeElapsed.inMinutes;
      if (travelMins <= 0 && widget.assignment.travelStartTime != null) {
        final startDt = _parseTimeString(widget.assignment.travelStartTime);
        travelMins = DateTime.now().difference(startDt).inMinutes;
      }
      if (travelMins < 0) travelMins = 0;

      final updated = widget.assignment.copyWith(
        status: 'REACHED_DESTINATION',
        reachedTime: nowStr,
        reachedPhoto: photo,
        startPhoto: photo,
        reachedLatitude: position?.latitude ?? widget.assignment.effectiveDestinationLatitude,
        reachedLongitude: position?.longitude ?? widget.assignment.effectiveDestinationLongitude,
        travelToSiteDurationMinutes: travelMins,
      );

      final repo = ref.read(onDutyRepositoryProvider);
      await repo.updateAssignment(updated);

      _invalidateProviders();
      _startLiveTimer();
      _checkDestinationGeofence();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Arrival Verified ✓ On-Site Work Timer Started!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to confirm arrival: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  // =========================================================================
  // STEP 3: COMPLETE OD WORK
  // =========================================================================
  Future<void> _handleCompleteOdWork() async {
    // 1. Capture Work Completion Photo
    final photo = await _captureLivePhoto(
      title: 'Work Completion Photo Proof',
      subtitle: 'Please capture a photo demonstrating the completed work / meeting proof.',
    );
    if (photo == null) return;

    setState(() => _isActionLoading = true);
    try {
      final position = await _getGpsPosition();
      final nowStr = DateFormat('hh:mm a').format(DateTime.now());
      final nowTime24 = '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}';
      final empIdInt = widget.assignment.employeeId > 0 ? widget.assignment.employeeId : 1;
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Calculate on-site work duration
      int workMins = _activeElapsed.inMinutes;
      if (workMins <= 0 && widget.assignment.reachedTime != null) {
        final startDt = _parseTimeString(widget.assignment.reachedTime);
        workMins = DateTime.now().difference(startDt).inMinutes;
      }
      if (workMins < 0) workMins = 0;

      final isReturnToOffice = widget.assignment.isReturnToOfficeOption;

      if (!isReturnToOffice) {
        // Direct Checkout from OD Location branch
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
          afterCompletionOption: 'CHECKOUT_FROM_OD',
        );

        if (!completeResult.allowed) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(completeResult.message), backgroundColor: Colors.red),
            );
          }
          return;
        }

        final totalMins = widget.assignment.travelToSiteDurationMinutes + workMins;

        final updated = widget.assignment.copyWith(
          status: 'COMPLETED',
          workCompletedTime: nowStr,
          workPhoto: photo,
          endPhoto: photo,
          actualEndTime: nowStr,
          workEndLatitude: position?.latitude,
          workEndLongitude: position?.longitude,
          endLatitude: position?.latitude,
          endLongitude: position?.longitude,
          onSiteWorkDurationMinutes: workMins,
          durationMinutes: totalMins > 0 ? totalMins : workMins,
        );

        final repo = ref.read(onDutyRepositoryProvider);
        await repo.updateAssignment(updated);

        _invalidateProviders();
        _timer?.cancel();
        _gpsCheckTimer?.cancel();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('OD Completed ✓ Checked out directly from site location!'),
              backgroundColor: Color(0xFF16A34A),
            ),
          );
        }
      } else {
        // Return to Office branch: Mark work completed, advance to Step 4
        final updated = widget.assignment.copyWith(
          status: 'WORK_COMPLETED',
          workCompletedTime: nowStr,
          workPhoto: photo,
          endPhoto: photo,
          workEndLatitude: position?.latitude,
          workEndLongitude: position?.longitude,
          onSiteWorkDurationMinutes: workMins,
        );

        final repo = ref.read(onDutyRepositoryProvider);
        await repo.updateAssignment(updated);

        _invalidateProviders();
        _timer?.cancel();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('OD work completed ✓ Click "Return to Office" to begin return trip.'),
              backgroundColor: Color(0xFF414A51),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete work: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  // =========================================================================
  // STEP 4: RETURN TO OFFICE (Start Return Travel)
  // =========================================================================
  Future<void> _handleStartReturnTrip() async {
    setState(() => _isActionLoading = true);
    try {
      final position = await _getGpsPosition();
      final nowStr = DateFormat('hh:mm a').format(DateTime.now());

      final updated = widget.assignment.copyWith(
        status: 'RETURNING_TO_OFFICE',
        returnStartTime: nowStr,
        returnLatitude: position?.latitude,
        returnLongitude: position?.longitude,
      );

      final repo = ref.read(onDutyRepositoryProvider);
      await repo.updateAssignment(updated);

      _invalidateProviders();
      _startLiveTimer();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Return office from site started! Traveling back to office...'),
            backgroundColor: Color(0xFF414A51),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start return trip: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  // =========================================================================
  // STEP 5: CAME TO OFFICE (Confirmation Popup -> Completed)
  // =========================================================================
  Future<void> _handleCameToOffice() async {
    // 1. Calculate durations for the summary popup
    int returnMins = _activeElapsed.inMinutes;
    if (returnMins <= 0 && widget.assignment.returnStartTime != null) {
      final startDt = _parseTimeString(widget.assignment.returnStartTime);
      returnMins = DateTime.now().difference(startDt).inMinutes;
    }
    if (returnMins < 0) returnMins = 0;

    final travelMins = widget.assignment.travelToSiteDurationMinutes;
    final workMins = widget.assignment.onSiteWorkDurationMinutes;
    final totalTripMins = travelMins + workMins + returnMins;

    // 2. Show Confirmation Popup (No photo required)
    bool confirmed = false;
    if (mounted) {
      confirmed = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.location_city_rounded, color: Color(0xFF9CC70A), size: 26),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Confirm Office Arrival',
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
                    'You have arrived back at the office. Here is your trip breakdown:',
                    style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _buildDurationRow('1. Travel to Site:', _formatMinutes(travelMins)),
                        const SizedBox(height: 6),
                        _buildDurationRow('2. On-Site Work:', _formatMinutes(workMins)),
                        const SizedBox(height: 6),
                        _buildDurationRow('3. Return to Office:', _formatMinutes(returnMins)),
                        const Divider(height: 14, color: Color(0xFFCBD5E1)),
                        _buildDurationRow('Total OD Duration:', _formatMinutes(totalTripMins), isTotal: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No photo upload needed. Click Confirm to log hours and complete this OD.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9CC70A),
                    foregroundColor: const Color(0xFF414A51),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 1,
                  ),
                  child: const Text('Confirm & Complete OD', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ) ??
          false;
    }

    if (!confirmed) return;

    setState(() => _isActionLoading = true);
    try {
      final position = await _getGpsPosition();
      final nowStr = DateFormat('hh:mm a').format(DateTime.now());
      final nowTime24 = '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}';
      final empIdInt = widget.assignment.employeeId > 0 ? widget.assignment.employeeId : 1;
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Complete Attendance Session
      final attendanceRepo = ref.read(attendanceRepositoryProvider);
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
        afterCompletionOption: 'RETURN_TO_OFFICE',
      );

      final updated = widget.assignment.copyWith(
        status: 'COMPLETED',
        officeReachedTime: nowStr,
        actualEndTime: nowStr,
        officeLatitude: position?.latitude,
        officeLongitude: position?.longitude,
        endLatitude: position?.latitude,
        endLongitude: position?.longitude,
        returnTravelDurationMinutes: returnMins,
        durationMinutes: totalTripMins > 0 ? totalTripMins : (travelMins + workMins + returnMins),
      );

      final repo = ref.read(onDutyRepositoryProvider);
      await repo.updateAssignment(updated);

      _invalidateProviders();
      _timer?.cancel();
      _gpsCheckTimer?.cancel();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('On-Duty Completed! All travel and working hours logged.'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete OD: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Widget _buildDurationRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 13.5 : 12.5,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: isTotal ? const Color(0xFF1E293B) : const Color(0xFF475569),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 14 : 12.5,
            fontWeight: FontWeight.bold,
            color: isTotal ? const Color(0xFF16A34A) : const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.assignment.status;

    if (status == 'ASSIGNED') {
      return _buildAssignedCard();
    } else if (status == 'TRAVELING_TO_DESTINATION' || (status == 'IN_PROGRESS' && widget.assignment.reachedTime == null)) {
      return _buildTravelingToDestinationCard();
    } else if (status == 'REACHED_DESTINATION') {
      return _buildWorkingOnSiteCard();
    } else if (status == 'WORK_COMPLETED') {
      return _buildWorkCompletedCard();
    } else if (status == 'RETURNING_TO_OFFICE') {
      return _buildReturningToOfficeCard();
    } else if (status == 'COMPLETED') {
      return _buildCompletedCard();
    }

    return const SizedBox.shrink();
  }

  // =========================================================================
  // VIEW 1: ASSIGNED STATE
  // =========================================================================
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
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9CC70A).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Step 1 of 5',
                    style: TextStyle(color: Color(0xFF9CC70A), fontWeight: FontWeight.bold, fontSize: 11),
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
                const SizedBox(height: 6),
                _buildMetaRow(
                  Icons.sync_alt_rounded,
                  'After OD',
                  widget.assignment.isReturnToOfficeOption ? 'Return to Office required' : 'Checkout directly from OD Site',
                ),
                const SizedBox(height: 16),

                // Start OD Trip Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isActionLoading ? null : _handleStartOdTrip,
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
                        : const Icon(Icons.directions_car_rounded, size: 22),
                    label: const Text(
                      '[ 1. START OD TRIP ]',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
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

  // =========================================================================
  // VIEW 2: TRAVELING TO DESTINATION STATE (Step 1 -> 2)
  // =========================================================================
  Widget _buildTravelingToDestinationCard() {
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
          color: const Color(0xFFD97706),
          width: 1.5,
        ),
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
                const Row(
                  children: [
                    Icon(Icons.directions_car_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'TRAVELING TO DESTINATION',
                      style: TextStyle(
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
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        _formatTimerDisplay(_activeElapsed),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      'Trip Started: ${widget.assignment.travelStartTime ?? widget.assignment.actualStartTime ?? "Just now"}',
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

                // Geofence status card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isAtDestination ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _isAtDestination ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isAtDestination ? Icons.check_circle : Icons.navigation_outlined,
                        color: _isAtDestination ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isAtDestination ? 'At Destination Area ✓' : 'En Route to Site',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _isAtDestination ? const Color(0xFF15803D) : const Color(0xFF92400E),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dist != null
                                  ? 'Distance to site: $dist m (Allowed geofence: $destRadius m)'
                                  : 'Tracking GPS coordinates...',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: _isAtDestination ? const Color(0xFF166534) : const Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Step 2 Button: I Have Reached (Camera + GPS)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isActionLoading ? null : _handleReachedDestination,
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
                        : const Icon(Icons.camera_alt_rounded, size: 20),
                    label: const Text(
                      '[ 2. I HAVE REACHED (CAPTURE PHOTO) ]',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
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

  // =========================================================================
  // VIEW 3: REACHED DESTINATION / WORKING ON SITE (Step 2 -> 3)
  // =========================================================================
  Widget _buildWorkingOnSiteCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF16A34A),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withValues(alpha: 0.08),
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
              color: Color(0xFF16A34A),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.engineering_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'WORKING ON SITE',
                      style: TextStyle(
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
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        _formatTimerDisplay(_activeElapsed),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(16.0),
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
                const SizedBox(height: 10),

                // Arrival & Travel details banner
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Reached: ${widget.assignment.reachedTime ?? "--"}',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                          ),
                        ],
                      ),
                      Text(
                        'Travel: ${_formatMinutes(widget.assignment.travelToSiteDurationMinutes)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                      ),
                      if (widget.assignment.effectiveReachedPhoto != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Photo ✓', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                _buildMetaRow(Icons.lightbulb_outline, 'Purpose', widget.assignment.purpose, isBold: true),
                const SizedBox(height: 6),
                _buildMetaRow(
                  Icons.sync_alt_rounded,
                  'Next Step',
                  widget.assignment.isReturnToOfficeOption
                      ? 'Complete work -> Start Return Trip to Office'
                      : 'Complete work -> Check out directly from site',
                ),
                const SizedBox(height: 16),

                // Step 3 Button: Complete OD Work (Capture proof photo)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isActionLoading ? null : _handleCompleteOdWork,
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
                        : const Icon(Icons.task_alt_rounded, size: 20),
                    label: const Text(
                      '[ 3. COMPLETE OD WORK (PHOTO PROOF) ]',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
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

  // =========================================================================
  // VIEW 4: WORK COMPLETED (Waiting to Return to Office) (Step 3 -> 4)
  // =========================================================================
  Widget _buildWorkCompletedCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF414A51), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              color: Color(0xFF414A51),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Color(0xFF9CC70A), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'OD WORK COMPLETED',
                      style: TextStyle(
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
                    color: const Color(0xFF9CC70A).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Step 4 of 5',
                    style: TextStyle(color: Color(0xFF9CC70A), fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.assignment.effectiveDestinationTitle,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
                ),
                const SizedBox(height: 10),

                // Metrics summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('Travel Time', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          const SizedBox(height: 2),
                          Text(
                            _formatMinutes(widget.assignment.travelToSiteDurationMinutes),
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
                          ),
                        ],
                      ),
                      Container(height: 24, width: 1, color: const Color(0xFFCBD5E1)),
                      Column(
                        children: [
                          const Text('On-Site Work', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          const SizedBox(height: 2),
                          Text(
                            _formatMinutes(widget.assignment.onSiteWorkDurationMinutes),
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                          ),
                        ],
                      ),
                      Container(height: 24, width: 1, color: const Color(0xFFCBD5E1)),
                      Column(
                        children: [
                          const Text('Work Proof', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          const SizedBox(height: 2),
                          const Text(
                            'Captured ✓',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFFD97706), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Work finished. Please click "Return to Office" when you head back.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Step 4 Button: Return to Office
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isActionLoading ? null : _handleStartReturnTrip,
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
                        : const Icon(Icons.directions_car_filled_rounded, size: 20),
                    label: const Text(
                      '[ 4. RETURN TO OFFICE ]',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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

  // =========================================================================
  // VIEW 5: RETURNING TO OFFICE STATE (Step 4 -> 5)
  // =========================================================================
  Widget _buildReturningToOfficeCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3B82F6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
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
              color: Color(0xFF3B82F6),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.directions_car_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'RETURNING TO OFFICE',
                      style: TextStyle(
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
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        _formatTimerDisplay(_activeElapsed),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Return Started: ${widget.assignment.returnStartTime ?? "Just now"}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF414A51), fontWeight: FontWeight.w600),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('En Route to Office', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Journey breakdown preview
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _buildDurationRow('1. Travel to Site:', _formatMinutes(widget.assignment.travelToSiteDurationMinutes)),
                      const SizedBox(height: 4),
                      _buildDurationRow('2. On-Site Work:', _formatMinutes(widget.assignment.onSiteWorkDurationMinutes)),
                      const SizedBox(height: 4),
                      _buildDurationRow('3. Return Travel (Live):', _formatTimerDisplay(_activeElapsed)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Step 5 Button: Came to Office (No photo needed)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isActionLoading ? null : _handleCameToOffice,
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
                        : const Icon(Icons.location_city_rounded, size: 20),
                    label: const Text(
                      '[ 5. CAME TO OFFICE (CONFIRM ARRIVAL) ]',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
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

  // =========================================================================
  // VIEW 6: COMPLETED STATE (Rich Journey Breakdown)
  // =========================================================================
  Widget _buildCompletedCard() {
    final totalMin = widget.assignment.durationMinutes > 0
        ? widget.assignment.durationMinutes
        : (widget.assignment.travelToSiteDurationMinutes +
            widget.assignment.onSiteWorkDurationMinutes +
            widget.assignment.returnTravelDurationMinutes);

    final isReturnToOffice = widget.assignment.isReturnToOfficeOption;
    final empIdInt = widget.assignment.employeeId > 0 ? widget.assignment.employeeId : 1;
    final todayAttendanceAsync = ref.watch(todayAttendanceRecordProvider(empIdInt));
    final todayAttendance = todayAttendanceAsync.valueOrNull;

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
                  '${widget.assignment.odType} - ENTIRE OD COMPLETED',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF14532D)),
                ),
              ],
            ),
            const Divider(height: 16),
            Text(
              widget.assignment.effectiveDestinationTitle,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
            ),
            const SizedBox(height: 8),

            // Segment Breakdown Cards
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                children: [
                  _buildDurationRow('1. Travel to Site:', _formatMinutes(widget.assignment.travelToSiteDurationMinutes)),
                  const SizedBox(height: 4),
                  _buildDurationRow('2. On-Site Work:', _formatMinutes(widget.assignment.onSiteWorkDurationMinutes)),
                  if (isReturnToOffice) ...[
                    const SizedBox(height: 4),
                    _buildDurationRow('3. Return to Office:', _formatMinutes(widget.assignment.returnTravelDurationMinutes)),
                  ],
                  const Divider(height: 12, color: Color(0xFFE2E8F0)),
                  _buildDurationRow('Total OD Logged:', _formatMinutes(totalMin), isTotal: true),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Proof tags
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Completed: ${widget.assignment.actualEndTime ?? "--"}',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF414A51), fontWeight: FontWeight.w600),
                ),
                Row(
                  children: [
                    if (widget.assignment.effectiveReachedPhoto != null)
                      const Text('Arrival Photo ✓  ', style: TextStyle(fontSize: 11, color: Color(0xFF15803D), fontWeight: FontWeight.w600)),
                    if (widget.assignment.effectiveWorkPhoto != null)
                      const Text('Work Photo ✓', style: TextStyle(fontSize: 11, color: Color(0xFF15803D), fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
            if (todayAttendance?.checkOutTime.isNotEmpty == true && todayAttendance?.checkOutTime != '--:--') ...[
              const SizedBox(height: 8),
              Text(
                'Attendance Checked out at: ${todayAttendance!.checkOutTime}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF15803D), fontWeight: FontWeight.w500),
              ),
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
