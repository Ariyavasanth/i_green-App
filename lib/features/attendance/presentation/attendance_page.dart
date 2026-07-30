import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/attendance_record.dart';
import '../../employee/domain/employee.dart';
import '../../leave/domain/leave_request.dart';
import '../../leave/providers/leave_providers.dart';
import '../domain/attendance_repository.dart';
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
      builder: (dialogContext) => AttendanceVerificationDialog(
        date: date,
        isLeave: isLeave,
        isAttendance: isAttendance,
        attendanceRepository: ref.read(attendanceRepositoryProvider),
        currentEmployee: ref.read(currentEmployeeProvider)!,
        onAttendanceMarked: () {
          ref.invalidate(attendanceRecordsProvider(ref.read(currentEmployeeProvider)!.id));
          if (mounted) setState(() {});
        },
      ),
    );
  }
}

class AttendanceVerificationDialog extends StatefulWidget {
  const AttendanceVerificationDialog({
    super.key,
    required this.date,
    required this.isLeave,
    required this.isAttendance,
    required this.attendanceRepository,
    required this.currentEmployee,
    required this.onAttendanceMarked,
  });

  final DateTime date;
  final bool isLeave;
  final bool isAttendance;
  final AttendanceRepository attendanceRepository;
  final Employee currentEmployee;
  final VoidCallback onAttendanceMarked;

  @override
  State<AttendanceVerificationDialog> createState() => _AttendanceVerificationDialogState();
}

class _AttendanceVerificationDialogState extends State<AttendanceVerificationDialog> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _verifying = false;
  String? _message;

  String _formatKey(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';

  Future<void> _authenticateAndMark() async {
    if (_verifying) return;
    setState(() {
      _verifying = true;
      _message = null;
    });
    try {
      final canCheckBiometrics = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!canCheckBiometrics) {
        throw Exception('Biometric authentication is not available on this device.');
      }

      final authenticated = await _auth.authenticate(
        localizedReason: 'Verify your identity to mark attendance',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      final now = DateTime.now();
      final dateKey = _formatKey(widget.date);
      final time = DateFormat('HH:mm:ss').format(now);

      if (authenticated) {
        if (!(await widget.attendanceRepository.hasAttendanceForDate(widget.currentEmployee.id, dateKey))) {
          await widget.attendanceRepository.markAttendance(
            employeeId: widget.currentEmployee.id,
            employeeName: widget.currentEmployee.fullName,
            date: dateKey,
            time: time,
            verificationStatus: 'Verified',
            similarityScore: 1.0,
          );
        }
        await widget.attendanceRepository.logAttendanceAttempt(
          employeeId: widget.currentEmployee.id,
          employeeName: widget.currentEmployee.fullName,
          date: dateKey,
          time: time,
          verificationStatus: 'Verified',
          similarityScore: 1.0,
          message: 'Attendance marked successfully.',
        );
        if (!mounted) return;
        setState(() => _message = 'Attendance marked successfully.');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance marked successfully.')));
        widget.onAttendanceMarked();
        Navigator.of(context).pop();
      } else {
        await widget.attendanceRepository.logAttendanceAttempt(
          employeeId: widget.currentEmployee.id,
          employeeName: widget.currentEmployee.fullName,
          date: dateKey,
          time: time,
          verificationStatus: 'Failed',
          similarityScore: 0.0,
          message: 'Biometric verification failed. Please try again.',
        );
        if (!mounted) return;
        setState(() => _message = 'Biometric verification failed. Please try again.');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Biometric verification failed. Please try again.')));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = e.toString().replaceFirst('Exception: ', ''));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _unmarkAttendance() async {
    if (_verifying) return;
    setState(() {
      _verifying = true;
      _message = null;
    });
    try {
      final now = DateTime.now();
      final dateKey = _formatKey(widget.date);
      final time = DateFormat('HH:mm:ss').format(now);

      await widget.attendanceRepository.unmarkAttendance(
        employeeId: widget.currentEmployee.id,
        date: dateKey,
      );
      await widget.attendanceRepository.logAttendanceAttempt(
        employeeId: widget.currentEmployee.id,
        employeeName: widget.currentEmployee.fullName,
        date: dateKey,
        time: time,
        verificationStatus: 'Unmarked',
        similarityScore: 0.0,
        message: 'Attendance unmarked successfully.',
      );
      if (!mounted) return;
      setState(() => _message = 'Attendance unmarked successfully.');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance unmarked successfully.')));
      widget.onAttendanceMarked();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = e.toString().replaceFirst('Exception: ', ''));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _cancel() async {
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      title: const Text('Attendance Date'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(DateFormat('dd/MM/yyyy').format(widget.date), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(DateFormat('EEEE').format(widget.date), style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              if (widget.isLeave)
                const Text('Leave is marked on this date.', style: TextStyle(color: Color(0xFFE53935)))
              else if (widget.isAttendance)
                const Text('Attendance already marked.', style: TextStyle(color: AppColors.primary))
              else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F8FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.fingerprint, size: 56, color: AppColors.active),
                      SizedBox(height: 12),
                      Text(
                        'Use the phone biometric prompt to mark attendance.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 8),
                  Text(_message!, style: TextStyle(color: _message!.contains('successfully') ? AppColors.primary : const Color(0xFFE53935))),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _cancel, child: const Text('Cancel')),
        if (widget.isAttendance)
          TextButton(
            onPressed: _verifying ? null : _unmarkAttendance,
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFE53935)),
            child: Text(_verifying ? 'Working...' : 'Unmark Attendance'),
          ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.active, foregroundColor: Colors.white),
          onPressed: widget.isLeave || widget.isAttendance ? null : _authenticateAndMark,
          child: Text(_verifying ? 'Verifying...' : 'Mark Attendance'),
        ),
      ],
    );
  }
}
