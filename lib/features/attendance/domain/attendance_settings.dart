class AttendanceSettings {
  const AttendanceSettings({
    required this.gracePeriodMinutes,
    required this.lateLimitMinutes,
    required this.officeLatitude,
    required this.officeLongitude,
    required this.allowedAttendanceRadiusMeters,
    required this.requireGpsVerification,
  });

  final int gracePeriodMinutes;
  final int lateLimitMinutes;
  final double officeLatitude;
  final double officeLongitude;
  final int allowedAttendanceRadiusMeters;
  final bool requireGpsVerification;

  factory AttendanceSettings.defaults() => const AttendanceSettings(
        gracePeriodMinutes: 10,
        lateLimitMinutes: 45,
        officeLatitude: 0,
        officeLongitude: 0,
        allowedAttendanceRadiusMeters: 15,
        requireGpsVerification: true,
      );

  Map<String, dynamic> toMap() => {
        'grace_period_minutes': gracePeriodMinutes,
        'late_limit_minutes': lateLimitMinutes,
        'office_latitude': officeLatitude,
        'office_longitude': officeLongitude,
        'allowed_attendance_radius_meters': allowedAttendanceRadiusMeters,
        'require_gps_verification': requireGpsVerification,
      };

  factory AttendanceSettings.fromMap(Map<String, dynamic> map) => AttendanceSettings(
        gracePeriodMinutes: map['grace_period_minutes'] as int? ?? 10,
        lateLimitMinutes: map['late_limit_minutes'] as int? ?? 45,
        officeLatitude: (map['office_latitude'] as num?)?.toDouble() ?? 0,
        officeLongitude: (map['office_longitude'] as num?)?.toDouble() ?? 0,
        allowedAttendanceRadiusMeters: map['allowed_attendance_radius_meters'] as int? ?? 15,
        requireGpsVerification: map['require_gps_verification'] is bool
            ? map['require_gps_verification'] as bool
            : (map['require_gps_verification'] as num?)?.toInt() == 1,
      );
}
