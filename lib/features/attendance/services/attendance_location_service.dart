import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/attendance_record.dart';
import '../providers/attendance_providers.dart';

/// Service that checks geofence boundaries and manages auto-checkout when an employee
/// exits the office premises during an active office attendance session.
class AttendanceLocationService {
  AttendanceLocationService._();
  static final AttendanceLocationService instance = AttendanceLocationService._();

  Timer? _pollingTimer;
  bool _isChecking = false;

  /// Checks if the employee is currently outside the office geofence.
  /// If an active office session exists and the employee has stepped outside the office radius,
  /// triggers automatic check-out and refreshes relevant providers.
  ///
  /// Protected against OD (On-Duty) sessions: Active OD sessions will never trigger auto-checkout.
  Future<bool> checkGeofenceAndAutoCheckOut({
    required WidgetRef ref,
    required int employeeId,
    String? exitTime,
  }) async {
    if (_isChecking || employeeId <= 0) return false;
    _isChecking = true;

    try {
      if (!kIsWeb) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          _isChecking = false;
          return false;
        }
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _isChecking = false;
        return false;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final attendanceRepo = ref.read(attendanceRepositoryProvider);
      final didAutoCheckOut = await attendanceRepo.handleGeofenceExitAutoCheckOut(
        employeeId: employeeId,
        currentLatitude: position.latitude,
        currentLongitude: position.longitude,
        exitTime: exitTime,
      );

      if (didAutoCheckOut) {
        ref.invalidate(todayAttendanceRecordProvider(employeeId));
        ref.invalidate(attendanceRecordsProvider(employeeId));
        ref.invalidate(allAttendanceRecordsProvider);
      }

      _isChecking = false;
      return didAutoCheckOut;
    } catch (_) {
      _isChecking = false;
      return false;
    }
  }

  /// Starts a periodic foreground boundary monitor (e.g. checks every 60 seconds).
  void startPeriodicGeofenceMonitoring({
    required WidgetRef ref,
    required int employeeId,
    Duration interval = const Duration(minutes: 1),
  }) {
    stopPeriodicGeofenceMonitoring();
    _pollingTimer = Timer.periodic(interval, (_) async {
      final todayRec = ref.read(todayAttendanceRecordProvider(employeeId)).valueOrNull;
      if (todayRec != null && todayRec.effectiveCheckInTime.isNotEmpty && todayRec.checkOutTime.isEmpty) {
        final bool isOdActive = todayRec.sessions.any((s) => s.isActive && s.isOd);
        if (!isOdActive) {
          await checkGeofenceAndAutoCheckOut(ref: ref, employeeId: employeeId);
        }
      }
    });
  }

  /// Stops periodic boundary monitoring.
  void stopPeriodicGeofenceMonitoring() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }
}
