import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/on_duty_assignment.dart';
import '../domain/on_duty_site.dart';
import '../data/on_duty_storage_service.dart';
import '../providers/on_duty_providers.dart';
import 'assign_on_duty_dialog.dart';
import 'widgets/on_duty_camera_page.dart';
import 'widgets/work_proof_upload_dialog.dart';
import '../../attendance/providers/attendance_providers.dart';
import '../../employee/providers/employee_providers.dart';
import '../../../core/widgets/reverse_geocoded_location_text.dart';

String _sanitizePurposeText(String text) {
  if (text.isEmpty) return text;
  var cleaned = text.trim();
  if (RegExp(r'to supervise the work is hapen+ing( or not)?', caseSensitive: false).hasMatch(cleaned)) {
    return 'To supervise ongoing work';
  }
  if (RegExp(r'check the work is done( or not)?', caseSensitive: false).hasMatch(cleaned)) {
    return 'Verify task completion';
  }
  return cleaned;
}

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

    final totalPausedSecs = _assignment.totalPausedSeconds;

    if (_assignment.isPaused && _assignment.pausedAt != null) {
      DateTime pausedTime;
      try {
        pausedTime = DateTime.parse(_assignment.pausedAt!);
      } catch (_) {
        pausedTime = DateTime.now();
      }
      final rawDiff = pausedTime.difference(startTime).inSeconds - totalPausedSecs;
      _activeElapsed = Duration(seconds: rawDiff > 0 ? rawDiff : 0);
      return; // Frozen while paused
    }

    final rawDiff = DateTime.now().difference(startTime).inSeconds - totalPausedSecs;
    _activeElapsed = Duration(seconds: rawDiff > 0 ? rawDiff : 0);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          final diffSecs = DateTime.now().difference(startTime).inSeconds - totalPausedSecs;
          _activeElapsed = Duration(seconds: diffSecs > 0 ? diffSecs : 0);
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

  Future<String?> _captureLivePhoto({required String title, String subtitle = ''}) async {
    return Navigator.of(context, rootNavigator: true).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
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
  
  // CANCEL, PAUSE & RESUME OD HANDLERS
  // =========================================================================

  Future<void> _handleCancelOd() async {
    if (_isActionLoading) return;

    final reasons = [
      'Client Meeting Cancelled',
      'Heavy Rain / Extreme Weather',
      'Vehicle Breakdown / Traffic Issue',
      'Emergency Return to Office',
      'Started by Mistake',
      'Other',
    ];
    String selectedReason = reasons.first;
    final otherController = TextEditingController();
    String? proofPhoto;
    bool weatherSafeException = false;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isRain = selectedReason.contains('Heavy Rain');
            final canConfirm = (proofPhoto != null && proofPhoto!.isNotEmpty) ||
                (isRain && weatherSafeException);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 24),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cancel On-Duty Trip',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select cancellation reason:',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedReason,
                      isExpanded: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedReason = val;
                          });
                        }
                      },
                    ),
                    if (selectedReason == 'Other') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: otherController,
                        decoration: InputDecoration(
                          hintText: 'Enter specific reason...',
                          hintStyle: const TextStyle(fontSize: 12),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    const Text(
                      'Mandatory Image Proof:',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 6),
                    if (proofPhoto != null && proofPhoto!.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          height: 120,
                          width: double.infinity,
                          child: _buildThumbnailImage(proofPhoto!),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () async {
                            final retake = await _captureLivePhoto(title: 'Cancellation Proof');
                            if (retake != null) {
                              setDialogState(() => proofPhoto = retake);
                            }
                          },
                          icon: const Icon(Icons.refresh, size: 14),
                          label: const Text('Retake Photo', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ] else ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 42),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: const BorderSide(color: Color(0xFFDC2626)),
                        ),
                        onPressed: () async {
                          final photo = await _captureLivePhoto(title: 'Cancellation Proof');
                          if (photo != null) {
                            setDialogState(() => proofPhoto = photo);
                          }
                        },
                        icon: const Icon(Icons.camera_alt, color: Color(0xFFDC2626), size: 18),
                        label: const Text('Capture Live Proof Photo', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                      ),
                    ],
                    if (isRain) ...[
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text(
                          'Outdoor camera unsafe due to storm (Verified by GPS)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
                        ),
                        value: weatherSafeException,
                        onChanged: (val) {
                          setDialogState(() => weatherSafeException = val == true);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Keep Active'),
                ),
                ElevatedButton(
                  onPressed: canConfirm ? () => Navigator.pop(ctx, true) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: const Text('Confirm Cancellation', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    final effectiveReason = selectedReason == 'Other' && otherController.text.trim().isNotEmpty
        ? otherController.text.trim()
        : (weatherSafeException ? '$selectedReason [Storm Safety Exception]' : selectedReason);

    setState(() => _isActionLoading = true);
    try {
      final position = await _getGpsPosition();
      final storageService = ref.read(onDutyStorageServiceProvider);
      String photoUrl = '';
      if (proofPhoto != null && proofPhoto!.isNotEmpty) {
        photoUrl = await storageService.uploadOdProof(
          assignmentId: _assignment.id,
          action: 'cancel',
          photoData: proofPhoto!,
        );
      } else if (weatherSafeException) {
        photoUrl = 'WEATHER_STORM_SAFETY_VERIFIED';
      }

      final repo = ref.read(onDutyRepositoryProvider);
      await repo.cancelAssignment(
        id: _assignment.id,
        reason: effectiveReason,
        photoUrl: photoUrl,
        latitude: position?.latitude,
        longitude: position?.longitude,
      );

      // Gracefully close active OD attendance session
      try {
        final attendanceRepo = ref.read(attendanceRepositoryProvider);
        final empIdInt = _assignment.employeeId > 0 ? _assignment.employeeId : 1;
        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final nowTime24 = '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}';
        await attendanceRepo.completeOdAttendanceSession(
          employeeId: empIdInt,
          employeeName: _assignment.employeeName,
          date: todayStr,
          time: nowTime24,
          assignmentId: _assignment.id,
          latitude: position?.latitude,
          longitude: position?.longitude,
          afterCompletionOption: 'RETURN_TO_OFFICE',
        );
      } catch (_) {}

      _timer?.cancel();
      _gpsCheckTimer?.cancel();
      _invalidateProviders();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('On-Duty trip cancelled and attendance updated ✓'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel On-Duty: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handlePauseOd() async {
    if (_isActionLoading) return;

    final reasons = [
      'Heavy Rain / Weather Disruption',
      'Waiting for Client / Site Access',
      'Vehicle Breakdown / Traffic Block',
      'Personal Break / Lunch',
      'Other',
    ];
    String selectedReason = reasons.first;
    final otherController = TextEditingController();
    String? proofPhoto;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final canConfirm = proofPhoto != null && proofPhoto!.isNotEmpty;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.pause_circle_filled, color: Color(0xFFF59E0B), size: 24),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pause On-Duty Timer',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select pause reason:',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedReason,
                      isExpanded: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedReason = val);
                        }
                      },
                    ),
                    if (selectedReason == 'Other') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: otherController,
                        decoration: InputDecoration(
                          hintText: 'Enter reason details...',
                          hintStyle: const TextStyle(fontSize: 12),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    const Text(
                      'Mandatory Condition Photo Proof:',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 6),
                    if (proofPhoto != null && proofPhoto!.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          height: 120,
                          width: double.infinity,
                          child: _buildThumbnailImage(proofPhoto!),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () async {
                            final retake = await _captureLivePhoto(title: 'Pause Proof');
                            if (retake != null) {
                              setDialogState(() => proofPhoto = retake);
                            }
                          },
                          icon: const Icon(Icons.refresh, size: 14),
                          label: const Text('Retake Photo', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ] else ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 42),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: const BorderSide(color: Color(0xFFF59E0B)),
                        ),
                        onPressed: () async {
                          final photo = await _captureLivePhoto(title: 'Pause Proof');
                          if (photo != null) {
                            setDialogState(() => proofPhoto = photo);
                          }
                        },
                        icon: const Icon(Icons.camera_alt, color: Color(0xFFF59E0B), size: 18),
                        label: const Text('Capture Live Proof Photo', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: canConfirm ? () => Navigator.pop(ctx, true) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: const Text('Pause Timer', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || proofPhoto == null) return;

    final effectiveReason = selectedReason == 'Other' && otherController.text.trim().isNotEmpty
        ? otherController.text.trim()
        : selectedReason;

    setState(() => _isActionLoading = true);
    try {
      final storageService = ref.read(onDutyStorageServiceProvider);
      final photoUrl = await storageService.uploadOdProof(
        assignmentId: _assignment.id,
        action: 'pause',
        photoData: proofPhoto!,
      );

      final repo = ref.read(onDutyRepositoryProvider);
      await repo.pauseAssignment(
        id: _assignment.id,
        reason: effectiveReason,
        photoUrl: photoUrl,
      );

      _timer?.cancel();
      _localAssignment = _assignment.copyWith(
        isPaused: true,
        pausedAt: DateTime.now().toIso8601String(),
        pauseReason: effectiveReason,
        pausePhoto: photoUrl,
      );
      _invalidateProviders();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('On-Duty paused: $effectiveReason'),
            backgroundColor: const Color(0xFFF59E0B),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pause On-Duty: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleResumeOd() async {
    if (_isActionLoading) return;

    String? proofPhoto;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final canConfirm = proofPhoto != null && proofPhoto!.isNotEmpty;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.play_circle_filled, color: Color(0xFF16A34A), size: 24),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Resume On-Duty',
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
                    'Paused Reason: ${_assignment.pauseReason ?? "Weather / Interruption"}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Mandatory Restart Photo Proof:',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Capture proof that work/travel can safely restart.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),
                  if (proofPhoto != null && proofPhoto!.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 120,
                        width: double.infinity,
                        child: _buildThumbnailImage(proofPhoto!),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          final retake = await _captureLivePhoto(title: 'Resume Proof');
                          if (retake != null) {
                            setDialogState(() => proofPhoto = retake);
                          }
                        },
                        icon: const Icon(Icons.refresh, size: 14),
                        label: const Text('Retake Photo', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 42),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        side: const BorderSide(color: Color(0xFF16A34A)),
                      ),
                      onPressed: () async {
                        final photo = await _captureLivePhoto(title: 'Resume Proof');
                        if (photo != null) {
                          setDialogState(() => proofPhoto = photo);
                        }
                      },
                      icon: const Icon(Icons.camera_alt, color: Color(0xFF16A34A), size: 18),
                      label: const Text('Capture Live Proof Photo', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: canConfirm ? () => Navigator.pop(ctx, true) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: const Text('Resume Timer & Work', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || proofPhoto == null) return;

    setState(() => _isActionLoading = true);
    try {
      final storageService = ref.read(onDutyStorageServiceProvider);
      final photoUrl = await storageService.uploadOdProof(
        assignmentId: _assignment.id,
        action: 'resume',
        photoData: proofPhoto!,
      );

      final repo = ref.read(onDutyRepositoryProvider);
      await repo.resumeAssignment(
        id: _assignment.id,
        photoUrl: photoUrl,
      );

      final now = DateTime.now();
      int addedSecs = 0;
      if (_assignment.pausedAt != null) {
        try {
          addedSecs = now.difference(DateTime.parse(_assignment.pausedAt!)).inSeconds;
          if (addedSecs < 0) addedSecs = 0;
        } catch (_) {}
      }

      _localAssignment = _assignment.copyWith(
        isPaused: false,
        pausedAt: null,
        pauseReason: null,
        pausePhoto: null,
        totalPausedSeconds: _assignment.totalPausedSeconds + addedSecs,
      );

      _invalidateProviders();
      _startLiveTimer();
      _startPeriodicGpsCheck();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('On-Duty resumed successfully ✓'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resume On-Duty: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

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
        title: 'Reached Proof - Site ${siteIndex + 1}',
        subtitle: '',
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
    final String? origVoice = result is OdStatusSubmitResult ? result.originalVoiceText : null;
    final String? voiceLang = result is OdStatusSubmitResult ? result.voiceLanguage : null;

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
        notes: purposeDetails.isNotEmpty ? purposeDetails : site.notes,
        voiceNoteText: purposeDetails.isNotEmpty ? purposeDetails : site.voiceNoteText,
        originalVoiceText: origVoice ?? site.originalVoiceText,
        voiceLanguage: voiceLang ?? site.voiceLanguage,
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
          notes: purposeDetails.isNotEmpty ? purposeDetails : _assignment.notes,
          voiceNoteText: purposeDetails.isNotEmpty ? purposeDetails : _assignment.voiceNoteText,
          originalVoiceText: origVoice ?? _assignment.originalVoiceText,
          voiceLanguage: voiceLang ?? _assignment.voiceLanguage,
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
          notes: purposeDetails.isNotEmpty ? purposeDetails : _assignment.notes,
          voiceNoteText: purposeDetails.isNotEmpty ? purposeDetails : _assignment.voiceNoteText,
          originalVoiceText: origVoice ?? _assignment.originalVoiceText,
          voiceLanguage: voiceLang ?? _assignment.voiceLanguage,
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
    if (status == 'NOT_COMPLETED' || status == 'CANCELLED') {
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
                    if (assignment.isPaused) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.pause, size: 13, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'PAUSED (${_formatTimerDisplay(_activeElapsed)})',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
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
                                mainAxisSize: MainAxisSize.min,
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
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: _isActionLoading ? null : _handlePauseOd,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.pause, size: 12, color: Colors.white),
                              SizedBox(width: 2),
                              Text('Pause', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10.5)),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: _isActionLoading ? null : _handleCancelOd,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.close, size: 12, color: Colors.white),
                            SizedBox(width: 2),
                            Text('Cancel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10.5)),
                          ],
                        ),
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
                _buildMetaRow(Icons.lightbulb_outline, 'OD Purpose', _sanitizePurposeText(assignment.purpose), isBold: true),
                if (assignment.projectCode != null && assignment.projectCode!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _buildMetaRow(Icons.folder_outlined, 'Project', assignment.projectCode!, isBold: true),
                ],
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
                                      if (site.purpose.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Purpose: ${_sanitizePurposeText(site.purpose)}',
                                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                                        ),
                                      ],
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

                                if (assignment.isPaused) {
                                  return Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFFDE68A)),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.pause_circle_filled, color: Color(0xFFB45309), size: 18),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'OD is currently PAUSED (${assignment.pauseReason ?? "Weather / Interruption"})',
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: ElevatedButton.icon(
                                                onPressed: _isActionLoading ? null : _handleResumeOd,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF16A34A),
                                                  foregroundColor: Colors.white,
                                                  minimumSize: const Size(0, 40),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  elevation: 0,
                                                ),
                                                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                                                label: const Text('Resume OD (Photo Proof)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              flex: 2,
                                              child: OutlinedButton.icon(
                                                onPressed: _isActionLoading ? null : _handleCancelOd,
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: const Color(0xFFDC2626),
                                                  side: const BorderSide(color: Color(0xFFEF4444)),
                                                  minimumSize: const Size(0, 40),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                ),
                                                icon: const Icon(Icons.cancel_outlined, size: 15),
                                                label: const Text('Cancel OD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                if (isSiteReached) {
                                  return Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: ElevatedButton.icon(
                                          onPressed: _isActionLoading ? null : () => _handleCompleteSiteWork(index),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF16A34A),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            elevation: 0,
                                          ),
                                          icon: const Icon(Icons.check_circle_outline, size: 17),
                                          label: const Text(
                                            'Complete OD Work (Photo Proof)',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: OutlinedButton.icon(
                                          onPressed: _isActionLoading ? null : () => _handleNotCompletedSiteWork(index),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFFDC2626),
                                            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            side: const BorderSide(color: Color(0xFFEF4444)),
                                          ),
                                          icon: const Icon(Icons.cancel_outlined, size: 15),
                                          label: const Text(
                                            'Not Completed',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                } else if (isSiteTraveling) {
                                  return Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: ElevatedButton.icon(
                                          onPressed: _isActionLoading ? null : () => _handleReachedSite(index),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: primaryColor,
                                            foregroundColor: darkAccent,
                                            minimumSize: const Size(0, 44),
                                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            elevation: 0,
                                          ),
                                          icon: const Icon(Icons.camera_alt_outlined, size: 16),
                                          label: const Text(
                                            'Reached Site (Photo)',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: OutlinedButton.icon(
                                          onPressed: _isActionLoading ? null : _handleCancelOd,
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFFDC2626),
                                            minimumSize: const Size(0, 44),
                                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            side: const BorderSide(color: Color(0xFFEF4444)),
                                          ),
                                          icon: const Icon(Icons.cancel_outlined, size: 15),
                                          label: const Text(
                                            'Cancel OD',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                } else {
                                  return Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: ElevatedButton.icon(
                                          onPressed: _isActionLoading ? null : () => _handleStartSiteTrip(index),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: primaryColor,
                                            foregroundColor: darkAccent,
                                            minimumSize: const Size(0, 44),
                                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            elevation: 0,
                                          ),
                                          icon: const Icon(Icons.directions_car_outlined, size: 16),
                                          label: Text(
                                            'Start Site ${index + 1} Trip',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: OutlinedButton.icon(
                                          onPressed: _isActionLoading ? null : () => _handleNotCompletedSiteWork(index),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFFDC2626),
                                            minimumSize: const Size(0, 44),
                                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            side: const BorderSide(color: Color(0xFFEF4444)),
                                          ),
                                          icon: const Icon(Icons.cancel_outlined, size: 15),
                                          label: const Text(
                                            'Not Completed',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
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
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.directions_car_filled, size: 20),
                          label: const Text(
                            'Return to Office',
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
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.location_city, size: 20),
                          label: const Text(
                            'Confirm Arrival at Office',
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
            if (widget.assignment.projectCode != null && widget.assignment.projectCode!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF9CC70A).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.folder_outlined, size: 12, color: Color(0xFF414A51)),
                    const SizedBox(width: 4),
                    Text(
                      widget.assignment.projectCode!,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
                    ),
                  ],
                ),
              ),
            ],
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
                      const Text('Reached Photo ✓  ', style: TextStyle(fontSize: 11, color: Color(0xFF15803D), fontWeight: FontWeight.w600)),
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
    final displayReason = assignment.isCancelled
        ? (assignment.cancellationReason ?? assignment.notCompletedReason)
        : assignment.notCompletedReason;

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
                    assignment.isCancelled ? '${assignment.odType} - CANCELLED' : '${assignment.odType} - NOT COMPLETED',
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
            if (assignment.projectCode != null && assignment.projectCode!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF9CC70A).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.folder_outlined, size: 12, color: Color(0xFF414A51)),
                    const SizedBox(width: 4),
                    Text(
                      assignment.projectCode!,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
                    ),
                  ],
                ),
              ),
            ],
            if (displayReason != null && displayReason.isNotEmpty) ...[
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
                    Text(
                      assignment.isCancelled ? 'Reason for Cancellation:' : 'Reason for Non-Completion:',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayReason,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                    ),
                    if (assignment.cancellationPhoto != null && assignment.cancellationPhoto!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Cancellation Proof Photo:',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          height: 100,
                          width: 140,
                          child: _buildThumbnailImage(assignment.cancellationPhoto!),
                        ),
                      ),
                    ],
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

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Color titleColor,
    required double lat,
    required double lng,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 15, color: iconColor),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 2),
              ReverseGeocodedLocationText(
                latitude: lat,
                longitude: lng,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: () => _openMap(lat, lng),
          borderRadius: BorderRadius.circular(6),
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
            const SizedBox(height: 8),
            _buildLocationRow(
              icon: Icons.navigation_outlined,
              iconColor: const Color(0xFFD97706),
              title: 'Started Location${startTimeStr != null && startTimeStr.isNotEmpty ? " ($startTimeStr)" : ""}',
              titleColor: const Color(0xFFB45309),
              lat: startLat,
              lng: startLng,
            ),
          ],
          if (reachedLat != null && reachedLng != null) ...[
            const SizedBox(height: 8),
            _buildLocationRow(
              icon: Icons.location_on,
              iconColor: const Color(0xFF414A51),
              title: 'Reached Location${reachedTimeStr != null && reachedTimeStr.isNotEmpty ? " ($reachedTimeStr)" : ""}',
              titleColor: const Color(0xFF414A51),
              lat: reachedLat,
              lng: reachedLng,
            ),
          ],
          if (endLat != null && endLng != null && (site.isCompleted || site.isNotCompleted || widget.assignment.isCompleted || widget.assignment.isNotCompleted)) ...[
            const SizedBox(height: 8),
            _buildLocationRow(
              icon: (site.isNotCompleted || widget.assignment.isNotCompleted) ? Icons.cancel_outlined : Icons.check_circle_outline,
              iconColor: (site.isNotCompleted || widget.assignment.isNotCompleted) ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
              title: '${(site.isNotCompleted || widget.assignment.isNotCompleted) ? "Not Completed Location" : "Completed Location"}${completedTimeStr != null && completedTimeStr.isNotEmpty ? " ($completedTimeStr)" : ""}',
              titleColor: (site.isNotCompleted || widget.assignment.isNotCompleted) ? const Color(0xFFDC2626) : const Color(0xFF15803D),
              lat: endLat,
              lng: endLng,
            ),
          ],
          if (widget.assignment.returnLatitude != null && widget.assignment.returnLongitude != null) ...[
            const SizedBox(height: 8),
            _buildLocationRow(
              icon: Icons.directions_car_rounded,
              iconColor: const Color(0xFF2563EB),
              title: 'Return Started Location${widget.assignment.returnStartTime != null ? " (${widget.assignment.returnStartTime})" : ""}',
              titleColor: const Color(0xFF1D4ED8),
              lat: widget.assignment.returnLatitude!,
              lng: widget.assignment.returnLongitude!,
            ),
          ],
          if (widget.assignment.officeLatitude != null && widget.assignment.officeLongitude != null) ...[
            const SizedBox(height: 8),
            _buildLocationRow(
              icon: Icons.location_city_rounded,
              iconColor: const Color(0xFF16A34A),
              title: 'Office Reached Location${widget.assignment.officeReachedTime != null ? " (${widget.assignment.officeReachedTime})" : ""}',
              titleColor: const Color(0xFF15803D),
              lat: widget.assignment.officeLatitude!,
              lng: widget.assignment.officeLongitude!,
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
