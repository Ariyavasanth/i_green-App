import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../employee/domain/employee.dart';
import '../../domain/attendance_record.dart';
import '../../domain/attendance_status_helper.dart';

class AttendanceDetailsDialog extends StatelessWidget {
  const AttendanceDetailsDialog({
    super.key,
    required this.employee,
    required this.date,
    this.record,
    this.statusInfo,
    this.onEdit,
  });

  final Employee employee;
  final DateTime date;
  final AttendanceRecord? record;
  final AttendanceStatusInfo? statusInfo;
  final VoidCallback? onEdit;

  int _calculateLateMinutes() {
    if (record == null) return 0;
    if (record!.notes.isNotEmpty) {
      final reg = RegExp(r'Late\s*=\s*(\d+)', caseSensitive: false);
      final match = reg.firstMatch(record!.notes);
      if (match != null && match.groupCount >= 1) {
        return int.tryParse(match.group(1) ?? '0') ?? 0;
      }
    }
    if (record!.status == 'Late' && record!.effectiveCheckInTime.isNotEmpty) {
      try {
        final inTimeStr = employee.inTime.trim().isNotEmpty ? employee.inTime : '09:00';
        final inParts = inTimeStr.replaceAll(RegExp(r'[^0-9:]'), '').split(':');
        final actualParts = record!.effectiveCheckInTime.replaceAll(RegExp(r'[^0-9:]'), '').split(':');
        if (inParts.length >= 2 && actualParts.length >= 2) {
          final schedMin = int.parse(inParts[0]) * 60 + int.parse(inParts[1]);
          final actualMin = int.parse(actualParts[0]) * 60 + int.parse(actualParts[1]);
          final delay = actualMin - schedMin;
          if (delay > 0) return delay;
        }
      } catch (_) {}
    }
    return 0;
  }

  String _resolveShiftLabel() {
    if (employee.isDynamicEmployee) {
      return 'Dynamic / Flexible';
    }
    if (employee.inTime.isNotEmpty && employee.outTime.isNotEmpty) {
      return '${employee.inTime} - ${employee.outTime}';
    } else if (employee.inTime.isNotEmpty) {
      return 'From ${employee.inTime}';
    }
    return 'Fixed (09:00 AM - 06:00 PM)';
  }

  String _resolveAttendanceSource() {
    if (record == null) return 'No Record';
    final ver = record!.effectiveCheckInVerification.trim();
    if (ver.isNotEmpty) return ver;
    final st = record!.verificationStatus.trim();
    if (st.isNotEmpty) return st;
    return 'Mobile App Check-in';
  }

  String _resolveLocation() {
    if (record == null) return 'N/A';
    if (record!.notes.contains('Site') || record!.notes.contains('Customer Visit')) {
      return 'Customer Site Visit';
    }
    return 'Office Geofence Verified';
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, dd MMMM yyyy').format(date);
    final status = statusInfo;
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 550;
    final lateMins = _calculateLateMinutes();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? size.width * 0.95 : 520,
          maxHeight: size.height * 0.88,
        ),
        child: Container(
          padding: EdgeInsets.all(isMobile ? 14 : 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.assignment_ind_outlined, color: Color(0xFF414A51), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Attendance Details',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 10),

              // Scrollable Body
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Employee Info Card
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: const Color(0xFF9CC70A).withValues(alpha: 0.2),
                              backgroundImage: (employee.profileImageUrl.isNotEmpty && employee.profileImageUrl.startsWith('http'))
                                  ? NetworkImage(employee.profileImageUrl)
                                  : null,
                              child: (employee.profileImageUrl.isEmpty || !employee.profileImageUrl.startsWith('http'))
                                  ? Text(
                                      employee.fullName.isNotEmpty ? employee.fullName[0].toUpperCase() : 'E',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF414A51), fontSize: 14),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    employee.fullName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    '${employee.employeeId.isNotEmpty ? employee.employeeId : "EMP${employee.id}"} • ${employee.department.isNotEmpty ? employee.department : "General"}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 2. Date & 3. Status Header Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: status != null ? status.bgColor.withValues(alpha: 0.4) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: status != null ? status.textColor.withValues(alpha: 0.3) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 14, color: Color(0xFF475569)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      dateStr,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: status?.bgColor ?? const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: status?.textColor ?? const Color(0xFF94A3B8)),
                              ),
                              child: Text(
                                status != null ? '${status.code} - ${status.label}' : 'Not Marked',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: status?.textColor ?? const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 4. Check-in & 5. Check-out
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailMetric(
                              label: 'Check-in',
                              value: record?.effectiveCheckInTime.isNotEmpty == true ? record!.effectiveCheckInTime : '--:--',
                              icon: Icons.login,
                              iconColor: const Color(0xFF16A34A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDetailMetric(
                              label: 'Check-out',
                              value: record?.checkOutTime.isNotEmpty == true ? record!.checkOutTime : '--:--',
                              icon: Icons.logout,
                              iconColor: const Color(0xFFEA580C),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 6. Working Hours & 7. Shift
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailMetric(
                              label: 'Working Hours',
                              value: record != null && record!.totalHours > 0 ? '${record!.totalHours.toStringAsFixed(1)} hrs' : '0.0 hrs',
                              icon: Icons.access_time,
                              iconColor: const Color(0xFF0284C7),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDetailMetric(
                              label: 'Shift Schedule',
                              value: _resolveShiftLabel(),
                              icon: Icons.schedule,
                              iconColor: const Color(0xFF6366F1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 8. Attendance Source & 9. Location
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailMetric(
                              label: 'Attendance Source',
                              value: _resolveAttendanceSource(),
                              icon: Icons.verified_user_outlined,
                              iconColor: const Color(0xFF9333EA),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDetailMetric(
                              label: 'Location',
                              value: _resolveLocation(),
                              icon: Icons.location_on_outlined,
                              iconColor: const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 10. Late Minutes Metric
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailMetric(
                              label: 'Late Minutes',
                              value: lateMins > 0 ? '$lateMins mins late' : (record?.status == 'Late' ? 'Late' : '0 mins (On Time)'),
                              icon: Icons.timer_outlined,
                              iconColor: lateMins > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),

                      if (record?.notes.isNotEmpty == true) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Notes & Remarks',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                record!.notes,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Footer Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onEdit != null) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF414A51),
                        side: const BorderSide(color: Color(0xFF414A51)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.edit, size: 15),
                      label: const Text('Edit / Override', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        Navigator.pop(context);
                        onEdit!();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9CC70A),
                      foregroundColor: const Color(0xFF21273E),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
