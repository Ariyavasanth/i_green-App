class AttendanceManagementStats {
  const AttendanceManagementStats({
    required this.totalEmployees,
    required this.presentToday,
    required this.lateToday,
    required this.checkedOutToday,
    required this.absentToday,
    required this.onLeaveToday,
    required this.averageWorkHours,
  });

  final int totalEmployees;
  final int presentToday;
  final int lateToday;
  final int checkedOutToday;
  final int absentToday;
  final int onLeaveToday;
  final double averageWorkHours;

  factory AttendanceManagementStats.empty() => const AttendanceManagementStats(
        totalEmployees: 0,
        presentToday: 0,
        lateToday: 0,
        checkedOutToday: 0,
        absentToday: 0,
        onLeaveToday: 0,
        averageWorkHours: 0.0,
      );
}
