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
  weeklyOff('WO', 'Weekly Off', Color(0xFFF1F5F9), Color(0xFF64748B));

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
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    final dateStr = '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';

    // 1. If an explicit AttendanceRecord exists
    if (record != null) {
      final stLower = record.status.trim().toLowerCase();

      if (stLower == 'present' || stLower == 'completed' || stLower == 'checked out') {
        return AttendanceStatusInfo.present;
      }
      if (stLower == 'late') {
        return AttendanceStatusInfo.late;
      }
      if (stLower == 'absent') {
        return AttendanceStatusInfo.absent;
      }
      if (stLower.contains('missing check-out') || stLower.contains('missing checkout') || stLower == 'mc') {
        return AttendanceStatusInfo.missingCheckout;
      }
      if (stLower.contains('insufficient') || stLower == 'ih') {
        return AttendanceStatusInfo.insufficientHours;
      }
      if (stLower.contains('leave') || stLower == 'half day' || stLower == 'ol') {
        return AttendanceStatusInfo.onLeave;
      }
      if (stLower.contains('on duty') || stLower == 'od') {
        return AttendanceStatusInfo.onDuty;
      }
      if (stLower.contains('holiday') || stLower == 'h') {
        return AttendanceStatusInfo.holiday;
      }
      if (stLower.contains('weekly off') || stLower == 'wo') {
        return AttendanceStatusInfo.weeklyOff;
      }

      // If check-in is present but no check-out on a past day
      if (targetDate.isBefore(today) &&
          record.effectiveCheckInTime.isNotEmpty &&
          record.checkOutTime.isEmpty) {
        return AttendanceStatusInfo.missingCheckout;
      }

      return AttendanceStatusInfo.present;
    }

    // 2. Check Leave Requests
    if (leaves != null && leaves.isNotEmpty) {
      for (final leave in leaves) {
        if (leave.employeeId == employee.id &&
            (leave.status.toLowerCase() == 'approved' || leave.status.toLowerCase() == 'pending')) {
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
        if (od.employeeId == employee.id && od.status.toUpperCase() != 'CANCELLED') {
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

    // 5. No record -> return null (renders '-')
    return null;
  }

  static DateTime? _parseDate(String val) {
    if (val.trim().isEmpty) return null;
    try {
      final isoDate = DateTime.tryParse(val);
      if (isoDate != null) return isoDate;
      final parts = val.split('-');
      if (parts.length == 3) {
        if (parts[0].length == 4) {
          return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        } else {
          return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      }
    } catch (_) {}
    return null;
  }
}
