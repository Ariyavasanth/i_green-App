import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../attendance/domain/attendance_record.dart';
import '../../../attendance/domain/attendance_status_helper.dart';
import '../../../employee/domain/employee.dart';
import '../../../leave/domain/leave_request.dart';
import '../../../on_duty/domain/on_duty_assignment.dart';

class AttendanceTableView extends StatelessWidget {
  const AttendanceTableView({
    super.key,
    required this.records,
    this.employees = const [],
    this.leaves,
    this.onDutyAssignments,
    required this.onEdit,
    required this.onDelete,
    this.onRowTap,
    this.isMobile = false,
  });

  final List<AttendanceRecord> records;
  final List<Employee> employees;
  final List<LeaveRequest>? leaves;
  final List<OnDutyAssignment>? onDutyAssignments;
  final void Function(AttendanceRecord record) onEdit;
  final void Function(AttendanceRecord record) onDelete;
  final void Function(AttendanceRecord record, Employee? employee)? onRowTap;
  final bool isMobile;

  Employee? _findEmployee(AttendanceRecord record) {
    if (employees.isEmpty) return null;
    final code = record.employeeCode.trim().toLowerCase();
    if (code.isNotEmpty) {
      for (final e in employees) {
        if (e.employeeId.trim().toLowerCase() == code) return e;
      }
    }
    if (record.employeeId != 0) {
      for (final e in employees) {
        if (e.id == record.employeeId) return e;
      }
    }
    final name = record.employeeName.trim().toLowerCase();
    if (name.isNotEmpty) {
      for (final e in employees) {
        if (e.fullName.trim().toLowerCase() == name) return e;
      }
    }
    return null;
  }

