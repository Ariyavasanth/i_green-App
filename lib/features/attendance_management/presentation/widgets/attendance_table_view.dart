import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../attendance/domain/attendance_record.dart';

class AttendanceTableView extends StatelessWidget {
  const AttendanceTableView({
    super.key,
    required this.records,
    required this.onEdit,
    required this.onDelete,
  });

  final List<AttendanceRecord> records;
  final void Function(AttendanceRecord record) onEdit;
  final void Function(AttendanceRecord record) onDelete;

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
          columns: const [
            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Employee Name', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Check In', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Check Out', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Total Hours', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Verification Mode', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: records.map((rec) => _buildRow(rec)).toList(),
        ),
      ),
    );
  }

  DataRow _buildRow(AttendanceRecord record) {
    Color statusColor;
    switch (record.status) {
      case 'Present':
      case 'Completed':
        statusColor = const Color(0xFF2E7D32);
        break;
      case 'Late':
      case 'Insufficient hours':
      case 'Missing Check-Out':
        statusColor = const Color(0xFFD84315);
        break;
      case 'Checked Out':
        statusColor = const Color(0xFF414A51);
        break;
      case 'Absent':
        statusColor = const Color(0xFFC62828);
        break;
      default:
        statusColor = AppColors.active;
    }

    return DataRow(
      cells: [
        DataCell(Text(record.date, style: const TextStyle(fontWeight: FontWeight.w600))),
        DataCell(Text(record.employeeName, style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text(record.effectiveCheckInTime.isNotEmpty ? record.effectiveCheckInTime : '--:--')),
        DataCell(Text(record.checkOutTime.isNotEmpty ? record.checkOutTime : '--:--')),
        DataCell(Text(record.totalHours > 0 ? '${record.totalHours} hrs' : '--')),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              record.effectiveCheckInVerification,
              style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              record.status,
              style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, size: 16, color: AppColors.active),
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
