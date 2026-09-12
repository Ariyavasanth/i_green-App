import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/on_duty_assignment.dart';
import '../domain/on_duty_site.dart';
import '../providers/on_duty_providers.dart';
import 'widgets/on_duty_camera_page.dart';
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
        oldWidget.assignment.returnStartTime != widget.assignment.returnStartTime ||
        oldWidget.assignment.sites != widget.assignment.sites) {
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

    final activeSite = widget.assignment.currentSite;

    if (status == 'REACHED_DESTINATION') {
      startTime = _parseTimeString(activeSite?.reachedTime ?? widget.assignment.reachedTime ?? widget.assignment.actualStartTime);
    } else if (status == 'RETURNING_TO_OFFICE') {
      startTime = _parseTimeString(widget.assignment.returnStartTime);
    } else {
      startTime = _parseTimeString(activeSite?.travelStartTime ?? widget.assignment.travelStartTime ?? widget.assignment.actualStartTime);
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
      final targetRadius = widget.assignment.effectiveDestinationRadius > 0
          ? widget.assignment.effectiveDestinationRadius
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
  // MULTI-SITE SEQUENTIAL HANDLERS
  // =========================================================================

  Future<void> _handleStartSiteTrip(int siteIndex) async {
    final attendanceRepo = ref.read(attendanceRepositoryProvider);
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final empIdInt = widget.assignment.employeeId > 0 ? widget.assignment.employeeId : 1;

    if (siteIndex == 0) {
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
                    'You are currently checked in at the Office. Would you like to check out of the office now and start your On-Duty trip?',
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
    }

    setState(() => _isActionLoading = true);
    try {
      final position = await _getGpsPosition();
      final nowStr = DateFormat('hh:mm a').format(DateTime.now());
      final nowTime24 = '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}';

      final sitesList = List<OnDutySite>.from(widget.assignment.sites);
      final site = sitesList[siteIndex];

      sitesList[siteIndex] = site.copyWith(
        status: 'TRAVELING',
        travelStartTime: nowStr,
        startLatitude: position?.latitude,
        startLongitude: position?.longitude,
      );

      if (siteIndex == 0) {
        await attendanceRepo.startOdAttendanceSession(
          employeeId: empIdInt,
          employeeName: widget.assignment.employeeName,
          date: todayStr,
          time: nowTime24,
          assignmentId: widget.assignment.id,
          purpose: site.purpose.isNotEmpty ? site.purpose : widget.assignment.purpose,
          destination: site.effectiveName,
          destinationAddress: site.destinationAddress,
          latitude: position?.latitude,
          longitude: position?.longitude,
          destinationLatitude: site.latitude,
          destinationLongitude: site.longitude,
          destinationRadius: site.radius,
          startOdFromHome: widget.assignment.startOdFromHome,
          notes: widget.assignment.startOdFromHome
              ? 'OD Starts from Home Site 1: ${site.effectiveName}'
              : 'On Duty Site 1: ${site.effectiveName}',
        );
      }

      final updated = widget.assignment.copyWith(
        status: 'TRAVELING_TO_DESTINATION',
        travelStartTime: nowStr,
        actualStartTime: widget.assignment.actualStartTime ?? nowStr,
        destination: site.effectiveName,
        destinationName: site.effectiveName,
        destinationAddress: site.destinationAddress,
        destinationLatitude: site.latitude,
        destinationLongitude: site.longitude,
        destinationRadius: site.radius,
        sites: sitesList,
      );

      final repo = ref.read(onDutyRepositoryProvider);
      await repo.updateAssignment(updated);

      _invalidateProviders();
      _startLiveTimer();
      _checkDestinationGeofence();
      _startPeriodicGpsCheck();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trip started for Site ${siteIndex + 1} (${site.effectiveName})!'),
            backgroundColor: const Color(0xFF414A51),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start site trip: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleReachedSite(int siteIndex) async {
    final site = widget.assignment.sites[siteIndex];

    final photo = await _captureLivePhoto(
      title: 'Arrival Proof - Site ${siteIndex + 1}',
      subtitle: 'Capture a live photo at ${site.effectiveName} to verify your arrival.',
    );
    if (photo == null) return;

    setState(() => _isActionLoading = true);
    try {
      final position = await _getGpsPosition();
      final nowStr = DateFormat('hh:mm a').format(DateTime.now());

      final sitesList = List<OnDutySite>.from(widget.assignment.sites);
      sitesList[siteIndex] = site.copyWith(
        status: 'REACHED',
        reachedTime: nowStr,
        reachedPhoto: photo,
        reachedLatitude: position?.latitude ?? site.latitude,
        reachedLongitude: position?.longitude ?? site.longitude,
      );

      final updated = widget.assignment.copyWith(
        status: 'REACHED_DESTINATION',
        reachedTime: nowStr,
        reachedPhoto: photo,
        reachedLatitude: position?.latitude ?? site.latitude,
        reachedLongitude: position?.longitude ?? site.longitude,
        sites: sitesList,
      );

      final repo = ref.read(onDutyRepositoryProvider);
      await repo.updateAssignment(updated);

      _invalidateProviders();
      _startLiveTimer();
      _checkDestinationGeofence();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Arrival verified at Site ${siteIndex + 1} (${site.effectiveName}) ✓'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to confirm site arrival: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleCompleteSiteWork(int siteIndex) async {
    final site = widget.assignment.sites[siteIndex];

    final photo = await _captureLivePhoto(
      title: 'Work Proof - Site ${siteIndex + 1}',
      subtitle: 'Capture photo proof of completed work at ${site.effectiveName}.',
    );
    if (photo == null) return;

    setState(() => _isActionLoading = true);
    try {
      final position = await _getGpsPosition();
      final nowStr = DateFormat('hh:mm a').format(DateTime.now());
      final empIdInt = widget.assignment.employeeId > 0 ? widget.assignment.employeeId : 1;
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final nowTime24 = '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}';

      final sitesList = List<OnDutySite>.from(widget.assignment.sites);
      sitesList[siteIndex] = site.copyWith(
        status: 'COMPLETED',
        workCompletedTime: nowStr,
        workPhoto: photo,
        workEndLatitude: position?.latitude,
        workEndLongitude: position?.longitude,
      );

      final allCompleted = sitesList.every((s) => s.isCompleted);
      final isReturnToOffice = widget.assignment.isReturnToOfficeOption;

      if (allCompleted && !isReturnToOffice) {
        // Direct checkout option
        final attendanceRepo = ref.read(attendanceRepositoryProvider);
        await attendanceRepo.completeOdAttendanceSession(
          employeeId: empIdInt,
          employeeName: widget.assignment.employeeName,
          date: todayStr,
          time: nowTime24,
          assignmentId: widget.assignment.id,
          latitude: position?.latitude,
          longitude: position?.longitude,
          destinationLatitude: site.latitude,
          destinationLongitude: site.longitude,
          destinationRadius: site.radius,
          afterCompletionOption: 'CHECKOUT_FROM_OD',
        );

        final updated = widget.assignment.copyWith(
          status: 'COMPLETED',
          workCompletedTime: nowStr,
          workPhoto: photo,
          actualEndTime: nowStr,
          sites: sitesList,
        );

        final repo = ref.read(onDutyRepositoryProvider);
        await repo.updateAssignment(updated);

        _invalidateProviders();
        _timer?.cancel();
        _gpsCheckTimer?.cancel();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All site visits finished! Checked out directly from site.'),
              backgroundColor: Color(0xFF16A34A),
            ),
          );
        }
      } else {
        final newStatus = allCompleted ? 'WORK_COMPLETED' : 'IN_PROGRESS';

        final updated = widget.assignment.copyWith(
          status: newStatus,
          workCompletedTime: nowStr,
          workPhoto: photo,
          sites: sitesList,
        );

        final repo = ref.read(onDutyRepositoryProvider);
        await repo.updateAssignment(updated);

        _invalidateProviders();

        if (mounted) {
          final snackMsg = allCompleted
              ? 'All sites completed ✓ Return to Office is now available.'
              : 'Site ${siteIndex + 1} (${site.effectiveName}) completed! Site ${siteIndex + 2} is now unlocked.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(snackMsg), backgroundColor: const Color(0xFF16A34A)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete site work: $e'), backgroundColor: Colors.red),
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
    int returnMins = _activeElapsed.inMinutes;
    if (returnMins <= 0 && widget.assignment.returnStartTime != null) {
      final startDt = _parseTimeString(widget.assignment.returnStartTime);
      returnMins = DateTime.now().difference(startDt).inMinutes;
    }
    if (returnMins < 0) returnMins = 0;

    final travelMins = widget.assignment.travelToSiteDurationMinutes;
    final workMins = widget.assignment.onSiteWorkDurationMinutes;
    final totalTripMins = travelMins + workMins + returnMins;

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
                        _buildDurationRow('1. Site Visits Completed:', '${widget.assignment.sites.length} Sites ✓'),
                        const SizedBox(height: 6),
                        _buildDurationRow('2. Total On-Site Duration:', _formatMinutes(totalTripMins)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Click Confirm to check out from On-Duty and complete this assignment.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9CC70A),
                    foregroundColor: const Color(0xFF414A51),
                  ),
                  child: const Text('Confirm & Checkout', style: TextStyle(fontWeight: FontWeight.bold)),
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

      final attendanceRepo = ref.read(attendanceRepositoryProvider);
      final result = await attendanceRepo.completeOdAttendanceSession(
        employeeId: empIdInt,
        employeeName: widget.assignment.employeeName,
        date: todayStr,
        time: nowTime24,
        assignmentId: widget.assignment.id,
        latitude: position?.latitude,
        longitude: position?.longitude,
        afterCompletionOption: 'RETURN_TO_OFFICE',
      );

      if (!result.allowed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to complete OD attendance: ${result.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final updated = widget.assignment.copyWith(
        status: 'COMPLETED',
        officeReachedTime: nowStr,
        actualEndTime: nowStr,
        officeLatitude: position?.latitude,
        officeLongitude: position?.longitude,
        returnTravelDurationMinutes: returnMins,
        durationMinutes: totalTripMins > 0 ? totalTripMins : returnMins,
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

    if (status == 'COMPLETED') {
      return _buildCompletedCard();
    }

    return _buildSequentialOdCard();
  }

  Widget _buildSequentialOdCard() {
    final assignment = widget.assignment;
    final sites = assignment.sites;
    final primaryColor = const Color(0xFF9CC70A);
    final darkAccent = const Color(0xFF414A51);

    final isReturnPhase = assignment.status == 'RETURNING_TO_OFFICE';
    final allDone = assignment.allSitesCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor, width: 1.5),
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
            decoration: BoxDecoration(
              color: darkAccent,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.directions_car_filled_rounded, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ON-DUTY: ${assignment.odType.toUpperCase()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (assignment.isOngoing && !assignment.isAssigned) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 13, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          _formatTimerDisplay(_activeElapsed),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Details Body
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMetaRow(Icons.person_outline, 'Employee', assignment.employeeName, isBold: true),
                const SizedBox(height: 6),
                _buildMetaRow(Icons.lightbulb_outline, 'OD Purpose', assignment.purpose, isBold: true),
                if (assignment.startOdFromHome) ...[
                  const SizedBox(height: 6),
                  _buildMetaRow(Icons.home_outlined, 'Start Mode', 'OD Starts from Home (Auto Check-In)', isBold: true),
                ],
                const SizedBox(height: 14),

                // Added Sites Sequential Section
                Row(
                  children: [
                    Text(
                      'Added Sites (${sites.length}):',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (sites.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(assignment.effectiveDestinationTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sites.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, index) {
                      final site = sites[index];
                      final isCurrentActive = index == assignment.currentSiteIndex && !allDone;
                      final canStart = assignment.canStartSite(index);
                      final isLocked = !canStart && !site.isCompleted;

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: site.isCompleted
                              ? Colors.green.shade50
                              : (isCurrentActive ? primaryColor.withValues(alpha: 0.1) : (isLocked ? Colors.grey.shade100 : Colors.white)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: site.isCompleted
                                ? Colors.green.shade400
                                : (isCurrentActive ? primaryColor : (isLocked ? Colors.grey.shade300 : primaryColor.withValues(alpha: 0.5))),
                            width: isCurrentActive ? 2.0 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: site.isCompleted
                                        ? Colors.green
                                        : (isCurrentActive ? primaryColor : (isLocked ? Colors.grey : darkAccent)),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        site.effectiveName,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: isLocked ? Colors.grey.shade600 : darkAccent,
                                        ),
                                      ),
                                      if (site.purpose.isNotEmpty)
                                        Text(
                                          'Purpose: ${site.purpose}',
                                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                                        ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: site.isCompleted
                                        ? Colors.green.shade100
                                        : (isCurrentActive
                                            ? primaryColor.withValues(alpha: 0.25)
                                            : (isLocked ? Colors.grey.shade200 : Colors.blue.shade50)),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    site.isCompleted
                                        ? 'Completed ✓'
                                        : (isCurrentActive
                                            ? (site.isReached ? 'Arrived' : (site.isTraveling ? 'Traveling' : 'Active'))
                                            : (isLocked ? 'Locked 🔒' : 'Pending')),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: site.isCompleted
                                          ? Colors.green.shade800
                                          : (isCurrentActive
                                              ? darkAccent
                                              : (isLocked ? Colors.grey.shade700 : Colors.blue.shade900)),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            _buildSiteLocationProofsBox(site: site, siteIndex: index + 1, assignment: widget.assignment),

                            // Action Button for active/current site
                            if (!allDone && canStart && !site.isCompleted) ...[
                              const SizedBox(height: 10),
                              if (site.isPending) ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _isActionLoading ? null : () => _handleStartSiteTrip(index),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: darkAccent,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.directions_car, size: 18),
                                    label: Text(
                                      '[ Start Site ${index + 1} (${site.effectiveName}) ]',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                    ),
                                  ),
                                ),
                              ] else if (site.isTraveling) ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _isActionLoading ? null : () => _handleReachedSite(index),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: darkAccent,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.camera_alt, size: 18),
                                    label: Text(
                                      '[ Reached Site ${index + 1} (Capture Photo) ]',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                    ),
                                  ),
                                ),
                              ] else if (site.isReached) ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _isActionLoading ? null : () => _handleCompleteSiteWork(index),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF16A34A),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.check_circle_outline, size: 18),
                                    label: Text(
                                      '[ Complete Site ${index + 1} Work (Photo Proof) ]',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 16),

                // Return to Office -> Checkout section once all sites are completed
                if (allDone) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'All Planned Sites Completed ✓',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF14532D)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          assignment.isReturnToOfficeOption
                              ? 'Please return to office location to complete final check-out.'
                              : 'You can now complete checkout directly.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF166534)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (assignment.isReturnToOfficeOption) ...[
                    if (!isReturnPhase) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isActionLoading ? null : _handleStartReturnTrip,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: darkAccent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.directions_car_filled, size: 20),
                          label: const Text(
                            '[ Return to Office ]',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isActionLoading ? null : _handleCameToOffice,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: darkAccent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.location_city, size: 20),
                          label: const Text(
                            '[ Reached Office - Checkout ]',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                children: [
                  _buildDurationRow('1. Sites Visited:', '${widget.assignment.sites.length} Sites ✓'),
                  const SizedBox(height: 4),
                  _buildDurationRow('2. Travel to Site:', _formatMinutes(widget.assignment.travelToSiteDurationMinutes)),
                  const SizedBox(height: 4),
                  _buildDurationRow('3. On-Site Work:', _formatMinutes(widget.assignment.onSiteWorkDurationMinutes)),
                  if (isReturnToOffice) ...[
                    const SizedBox(height: 4),
                    _buildDurationRow('4. Return to Office:', _formatMinutes(widget.assignment.returnTravelDurationMinutes)),
                  ],
                  const Divider(height: 12, color: Color(0xFFE2E8F0)),
                  _buildDurationRow('Total OD Logged:', _formatMinutes(totalMin), isTotal: true),
                ],
              ),
            ),
            const SizedBox(height: 10),
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

  Widget _buildSiteLocationProofsBox({
    required OnDutySite site,
    required int siteIndex,
    OnDutyAssignment? assignment,
  }) {
    final startLat = site.startLatitude ?? (siteIndex == 1 ? assignment?.startTripLatitude ?? assignment?.startLatitude : null);
    final startLng = site.startLongitude ?? (siteIndex == 1 ? assignment?.startTripLongitude ?? assignment?.startLongitude : null);

    final reachedLat = site.reachedLatitude ?? (siteIndex == 1 ? assignment?.reachedLatitude : null);
    final reachedLng = site.reachedLongitude ?? (siteIndex == 1 ? assignment?.reachedLongitude : null);

    final endLat = site.workEndLatitude ?? (siteIndex == 1 ? assignment?.workEndLatitude : null);
    final endLng = site.workEndLongitude ?? (siteIndex == 1 ? assignment?.workEndLongitude : null);

    final hasAnyLocation = (startLat != null && startLng != null) ||
        (reachedLat != null && reachedLng != null) ||
        (endLat != null && endLng != null);

    if (!hasAnyLocation) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.my_location, size: 13, color: Color(0xFF414A51)),
              SizedBox(width: 4),
              Text(
                'STAGE GPS LOCATIONS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: Color(0xFF414A51),
                ),
              ),
            ],
          ),
          if (startLat != null && startLng != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.navigation_outlined, size: 14, color: Color(0xFFD97706)),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Started Location',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                      ),
                      Text(
                        '${startLat.toStringAsFixed(5)}, ${startLng.toStringAsFixed(5)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => _openMap(startLat, startLng),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map_outlined, size: 12, color: Color(0xFF2563EB)),
                        SizedBox(width: 3),
                        Text('Map', style: TextStyle(fontSize: 10.5, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (reachedLat != null && reachedLng != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Color(0xFF2563EB)),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reached Location',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                      ),
                      Text(
                        '${reachedLat.toStringAsFixed(5)}, ${reachedLng.toStringAsFixed(5)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => _openMap(reachedLat, reachedLng),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map_outlined, size: 12, color: Color(0xFF2563EB)),
                        SizedBox(width: 3),
                        Text('Map', style: TextStyle(fontSize: 10.5, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (endLat != null && endLng != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF16A34A)),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Completed Location',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                      ),
                      Text(
                        '${endLat.toStringAsFixed(5)}, ${endLng.toStringAsFixed(5)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => _openMap(endLat, endLng),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map_outlined, size: 12, color: Color(0xFF2563EB)),
                        SizedBox(width: 3),
                        Text('Map', style: TextStyle(fontSize: 10.5, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
