import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/attendance_record.dart';
import '../domain/attendance_repository.dart';
import '../providers/attendance_providers.dart';
import 'attendance_foreground_handler.dart';
import 'geofence_exit_validator.dart';

/// Service that checks geofence boundaries and manages auto-checkout when an employee
/// exits the office premises during an active office attendance session.
///
/// Also detects location service interruptions during active sessions, logs interruption
/// & recovery times, revalidates location on recovery before resuming monitoring,
/// and alerts the UI when location services are unavailable.
class AttendanceLocationService {
  AttendanceLocationService._();
  static final AttendanceLocationService instance = AttendanceLocationService._();

  Timer? _pollingTimer;
  bool _isChecking = false;

  /// Notifier for whether location services are currently unavailable during an active session.
  final ValueNotifier<bool> isLocationUnavailableNotifier = ValueNotifier<bool>(false);

  /// Notifier for the timestamp when location service interruption began.
  final ValueNotifier<String?> interruptionStartTimeNotifier = ValueNotifier<String?>(null);

  /// Notifier for the 10-second exit countdown popup (10..0, or null when inactive).
  final ValueNotifier<int?> exitCountdownNotifier = ValueNotifier<int?>(null);

  Timer? _countdownTimer;
  StreamSubscription<Position>? _positionStreamSub;
  bool _isRecheckingLocation = false;
  int _countdownSeconds = 10;
  WidgetRef? _pendingRef;
  int? _pendingEmployeeId;
  double? _pendingLatitude;
  double? _pendingLongitude;
  String? _pendingExitTime;

  bool _isLocationUnavailable = false;
  String? _interruptionStartTime;

  bool get isLocationUnavailable => _isLocationUnavailable;
  String? get interruptionStartTime => _interruptionStartTime;
  int? get exitCountdownSeconds => exitCountdownNotifier.value;

  /// Checks if the employee is currently outside the office geofence.
  /// If an active office session exists and the employee has stepped outside the office radius,
  /// triggers automatic check-out and refreshes relevant providers.
  ///
  /// Protected against OD (On-Duty) sessions: Active OD sessions will never trigger auto-checkout.
  /// Also detects location service unavailability and logs interruption/recovery timestamps.
  Future<bool> checkGeofenceAndAutoCheckOut({
    required WidgetRef ref,
    required int employeeId,
    String? exitTime,
  }) async {
    if (_isChecking || employeeId <= 0) return false;
    _isChecking = true;

    try {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final nowFormattedTime = DateFormat('hh:mm:ss a').format(now);

      bool locationAvailable = true;
      String unavailableReason = '';

      if (!kIsWeb) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          locationAvailable = false;
          unavailableReason = 'Location services are disabled on device';
        }
      }

