import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../attendance/domain/attendance_record.dart';
import '../../../employee/domain/employee.dart';

class AttendanceMatrixView extends StatelessWidget {
  const AttendanceMatrixView({
    super.key,
    required this.focusedMonth,
    required this.employees,
    required this.records,
    required this.onCellTap,
  });

  final DateTime focusedMonth;
  final List<Employee> employees;
  final List<AttendanceRecord> records;
  final void Function(Employee employee, String dateStr, AttendanceRecord? record) onCellTap;

  @override
  Widget build(BuildContext context) {
    final year = focusedMonth.year;
    final month = focusedMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;

    final isMobile = MediaQuery.of(context).size.width < 650;

    // Index records by employeeId + date string "DD-MM-YYYY"
    final recordMap = <String, AttendanceRecord>{};
    for (final r in records) {
      recordMap['${r.employeeId}_${r.date}'] = r;
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
            child: isMobile
                ? Column(
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
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          _legendPill('Present', const Color(0xFF22C55E)),
                          _legendPill('Late', const Color(0xFFF97316)),
                          _legendPill('On Leave', const Color(0xFFEAB308)),
                          _legendPill('Absent', const Color(0xFFEF4444)),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Monthly Attendance Matrix (${DateFormat('MMMM yyyy').format(focusedMonth)})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const Spacer(),
                      _legendPill('Present', const Color(0xFF22C55E)),
                      const SizedBox(width: 12),
                      _legendPill('Late', const Color(0xFFF97316)),
                      const SizedBox(width: 12),
                      _legendPill('On Leave', const Color(0xFFEAB308)),
                      const SizedBox(width: 12),
                      _legendPill('Absent', const Color(0xFFEF4444)),
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

  Widget _legendPill(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildDayCell(
    Employee emp,
    int day,
    int month,
    int year,
    Map<String, AttendanceRecord> recordMap,
  ) {
    final dateStr = '${day.toString().padLeft(2, '0')}-${month.toString().padLeft(2, '0')}-$year';
    final key = '${emp.id}_$dateStr';
    final record = recordMap[key];

    Color bgColor;
    Widget iconWidget;

    if (record == null) {
      bgColor = const Color(0xFFF8FAFC);
      iconWidget = const Text('-', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)));
    } else {
      switch (record.status) {
        case 'Present':
        case 'Completed':
        case 'Checked Out':
          bgColor = const Color(0xFFDCFCE7);
          iconWidget = const Icon(Icons.check, size: 13, color: Color(0xFF16A34A));
          break;
        case 'Late':
          bgColor = const Color(0xFFFFEDD5);
          iconWidget = const Text('L', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)));
          break;
        case 'Insufficient hours':
          bgColor = const Color(0xFFFFEDD5);
          iconWidget = const Text('I', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)));
          break;
        case 'On Leave':
        case 'Half Day':
          bgColor = const Color(0xFFFEF9C3);
          iconWidget = const Text('L', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFCA8A04)));
          break;
        case 'Absent':
          bgColor = const Color(0xFFFEE2E2);
          iconWidget = const Icon(Icons.close, size: 13, color: Color(0xFFDC2626));
          break;
        default:
          bgColor = const Color(0xFFDCFCE7);
          iconWidget = const Icon(Icons.check, size: 13, color: Color(0xFF16A34A));
      }
    }

    final tooltipMsg = record != null
        ? '${emp.fullName} (${emp.employeeId.isNotEmpty ? emp.employeeId : "EMP${emp.id}"})\nDate: $dateStr\nStatus: ${record.status}\nIn: ${record.effectiveCheckInTime}\nOut: ${record.checkOutTime.isNotEmpty ? record.checkOutTime : "--:--"}\nHours: ${record.totalHours} hrs'
        : '${emp.fullName}\nDate: $dateStr\nStatus: Not Marked';

    return Tooltip(
      message: tooltipMsg,
      child: InkWell(
        onTap: () => onCellTap(emp, dateStr, record),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: iconWidget,
        ),
      ),
    );
  }
}
