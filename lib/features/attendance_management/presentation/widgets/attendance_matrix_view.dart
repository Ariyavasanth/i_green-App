import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../attendance/domain/attendance_record.dart';
import '../../../attendance/domain/attendance_status_helper.dart';
import '../../../employee/domain/employee.dart';
import '../../../leave/domain/leave_request.dart';
import '../../../on_duty/domain/on_duty_assignment.dart';

class AttendanceMatrixView extends StatelessWidget {
  const AttendanceMatrixView({
    super.key,
    required this.focusedMonth,
    required this.employees,
    required this.records,
    this.leaves,
    this.onDutyAssignments,
    required this.onCellTap,
  });

  final DateTime focusedMonth;
  final List<Employee> employees;
  final List<AttendanceRecord> records;
  final List<LeaveRequest>? leaves;
  final List<OnDutyAssignment>? onDutyAssignments;
  final void Function(
    Employee employee,
    DateTime date,
    AttendanceRecord? record,
    AttendanceStatusInfo? statusInfo,
  ) onCellTap;

  @override
  Widget build(BuildContext context) {
    final year = focusedMonth.year;
    final month = focusedMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;

    // Index records by employeeId + date string "DD-MM-YYYY"
    final recordMap = <String, AttendanceRecord>{};
    for (final r in records) {
      final dt = _parseKey(r.date);
      if (dt != null) {
        final dateKey = '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
        recordMap['${r.employeeId}_$dateKey'] = r;
        if (r.employeeName.isNotEmpty) recordMap['${r.employeeName}_$dateKey'] = r;
      } else {
        recordMap['${r.employeeId}_${r.date}'] = r;
        if (r.employeeName.isNotEmpty) recordMap['${r.employeeName}_${r.date}'] = r;
      }
    }

    if (employees.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 40),
        alignment: Alignment.center,
        child: const Text('No employee profiles found in database.'),
      );
    }

    const double leftColWidth = 180.0;
    const double dayColWidth = 36.0;
    const double rowHeight = 52.0;
    const double headerHeight = 44.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with Title & Legend
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Monthly Attendance Matrix (${DateFormat('MMMM yyyy').format(focusedMonth)})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: AttendanceStatusInfo.values
                      .map((s) => _legendPill('${s.code}: ${s.label}', s.textColor, s.bgColor))
                      .toList(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Sticky Column Grid Layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── FROZEN/STICKY FIRST COLUMN (Employee Names) ──
              Container(
                width: leftColWidth,
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Cell
                    Container(
                      height: headerHeight,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      color: const Color(0xFFF8FAFC),
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        'Employee',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    // Rows
                    for (final emp in employees) ...[
                      Container(
                        height: rowHeight,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.active.withValues(alpha: 0.15),
                              backgroundImage: (emp.profileImageUrl.isNotEmpty && emp.profileImageUrl.startsWith('http'))
                                  ? NetworkImage(emp.profileImageUrl)
                                  : null,
                              onBackgroundImageError: (emp.profileImageUrl.isNotEmpty && emp.profileImageUrl.startsWith('http'))
                                  ? (_, __) {}
                                  : null,
                              child: (emp.profileImageUrl.isEmpty || !emp.profileImageUrl.startsWith('http'))
                                  ? Text(
                                      emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : 'E',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.active,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    emp.fullName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    emp.employeeId.isNotEmpty
                                        ? emp.employeeId
                                        : 'EMP${emp.id.toString().padLeft(3, '0')}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    ],
                  ],
                ),
              ),

              // ── SCROLLABLE RIGHT GRID (Days 1..N) ──
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: SizedBox(
                    width: daysInMonth * dayColWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header row for days 1..daysInMonth
                        Container(
                          height: headerHeight,
                          color: const Color(0xFFF8FAFC),
                          child: Row(
                            children: [
                              for (int day = 1; day <= daysInMonth; day++)
                                SizedBox(
                                  width: dayColWidth,
                                  child: Center(
                                    child: Text(
                                      '$day',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        // Data rows
                        for (final emp in employees) ...[
                          SizedBox(
                            height: rowHeight,
                            child: Row(
                              children: [
                                for (int day = 1; day <= daysInMonth; day++)
                                  SizedBox(
                                    width: dayColWidth,
                                    child: Center(
                                      child: _buildDayCell(emp, day, month, year, recordMap),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendPill(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  DateTime? _parseKey(String value) {
    if (value.isEmpty) return null;
    try {
      final isoDate = DateTime.tryParse(value);
      if (isoDate != null) return isoDate;
      final parts = value.split('-');
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

  Widget _buildDayCell(
    Employee emp,
    int day,
    int month,
    int year,
    Map<String, AttendanceRecord> recordMap,
  ) {
    final date = DateTime(year, month, day);
    final dateStr = '${day.toString().padLeft(2, '0')}-${month.toString().padLeft(2, '0')}-$year';
    final record = recordMap['${emp.id}_$dateStr'] ?? recordMap['${emp.employeeId}_$dateStr'] ?? recordMap['${emp.fullName}_$dateStr'];

    final statusInfo = AttendanceStatusHelper.resolveStatus(
      employee: emp,
      date: date,
      record: record,
      leaves: leaves,
      onDutyAssignments: onDutyAssignments,
    );

    Color bgColor = statusInfo?.bgColor ?? const Color(0xFFF8FAFC);
    Color textColor = statusInfo?.textColor ?? const Color(0xFF94A3B8);
    String codeStr = statusInfo?.code ?? '-';

    final tooltipMsg = record != null
        ? '${emp.fullName} (${emp.employeeId.isNotEmpty ? emp.employeeId : "EMP${emp.id}"})\nDate: $dateStr\nStatus: ${statusInfo?.label ?? record.status}\nIn: ${record.effectiveCheckInTime}\nOut: ${record.checkOutTime.isNotEmpty ? record.checkOutTime : "--:--"}\nHours: ${record.totalHours} hrs'
        : '${emp.fullName}\nDate: $dateStr\nStatus: ${statusInfo?.label ?? "Not Marked"}';

    return Tooltip(
      message: tooltipMsg,
      child: InkWell(
        onTap: () => onCellTap(emp, date, record, statusInfo),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: statusInfo != null ? textColor.withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            codeStr,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
