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

    const double leftColWidth = 145.0;
    const double dayColWidth = 36.0;
    const double rowHeight = 44.0;
    const double headerHeight = 40.0;

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
            padding: const EdgeInsets.all(14),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.grid_on, size: 18, color: AppColors.active),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Monthly Matrix (${DateFormat('MMM yyyy').format(focusedMonth)})',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _legendPill('Present', const Color(0xFF2E7D32)),
                          _legendPill('Late', const Color(0xFFE65100)),
                          _legendPill('Checked Out', const Color(0xFF414A51)),
                          _legendPill('Absent', const Color(0xFFC62828)),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      const Icon(Icons.grid_on, size: 18, color: AppColors.active),
                      const SizedBox(width: 8),
                      Text(
                        'Monthly Attendance Matrix (${DateFormat('MMMM yyyy').format(focusedMonth)})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      _legendPill('Present', const Color(0xFF2E7D32)),
                      const SizedBox(width: 8),
                      _legendPill('Late', const Color(0xFFE65100)),
                      const SizedBox(width: 8),
                      _legendPill('Checked Out', const Color(0xFF414A51)),
                      const SizedBox(width: 8),
                      _legendPill('Absent', const Color(0xFFC62828)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      color: const Color(0xFFF8F9FA),
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        'Employee',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    // Rows
                    for (final emp in employees) ...[
                      Container(
                        height: rowHeight,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 11,
                              backgroundColor: AppColors.active.withValues(alpha: 0.2),
                              child: Text(
                                emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : 'E',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.active),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                emp.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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
                          color: const Color(0xFFF8F9FA),
                          child: Row(
                            children: [
                              for (int day = 1; day <= daysInMonth; day++)
                                SizedBox(
                                  width: dayColWidth,
                                  child: Center(
                                    child: Text(
                                      '$day',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
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
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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

    Color color;
    String label;

    if (record == null) {
      color = Colors.grey.shade300;
      label = '-';
    } else {
      switch (record.status) {
        case 'Present':
          color = const Color(0xFF2E7D32);
          label = 'P';
          break;
        case 'Late':
          color = const Color(0xFFE65100);
          label = 'L';
          break;
        case 'Checked Out':
          color = const Color(0xFF414A51);
          label = 'CO';
          break;
        case 'Absent':
          color = const Color(0xFFC62828);
          label = 'A';
          break;
        default:
          color = AppColors.active;
          label = 'P';
      }
    }

    final tooltipMsg = record != null
        ? '${emp.fullName}\nDate: $dateStr\nStatus: ${record.status}\nIn: ${record.effectiveCheckInTime}\nOut: ${record.checkOutTime.isNotEmpty ? record.checkOutTime : "--:--"}\nHours: ${record.totalHours} hrs'
        : '${emp.fullName}\nDate: $dateStr\nStatus: Not Marked';

    return Tooltip(
      message: tooltipMsg,
      child: InkWell(
        onTap: () => onCellTap(emp, dateStr, record),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: record != null ? 0.9 : 0.4),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: record != null ? Colors.white : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
}

