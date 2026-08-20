class PermissionBalance {
  final int employeeId;
  final DateTime month;
  final int monthlyLimitMinutes;
  final int monthlyUsedMinutes;
  final int todayLimitMinutes;
  final int todayUsedMinutes;

  const PermissionBalance({
    required this.employeeId,
    required this.month,
    required this.monthlyLimitMinutes,
    required this.monthlyUsedMinutes,
    required this.todayLimitMinutes,
    required this.todayUsedMinutes,
  });

  int get monthlyRemainingMinutes =>
      (monthlyLimitMinutes - monthlyUsedMinutes).clamp(0, monthlyLimitMinutes);

  int get todayRemainingMinutes =>
      (todayLimitMinutes - todayUsedMinutes).clamp(0, todayLimitMinutes);

  double get monthlyUsedHours => monthlyUsedMinutes / 60.0;
  double get monthlyRemainingHours => monthlyRemainingMinutes / 60.0;
  double get monthlyLimitHours => monthlyLimitMinutes / 60.0;

  double get todayUsedHours => todayUsedMinutes / 60.0;
  double get todayRemainingHours => todayRemainingMinutes / 60.0;
  double get todayLimitHours => todayLimitMinutes / 60.0;
}
