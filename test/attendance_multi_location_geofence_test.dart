import 'package:flutter_test/flutter_test.dart';
import 'package:i_green_technology/features/attendance/domain/attendance_settings.dart';

void main() {
  group('AttendanceSettings & Multi-Location Geofence Tests', () {
    test('Backward compatibility: deserializes correctly when locations field is missing', () {
      final legacyMap = {
        'grace_period_minutes': 15,
        'office_latitude': 13.0827,
        'office_longitude': 80.2707,
        'allowed_attendance_radius_meters': 25,
        'require_gps_verification': true,
      };

      final settings = AttendanceSettings.fromMap(legacyMap);
      expect(settings.gracePeriodMinutes, 15);
      expect(settings.officeLatitude, 13.0827);
      expect(settings.officeLongitude, 80.2707);
      expect(settings.allowedAttendanceRadiusMeters, 25);
      expect(settings.requireGpsVerification, true);
      expect(settings.locations, isEmpty);
    });

    test('Serializes and deserializes multi-location settings properly', () {
      const officeLoc = AttendanceLocationItem(
        id: 'loc_office_1',
        name: 'Head Office',
        latitude: 13.0827,
        longitude: 80.2707,
        radiusMeters: 20,
        requireGpsVerification: true,
      );

      const factoryLoc = AttendanceLocationItem(
        id: 'loc_factory_1',
        name: 'Factory Unit',
        latitude: 12.9815,
        longitude: 80.0543,
        radiusMeters: 50,
        requireGpsVerification: true,
      );

      const settings = AttendanceSettings(
        gracePeriodMinutes: 10,
        officeLatitude: 13.0827,
        officeLongitude: 80.2707,
        allowedAttendanceRadiusMeters: 15,
        requireGpsVerification: true,
        locations: [officeLoc, factoryLoc],
      );

      final map = settings.toMap();
      final restored = AttendanceSettings.fromMap(map);

      expect(restored.locations.length, 2);
      expect(restored.locations[0].name, 'Head Office');
      expect(restored.locations[0].latitude, 13.0827);
      expect(restored.locations[0].radiusMeters, 20);
      expect(restored.locations[1].name, 'Factory Unit');
      expect(restored.locations[1].latitude, 12.9815);
      expect(restored.locations[1].radiusMeters, 50);
    });

    test('findMatchingLocation matches workplace case-insensitively and returns correct location', () {
      const officeLoc = AttendanceLocationItem(
        id: 'loc_1',
        name: 'Head Office',
        latitude: 13.0827,
        longitude: 80.2707,
        radiusMeters: 20,
      );

      const factoryLoc = AttendanceLocationItem(
        id: 'loc_2',
        name: 'Factory',
        latitude: 12.9815,
        longitude: 80.0543,
        radiusMeters: 40,
      );

      const settings = AttendanceSettings(
        gracePeriodMinutes: 10,
        officeLatitude: 13.0000,
        officeLongitude: 80.0000,
        allowedAttendanceRadiusMeters: 15,
        requireGpsVerification: true,
        locations: [officeLoc, factoryLoc],
      );

      // Factory worker
      final matchedFactory = settings.findMatchingLocation('Factory');
      expect(matchedFactory, isNotNull);
      expect(matchedFactory!.latitude, 12.9815);
      expect(matchedFactory.radiusMeters, 40);

      // Case insensitive match
      final matchedLower = settings.findMatchingLocation('factory');
      expect(matchedLower, isNotNull);
      expect(matchedLower!.latitude, 12.9815);

      // Office worker
      final matchedOffice = settings.findMatchingLocation('Head Office');
      expect(matchedOffice, isNotNull);
      expect(matchedOffice!.latitude, 13.0827);
      expect(matchedOffice.radiusMeters, 20);

      // Unmatched / Unknown returns null (which falls back to global office coordinates)
      final unmatched = settings.findMatchingLocation('Remote Branch');
      expect(unmatched, isNull);

      final emptyMatch = settings.findMatchingLocation('');
      expect(emptyMatch, isNull);
    });
  });
}
