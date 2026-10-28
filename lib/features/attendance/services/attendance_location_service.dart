import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/attendance_record.dart';
import '../providers/attendance_providers.dart';
import 'attendance_foreground_handler.dart';

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

  bool _isLocationUnavailable = false;
  String? _interruptionStartTime;

  bool get isLocationUnavailable => _isLocationUnavailable;
  String? get interruptionStartTime => _interruptionStartTime;

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
          );
        } catch (e) {
          locationAvailable = false;
          unavailableReason = 'Failed to acquire GPS coordinates: $e';
        }
      }

      final attendanceRepo = ref.read(attendanceRepositoryProvider);

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
            await stopBackgroundMonitoring();
            ref.invalidate(todayAttendanceRecordProvider(employeeId));
            ref.invalidate(attendanceRecordsProvider(employeeId));
            ref.invalidate(allAttendanceRecordsProvider);
          }
          _isChecking = false;
          return didAutoCheckOut;
        }

        // Inside geofence: safe to continue normal monitoring
        _isChecking = false;
        return false;
      }

      // --- 3. Normal Geofence monitoring when location is healthy ---
      if (position != null) {
        final didAutoCheckOut = await attendanceRepo.handleGeofenceExitAutoCheckOut(
          employeeId: employeeId,
          currentLatitude: position.latitude,
          currentLongitude: position.longitude,
          exitTime: exitTime,
        );

        if (didAutoCheckOut) {
          await stopBackgroundMonitoring();
          ref.invalidate(todayAttendanceRecordProvider(employeeId));
          ref.invalidate(attendanceRecordsProvider(employeeId));
          ref.invalidate(allAttendanceRecordsProvider);
        }

        _isChecking = false;
        return didAutoCheckOut;
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

  int? _monitoredEmployeeId;
  bool _isForegroundTaskInitialized = false;
  WidgetRef? _activeRef;

  void _onReceiveTaskData(Object data) {
    if (data is Map && data['action'] == 'auto_checkout') {
      final empId = (data['employeeId'] as num?)?.toInt() ?? _monitoredEmployeeId;
      if (empId != null && empId > 0 && _activeRef != null) {
        _activeRef!.invalidate(todayAttendanceRecordProvider(empId));
        _activeRef!.invalidate(attendanceRecordsProvider(empId));
        _activeRef!.invalidate(allAttendanceRecordsProvider);
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
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
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
      _activeRef = ref;
      final todayRec = ref.read(todayAttendanceRecordProvider(employeeId)).valueOrNull;
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
        await checkGeofenceAndAutoCheckOut(ref: ref, employeeId: employeeId);
      } else if (todayRec != null && !hasActiveSession && (todayRec.checkOutTime.isNotEmpty || todayRec.status == 'Checked Out')) {
        unawaited(stopBackgroundMonitoring());
      }
    });
  }

  /// Stops periodic boundary monitoring and cleans up.
  void stopPeriodicGeofenceMonitoring() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _monitoredEmployeeId = null;
    unawaited(stopBackgroundMonitoring());
  }
}
