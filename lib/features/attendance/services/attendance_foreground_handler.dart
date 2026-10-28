import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../firebase_options.dart';
import '../data/firebase_attendance_repository.dart';

/// Top-level callback required by flutter_foreground_task.
/// Must be annotated with @pragma('vm:entry-point') so it is preserved in release mode.
@pragma('vm:entry-point')
void attendanceTaskCallback() {
  FlutterForegroundTask.setTaskHandler(AttendanceTaskHandler());
}

/// TaskHandler running in the Android Foreground Service isolate.
/// Checks GPS coordinates while the device screen is locked and triggers auto-checkout
/// via the existing FirebaseAttendanceRepository if the employee crosses the office geofence.
class AttendanceTaskHandler extends TaskHandler {
  FirebaseAttendanceRepository? _repository;

  Future<void> _ensureFirebaseInitialized() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      _repository ??= FirebaseAttendanceRepository();
    } catch (e) {
      debugPrint('Background AttendanceTaskHandler Firebase init error: $e');
    }
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('Attendance Foreground Task started at $timestamp by ${starter.name}');
    await _ensureFirebaseInitialized();
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final employeeId = prefs.getInt('bg_monitored_employee_id') ?? 0;

      // If no valid employee is assigned to background monitoring, stop the service safely.
      if (employeeId <= 0) {
        await FlutterForegroundTask.stopService();
        return;
      }

      await _ensureFirebaseInitialized();
      final repo = _repository ?? FirebaseAttendanceRepository();

      // 1. Verify if device location services are enabled
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        return; // Location turned off -> safe skip, never trigger false checkout
      }

      // 2. Verify location permission
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return; // Permission missing -> safe skip
      }

      // 3. Acquire current GPS position with timeout
      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15),
        );
      } catch (_) {
        return; // GPS acquisition timeout or hardware error -> safe skip
      }

      // 4. GPS Reading Sanity Validation (Rule: Never auto-checkout on invalid GPS)
      if (position.latitude == 0.0 && position.longitude == 0.0) {
        return; // Invalid 0,0 coordinates
      }
      if (position.accuracy > 100 || position.accuracy <= 0) {
        return; // Accuracy too low (>100 meters) to reliably judge geofence exit
      }
      if (!kIsWeb && position.isMocked) {
        return; // Fake/mocked location -> ignore
      }

      // 5. Invoke the existing repository auto-checkout logic with full safeguards
      final didAutoCheckOut = await repo.handleGeofenceExitAutoCheckOut(
        employeeId: employeeId,
        currentLatitude: position.latitude,
        currentLongitude: position.longitude,
      );

      if (didAutoCheckOut) {
        debugPrint('Background Auto-Checkout successful for employee $employeeId at $timestamp');
        // Notify the main UI isolate if alive
        FlutterForegroundTask.sendDataToMain({
          'action': 'auto_checkout',
          'employeeId': employeeId,
          'time': timestamp.toIso8601String(),
        });

        // Clear monitored ID and stop the foreground service immediately
        await prefs.remove('bg_monitored_employee_id');
        await FlutterForegroundTask.stopService();
        return;
      }

      // 6. If not checked out, verify if record was already checked out manually
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final record = await repo.getAttendanceRecordForDate(employeeId, todayStr);
      final bool hasActiveSession = record != null &&
          (record.sessions.any((s) => s.isActive) ||
           (record.effectiveCheckInTime.isNotEmpty && record.checkOutTime.isEmpty));

      if (record != null &&
          !hasActiveSession &&
          (record.checkOutTime.trim().isNotEmpty || record.status == 'Checked Out')) {
        // Employee checked out manually or via other means -> tear down background monitoring
        await prefs.remove('bg_monitored_employee_id');
        await FlutterForegroundTask.stopService();
        return;
      }

      // 7. Normal operation: update notification text
      await FlutterForegroundTask.updateService(
        notificationTitle: 'I-Green Attendance Active',
        notificationText: 'Shift active • Workplace departure monitored',
      );
    } catch (e) {
      debugPrint('AttendanceTaskHandler onRepeatEvent notice: $e');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    debugPrint('Attendance Foreground Task stopped at $timestamp (isTimeout: $isTimeout)');
  }

  @override
  void onReceiveData(Object data) {
    debugPrint('Attendance Foreground Task received data: $data');
  }

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  @override
  void onNotificationDismissed() {}
}
