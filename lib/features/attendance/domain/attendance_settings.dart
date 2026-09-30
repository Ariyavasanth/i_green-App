class AttendanceLocationItem {
  const AttendanceLocationItem({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.requireGpsVerification = true,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final bool requireGpsVerification;

  AttendanceLocationItem copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    int? radiusMeters,
    bool? requireGpsVerification,
  }) {
    return AttendanceLocationItem(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      requireGpsVerification: requireGpsVerification ?? this.requireGpsVerification,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radius_meters': radiusMeters,
        'require_gps_verification': requireGpsVerification,
      };

  factory AttendanceLocationItem.fromMap(Map<String, dynamic> map) => AttendanceLocationItem(
        id: map['id']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
        radiusMeters: (map['radius_meters'] as num?)?.toInt() ?? (map['radiusMeters'] as num?)?.toInt() ?? 15,
        requireGpsVerification: map['require_gps_verification'] is bool
            ? map['require_gps_verification'] as bool
            : (map['require_gps_verification'] as num?)?.toInt() != 0,
      );
}

class AttendanceSettings {
  const AttendanceSettings({
    required this.gracePeriodMinutes,
    required this.officeLatitude,
    required this.officeLongitude,
    required this.allowedAttendanceRadiusMeters,
    required this.requireGpsVerification,
    this.locations = const [],
  });

  final int gracePeriodMinutes;
  final double officeLatitude;
  final double officeLongitude;
  final int allowedAttendanceRadiusMeters;
  final bool requireGpsVerification;
  final List<AttendanceLocationItem> locations;

  factory AttendanceSettings.defaults() => const AttendanceSettings(
        gracePeriodMinutes: 10,
        officeLatitude: 0,
        officeLongitude: 0,
        allowedAttendanceRadiusMeters: 15,
        requireGpsVerification: true,
        locations: [],
      );

  AttendanceSettings copyWith({
    int? gracePeriodMinutes,
    double? officeLatitude,
    double? officeLongitude,
    int? allowedAttendanceRadiusMeters,
    bool? requireGpsVerification,
    List<AttendanceLocationItem>? locations,
  }) {
    return AttendanceSettings(
      gracePeriodMinutes: gracePeriodMinutes ?? this.gracePeriodMinutes,
      officeLatitude: officeLatitude ?? this.officeLatitude,
      officeLongitude: officeLongitude ?? this.officeLongitude,
      allowedAttendanceRadiusMeters: allowedAttendanceRadiusMeters ?? this.allowedAttendanceRadiusMeters,
      requireGpsVerification: requireGpsVerification ?? this.requireGpsVerification,
      locations: locations ?? this.locations,
    );
  }

  AttendanceLocationItem? findMatchingLocation(String? workLocation, {String? locationId}) {
    if (locations.isEmpty) return null;
    if (locationId != null && locationId.trim().isNotEmpty) {
      final targetId = locationId.trim().toLowerCase();
      for (final loc in locations) {
        if (loc.id.trim().toLowerCase() == targetId) return loc;
      }
    }
    if (workLocation != null && workLocation.trim().isNotEmpty) {
      final targetName = workLocation.trim().toLowerCase();
      for (final loc in locations) {
        if (loc.name.trim().toLowerCase() == targetName ||
            loc.id.trim().toLowerCase() == targetName) {
          return loc;
        }
      }
    }
    return null;
  }

  Map<String, dynamic> toMap() => {
        'grace_period_minutes': gracePeriodMinutes,
        'office_latitude': officeLatitude,
        'office_longitude': officeLongitude,
        'allowed_attendance_radius_meters': allowedAttendanceRadiusMeters,
        'require_gps_verification': requireGpsVerification,
        'locations': locations.map((e) => e.toMap()).toList(),
      };

  factory AttendanceSettings.fromMap(Map<String, dynamic> map) {
    final rawLocations = map['locations'];
    final List<AttendanceLocationItem> locList = [];
    if (rawLocations is List) {
      for (final item in rawLocations) {
        if (item is Map<String, dynamic>) {
          locList.add(AttendanceLocationItem.fromMap(item));
        } else if (item is Map) {
          locList.add(AttendanceLocationItem.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    return AttendanceSettings(
      gracePeriodMinutes: map['grace_period_minutes'] as int? ?? 10,
      officeLatitude: (map['office_latitude'] as num?)?.toDouble() ?? 0,
      officeLongitude: (map['office_longitude'] as num?)?.toDouble() ?? 0,
      allowedAttendanceRadiusMeters: map['allowed_attendance_radius_meters'] as int? ?? 15,
      requireGpsVerification: map['require_gps_verification'] is bool
          ? map['require_gps_verification'] as bool
          : (map['require_gps_verification'] as num?)?.toInt() == 1,
      locations: locList,
    );
  }
}
