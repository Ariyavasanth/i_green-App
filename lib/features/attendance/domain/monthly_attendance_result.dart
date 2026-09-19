import '../../employee/domain/employee.dart';
import '../../leave/domain/leave_request.dart';
import '../../on_duty/domain/on_duty_assignment.dart';
import 'attendance_record.dart';
import 'attendance_status_helper.dart';

class DailyAttendanceResult {
  const DailyAttendanceResult({
    required this.date,
    required this.dateStr,
    required this.statusInfo,
    required this.statusCode,
    required this.statusLabel,
    this.record,
    required this.isWorkingDay,
    required this.requiredHours,
    required this.workingHours,
    required this.shortfallHours,
  });

  final DateTime date;
  final String dateStr;
  final AttendanceStatusInfo? statusInfo;
  final String statusCode;
  final String statusLabel;
  final AttendanceRecord? record;
  final bool isWorkingDay;
  final double requiredHours;
  final double workingHours;
  final double shortfallHours;

  Map<String, dynamic> toMap() => {
        'date': date.toIso8601String(),
        'date_str': dateStr,
        'status_code': statusCode,
        'status_label': statusLabel,
        'is_working_day': isWorkingDay,
        'required_hours': requiredHours,
        'working_hours': workingHours,
        'shortfall_hours': shortfallHours,
        if (record != null) 'record': record!.toMap(),
      };
}

class MonthlyAttendanceResult {
  const MonthlyAttendanceResult({
    required this.employeeId,
    required this.employeeCode,
    required this.employeeName,
    required this.year,
    required this.month,
    required this.monthYear,
    required this.totalDaysInMonth,
    required this.presentCount,
    required this.lateCount,
    required this.absentCount,
    required this.onLeaveCount,
    required this.onDutyCount,
    required this.weeklyOffCount,
    required this.holidayCount,
    required this.missingCheckoutCount,
    required this.insufficientHoursCount,
    required this.totalWorkingDays,
    required this.totalRequiredHours,
    required this.totalWorkingHours,
    required this.totalShortfallHours,
    required this.dailyResults,
  });

  final int employeeId;
  final String employeeCode;
  final String employeeName;
  final int year;
  final int month;
  final String monthYear;
  final int totalDaysInMonth;

  // Counts
  final int presentCount;
  final int lateCount;
  final int absentCount;
  final int onLeaveCount;
  final int onDutyCount;
  final int weeklyOffCount;
  final int holidayCount;
  final int missingCheckoutCount;
  final int insufficientHoursCount;

  // Hours
  final int totalWorkingDays;
  final double totalRequiredHours;
  final double totalWorkingHours;
  final double totalShortfallHours;

  final List<DailyAttendanceResult> dailyResults;

  String get formattedRequiredHours => AttendanceRecord.formatHours(totalRequiredHours);
  String get formattedWorkingHours => AttendanceRecord.formatHours(totalWorkingHours);
  String get formattedShortfallHours =>
      totalShortfallHours <= 0 ? '0hr' : AttendanceRecord.formatHours(totalShortfallHours);

  Map<String, dynamic> toMap() => {
        'employee_id': employeeId,
        'employee_code': employeeCode,
        'employee_name': employeeName,
        'year': year,
        'month': month,
        'month_year': monthYear,
        'total_days_in_month': totalDaysInMonth,
        'present_count': presentCount,
        'late_count': lateCount,
        'absent_count': absentCount,
        'on_leave_count': onLeaveCount,
        'on_duty_count': onDutyCount,
        'weekly_off_count': weeklyOffCount,
        'holiday_count': holidayCount,
        'missing_checkout_count': missingCheckoutCount,
        'insufficient_hours_count': insufficientHoursCount,
        'total_working_days': totalWorkingDays,
        'total_required_hours': totalRequiredHours,
        'total_working_hours': totalWorkingHours,
        'total_shortfall_hours': totalShortfallHours,
        'daily_results': dailyResults.map((d) => d.toMap()).toList(),
      };

  factory MonthlyAttendanceResult.empty({
    int employeeId = 0,
    String employeeCode = '',
    String employeeName = '',
    int year = 2026,
    int month = 1,
  }) {
    final days = DateTime(year, month + 1, 0).day;
    return MonthlyAttendanceResult(
      employeeId: employeeId,
      employeeCode: employeeCode,
      employeeName: employeeName,
      year: year,
      month: month,
      monthYear: '${month.toString().padLeft(2, '0')}-$year',
      totalDaysInMonth: days,
      presentCount: 0,
      lateCount: 0,
      absentCount: 0,
      onLeaveCount: 0,
      onDutyCount: 0,
      weeklyOffCount: 0,
      holidayCount: 0,
      missingCheckoutCount: 0,
      insufficientHoursCount: 0,
      totalWorkingDays: 0,
      totalRequiredHours: 0.0,
      totalWorkingHours: 0.0,
      totalShortfallHours: 0.0,
      dailyResults: const [],
    );
  }
}

