class PermissionPolicy {
  final double dailyLimitHours;
  final double monthlyLimitHours;
  final bool requireApproval;
  final bool allowEmergency;
  final bool emergencyRequiresApproval;
  final bool allowMultiplePerDay;
  final bool allowPostDateEmergency;

  const PermissionPolicy({
    this.dailyLimitHours = 1.0,
    this.monthlyLimitHours = 3.0,
    this.requireApproval = true,
    this.allowEmergency = true,
    this.emergencyRequiresApproval = true,
    this.allowMultiplePerDay = false,
    this.allowPostDateEmergency = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'daily_limit_hours': dailyLimitHours,
      'monthly_limit_hours': monthlyLimitHours,
      'require_approval': requireApproval ? 1 : 0,
      'allow_emergency': allowEmergency ? 1 : 0,
      'emergency_requires_approval': emergencyRequiresApproval ? 1 : 0,
      'allow_multiple_per_day': allowMultiplePerDay ? 1 : 0,
      'allow_post_date_emergency': allowPostDateEmergency ? 1 : 0,
    };
  }

  factory PermissionPolicy.fromMap(Map<String, dynamic> map) {
    return PermissionPolicy(
      dailyLimitHours: (map['daily_limit_hours'] as num?)?.toDouble() ?? 1.0,
      monthlyLimitHours: (map['monthly_limit_hours'] as num?)?.toDouble() ?? 3.0,
      requireApproval: (map['require_approval'] ?? 1) == 1,
      allowEmergency: (map['allow_emergency'] ?? 1) == 1,
      emergencyRequiresApproval: (map['emergency_requires_approval'] ?? 1) == 1,
      allowMultiplePerDay: (map['allow_multiple_per_day'] ?? 0) == 1,
      allowPostDateEmergency: (map['allow_post_date_emergency'] ?? 0) == 1,
    );
  }
}
