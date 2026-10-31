import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/features/attendance/services/geofence_exit_validator.dart';

void main() {
  group('Android Background Location Service Sanity & Safeguard Tests', () {
    setUp(() {
      GeofenceExitValidator.resetAllInMemory();
      SharedPreferences.setMockInitialValues({});
    });

    test('1. Invalid (0,0) GPS coordinates are rejected and never trigger auto-checkout', () {
      expect(
        GeofenceExitValidator.isValidGpsReading(latitude: 0.0, longitude: 0.0, accuracy: 10.0, isMocked: false),
        isFalse,
      );
      expect(
        GeofenceExitValidator.isValidGpsReading(latitude: 13.0827, longitude: 80.2707, accuracy: 250.0, isMocked: false),
        isFalse,
      );
      expect(
        GeofenceExitValidator.isValidGpsReading(latitude: 13.0827, longitude: 80.2707, accuracy: -5.0, isMocked: false),
        isFalse,
      );
      expect(
        GeofenceExitValidator.isValidGpsReading(latitude: 13.0827, longitude: 80.2707, accuracy: 15.0, isMocked: true),
        isFalse,
      );
      expect(
        GeofenceExitValidator.isValidGpsReading(latitude: 13.0827, longitude: 80.2707, accuracy: 15.0, isMocked: false),
        isTrue,
      );
    });

    test('2. Background task monitors only during active office session without break or OD', () {
      bool shouldBackgroundMonitorRun({
        required bool hasCheckIn,
        required bool hasCheckOut,
        required bool isBreakActive,
        required bool isOdActive,
        required bool isHomeSession,
      }) {
        if (!hasCheckIn || hasCheckOut) return false;
        if (isBreakActive || isOdActive || isHomeSession) return false;
        return true;
      }

      // Active office session
      expect(shouldBackgroundMonitorRun(hasCheckIn: true, hasCheckOut: false, isBreakActive: false, isOdActive: false, isHomeSession: false), isTrue);

      // On lunch break -> background exit checkout should be suspended
      expect(shouldBackgroundMonitorRun(hasCheckIn: true, hasCheckOut: false, isBreakActive: true, isOdActive: false, isHomeSession: false), isFalse);

      // On Duty -> background exit checkout should be suspended
      expect(shouldBackgroundMonitorRun(hasCheckIn: true, hasCheckOut: false, isBreakActive: false, isOdActive: true, isHomeSession: false), isFalse);

      // Work from home -> background exit checkout should be suspended
      expect(shouldBackgroundMonitorRun(hasCheckIn: true, hasCheckOut: false, isBreakActive: false, isOdActive: false, isHomeSession: true), isFalse);

      // Already checked out -> background monitor must stop
      expect(shouldBackgroundMonitorRun(hasCheckIn: true, hasCheckOut: true, isBreakActive: false, isOdActive: false, isHomeSession: false), isFalse);
    });

    test('3. Geofence debounce: Single momentary exit does not trigger checkout, recovery inside resets state', () {
      const employeeId = 42;
      final t1 = DateTime(2026, 10, 31, 17, 30, 0);

      // Observation 1: Outside geofence -> count 1, NOT confirmed
      final confirmed1 = GeofenceExitValidator.recordExitObservation(
        employeeId: employeeId,
        timestamp: t1,
        requiredExits: 2,
      );
      expect(confirmed1, isFalse);
      expect(GeofenceExitValidator.getConsecutiveExitCount(employeeId), equals(1));
      expect(GeofenceExitValidator.getFirstExitTime(employeeId), isNotNull);

      // Employee walks back inside office -> candidate is reset
      GeofenceExitValidator.resetCandidate(employeeId);
      expect(GeofenceExitValidator.getConsecutiveExitCount(employeeId), equals(0));
      expect(GeofenceExitValidator.getFirstExitTime(employeeId), isNull);
    });

    test('4. Geofence debounce: Consecutive outside observations confirm valid exit with initial departure time', () {
      const employeeId = 42;
      final t1 = DateTime(2026, 10, 31, 18, 0, 0);
      final t2 = DateTime(2026, 10, 31, 18, 0, 30);

      // Observation 1: Outside geofence -> count 1, NOT confirmed
      final confirmed1 = GeofenceExitValidator.recordExitObservation(
        employeeId: employeeId,
        timestamp: t1,
        requiredExits: 2,
      );
      expect(confirmed1, isFalse);
      final firstExitTime = GeofenceExitValidator.getFirstExitTime(employeeId);

      // Observation 2 (30 seconds later): Still outside geofence -> count 2, CONFIRMED!
      final confirmed2 = GeofenceExitValidator.recordExitObservation(
        employeeId: employeeId,
        timestamp: t2,
        requiredExits: 2,
      );
      expect(confirmed2, isTrue);
      // Valid exit time retains initial departure timestamp
      expect(GeofenceExitValidator.getFirstExitTime(employeeId), equals(firstExitTime));
    });

    test('5. Background isolate SharedPreferences persistence debounce works reliably', () async {
      final prefs = await SharedPreferences.getInstance();
      const employeeId = 88;
      final t1 = DateTime(2026, 10, 31, 19, 15, 0);
      final t2 = DateTime(2026, 10, 31, 19, 15, 30);

      // First background tick outside: count 1, NOT confirmed
      final c1 = await GeofenceExitValidator.recordExitObservationAsync(
        prefs: prefs,
        employeeId: employeeId,
        timestamp: t1,
        requiredExits: 2,
      );
      expect(c1, isFalse);
      final storedTime = await GeofenceExitValidator.getFirstExitTimeAsync(prefs: prefs, employeeId: employeeId);
      expect(storedTime, isNotNull);

      // Second background tick outside: count 2, CONFIRMED!
      final c2 = await GeofenceExitValidator.recordExitObservationAsync(
        prefs: prefs,
        employeeId: employeeId,
        timestamp: t2,
        requiredExits: 2,
      );
      expect(c2, isTrue);

      // Reset on checkout completion
      await GeofenceExitValidator.resetCandidateAsync(prefs: prefs, employeeId: employeeId);
      final afterReset = await GeofenceExitValidator.getFirstExitTimeAsync(prefs: prefs, employeeId: employeeId);
      expect(afterReset, isNull);
    });
  });
}