class MonthlyAttendanceCalculator {
  static MonthlyAttendanceResult calculate({
    required Employee employee,
    required int year,
    required int month,
    required List<AttendanceRecord> records,
    List<LeaveRequest>? leaves,
    List<OnDutyAssignment>? onDutyAssignments,
    List<String>? holidays,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final lastDayOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);
    final effectiveRefDate = now.isAfter(lastDayOfMonth) ? DateTime(year, month + 1, 1) : now;

    final daysInMonth = DateTime(year, month + 1, 0).day;
    final monthYear = '${month.toString().padLeft(2, '0')}-$year';

    final recordMap = <String, AttendanceRecord>{};
    for (final r in records) {
      final norm = _normalizeDateKey(r.date);
      if (r.employeeId == employee.id ||
          (r.employeeCode.isNotEmpty &&
              employee.employeeId.isNotEmpty &&
              r.employeeCode.trim().toLowerCase() == employee.employeeId.trim().toLowerCase())) {
        recordMap[norm] = r;
      }
    }

    int presentCount = 0;
    int lateCount = 0;
    int absentCount = 0;
    int onLeaveCount = 0;
    int onDutyCount = 0;
    int weeklyOffCount = 0;
    int holidayCount = 0;
    int missingCheckoutCount = 0;
    int insufficientHoursCount = 0;

    double totalWorkingHours = 0.0;
    int totalWorkingDays = 0;
    final List<DailyAttendanceResult> dailyResults = [];

    final dailyRequiredHours =
        employee.requiredWorkingHours > 0 ? employee.requiredWorkingHours : 9.0;

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final dateStr =
          '${day.toString().padLeft(2, '0')}-${month.toString().padLeft(2, '0')}-$year';

      final record = recordMap[dateStr];

      // 1. Resolve daily status using authoritative AttendanceStatusHelper
      final statusInfo = AttendanceStatusHelper.resolveStatus(
        employee: employee,
        date: date,
        record: record,
        leaves: leaves,
        onDutyAssignments: onDutyAssignments,
        holidays: holidays,
        referenceDate: effectiveRefDate,
      );

      final isWeeklyOff = statusInfo == AttendanceStatusInfo.weeklyOff;
      final isHoliday = statusInfo == AttendanceStatusInfo.holiday;
      final isWorkingDay = !isWeeklyOff && !isHoliday;

      if (isWorkingDay) {
        totalWorkingDays++;
      }

      // Working hours from dynamic sessions / record
      final dayWorkingHours = record?.computedTotalHours ?? 0.0;
      totalWorkingHours += dayWorkingHours;

      // Status categorization counters
      switch (statusInfo) {
        case AttendanceStatusInfo.present:
          presentCount++;
          break;
        case AttendanceStatusInfo.late:
          lateCount++;
          break;
        case AttendanceStatusInfo.absent:
          absentCount++;
          break;
        case AttendanceStatusInfo.onLeave:
          onLeaveCount++;
          break;
        case AttendanceStatusInfo.onDuty:
          onDutyCount++;
          break;
        case AttendanceStatusInfo.weeklyOff:
          weeklyOffCount++;
          break;
        case AttendanceStatusInfo.holiday:
          holidayCount++;
          break;
        case AttendanceStatusInfo.missingCheckout:
          missingCheckoutCount++;
          break;
        case AttendanceStatusInfo.insufficientHours:
          insufficientHoursCount++;
          break;
        case null:
          break;
      }

      final reqHoursForDay = isWorkingDay ? dailyRequiredHours : 0.0;
      final shortfallForDay =
          isWorkingDay ? (reqHoursForDay - dayWorkingHours).clamp(0.0, 999.0) : 0.0;

      dailyResults.add(DailyAttendanceResult(
        date: date,
        dateStr: dateStr,
        statusInfo: statusInfo,
        statusCode: statusInfo?.code ?? '-',
        statusLabel: statusInfo?.label ?? (record != null ? record.status : 'Pending'),
        record: record,
        isWorkingDay: isWorkingDay,
        requiredHours: reqHoursForDay,
        workingHours: dayWorkingHours,
        shortfallHours: double.parse(shortfallForDay.toStringAsFixed(2)),
      ));
    }

    totalWorkingHours = double.parse(totalWorkingHours.toStringAsFixed(2));
    final totalRequiredHours =
        double.parse((totalWorkingDays * dailyRequiredHours).toStringAsFixed(2));
    final totalShortfallHours = totalRequiredHours > totalWorkingHours
        ? double.parse((totalRequiredHours - totalWorkingHours).toStringAsFixed(2))
        : 0.0;

    return MonthlyAttendanceResult(
      employeeId: employee.id,
      employeeCode: employee.employeeId,
      employeeName: employee.fullName,
      year: year,
      month: month,
      monthYear: monthYear,
      totalDaysInMonth: daysInMonth,
      presentCount: presentCount,
      lateCount: lateCount,
      absentCount: absentCount,
      onLeaveCount: onLeaveCount,
      onDutyCount: onDutyCount,
      weeklyOffCount: weeklyOffCount,
      holidayCount: holidayCount,
      missingCheckoutCount: missingCheckoutCount,
      insufficientHoursCount: insufficientHoursCount,
      totalWorkingDays: totalWorkingDays,
      totalRequiredHours: totalRequiredHours,
      totalWorkingHours: totalWorkingHours,
      totalShortfallHours: totalShortfallHours,
      dailyResults: dailyResults,
    );
  }

  static String _normalizeDateKey(String dateStr) {
    if (dateStr.trim().isEmpty) return dateStr;
    try {
      final isoDate = DateTime.tryParse(dateStr);
      if (isoDate != null) {
        return '${isoDate.day.toString().padLeft(2, '0')}-${isoDate.month.toString().padLeft(2, '0')}-${isoDate.year}';
      }
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        if (parts[0].length == 4) {
          return '${parts[2].padLeft(2, '0')}-${parts[1].padLeft(2, '0')}-${parts[0]}';
        } else {
          return '${parts[0].padLeft(2, '0')}-${parts[1].padLeft(2, '0')}-${parts[2]}';
        }
      }
    } catch (_) {}
    return dateStr;
  }
}
