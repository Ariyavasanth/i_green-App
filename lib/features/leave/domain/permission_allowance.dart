class PermissionAllowance {
  const PermissionAllowance({
    required this.monthlyLimitHours,
    required this.dailyLimitHours,
    required this.usedHours,
  });

  final double monthlyLimitHours;
  final double dailyLimitHours;
  final double usedHours;

  double get remainingHours =>
      (monthlyLimitHours - usedHours).clamp(0.0, monthlyLimitHours).toDouble();
}
