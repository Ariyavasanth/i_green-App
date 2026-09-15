import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/on_duty_assignment.dart';
import '../domain/on_duty_site.dart';
import '../providers/on_duty_providers.dart';
import 'assign_on_duty_dialog.dart';
import 'widgets/on_duty_camera_page.dart';
import 'widgets/work_proof_upload_dialog.dart';
import '../../attendance/providers/attendance_providers.dart';
import '../../employee/providers/employee_providers.dart';

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

  OnDutyAssignment? _localAssignment;
  OnDutyAssignment get _assignment => _localAssignment ?? widget.assignment;

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
    if (oldWidget.assignment != widget.assignment) {
      final prevStatus = _assignment.status;
      _localAssignment = _mergeAssignments(widget.assignment, _localAssignment);
      if (prevStatus != _assignment.status || oldWidget.assignment.id != widget.assignment.id) {
        _initCardState();
      }
    }
  }

  OnDutyAssignment _mergeAssignments(OnDutyAssignment remote, OnDutyAssignment? local) {
    if (local == null) return remote;

    int getRank(String s) {
      final u = s.toUpperCase();
      if (u == 'COMPLETED') return 6;
      if (u == 'RETURNING_TO_OFFICE') return 5;
      if (u == 'WORK_COMPLETED') return 4;
      if (u == 'REACHED_DESTINATION') return 3;
      if (u == 'TRAVELING_TO_DESTINATION' || u == 'IN_PROGRESS' || u == 'ACTIVE') return 2;
      if (u == 'ASSIGNED') return 1;
      return 0;
    }

    final localRank = getRank(local.status);
    final remoteRank = getRank(remote.status);
    final effectiveStatus = localRank > remoteRank ? local.status : remote.status;

    final mergedSites = List<OnDutySite>.from(remote.sites.isNotEmpty ? remote.sites : local.sites);
    for (int i = 0; i < mergedSites.length && i < local.sites.length; i++) {
      final localSite = local.sites[i];
      final remoteSite = mergedSites[i];
      if ((localSite.isReached || localSite.isCompleted || localSite.reachedPhoto != null) && !remoteSite.isCompleted) {
        mergedSites[i] = remoteSite.copyWith(
          status: localSite.status,
          reachedTime: localSite.reachedTime ?? remoteSite.reachedTime,
          reachedPhoto: localSite.reachedPhoto ?? remoteSite.reachedPhoto,
          reachedLatitude: localSite.reachedLatitude ?? remoteSite.reachedLatitude,
          reachedLongitude: localSite.reachedLongitude ?? remoteSite.reachedLongitude,
          workCompletedTime: localSite.workCompletedTime ?? remoteSite.workCompletedTime,
          workPhoto: localSite.workPhoto ?? remoteSite.workPhoto,
          workPhotos: localSite.workPhotos.isNotEmpty ? localSite.workPhotos : remoteSite.workPhotos,
        );
      }
    }

    return (localRank > remoteRank ? local : remote).copyWith(
      status: effectiveStatus,
      reachedTime: local.reachedTime ?? remote.reachedTime,
      reachedPhoto: local.reachedPhoto ?? remote.reachedPhoto,
      reachedLatitude: local.reachedLatitude ?? remote.reachedLatitude,
      reachedLongitude: local.reachedLongitude ?? remote.reachedLongitude,
      workCompletedTime: local.workCompletedTime ?? remote.workCompletedTime,
      workPhoto: local.workPhoto ?? remote.workPhoto,
      workPhotos: local.workPhotos.isNotEmpty ? local.workPhotos : remote.workPhotos,
      sites: mergedSites,
    );
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

    final status = _assignment.status;
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
    final status = _assignment.status;
    DateTime startTime;

    final activeSite = _assignment.currentSite;

    if (status == 'REACHED_DESTINATION') {
      startTime = _parseTimeString(activeSite?.reachedTime ?? _assignment.reachedTime ?? _assignment.actualStartTime);
    } else if (status == 'RETURNING_TO_OFFICE') {
      startTime = _parseTimeString(_assignment.returnStartTime);
    } else {
      startTime = _parseTimeString(activeSite?.travelStartTime ?? _assignment.travelStartTime ?? _assignment.actualStartTime);
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
      if (mounted && _assignment.isOngoing) {
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
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } catch (_) {
        return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      }
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

      final targetLat = _assignment.effectiveDestinationLatitude;
      final targetLng = _assignment.effectiveDestinationLongitude;
      final targetRadius = _assignment.effectiveDestinationRadius > 0
          ? _assignment.effectiveDestinationRadius
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
    final empId = widget.assignment.employeeId;
    ref.invalidate(activeOnDutyAssignmentProvider(empId));
    ref.invalidate(activeOnDutyAssignmentProvider(1));
    ref.invalidate(activeOnDutyAssignmentProvider(0));
    ref.invalidate(allOnDutyAssignmentsProvider);
    ref.invalidate(employeeOnDutyAssignmentsProvider);
    ref.invalidate(attendanceRecordsProvider);
    ref.invalidate(todayAttendanceRecordProvider);
    ref.invalidate(todayAttendanceRecordProvider(empId));
    ref.invalidate(todayAttendanceRecordProvider(1));
    ref.invalidate(attendanceRecordsProvider(empId));
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

      final sitesList = List<OnDutySite>.from(_assignment.effectiveSites);
      final targetIndex = siteIndex < sitesList.length ? siteIndex : 0;
      final site = sitesList[targetIndex];

      sitesList[targetIndex] = site.copyWith(
        status: 'TRAVELING',
        travelStartTime: nowStr,
        startLatitude: position?.latitude,
        startLongitude: position?.longitude,
      );

      if (siteIndex == 0) {
        // Only start attendance session when starting trip if NOT starting from home.
        // If starting from home, check-in time will be recorded when the employee actually reaches the site.
        if (!widget.assignment.startOdFromHome) {
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
            startOdFromHome: false,
            notes: 'On Duty Site 1: ${site.effectiveName}',
          );
        }
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

      if (mounted) {
        setState(() {
          _localAssignment = updated;
        });
      }

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
    final currentSites = _assignment.effectiveSites;
    final site = siteIndex < currentSites.length ? currentSites[siteIndex] : currentSites.first;

    setState(() => _isActionLoading = true);
    try {
      final position = await _getGpsPosition();
      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to capture GPS position. Please enable location services.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final targetLat = site.latitude ?? _assignment.destinationLatitude;
      final targetLng = site.longitude ?? _assignment.destinationLongitude;
      final targetRadius = site.radius > 0
          ? site.radius
          : (_assignment.destinationRadius > 0 ? _assignment.destinationRadius : 100);

      if (targetLat != null && targetLng != null && targetLat != 0 && targetLng != 0) {
        final distMeters = Geolocator.distanceBetween(
          targetLat,
          targetLng,
          position.latitude,
          position.longitude,
        );

        if (distMeters > targetRadius) {
          if (mounted) {
            final confirmProceed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Row(
                  children: [
                    Icon(Icons.location_off_rounded, color: Color(0xFFDC2626), size: 28),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Geofence Distance Warning',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You are ${distMeters.round()}m away from ${site.effectiveName} (Allowed radius: ${targetRadius}m).',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• Target Site: ${site.effectiveName}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• Allowed Radius: Within ${targetRadius}m',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• Your Distance: ${distMeters.round()}m away',
                            style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Would you like to capture live arrival photo proof to verify site arrival anyway?',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                    ),
                  ],
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
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9CC70A),
                      foregroundColor: const Color(0xFF414A51),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Proceed & Take Photo', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
            if (confirmProceed != true) return;
          } else {
            return;
          }
        }
      }

      setState(() => _isActionLoading = false);

      final photo = await _captureLivePhoto(
        title: 'Arrival Proof - Site ${siteIndex + 1}',
        subtitle: 'Capture a live photo at ${site.effectiveName} to verify your arrival.',
      );
      if (photo == null) return;

      setState(() => _isActionLoading = true);

      final nowStr = DateFormat('hh:mm a').format(DateTime.now());

      // For first OD started from home, record attendance check-in NOW upon reaching site location
      if (siteIndex == 0 && _assignment.startOdFromHome) {
        final attendanceRepo = ref.read(attendanceRepositoryProvider);
        final empIdInt = _assignment.employeeId > 0 ? _assignment.employeeId : 1;
        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final nowTime24 = '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}';

        await attendanceRepo.startOdAttendanceSession(
          employeeId: empIdInt,
          employeeName: _assignment.employeeName,
          date: todayStr,
          time: nowTime24,
          assignmentId: _assignment.id,
          purpose: site.purpose.isNotEmpty ? site.purpose : _assignment.purpose,
          destination: site.effectiveName,
          destinationAddress: site.destinationAddress,
          latitude: position.latitude,
          longitude: position.longitude,
          destinationLatitude: site.latitude,
          destinationLongitude: site.longitude,
          destinationRadius: site.radius,
          startOdFromHome: true,
          notes: 'OD Started from Home - Reached Site 1: ${site.effectiveName}',
        );
      }

      final sitesList = List<OnDutySite>.from(_assignment.effectiveSites);
      final updatedSite = site.copyWith(
        status: 'REACHED',
        reachedTime: nowStr,
        reachedPhoto: photo,
        reachedLatitude: position.latitude,
        reachedLongitude: position.longitude,
      );

      if (siteIndex < sitesList.length) {
        sitesList[siteIndex] = updatedSite;
      } else {
        sitesList.add(updatedSite);
      }

      final updated = _assignment.copyWith(
        status: 'REACHED_DESTINATION',
        reachedTime: nowStr,
        reachedPhoto: photo,
        reachedLatitude: position.latitude,
        reachedLongitude: position.longitude,
        sites: sitesList,
      );

      final repo = ref.read(onDutyRepositoryProvider);
      await repo.updateAssignment(updated);

      if (mounted) {
        setState(() {
          _localAssignment = updated;
        });
      }

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

  Future<String> _findNextAvailableOdDate(int employeeId, String currentDateStr) async {
    DateTime currentDt;
    try {
      currentDt = DateFormat('dd-MM-yyyy').parse(currentDateStr);
    } catch (_) {
      try {
        currentDt = DateFormat('yyyy-MM-dd').parse(currentDateStr);
      } catch (_) {
        currentDt = DateTime.now();
      }
    }

    final repo = ref.read(onDutyRepositoryProvider);
    final existingAssignments = await repo.getAssignmentsForEmployee(employeeId: employeeId);
    final assignedDates = existingAssignments
        .where((a) => a.id != widget.assignment.id && a.isOngoing)
        .map((a) => a.date)
        .toSet();

    DateTime candidate = currentDt.add(const Duration(days: 1));
    while (true) {
      final candidateStr = DateFormat('dd-MM-yyyy').format(candidate);
      if (!assignedDates.contains(candidateStr)) {
        return candidateStr;
      }
      candidate = candidate.add(const Duration(days: 1));
    }
  }

  Future<void> _handleNotCompletedSiteWork(int siteIndex) async {
    final siteName = widget.assignment.sites.length > siteIndex
        ? widget.assignment.sites[siteIndex].effectiveName
        : widget.assignment.effectiveDestinationTitle;

    final OdStatusSubmitResult? result = await showDialog<OdStatusSubmitResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WorkProofUploadDialog(
        siteName: siteName,
        isNotCompleted: true,
      ),
    );

    if (result == null) return;

    setState(() => _isActionLoading = true);
    try {
      final position = await _getGpsPosition();
      final empIdInt = _assignment.employeeId > 0 ? _assignment.employeeId : 1;
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final nowTime24 = '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}';

      final attendanceRepo = ref.read(attendanceRepositoryProvider);
      await attendanceRepo.completeOdAttendanceSession(
        employeeId: empIdInt,
        employeeName: _assignment.employeeName,
        date: todayStr,
        time: nowTime24,
        assignmentId: _assignment.id,
        latitude: position?.latitude,
        longitude: position?.longitude,
        afterCompletionOption: _assignment.afterCompletionOption,
      );

      final repo = ref.read(onDutyRepositoryProvider);
      await repo.markAsNotCompleted(
        id: _assignment.id,
        reason: result.text,
        photos: result.photos,
        latitude: position?.latitude,
        longitude: position?.longitude,
      );

      _invalidateProviders();
      _timer?.cancel();
      _gpsCheckTimer?.cancel();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('On-Duty marked as Not Completed with photo proof ✓'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark On-Duty as Not Completed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleAssignNextOd() async {
    setState(() => _isActionLoading = true);
    try {
      final position = await _getGpsPosition();
      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to capture GPS position. Please enable location services.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final targetLat = widget.assignment.effectiveDestinationLatitude;
      final targetLng = widget.assignment.effectiveDestinationLongitude;
      final targetRadius = widget.assignment.effectiveDestinationRadius > 0
          ? widget.assignment.effectiveDestinationRadius
          : 100;

      if (targetLat != null && targetLng != null && targetLat != 0 && targetLng != 0) {
        final distMeters = Geolocator.distanceBetween(
          targetLat,
          targetLng,
          position.latitude,
          position.longitude,
        );

        if (distMeters > targetRadius) {
          if (mounted) {
            showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Row(
                  children: [
                    Icon(Icons.location_off_rounded, color: Color(0xFFDC2626), size: 28),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Geofence Validation Failed',
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
                      'You must be within the OD location to assign the next OD.',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• Allowed Geofence Radius: Within ${targetRadius}m',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• Current Distance: ${distMeters.round()}m away',
                            style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF414A51),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
          return;
        }
      }

      // Geofence check passed! Open AssignOnDutyDialog to assign/start next OD
      if (mounted) {
        final currentEmp = ref.read(currentEmployeeProvider);
        showDialog<void>(
          context: context,
          builder: (ctx) => AssignOnDutyDialog(
            preSelectedEmployee: currentEmp,
            isSelfRequest: true,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to validate location for Next OD: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleCompleteSiteWork(int siteIndex) async {
    final currentSites = _assignment.effectiveSites;
    final site = siteIndex < currentSites.length ? currentSites[siteIndex] : currentSites.first;

    final dynamic result = await showDialog<dynamic>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WorkProofUploadDialog(
        siteName: site.effectiveName,
        initialPhotos: site.effectiveWorkPhotos,
        initialText: widget.assignment.purpose,
      ),
    );

    if (result == null) return;
    final List<String> photos = result is OdStatusSubmitResult ? result.photos : (result is List<String> ? result : []);
    final String purposeDetails = result is OdStatusSubmitResult ? result.text : '';

    if (photos.isEmpty) return;

    setState(() => _isActionLoading = true);
    try {
      final position = await _getGpsPosition();
      final nowStr = DateFormat('hh:mm a').format(DateTime.now());
      final empIdInt = widget.assignment.employeeId > 0 ? widget.assignment.employeeId : 1;
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final nowTime24 = '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}';

      final sitesList = List<OnDutySite>.from(_assignment.effectiveSites);
      final updatedSite = site.copyWith(
        status: 'COMPLETED',
        workCompletedTime: nowStr,
        workPhoto: photos.first,
        workPhotos: photos,
        workEndLatitude: position?.latitude,
        workEndLongitude: position?.longitude,
      );

      if (siteIndex < sitesList.length) {
        sitesList[siteIndex] = updatedSite;
      } else {
        sitesList.add(updatedSite);
      }

      final allCompleted = sitesList.every((s) => s.isCompleted);

      if (allCompleted) {
        final isReturnToOffice = _assignment.isReturnToOfficeOption;

        if (!isReturnToOffice) {
          final attendanceRepo = ref.read(attendanceRepositoryProvider);
          await attendanceRepo.completeOdAttendanceSession(
            employeeId: empIdInt,
            employeeName: _assignment.employeeName,
            date: todayStr,
            time: nowTime24,
            assignmentId: _assignment.id,
            latitude: position?.latitude,
            longitude: position?.longitude,
            destinationLatitude: site.latitude,
            destinationLongitude: site.longitude,
            destinationRadius: site.radius,
            afterCompletionOption: _assignment.afterCompletionOption,
          );
        }

        final nextStatus = isReturnToOffice ? 'WORK_COMPLETED' : 'COMPLETED';

        final updated = _assignment.copyWith(
          status: nextStatus,
          purpose: purposeDetails.isNotEmpty ? purposeDetails : _assignment.purpose,
          workCompletedTime: nowStr,
          workPhoto: photos.first,
          workPhotos: photos,
          actualEndTime: isReturnToOffice ? null : nowStr,
          workEndLatitude: position?.latitude,
          workEndLongitude: position?.longitude,
          returnStartTime: isReturnToOffice ? nowStr : _assignment.returnStartTime,
          returnLatitude: isReturnToOffice ? position?.latitude : _assignment.returnLatitude,
          returnLongitude: isReturnToOffice ? position?.longitude : _assignment.returnLongitude,
          sites: sitesList,
        );

        final repo = ref.read(onDutyRepositoryProvider);
        await repo.updateAssignment(updated);

        if (mounted) {
          setState(() {
            _localAssignment = updated;
          });
        }

        _invalidateProviders();
        _timer?.cancel();
        _gpsCheckTimer?.cancel();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('On-Duty work completed with ${photos.length} photo proof(s)! Marked as Completed ✓'),
              backgroundColor: const Color(0xFF16A34A),
            ),
          );
        }
      } else {
        final updated = _assignment.copyWith(
          status: 'IN_PROGRESS',
          workCompletedTime: nowStr,
          workPhoto: photos.first,
          workPhotos: photos,
          sites: sitesList,
        );

        final repo = ref.read(onDutyRepositoryProvider);
        await repo.updateAssignment(updated);

        if (mounted) {
          setState(() {
            _localAssignment = updated;
          });
        }

        _invalidateProviders();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Site ${siteIndex + 1} (${site.effectiveName}) completed!'),
              backgroundColor: const Color(0xFF16A34A),
            ),
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
        returnStartTime: widget.assignment.returnStartTime ?? nowStr,
        returnLatitude: widget.assignment.returnLatitude ?? position?.latitude,
        returnLongitude: widget.assignment.returnLongitude ?? position?.longitude,
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

      try {
        final attendanceRepo = ref.read(attendanceRepositoryProvider);
        await attendanceRepo.completeOdAttendanceSession(
          employeeId: empIdInt,
          employeeName: widget.assignment.employeeName,
          date: todayStr,
          time: nowTime24,
          assignmentId: widget.assignment.id,
          latitude: position?.latitude,
          longitude: position?.longitude,
          afterCompletionOption: widget.assignment.afterCompletionOption,
        );
      } catch (_) {}

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

      if (mounted) {
        setState(() {
          _localAssignment = updated;
        });
      }

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
    final status = _assignment.status;

    if (status == 'COMPLETED') {
      return _buildCompletedCard();
    }
    if (status == 'NOT_COMPLETED') {
      return _buildNotCompletedCard();
    }

    return _buildSequentialOdCard();
  }

  Widget _buildSequentialOdCard() {
    final assignment = _assignment;
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
          // Dynamic Header Banner matching reference design
          () {
            final currentSite = assignment.effectiveSites.isNotEmpty && assignment.currentSiteIndex < assignment.effectiveSites.length
                ? assignment.effectiveSites[assignment.currentSiteIndex]
                : null;
            
            Color headerBg = darkAccent;
            IconData headerIcon = Icons.directions_car_filled_rounded;
            String headerTitle = 'ON-DUTY: ${assignment.odType.toUpperCase()}';

            if (isReturnPhase) {
              headerBg = const Color(0xFF2563EB); // Blue
              headerIcon = Icons.directions_car_rounded;
              headerTitle = 'RETURNING TO OFFICE';
            } else if (allDone) {
              headerBg = const Color(0xFF414A51); // Dark Accent
              headerIcon = Icons.check_circle_rounded;
              headerTitle = 'OD WORK COMPLETED';
            } else if (currentSite?.isReached == true) {
              headerBg = const Color(0xFF16A34A); // Green
              headerIcon = Icons.groups_rounded;
              headerTitle = 'WORKING ON SITE';
            } else if (currentSite?.isTraveling == true || assignment.status == 'TRAVELING_TO_DESTINATION') {
              headerBg = const Color(0xFFB45309); // Amber / Brown Orange (Image 2)
              headerIcon = Icons.directions_car_rounded;
              headerTitle = 'TRAVELING TO DESTINATION';
            }

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: headerBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  Icon(headerIcon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      headerTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (assignment.isOngoing && !assignment.isAssigned) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: (allDone && !isReturnPhase)
                          ? const Text(
                              'Step 4 of 5',
                              style: TextStyle(color: Color(0xFF9CC70A), fontWeight: FontWeight.bold, fontSize: 11),
                            )
                          : Row(
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
            );
          }(),

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
                if (assignment.notes.contains('Postponed to')) ...[
                  const SizedBox(height: 8),
                  () {
                    final logs = assignment.notes
                        .split(RegExp(r'\s*\|\s*|\r?\n'))
                        .map((e) => e.trim())
                        .where((e) => e.startsWith('Postponed to'))
                        .toList();
                    final logText = logs.isNotEmpty ? logs.last : 'Postponed';
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.event_repeat_rounded, size: 16, color: Colors.amber.shade900),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Task $logText',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                            ),
                          ),
                        ],
                      ),
                    );
                  }(),
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
                              : (site.isNotCompleted ? Colors.red.shade50 : (isCurrentActive ? primaryColor.withValues(alpha: 0.1) : (isLocked ? Colors.grey.shade100 : Colors.white))),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: site.isCompleted
                                ? Colors.green.shade400
                                : (site.isNotCompleted ? Colors.red.shade400 : (isCurrentActive ? primaryColor : (isLocked ? Colors.grey.shade300 : primaryColor.withValues(alpha: 0.5)))),
                            width: isCurrentActive ? 2.0 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
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
                                        : (site.isNotCompleted
                                            ? Colors.red.shade100
                                            : (isCurrentActive
                                                ? primaryColor.withValues(alpha: 0.25)
                                                : (isLocked ? Colors.grey.shade200 : const Color(0xFFF1F5F9)))),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    site.isCompleted
                                        ? 'Completed ✓'
                                        : (site.isNotCompleted
                                            ? 'Not Completed ✕'
                                            : (isCurrentActive
                                                ? (site.isReached ? 'Arrived' : (site.isTraveling ? 'Traveling' : 'Active'))
                                                : (isLocked ? 'Locked 🔒' : 'Pending'))),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: site.isCompleted
                                          ? Colors.green.shade800
                                          : (site.isNotCompleted
                                              ? Colors.red.shade800
                                              : (isCurrentActive
                                                  ? darkAccent
                                                  : (isLocked ? Colors.grey.shade700 : darkAccent))),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            _buildSiteLocationProofsBox(site: site, siteIndex: index + 1, assignment: widget.assignment),

                             // Action Button for active/current site
                            if (!allDone && canStart && !site.isCompleted && !site.isNotCompleted) ...[
                              const SizedBox(height: 10),
                              () {
                                final isSiteReached = site.isReached ||
                                    site.reachedPhoto != null ||
                                    site.reachedTime != null ||
                                    site.status == 'REACHED' ||
                                    site.status == 'ARRIVED' ||
                                    (index == 0 && (assignment.status == 'REACHED_DESTINATION' || assignment.reachedPhoto != null || assignment.reachedTime != null));

                                final isSiteTraveling = site.isTraveling ||
                                    site.travelStartTime != null ||
                                    site.status == 'TRAVELING' ||
                                    site.status == 'IN_PROGRESS' ||
                                    assignment.status == 'TRAVELING_TO_DESTINATION';

                                if (isSiteReached) {
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _isActionLoading ? null : () => _handleCompleteSiteWork(index),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF16A34A),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 11),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          icon: const Icon(Icons.check_circle_outline, size: 18),
                                          label: const Text(
                                            '[ 3. COMPLETE OD WORK (PHOTO PROOF) ]',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        onPressed: _isActionLoading ? null : () => _handleNotCompletedSiteWork(index),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFFDC2626),
                                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          side: const BorderSide(color: Color(0xFFEF4444)),
                                        ),
                                        icon: const Icon(Icons.cancel_outlined, size: 16),
                                        label: const Text('Not Completed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      ),
                                    ],
                                  );
                                } else if (isSiteTraveling) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFFDE68A)),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.navigation_rounded, color: Color(0xFFB45309), size: 18),
                                            SizedBox(width: 8),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'En Route to Site',
                                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                                                ),
                                                Text(
                                                  'Tracking GPS coordinates...',
                                                  style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: _isActionLoading ? null : () => _handleReachedSite(index),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: primaryColor,
                                                foregroundColor: darkAccent,
                                                padding: const EdgeInsets.symmetric(vertical: 10),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              icon: const Icon(Icons.camera_alt, size: 18),
                                              label: const Text(
                                                '[ 2. I HAVE REACHED (CAPTURE PHOTO) ]',
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            onPressed: _isActionLoading ? null : () => _handleNotCompletedSiteWork(index),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFFDC2626),
                                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              side: const BorderSide(color: Color(0xFFEF4444)),
                                            ),
                                            icon: const Icon(Icons.cancel_outlined, size: 16),
                                            label: const Text('Not Completed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                } else {
                                  return Row(
                                    children: [
                                      Expanded(
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
                                            '[ 1. START SITE ${index + 1} TRIP ]',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        onPressed: _isActionLoading ? null : () => _handleNotCompletedSiteWork(index),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFFDC2626),
                                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          side: const BorderSide(color: Color(0xFFEF4444)),
                                        ),
                                        icon: const Icon(Icons.cancel_outlined, size: 16),
                                        label: const Text('Not Completed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      ),
                                    ],
                                  );
                                }
                              }(),
                            ],
                          ],
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 16),

                // Return to Office -> Checkout section once all sites are completed
                if (allDone) ...[
                  if (assignment.isReturnToOfficeOption && !isReturnPhase) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Color(0xFFB45309), size: 20),
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
                    const SizedBox(height: 14),
                  ] else if (!assignment.isReturnToOfficeOption) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              assignment.isAssignNextOdOption
                                  ? 'You can now assign your next OD from this location.'
                                  : 'You can now complete checkout directly from OD location.',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

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
                            '[ 4. RETURN TO OFFICE ]',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
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
                            '[ 5. CAME TO OFFICE (CONFIRM ARRIVAL) ]',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                        ),
                      ),
                    ],
                  ] else if (assignment.isAssignNextOdOption) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isActionLoading ? null : _handleAssignNextOd,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: darkAccent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add_location_alt_rounded, size: 20),
                        label: const Text(
                          'Assign Next OD',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
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
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isActionLoading ? null : _handleAssignNextOd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9CC70A),
                  foregroundColor: const Color(0xFF414A51),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_location_alt_rounded, size: 20),
                label: const Text(
                  'Assign Next OD',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotCompletedCard() {
    final assignment = widget.assignment;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cancel, color: Color(0xFFDC2626), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${assignment.odType} - NOT COMPLETED',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Text(
              assignment.effectiveDestinationTitle,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
            ),
            if (assignment.notCompletedReason != null && assignment.notCompletedReason!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reason for Non-Completion:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      assignment.notCompletedReason!,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isActionLoading ? null : _handleAssignNextOd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9CC70A),
                  foregroundColor: const Color(0xFF414A51),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_location_alt_rounded, size: 20),
                label: const Text(
                  'Assign Next OD',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
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

    final startTimeStr = site.travelStartTime ?? (siteIndex == 1 ? (assignment?.travelStartTime ?? assignment?.actualStartTime) : null);
    final reachedTimeStr = site.reachedTime ?? (siteIndex == 1 ? assignment?.reachedTime : null);
    final completedTimeStr = site.workCompletedTime ?? (siteIndex == 1 ? (assignment?.workCompletedTime ?? assignment?.actualEndTime) : null);

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
                      Text(
                        'Started Location${startTimeStr != null && startTimeStr.isNotEmpty ? " ($startTimeStr)" : ""}',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
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
                        Icon(Icons.map_outlined, size: 12, color: Color(0xFF414A51)),
                        SizedBox(width: 3),
                        Text('Map', style: TextStyle(fontSize: 10.5, color: Color(0xFF414A51), fontWeight: FontWeight.bold)),
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
                const Icon(Icons.location_on, size: 14, color: Color(0xFF414A51)),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reached Location${reachedTimeStr != null && reachedTimeStr.isNotEmpty ? " ($reachedTimeStr)" : ""}',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
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
                        Icon(Icons.map_outlined, size: 12, color: Color(0xFF414A51)),
                        SizedBox(width: 3),
                        Text('Map', style: TextStyle(fontSize: 10.5, color: Color(0xFF414A51), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (endLat != null && endLng != null && (site.isCompleted || site.isNotCompleted || widget.assignment.isCompleted || widget.assignment.isNotCompleted)) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  (site.isNotCompleted || widget.assignment.isNotCompleted) ? Icons.cancel_outlined : Icons.check_circle_outline,
                  size: 14,
                  color: (site.isNotCompleted || widget.assignment.isNotCompleted) ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${(site.isNotCompleted || widget.assignment.isNotCompleted) ? "Not Completed Location" : "Completed Location"}${completedTimeStr != null && completedTimeStr.isNotEmpty ? " ($completedTimeStr)" : ""}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: (site.isNotCompleted || widget.assignment.isNotCompleted) ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                        ),
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
                        Icon(Icons.map_outlined, size: 12, color: Color(0xFF414A51)),
                        SizedBox(width: 3),
                        Text('Map', style: TextStyle(fontSize: 10.5, color: Color(0xFF414A51), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (widget.assignment.returnLatitude != null && widget.assignment.returnLongitude != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.directions_car_rounded, size: 14, color: Color(0xFF2563EB)),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Return Started Location${widget.assignment.returnStartTime != null ? " (${widget.assignment.returnStartTime})" : ""}',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                      ),
                      Text(
                        '${widget.assignment.returnLatitude!.toStringAsFixed(5)}, ${widget.assignment.returnLongitude!.toStringAsFixed(5)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => _openMap(widget.assignment.returnLatitude!, widget.assignment.returnLongitude!),
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
                        Icon(Icons.map_outlined, size: 12, color: Color(0xFF414A51)),
                        SizedBox(width: 3),
                        Text('Map', style: TextStyle(fontSize: 10.5, color: Color(0xFF414A51), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (widget.assignment.officeLatitude != null && widget.assignment.officeLongitude != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_city_rounded, size: 14, color: Color(0xFF16A34A)),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Office Reached Location${widget.assignment.officeReachedTime != null ? " (${widget.assignment.officeReachedTime})" : ""}',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                      ),
                      Text(
                        '${widget.assignment.officeLatitude!.toStringAsFixed(5)}, ${widget.assignment.officeLongitude!.toStringAsFixed(5)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => _openMap(widget.assignment.officeLatitude!, widget.assignment.officeLongitude!),
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
                        Icon(Icons.map_outlined, size: 12, color: Color(0xFF414A51)),
                        SizedBox(width: 3),
                        Text('Map', style: TextStyle(fontSize: 10.5, color: Color(0xFF414A51), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (site.effectiveWorkPhotos.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.photo_library_outlined, size: 13, color: Color(0xFF16A34A)),
                const SizedBox(width: 4),
                Text(
                  'COMPLETION PROOF PHOTOS (${site.effectiveWorkPhotos.length})',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Color(0xFF15803D),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 54,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: site.effectiveWorkPhotos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, pIdx) {
                  final photoData = site.effectiveWorkPhotos[pIdx];
                  return GestureDetector(
                    onTap: () => _showFullImageDialog(ctx, photoData, 'Completion Proof ${pIdx + 1}'),
                    child: Container(
                      width: 54,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: _buildThumbnailImage(photoData),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThumbnailImage(String data) {
    try {
      if (data.startsWith('data:image')) {
        final commaIdx = data.indexOf(',');
        if (commaIdx != -1) {
          final bytes = base64Decode(data.substring(commaIdx + 1));
          return Image.memory(bytes, fit: BoxFit.cover);
        }
      }
      if (!data.startsWith('http://') && !data.startsWith('https://') && !data.startsWith('assets/')) {
        try {
          final cleanData = data.contains(',') ? data.split(',').last : data;
          final bytes = base64Decode(cleanData.trim());
          return Image.memory(bytes, fit: BoxFit.cover);
        } catch (_) {}
      }
      return Image.network(
        data,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 16, color: Colors.grey)),
      );
    } catch (_) {
      return const Center(child: Icon(Icons.broken_image, size: 16, color: Colors.grey));
    }
  }

  void _showFullImageDialog(BuildContext context, String photoData, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  child: _buildThumbnailImage(photoData),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
