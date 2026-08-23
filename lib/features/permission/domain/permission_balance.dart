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

  static String formatMinutes(int totalMinutes) {
    if (totalMinutes <= 0) return '0m';
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (hours > 0 && mins > 0) {
      return '${hours}h ${mins}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${mins}m';
    }
  }

  String get monthlyUsedFormatted => formatMinutes(monthlyUsedMinutes);
  String get monthlyRemainingFormatted => formatMinutes(monthlyRemainingMinutes);
  String get monthlyLimitFormatted => formatMinutes(monthlyLimitMinutes);

  String get todayUsedFormatted => formatMinutes(todayUsedMinutes);
  String get todayRemainingFormatted => formatMinutes(todayRemainingMinutes);
  String get todayLimitFormatted => formatMinutes(todayLimitMinutes);
}
