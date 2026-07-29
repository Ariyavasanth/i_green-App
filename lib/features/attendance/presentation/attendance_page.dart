import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/attendance_record.dart';
import '../../leave/domain/leave_request.dart';
import '../../leave/providers/leave_providers.dart';
import '../providers/attendance_providers.dart';

class AttendancePage extends ConsumerStatefulWidget {
  const AttendancePage({super.key});

  @override
  ConsumerState<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends ConsumerState<AttendancePage> {
  DateTime _focusedMonth = DateTime.now();

  String _formatKey(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';

  DateTime? _parseKey(String value) {
    final parts = value.split('-');
    if (parts.length != 3) return null;
    return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
  }

  @override
  Widget build(BuildContext context) {
    final currentEmp = ref.watch(currentEmployeeProvider);
    if (currentEmp == null) {
      return const Scaffold(body: Center(child: Text('No employee profile found.')));
    }

    final attendanceAsync = ref.watch(attendanceRecordsProvider(currentEmp.id));
    final leaveAsync = ref.watch(attendanceLeaveRequestsProvider(currentEmp.id));

    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F6),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.calendar_month, size: 24, color: AppColors.active),
                SizedBox(width: 8),
                Text('Attendance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ],
            ),
            const SizedBox(height: 16),
            attendanceAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error loading attendance: $e'),
              data: (attendanceRecords) => leaveAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error loading leaves: $e'),
                data: (leaveRequests) => _buildCalendar(attendanceRecords, leaveRequests.cast<LeaveRequest>()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar(List<AttendanceRecord> attendanceRecords, List<LeaveRequest> leaveRequests) {
    final attendanceDates = attendanceRecords
        .map((e) => e.date)
        .toSet();
    final today = DateTime.now();
    final todayKey = _formatKey(DateTime(today.year, today.month, today.day));
    final leaveDates = <String>{};
    for (final req in leaveRequests) {
      if (req.status != 'Approved' && req.status != 'Pending') continue;
      for (final d in [...req.approvedDates, ...req.lopDates]) {
        if (d != todayKey) {
          leaveDates.add(d);
        }
      }
      if (req.status == 'Pending') {
        final from = _parseKey(req.fromDate);
        final to = _parseKey(req.toDate);
        if (from != null && to != null) {
          var curr = from;
          while (!curr.isAfter(to)) {
            final key = _formatKey(curr);
            if (key != todayKey) {
              leaveDates.add(key);
            }
            curr = curr.add(const Duration(days: 1));
          }
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: AppColors.active),
                onPressed: () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1)),
              ),
              Text(DateFormat('MMMM yyyy').format(_focusedMonth), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: AppColors.active),
                onPressed: () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map((d) => Expanded(child: Center(child: Text(d, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)))))
                .toList(),
          ),
          const SizedBox(height: 8),
          ..._buildRows(attendanceDates, leaveDates),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legend(const Color(0xFFD6ECFF), 'Today'),
              const SizedBox(width: 16),
              _legend(const Color(0xFFE53935), 'Leave'),
              const SizedBox(width: 16),
              _legend(AppColors.primary, 'Attendance'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) => Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))), const SizedBox(width: 6), Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))]);

  List<Widget> _buildRows(Set<String> attendanceDates, Set<String> leaveDates) {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7;
    final today = DateTime.now();
    final todayKey = _formatKey(DateTime(today.year, today.month, today.day));

    final rows = <Widget>[];
    var day = 1 - startWeekday;
    while (day <= daysInMonth) {
      final cells = <Widget>[];
      for (var i = 0; i < 7; i++) {
        if (day < 1 || day > daysInMonth) {
          cells.add(const Expanded(child: SizedBox(height: 40)));
        } else {
          final date = DateTime(year, month, day);
          final key = _formatKey(date);
          final isToday = key == todayKey;
          final isLeave = leaveDates.contains(key);
          final isAttendance = attendanceDates.contains(key);
          final bg = isLeave
              ? const Color(0xFFE53935)
              : isToday
                  ? const Color(0xFFD6ECFF)
                  : isAttendance
                      ? AppColors.primary
                      : null;
          final fg = Colors.black;
          cells.add(
            Expanded(
              child: MouseRegion(
                cursor: isToday ? SystemMouseCursors.click : SystemMouseCursors.basic,
                child: GestureDetector(
                  onTap: isToday ? () => _showDateDialog(date, isLeave, isAttendance) : null,
                  child: Container(
                    height: 40,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(6),
                      border: isToday && bg == null
                          ? Border.all(color: const Color(0xFFD6ECFF), width: 1.5)
                          : isLeave
                              ? Border.all(color: const Color(0xFF9CC70A), width: 1.2)
                              : null,
                      boxShadow: null,
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isLeave || isAttendance || isToday ? FontWeight.bold : FontWeight.w500,
                              color: fg,
                            ),
                          ),
                        ),
                        if (isLeave)
                          const Positioned(
                            right: 6,
                            top: 6,
                            child: Icon(Icons.event_busy, size: 10, color: Colors.white),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        day++;
      }
      rows.add(Row(children: cells));
    }
    return rows;
  }

  void _showDateDialog(DateTime date, bool isLeave, bool isAttendance) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Attendance Date'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('dd/MM/yyyy').format(date), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(DateFormat('EEEE').format(date), style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            if (isLeave)
              const Text('Leave is marked on this date.', style: TextStyle(color: Color(0xFFE53935)))
            else if (isAttendance)
              const Text('Attendance already marked.', style: TextStyle(color: AppColors.primary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.active, foregroundColor: Colors.white),
            onPressed: () async {
              final today = DateTime.now();
              final todayOnly = DateTime(today.year, today.month, today.day);
              final selectedOnly = DateTime(date.year, date.month, date.day);
              if (selectedOnly != todayOnly) {
                return;
              }
              final currentEmp = ref.read(currentEmployeeProvider);
              if (currentEmp == null) return;
              await ref.read(attendanceRepositoryProvider).markAttendance(currentEmp.id, _formatKey(date));
              ref.invalidate(attendanceRecordsProvider(currentEmp.id));
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              if (mounted) setState(() {});
            },
            child: const Text('Mark Attendance'),
          ),
        ],
      ),
    );
  }
}
