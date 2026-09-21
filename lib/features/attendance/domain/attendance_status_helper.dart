import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../employee/domain/employee.dart';
import '../../leave/domain/leave_request.dart';
import '../../on_duty/domain/on_duty_assignment.dart';
import 'attendance_record.dart';

enum AttendanceStatusInfo {
  present('P', 'Present', Color(0xFFDCFCE7), Color(0xFF16A34A)),
  late('L', 'Late', Color(0xFFFFEDD5), Color(0xFFEA580C)),
  absent('A', 'Absent', Color(0xFFFEE2E2), Color(0xFFDC2626)),
  onLeave('OL', 'On Leave', Color(0xFFFEF9C3), Color(0xFFCA8A04)),
  onDuty('OD', 'On Duty', Color(0xFFE0F2FE), Color(0xFF0284C7)),
  missingCheckout('MC', 'Missing Checkout', Color(0xFFF3E8FF), Color(0xFF9333EA)),
  insufficientHours('IH', 'Insufficient Hours', Color(0xFFFFEDD5), Color(0xFFD97706)),
  holiday('H', 'Holiday', Color(0xFFF3E8FF), Color(0xFF7C3AED)),
  weeklyOff('WO', 'Weekly Off', Color(0xFFF1F5F9), Color(0xFF64748B)),
  beforeJoining('BJ', 'Before Joining', Color(0xFFF1F5F9), Color(0xFF94A3B8));

  final String code;
  final String label;
  final Color bgColor;
  final Color textColor;

  const AttendanceStatusInfo(this.code, this.label, this.bgColor, this.textColor);
}