  DateTime? _parseDate(String val) {
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

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
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
        child: const Column(
          children: [
            Icon(Icons.inbox, size: 40, color: AppColors.textSecondary),
            SizedBox(height: 8),
            Text(
              'No attendance records found matching filters.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (isMobile) {
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
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: records.length,
          separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
          itemBuilder: (context, index) {
            return _buildMobileCard(context, records[index]);
          },
        ),
      );
    }

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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8F9FA)),
          columnSpacing: 16,
          horizontalMargin: 16,
          columns: const [
            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Employee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Check In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Check Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Office Hrs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('OD Hrs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Lunch Hrs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Tea Hrs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Meeting/Other', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Total Hrs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Req. Hrs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Shortfall', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          ],
          rows: records.map((rec) => _buildRow(context, rec)).toList(),
        ),
      ),
    );
  }

  Widget _buildMobileCard(BuildContext context, AttendanceRecord record) {
    final emp = _findEmployee(record);
    final reqHours = emp?.requiredWorkingHours ?? 9.0;
    final dateDt = _parseDate(record.date) ?? DateTime.now();
    final dayName = DateFormat('EEEE').format(dateDt);

    final statusInfo = emp != null
        ? AttendanceStatusHelper.resolveStatus(
            employee: emp,
            date: dateDt,
            record: record,
            leaves: leaves,
            onDutyAssignments: onDutyAssignments,
          )
        : null;

    final statusLabel = statusInfo?.label ?? record.status;
    final statusBgColor = statusInfo?.bgColor ?? const Color(0xFFF1F5F9);
    final statusTextColor = statusInfo?.textColor ?? const Color(0xFF475569);
    final statusBorderColor = statusInfo != null ? statusInfo.textColor.withValues(alpha: 0.3) : const Color(0xFFCBD5E1);

    final shortfallStr = record.formattedShortfall(reqHours);
    final isShortfall = record.calculateShortfall(reqHours) > 0;

    final checkInStr = record.effectiveCheckInTime.isNotEmpty
        ? record.formattedCheckInTime
        : '--:--';
    final checkOutStr = record.checkOutTime.isNotEmpty
        ? record.formattedCheckOutTime
        : '--:--';
    final reqHrsStr = '${reqHours.toStringAsFixed(0)}hr';

    return InkWell(
      onTap: onRowTap != null ? () => onRowTap!(record, emp) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Date & Day on left, Status Chip & Action Icons on right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.date,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        dayName,
                        style: TextStyle(
                          fontSize: 11,
                          color: dateDt.weekday == DateTime.sunday ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusBorderColor),
                  ),
                  child: Text(
                    statusInfo != null ? '${statusInfo.code} - $statusLabel' : statusLabel,
                    style: TextStyle(fontSize: 10, color: statusTextColor, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF64748B)),
                  onSelected: (val) {
                    if (val == 'edit') onEdit(record);
                    if (val == 'delete') onDelete(record);
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16, color: Color(0xFF414A51)),
                          SizedBox(width: 8),
                          Text('Edit / Override', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 16, color: Color(0xFFC62828)),
                          SizedBox(width: 8),
                          Text('Delete / Unmark', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Middle Row: In & Out Time
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.login, size: 13, color: Color(0xFF16A34A)),
                    const SizedBox(width: 4),
                    Text('In: $checkInStr', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.logout, size: 13, color: Color(0xFFDC2626)),
                    const SizedBox(width: 4),
                    Text('Out: $checkOutStr', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Bottom Row: Hours & Shortfall
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Work: ${record.formattedTotalHours}  |  Req: $reqHrsStr',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isShortfall ? const Color(0xFFFEE2E2) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isShortfall ? 'Shortfall: $shortfallStr' : 'Shortfall: 0hr',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isShortfall ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  DataRow _buildRow(BuildContext context, AttendanceRecord record) {
    final emp = _findEmployee(record);
    final reqHours = emp?.requiredWorkingHours ?? 9.0;
    final dateDt = _parseDate(record.date) ?? DateTime.now();

    final statusInfo = emp != null
        ? AttendanceStatusHelper.resolveStatus(
            employee: emp,
            date: dateDt,
            record: record,
            leaves: leaves,
            onDutyAssignments: onDutyAssignments,
          )
        : null;

    final statusLabel = statusInfo?.label ?? record.status;
    final statusBgColor = statusInfo?.bgColor ?? const Color(0xFFF1F5F9);
    final statusTextColor = statusInfo?.textColor ?? const Color(0xFF475569);
    final statusBorderColor = statusInfo != null ? statusInfo.textColor.withValues(alpha: 0.3) : const Color(0xFFCBD5E1);

    final shortfallStr = record.formattedShortfall(reqHours);
    final isShortfall = record.calculateShortfall(reqHours) > 0;

    return DataRow(
      cells: [
        DataCell(
          InkWell(
            onTap: onRowTap != null ? () => onRowTap!(record, emp) : null,
            child: Text(record.date, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          ),
        ),
        DataCell(
          InkWell(
            onTap: onRowTap != null ? () => onRowTap!(record, emp) : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.employeeName.isNotEmpty ? record.employeeName : (emp?.fullName ?? 'EMP-${record.employeeId}'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                if (record.employeeCode.isNotEmpty || emp?.employeeId.isNotEmpty == true)
                  Text(
                    record.employeeCode.isNotEmpty ? record.employeeCode : emp!.employeeId,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                  ),
              ],
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusBgColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: statusBorderColor),
            ),
            child: Text(
              statusInfo != null ? '${statusInfo.code} - $statusLabel' : statusLabel,
              style: TextStyle(fontSize: 10, color: statusTextColor, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        DataCell(Text(record.effectiveCheckInTime.isNotEmpty ? record.formattedCheckInTime : '--:--', style: const TextStyle(fontSize: 12))),
        DataCell(Text(record.checkOutTime.isNotEmpty ? record.formattedCheckOutTime : '--:--', style: const TextStyle(fontSize: 12))),
        DataCell(Text(record.formattedOfficeHours, style: const TextStyle(fontSize: 12))),
        DataCell(Text(record.formattedOdHours, style: const TextStyle(fontSize: 12))),
        DataCell(Text(record.formattedLunchHours, style: const TextStyle(fontSize: 12))),
        DataCell(Text(record.formattedTeaBreakHours, style: const TextStyle(fontSize: 12))),
        DataCell(Text(record.formattedMeetingOtherHours, style: const TextStyle(fontSize: 12))),
        DataCell(
          Text(
            record.formattedTotalHours,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
        ),
        DataCell(Text('${reqHours.toStringAsFixed(1)}hr', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isShortfall ? const Color(0xFFFEE2E2) : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              shortfallStr,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isShortfall ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
              ),
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, size: 16, color: Color(0xFF414A51)),
                tooltip: 'Edit / Override',
                onPressed: () => onEdit(record),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFC62828)),
                tooltip: 'Delete / Unmark',
                onPressed: () => onDelete(record),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