      if (locationAvailable) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          locationAvailable = false;
          unavailableReason = 'Location permission is denied';
        }
      }

      Position? position;
      if (locationAvailable) {
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 15),
          );
        } catch (e) {
          final serviceEnabled = !kIsWeb ? await Geolocator.isLocationServiceEnabled() : true;
          if (!serviceEnabled) {
            locationAvailable = false;
            unavailableReason = 'Location services are disabled on device';
          } else {
            // Transient acquisition timeout: safe skip without false interruption
            _isChecking = false;
            return false;
          }
        }
      }

      // Filter out invalid, low-accuracy, or mocked GPS fixes upfront
      if (position != null &&
          !GeofenceExitValidator.isValidGpsReading(
            latitude: position.latitude,
            longitude: position.longitude,
            accuracy: position.accuracy,
            isMocked: !kIsWeb && position.isMocked,
          )) {
        _isChecking = false;
        return false;
      }

      final AttendanceRepository attendanceRepo;
      try {
        attendanceRepo = ref.read(attendanceRepositoryProvider);
      } catch (_) {
        _isChecking = false;
        return false;
      }

      // --- 1. Detect location services becoming unavailable during active session ---
      if (!locationAvailable) {
        if (!_isLocationUnavailable) {
          _isLocationUnavailable = true;
          isLocationUnavailableNotifier.value = true;
          _interruptionStartTime = nowFormattedTime;
          interruptionStartTimeNotifier.value = _interruptionStartTime;

          // Record interruption start time when connectivity permits
          try {
            await attendanceRepo.recordLocationInterruption(
              employeeId: employeeId,
              date: todayStr,
              startTime: _interruptionStartTime!,
              reason: unavailableReason,
            );
          } catch (_) {}
        }
        _isChecking = false;
        return false;
      }

      // --- 2. On recovery, revalidate location before resuming geofence monitoring ---
      if (_isLocationUnavailable && locationAvailable && position != null) {
        final recoveryTime = nowFormattedTime;
        final startT = _interruptionStartTime ?? recoveryTime;

        // Reset interruption state
        _isLocationUnavailable = false;
        isLocationUnavailableNotifier.value = false;
        _interruptionStartTime = null;
        interruptionStartTimeNotifier.value = null;

        // Record recovery time when connectivity permits
        try {
          await attendanceRepo.recordLocationInterruption(
            employeeId: employeeId,
            date: todayStr,
            startTime: startT,
            endTime: recoveryTime,
            reason: 'Location services restored',
          );
        } catch (_) {}

        // Revalidate location before resuming geofence monitoring
        final isInside = await attendanceRepo.verifyLocationWithinGeofence(
          employeeId: employeeId,
          latitude: position.latitude,
          longitude: position.longitude,
        );

        if (!isInside) {
          // Employee recovered outside office geofence -> trigger geofence exit checkout
          final didAutoCheckOut = await attendanceRepo.handleGeofenceExitAutoCheckOut(
            employeeId: employeeId,
            currentLatitude: position.latitude,
            currentLongitude: position.longitude,
            exitTime: exitTime ?? recoveryTime,
          );

          if (didAutoCheckOut) {
            GeofenceExitValidator.resetCandidate(employeeId);
            await stopBackgroundMonitoring();
            try {
              ref.invalidate(todayAttendanceRecordProvider(employeeId));
              ref.invalidate(attendanceRecordsProvider(employeeId));
              ref.invalidate(allAttendanceRecordsProvider);
            } catch (_) {}
          }
          _isChecking = false;
          return didAutoCheckOut;
        }

        // Inside geofence: safe to continue normal monitoring
        GeofenceExitValidator.resetCandidate(employeeId);
        _isChecking = false;
        return false;
      }

      // --- 3. Normal Geofence monitoring when location is healthy ---
      if (position != null) {
        final isInside = await attendanceRepo.verifyLocationWithinGeofence(
          employeeId: employeeId,
          latitude: position.latitude,
          longitude: position.longitude,
        );

        if (isInside) {
          // Employee is safely inside geofence -> cancel any active countdown & reset candidate
          cancelExitCountdown(employeeId);
          GeofenceExitValidator.resetCandidate(employeeId);
          _isChecking = false;
          return false;
        }

        // Employee detected outside office perimeter -> start 10-second countdown warning popup
        final firstExitTime = GeofenceExitValidator.getFirstExitTime(employeeId) ?? exitTime ?? nowFormattedTime;

        if (exitCountdownNotifier.value == null) {
          startExitCountdown(
            ref: ref,
            employeeId: employeeId,
            currentLatitude: position.latitude,
            currentLongitude: position.longitude,
            firstExitTime: firstExitTime,
          );
        }

        _isChecking = false;
        return false;
      }

      _isChecking = false;
      return false;
    } catch (_) {
      _isChecking = false;
      return false;
    }
  }

  /// Manually trigger location revalidation immediately (e.g. from UI retry button).
  Future<bool> revalidateLocationNow({
    required WidgetRef ref,
    required int employeeId,
  }) async {
    return checkGeofenceAndAutoCheckOut(ref: ref, employeeId: employeeId);
  }

  /// Starts the 10-second countdown gate when an employee crosses the workplace boundary.
  /// If the employee returns inside before countdown reaches 0, the checkout is aborted immediately.
  void startExitCountdown({
    required WidgetRef ref,
    required int employeeId,
    required double currentLatitude,
    required double currentLongitude,
    required String firstExitTime,
  }) {
    if (_countdownTimer != null) return;
    _pendingRef = ref;
    _pendingEmployeeId = employeeId;
    _pendingLatitude = currentLatitude;
    _pendingLongitude = currentLongitude;
    _pendingExitTime = firstExitTime;

    _countdownSeconds = 10;
    exitCountdownNotifier.value = 10;

    // Start live continuous location stream for instant re-entry detection without competing GPS locks
    try {
      _positionStreamSub?.cancel();
      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      ).listen((pos) async {
        if (_isRecheckingLocation) return;
        _isRecheckingLocation = true;
        try {
          final currentR = _pendingRef ?? _activeRef;
          if (currentR != null) {
            final attendanceRepo = currentR.read(attendanceRepositoryProvider);
            final isInside = await attendanceRepo.verifyLocationWithinGeofence(
              employeeId: employeeId,
              latitude: pos.latitude,
              longitude: pos.longitude,
            );
            if (isInside) {
              // Employee stepped back inside boundary! Cancel countdown immediately & close popup
              cancelExitCountdown(employeeId);
            }
          }
        } catch (_) {
        } finally {
          _isRecheckingLocation = false;
        }
      });
    } catch (_) {}

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      _countdownSeconds--;
      if (_countdownSeconds > 0) {
        exitCountdownNotifier.value = _countdownSeconds;

        // Fallback non-blocking check on each tick using last known fix
        if (!_isRecheckingLocation) {
          _isRecheckingLocation = true;
          try {
            final pos = await Geolocator.getLastKnownPosition();
            if (pos != null) {
              final currentR = _pendingRef ?? _activeRef;
              if (currentR != null) {
                final attendanceRepo = currentR.read(attendanceRepositoryProvider);
                final isInside = await attendanceRepo.verifyLocationWithinGeofence(
                  employeeId: employeeId,
                  latitude: pos.latitude,
                  longitude: pos.longitude,
                );
                if (isInside) {
                  cancelExitCountdown(employeeId);
                  return;
                }
              }
            }
          } catch (_) {
          } finally {
            _isRecheckingLocation = false;
          }
        }
      } else {
        // Countdown reached 0 and employee remained outside -> trigger confirmed auto-checkout!
        timer.cancel();
        _countdownTimer = null;
        _positionStreamSub?.cancel();
        _positionStreamSub = null;
        exitCountdownNotifier.value = null;

        try {
          final currentR = _pendingRef ?? _activeRef;
          if (currentR == null) return;
          final attendanceRepo = currentR.read(attendanceRepositoryProvider);
          final didAutoCheckOut = await attendanceRepo.handleGeofenceExitAutoCheckOut(
            employeeId: employeeId,
            currentLatitude: _pendingLatitude ?? currentLatitude,
            currentLongitude: _pendingLongitude ?? currentLongitude,
            exitTime: _pendingExitTime ?? firstExitTime,
          );

          GeofenceExitValidator.resetCandidate(employeeId);

          if (didAutoCheckOut) {
            await stopBackgroundMonitoring();
            try {
              currentR.invalidate(todayAttendanceRecordProvider(employeeId));
              currentR.invalidate(attendanceRecordsProvider(employeeId));
              currentR.invalidate(allAttendanceRecordsProvider);
            } catch (_) {}
          }
        } catch (_) {}
      }
    });
  }

  /// Cancels the 10-second exit countdown immediately (e.g. employee stepped back inside office).
  void cancelExitCountdown([int? employeeId]) {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _positionStreamSub?.cancel();
    _positionStreamSub = null;
    _isRecheckingLocation = false;
    exitCountdownNotifier.value = null;
    _pendingRef = null;
    _pendingEmployeeId = null;
    _pendingLatitude = null;
    _pendingLongitude = null;
    _pendingExitTime = null;
    if (employeeId != null) {
      GeofenceExitValidator.resetCandidate(employeeId);
    }
  }

  /// Confirms exit immediately (e.g. user pressed "Check Out Now" on warning popup).
  Future<void> confirmExitImmediately() async {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    exitCountdownNotifier.value = null;

    final ref = _pendingRef ?? _activeRef;
    final empId = _pendingEmployeeId ?? _monitoredEmployeeId;
    if (ref != null && empId != null && empId > 0) {
      try {
        final attendanceRepo = ref.read(attendanceRepositoryProvider);
        final didAutoCheckOut = await attendanceRepo.handleGeofenceExitAutoCheckOut(
          employeeId: empId,
          currentLatitude: _pendingLatitude ?? 0.0,
          currentLongitude: _pendingLongitude ?? 0.0,
          exitTime: _pendingExitTime,
        );
        GeofenceExitValidator.resetCandidate(empId);
        if (didAutoCheckOut) {
          await stopBackgroundMonitoring();
          try {
            ref.invalidate(todayAttendanceRecordProvider(empId));
            ref.invalidate(attendanceRecordsProvider(empId));
            ref.invalidate(allAttendanceRecordsProvider);
          } catch (_) {}
        }
      } catch (_) {}
    }
    cancelExitCountdown();
  }

  int? _monitoredEmployeeId;
  bool _isForegroundTaskInitialized = false;
  WidgetRef? _activeRef;

  WidgetRef? get activeRef => _activeRef;

  void updateActiveRef(WidgetRef ref) {
    _activeRef = ref;
  }

  void clearActiveRef([WidgetRef? ref]) {
    if (ref == null || _activeRef == ref) {
      _activeRef = null;
      _pollingTimer?.cancel();
      _pollingTimer = null;
      cancelExitCountdown();
    }
  }

  void _onReceiveTaskData(Object data) {
    if (data is Map) {
      final action = data['action'];
      if (action == 'auto_checkout') {
        cancelExitCountdown();
        final empId = (data['employeeId'] as num?)?.toInt() ?? _monitoredEmployeeId;
        if (empId != null && empId > 0 && _activeRef != null) {
          try {
            _activeRef!.invalidate(todayAttendanceRecordProvider(empId));
            _activeRef!.invalidate(attendanceRecordsProvider(empId));
            _activeRef!.invalidate(allAttendanceRecordsProvider);
          } catch (_) {
            _activeRef = null;
          }
        }
      } else if (action == 'border_crossed') {
        final empId = (data['employeeId'] as num?)?.toInt() ?? _monitoredEmployeeId;
        final lat = (data['latitude'] as num?)?.toDouble() ?? 0.0;
        final lng = (data['longitude'] as num?)?.toDouble() ?? 0.0;
        if (empId != null && empId > 0 && _activeRef != null) {
          startExitCountdown(
            ref: _activeRef!,
            employeeId: empId,
            currentLatitude: lat,
            currentLongitude: lng,
            firstExitTime: DateFormat('hh:mm:ss a').format(DateTime.now()),
          );
        }
      } else if (action == 'returned_inside') {
        cancelExitCountdown(_monitoredEmployeeId);
      }
    }
  }

  /// Initializes Android Foreground Task configurations once.
  void initForegroundTask() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android || _isForegroundTaskInitialized) return;
    _isForegroundTaskInitialized = true;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'igreen_attendance_geofence',
        channelName: 'I-Green Attendance Monitoring',
        channelDescription: 'Monitors office boundary to automatically complete checkout upon exit.',
        channelImportance: NotificationChannelImportance.DEFAULT,
        priority: NotificationPriority.DEFAULT,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(30000), // 30 seconds
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
  }

  /// Starts the Android Foreground Service for locked-screen geofence tracking.
  Future<void> startBackgroundMonitoring(int employeeId) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android || employeeId <= 0) return;
    try {
      initForegroundTask();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('bg_monitored_employee_id', employeeId);

      // Check Notification Permission on Android 13+
      final notifPermission = await FlutterForegroundTask.checkNotificationPermission();
      if (notifPermission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }

      final isRunning = await FlutterForegroundTask.isRunningService;
      if (isRunning) {
        await FlutterForegroundTask.restartService();
      } else {
        await FlutterForegroundTask.startService(
          serviceId: 256,
          notificationTitle: 'I-Green Attendance Active',
          notificationText: 'Shift active • Workplace departure monitored',
          callback: attendanceTaskCallback,
        );
      }
    } catch (e) {
      debugPrint('startBackgroundMonitoring notice: $e');
    }
  }

  /// Stops the Android Foreground Service and clears the monitored employee ID.
  Future<void> stopBackgroundMonitoring() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('bg_monitored_employee_id');
      final isRunning = await FlutterForegroundTask.isRunningService;
      if (isRunning) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {}
  }

  /// Starts a periodic foreground boundary monitor (e.g. checks every 30 seconds).
  /// Safe to call multiple times; if already monitoring for this employee, it preserves the existing timer.
  void startPeriodicGeofenceMonitoring({
    required WidgetRef ref,
    required int employeeId,
    Duration interval = const Duration(seconds: 30),
  }) {
    _activeRef = ref;
    if (_monitoredEmployeeId == employeeId && _pollingTimer != null && _pollingTimer!.isActive) {
      return; // Already actively monitoring this employee
    }
    stopPeriodicGeofenceMonitoring();
    _monitoredEmployeeId = employeeId;
    _activeRef = ref;

    initForegroundTask();

    _pollingTimer = Timer.periodic(interval, (_) async {
      final currentRef = _activeRef ?? ref;
      try {
        final todayRec = currentRef.read(todayAttendanceRecordProvider(employeeId)).valueOrNull;
        final bool hasActiveSession = todayRec != null &&
            (todayRec.sessions.any((s) => s.isActive) ||
             (todayRec.effectiveCheckInTime.isNotEmpty && todayRec.checkOutTime.isEmpty));

        if (todayRec != null && hasActiveSession) {
          final activeSession = todayRec.sessions.where((s) => s.isActive).firstOrNull;

          // 1. Exemption: Active Time Clocking (Lunch, Break, Meeting, etc.)
          final bool isTimeClockingActive = activeSession != null &&
              (activeSession.isLunch ||
               activeSession.isTeaBreak ||
               activeSession.isMeetingOrOther ||
               activeSession.type.toLowerCase().contains('lunch') ||
               activeSession.type.toLowerCase().contains('break') ||
               activeSession.type.toLowerCase().contains('meeting') ||
               activeSession.type.toLowerCase().contains('task'));
          if (isTimeClockingActive) {
            unawaited(stopBackgroundMonitoring());
            return;
          }

          // 2. Exemption: Active OD session
          final bool isOdActive = activeSession != null && activeSession.isOd;
          if (isOdActive) {
            unawaited(stopBackgroundMonitoring());
            return;
          }

          // 3. Exemption: Started from Home
          final bool isStartedFromHome = activeSession != null &&
              (activeSession.checkInMethod.toLowerCase().contains('home') ||
               activeSession.checkInVerificationStatus.toLowerCase().contains('home') ||
               activeSession.notes.toLowerCase().contains('starts from home'));
          if (isStartedFromHome) {
            unawaited(stopBackgroundMonitoring());
            return;
          }

          // 4. Regular Office Session -> Keep Android background service active for screen locked
          unawaited(startBackgroundMonitoring(employeeId));

          // 5. Check geofence boundary & auto check-out if outside radius while app is active
          await checkGeofenceAndAutoCheckOut(ref: currentRef, employeeId: employeeId);
        } else if (todayRec != null && !hasActiveSession && (todayRec.checkOutTime.isNotEmpty || todayRec.status == 'Checked Out')) {
          unawaited(stopBackgroundMonitoring());
        }
      } catch (e) {
        if (e.toString().contains('disposed') || e is StateError) {
          debugPrint('AttendanceLocationService: ref is disposed, clearing active ref.');
          if (_activeRef == currentRef) {
            _activeRef = null;
          }
        } else {
          debugPrint('AttendanceLocationService periodic monitoring notice: $e');
        }
      }
    });
  }

  /// Stops periodic boundary monitoring and cleans up.
  void stopPeriodicGeofenceMonitoring() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    cancelExitCountdown(_monitoredEmployeeId);
    _monitoredEmployeeId = null;
    unawaited(stopBackgroundMonitoring());
  }
}