class AttendanceStatusHelper {
  static AttendanceStatusInfo? resolveStatus({
    required Employee employee,
    required DateTime date,
    required AttendanceRecord? record,
    List<LeaveRequest>? leaves,
    List<OnDutyAssignment>? onDutyAssignments,
    List<String>? holidays,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    final dateStr = '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';

    // 0. Date of Joining (DOJ) minimum valid attendance date check:
    // Any date prior to employee.joiningDate MUST be treated as Before Joining.
    if (employee.joiningDate.trim().isNotEmpty) {
      final joinDt = _parseDate(employee.joiningDate);
      if (joinDt != null) {
        final cleanJoin = DateTime(joinDt.year, joinDt.month, joinDt.day);
        if (targetDate.isBefore(cleanJoin)) {
          return AttendanceStatusInfo.beforeJoining;
        }
      }
    }

    // 1. If an explicit AttendanceRecord exists
    if (record != null) {
      final stLower = record.status.trim().toLowerCase();

      if (stLower == 'absent') {
        return AttendanceStatusInfo.absent;
      }
      if (stLower.contains('leave') || stLower == 'half day' || stLower == 'ol') {
        return AttendanceStatusInfo.onLeave;
      }
      if (stLower.contains('holiday') || stLower == 'h') {
        return AttendanceStatusInfo.holiday;
      }
      if (stLower.contains('weekly off') || stLower == 'wo') {
        return AttendanceStatusInfo.weeklyOff;
      }
      if (stLower.contains('missing check-out') || stLower.contains('missing checkout') || stLower == 'mc') {
        return AttendanceStatusInfo.missingCheckout;
      }
      if (stLower.contains('insufficient') || stLower == 'ih') {
        return AttendanceStatusInfo.insufficientHours;
      }

      // If check-in is present but no check-out on a past day -> Missing Check-Out
      if (targetDate.isBefore(today) &&
          record.effectiveCheckInTime.isNotEmpty &&
          record.checkOutTime.isEmpty) {
        return AttendanceStatusInfo.missingCheckout;
      }

      if (stLower == 'late') {
        return AttendanceStatusInfo.late;
      }
      if (stLower.contains('on duty') || stLower == 'od') {
        return AttendanceStatusInfo.onDuty;
      }
      if (stLower == 'present' || stLower == 'completed' || stLower == 'checked out') {
        return AttendanceStatusInfo.present;
      }

      return AttendanceStatusInfo.present;
    }

    // 2. Check Leave Requests (Only Approved leaves resolve to On Leave)
    if (leaves != null && leaves.isNotEmpty) {
      for (final leave in leaves) {
        if (leave.employeeId == employee.id &&
            leave.status.trim().toLowerCase() == 'approved') {
          final fromDt = _parseDate(leave.fromDate);
          final toDt = _parseDate(leave.toDate) ?? fromDt;
          if (fromDt != null && toDt != null) {
            final fromClean = DateTime(fromDt.year, fromDt.month, fromDt.day);
            final toClean = DateTime(toDt.year, toDt.month, toDt.day);
            if (!targetDate.isBefore(fromClean) && !targetDate.isAfter(toClean)) {
              return AttendanceStatusInfo.onLeave;
            }
          }
        }
      }
    }

    // 3. Check On Duty Assignments
    if (onDutyAssignments != null && onDutyAssignments.isNotEmpty) {
      for (final od in onDutyAssignments) {
        if (od.employeeId == employee.id &&
            od.status.toUpperCase() != 'CANCELLED' &&
            od.status.toUpperCase() != 'REJECTED') {
          if (od.date.trim() == dateStr) {
            return AttendanceStatusInfo.onDuty;
          }
        }
      }
    }

    // 4. Check Weekly Off
    bool isWeeklyOff = false;
    final dayName = DateFormat('EEEE').format(date).toLowerCase();
    if (employee.weeklyOffDay.trim().isNotEmpty) {
      isWeeklyOff = employee.weeklyOffDay.trim().toLowerCase() == dayName;
    } else {
      isWeeklyOff = date.weekday == DateTime.sunday;
    }

    if (isWeeklyOff) {
      return AttendanceStatusInfo.weeklyOff;
    }

    // 5. Check Holidays
    if (holidays != null && holidays.isNotEmpty) {
      for (final h in holidays) {
        if (h.trim() == dateStr) {
          return AttendanceStatusInfo.holiday;
        }
        final hDt = _parseDate(h);
        if (hDt != null && DateTime(hDt.year, hDt.month, hDt.day) == targetDate) {
          return AttendanceStatusInfo.holiday;
        }
      }
    }

    // 6. Historical Past Working Day Check:
    if (targetDate.isBefore(today)) {
      return AttendanceStatusInfo.absent;
    }

    // 7. Today or Future date with no attendance -> return null (renders '-')
    return null;
  }

  static DateTime? _parseDate(String val) {
    final cleaned = val.trim();
    if (cleaned.isEmpty) return null;

    try {
      final isoDate = DateTime.tryParse(cleaned);
      if (isoDate != null) return isoDate;

      final patterns = [
        'dd-MM-yyyy',
        'dd/MM/yyyy',
        'yyyy/MM/dd',
        'yyyy-MM-dd',
        'dd-MMM-yyyy',
        'dd MMM yyyy',
        'MMM dd, yyyy',
        'dd-MMM-yy',
      ];

      for (final pattern in patterns) {
        try {
          final parsed = DateFormat(pattern).tryParse(cleaned);
          if (parsed != null) return parsed;
        } catch (_) {}
      }

      final parts = cleaned.replaceAll('/', '-').split('-');
      if (parts.length == 3) {
        int year, month, day;
        if (parts[0].length == 4) {
          year = int.parse(parts[0]);
          month = _parseMonthToken(parts[1]);
          day = int.parse(parts[2]);
        } else {
          day = int.parse(parts[0]);
          month = _parseMonthToken(parts[1]);
          year = int.parse(parts[2].length == 2 ? '20${parts[2]}' : parts[2]);
        }
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return null;
  }

  static int _parseMonthToken(String token) {
    final parsedInt = int.tryParse(token);
    if (parsedInt != null) return parsedInt;

    final lower = token.trim().toLowerCase();
    const monthNames = [
      'jan', 'feb', 'mar', 'apr', 'may', 'jun',
      'jul', 'aug', 'sep', 'oct', 'nov', 'dec'
    ];
    for (int i = 0; i < monthNames.length; i++) {
      if (lower.startsWith(monthNames[i])) {
        return i + 1;
      }
    }
    throw FormatException('Invalid month: $token');
  }
}
