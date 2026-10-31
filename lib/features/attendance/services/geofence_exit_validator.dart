import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Isolated helper for geofence exit validation, debouncing, and confirmation.
///
/// Ensures background location monitoring and auto-checkout are reliable by:
/// 1. Rejecting invalid, imprecise (>100m accuracy), or mocked GPS readings.
/// 2. Filtering transient GPS jitter/multipath hops at office boundaries using consecutive exit checks.
/// 3. Confirming an exit ONLY after multiple consecutive outside-geofence readings before connecting to checkout.
/// 4. Recording the initial exit timestamp so overtime or departure calculations reflect true boundary departure time.
/// 5. Automatically resetting candidate state whenever coordinates return safely inside the geofence.
class GeofenceExitValidator {
  const GeofenceExitValidator._();

  static const int defaultRequiredConsecutiveExits = 2;
  static const double maxReliableAccuracyMeters = 100.0;

  // In-memory candidate storage per employee (used in main UI isolate)
  static final Map<int, _ExitCandidateState> _activeCandidates = {};

  /// Validates GPS coordinate quality and sanity.
  /// Returns false if coordinates are 0,0, accuracy is unusable (>100m or <=0), or location is mocked.
  static bool isValidGpsReading({
    required double latitude,
    required double longitude,
    required double accuracy,
    required bool isMocked,
  }) {
    if (latitude == 0.0 && longitude == 0.0) return false;
    if (accuracy <= 0 || accuracy > maxReliableAccuracyMeters) return false;
    if (!kIsWeb && isMocked) return false;
    return true;
  }

  /// In-Memory: Records an outside-geofence observation for [employeeId].
  /// Returns true only if the exit is CONFIRMED (consecutive exits >= [requiredExits]).
  static bool recordExitObservation({
    required int employeeId,
    required DateTime timestamp,
    int requiredExits = defaultRequiredConsecutiveExits,
  }) {
    final candidate = _activeCandidates[employeeId];
    final formattedTime = DateFormat('hh:mm:ss a').format(timestamp);

    if (candidate == null) {
      _activeCandidates[employeeId] = _ExitCandidateState(
        firstExitTime: formattedTime,
        firstExitTimestamp: timestamp,
        consecutiveCount: 1,
      );
      return requiredExits <= 1;
    } else {
      candidate.consecutiveCount++;
      return candidate.consecutiveCount >= requiredExits;
    }
  }

  /// In-Memory: Resets any pending candidate exit for [employeeId] when confirmed inside geofence.
  static void resetCandidate(int employeeId) {
    _activeCandidates.remove(employeeId);
  }

  /// In-Memory: Gets the initial recorded exit time string (e.g. '05:30:00 PM') for [employeeId].
  static String? getFirstExitTime(int employeeId) {
    return _activeCandidates[employeeId]?.firstExitTime;
  }

  /// In-Memory: Gets current consecutive exit count for testing/debugging.
  static int getConsecutiveExitCount(int employeeId) {
    return _activeCandidates[employeeId]?.consecutiveCount ?? 0;
  }

  // --- SharedPreferences Persistent Helpers for Background Isolate (TaskHandler) ---

  static String _prefKeyCount(int empId) => 'bg_exit_count_$empId';
  static String _prefKeyTime(int empId) => 'bg_exit_time_$empId';

  /// Async / Persistent: Records an outside-geofence observation in SharedPreferences.
  /// Used in background foreground task isolate.
  static Future<bool> recordExitObservationAsync({
    required SharedPreferences prefs,
    required int employeeId,
    required DateTime timestamp,
    int requiredExits = defaultRequiredConsecutiveExits,
  }) async {
    final count = prefs.getInt(_prefKeyCount(employeeId)) ?? 0;
    final formattedTime = DateFormat('hh:mm:ss a').format(timestamp);

    if (count == 0) {
      await prefs.setInt(_prefKeyCount(employeeId), 1);
      await prefs.setString(_prefKeyTime(employeeId), formattedTime);
      return requiredExits <= 1;
    } else {
      final newCount = count + 1;
      await prefs.setInt(_prefKeyCount(employeeId), newCount);
      return newCount >= requiredExits;
    }
  }

  /// Async / Persistent: Resets candidate exit in SharedPreferences.
  static Future<void> resetCandidateAsync({
    required SharedPreferences prefs,
    required int employeeId,
  }) async {
    await prefs.remove(_prefKeyCount(employeeId));
    await prefs.remove(_prefKeyTime(employeeId));
  }

  /// Async / Persistent: Gets the initial recorded exit time from SharedPreferences.
  static Future<String?> getFirstExitTimeAsync({
    required SharedPreferences prefs,
    required int employeeId,
  }) async {
    return prefs.getString(_prefKeyTime(employeeId));
  }

  /// Resets all in-memory states (useful in unit tests).
  @visibleForTesting
  static void resetAllInMemory() {
    _activeCandidates.clear();
  }
}

class _ExitCandidateState {
  final String firstExitTime;
  final DateTime firstExitTimestamp;
  int consecutiveCount;

  _ExitCandidateState({
    required this.firstExitTime,
    required this.firstExitTimestamp,
    this.consecutiveCount = 1,
  });
}

