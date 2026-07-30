class AttendanceSettings {
  const AttendanceSettings({
    required this.gracePeriodMinutes,
    required this.lateLimitMinutes,
    required this.absentThresholdMinutes,
  });

  final int gracePeriodMinutes;
  final int lateLimitMinutes;
  final int absentThresholdMinutes;

  factory AttendanceSettings.defaults() => const AttendanceSettings(
        gracePeriodMinutes: 10,
        lateLimitMinutes: 45,
        absentThresholdMinutes: 45,
      );

  Map<String, dynamic> toMap() => {
        'grace_period_minutes': gracePeriodMinutes,
        'late_limit_minutes': lateLimitMinutes,
        'absent_threshold_minutes': absentThresholdMinutes,
      };

  factory AttendanceSettings.fromMap(Map<String, dynamic> map) => AttendanceSettings(
        gracePeriodMinutes: map['grace_period_minutes'] as int? ?? 10,
        lateLimitMinutes: map['late_limit_minutes'] as int? ?? 45,
        absentThresholdMinutes: map['absent_threshold_minutes'] as int? ?? 45,
      );
}
