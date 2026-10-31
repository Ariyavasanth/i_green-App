import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum LocationAccessStatus {
  granted,
  serviceDisabled, // GPS is disabled on the device
  denied,          // Denied once (promptable with rationale)
  deniedForever,   // Permanently denied (requires navigating to app settings)
}

class LocationPermissionHelper {
  const LocationPermissionHelper._();

  /// Checks the current location availability and permission without prompting the user.
  static Future<LocationAccessStatus> checkLocationStatus() async {
    if (!kIsWeb) {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationAccessStatus.serviceDisabled;
      }
    }

    final permission = await Geolocator.checkPermission();
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationAccessStatus.granted;
      case LocationPermission.deniedForever:
        return LocationAccessStatus.deniedForever;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationAccessStatus.denied;
    }
  }

  /// Requests location permission from the system popup.
  static Future<LocationAccessStatus> requestLocationPermission() async {
    if (!kIsWeb) {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationAccessStatus.serviceDisabled;
      }
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationAccessStatus.granted;
      case LocationPermission.deniedForever:
        return LocationAccessStatus.deniedForever;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationAccessStatus.denied;
    }
  }

  /// Opens the device's location/GPS settings page.
  static Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Opens the application details settings page so user can toggle permissions.
  static Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }
}

