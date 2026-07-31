import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
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
      return const Scaffold(
        backgroundColor: Color(0xFFEFF3F6),
        body: Center(child: Text('No employee profile found.')),
      );
    }

    final attendanceAsync = ref.watch(attendanceRecordsProvider(currentEmp.id));
    final todayAttendanceAsync = ref.watch(todayAttendanceRecordProvider(currentEmp.id));
    final leaveAsync = ref.watch(attendanceLeaveRequestsProvider(currentEmp.id));

    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F6),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            const Row(
              children: [
                Icon(Icons.calendar_month, size: 24, color: AppColors.active),
                SizedBox(width: 8),
                Text(
                  'Attendance',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Today's Status Banner Card
            _buildTodayBannerCard(currentEmp, todayAttendanceAsync),
            const SizedBox(height: 20),

            // Monthly Calendar Section
            attendanceAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error loading attendance: $e'),
              data: (attendanceRecords) => leaveAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error loading leaves: $e'),
                data: (leaveRequests) => _buildCalendar(
                  attendanceRecords,
                  leaveRequests.cast<LeaveRequest>(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayBannerCard(
    Employee employee,
    AsyncValue<AttendanceRecord?> todayAttendanceAsync,
  ) {
    final today = DateTime.now();
    final dateStr = DateFormat('EEEE, dd MMMM yyyy').format(today);

    return todayAttendanceAsync.when(
      loading: () => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black12),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black12),
        ),
        child: Text('Error loading today\'s attendance: $e'),
      ),
      data: (todayRecord) {
        final hasCheckedIn = todayRecord != null && todayRecord.effectiveCheckInTime.isNotEmpty;
        final hasCheckedOut = todayRecord != null && todayRecord.checkOutTime.isNotEmpty;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time_filled, color: AppColors.active, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Today\'s Attendance Overview ($dateStr)',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  _buildStatusChip(todayRecord),
                ],
              ),
              const SizedBox(height: 16),

              // Check-In / Check-Out / Total Hours Summary Row
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      icon: Icons.login,
                      iconColor: const Color(0xFF2E7D32),
                      title: 'Check In Time',
                      value: hasCheckedIn ? todayRecord.effectiveCheckInTime : '--:--',
                      subtitle: hasCheckedIn
                          ? 'Verification: ${todayRecord.effectiveCheckInVerification}'
                          : 'Not checked in yet',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      icon: Icons.logout,
                      iconColor: const Color(0xFFC62828),
                      title: 'Check Out Time',
                      value: hasCheckedOut ? todayRecord.checkOutTime : '--:--',
                      subtitle: hasCheckedOut
                          ? 'Verification: ${todayRecord.checkOutVerificationStatus}'
                          : hasCheckedIn
                              ? 'Pending Check Out'
                              : 'Not checked out',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      icon: Icons.timelapse,
                      iconColor: AppColors.active,
                      title: 'Total Work Hours',
                      value: todayRecord != null && todayRecord.totalHours > 0
                          ? '${todayRecord.totalHours} hrs'
                          : '--',
                      subtitle: hasCheckedOut ? 'Shift Completed' : 'In Progress',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Action Buttons Row
              Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !hasCheckedIn ? AppColors.active : Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: !hasCheckedIn
                        ? () => _openVerificationDialog(
                              date: today,
                              isCheckOut: false,
                              existingRecord: todayRecord,
                            )
                        : null,
                    icon: const Icon(Icons.fingerprint, size: 18),
                    label: const Text(
                      'Check In Attendance',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasCheckedIn && !hasCheckedOut
                          ? const Color(0xFF414A51)
                          : Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: hasCheckedIn && !hasCheckedOut
                        ? () => _openVerificationDialog(
                              date: today,
                              isCheckOut: true,
                              existingRecord: todayRecord,
                            )
                        : null,
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text(
                      'Check Out Attendance',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (hasCheckedOut)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF81C784)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 16, color: Color(0xFF2E7D32)),
                          SizedBox(width: 6),
                          Text(
                            'Shift Attendance Complete',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(AttendanceRecord? record) {
    if (record == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Not Marked',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
      );
    }
    Color color;
    switch (record.status) {
      case 'Present':
        color = const Color(0xFF2E7D32);
        break;
      case 'Late':
        color = const Color(0xFFE65100);
        break;
      case 'Checked Out':
        color = const Color(0xFF414A51);
        break;
      case 'Absent':
        color = const Color(0xFFC62828);
        break;
      default:
        color = AppColors.active;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        record.status,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: iconColor.withValues(alpha: 0.1),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(List<AttendanceRecord> attendanceRecords, List<LeaveRequest> leaveRequests) {
    final attendanceMap = <String, AttendanceRecord>{};
    for (final rec in attendanceRecords) {
      attendanceMap[rec.date] = rec;
    }

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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: AppColors.active),
                onPressed: () => setState(
                  () => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1),
                ),
              ),
              Text(
                DateFormat('MMMM yyyy').format(_focusedMonth),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: AppColors.active),
                onPressed: () => setState(
                  () => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          ..._buildRows(attendanceMap, leaveDates),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legend(const Color(0xFFD6ECFF), 'Today'),
              const SizedBox(width: 16),
              _legend(const Color(0xFFE53935), 'Leave'),
              const SizedBox(width: 16),
              _legend(const Color(0xFF2E7D32), 'Present / Checked Out'),
              const SizedBox(width: 16),
              _legend(const Color(0xFFE65100), 'Late'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) => Row(children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ]);

  List<Widget> _buildRows(Map<String, AttendanceRecord> attendanceMap, Set<String> leaveDates) {
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
          final record = attendanceMap[key];
          final isAttendance = record != null;

          Color? bg;
          if (isLeave) {
            bg = const Color(0xFFE53935);
          } else if (isAttendance) {
            bg = record.status == 'Late'
                ? const Color(0xFFE65100)
                : const Color(0xFF2E7D32);
          } else if (isToday) {
            bg = const Color(0xFFD6ECFF);
          }

          cells.add(
            Expanded(
              child: MouseRegion(
                cursor: isToday ? SystemMouseCursors.click : SystemMouseCursors.basic,
                child: GestureDetector(
                  onTap: isToday
                      ? () => _openVerificationDialog(
                            date: date,
                            isCheckOut: record != null && record.checkOutTime.isEmpty,
                            existingRecord: record,
                          )
                      : null,
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
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  isLeave || isAttendance || isToday ? FontWeight.bold : FontWeight.w500,
                              color: isAttendance || isLeave ? Colors.white : Colors.black,
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

  void _openVerificationDialog({
    required DateTime date,
    required bool isCheckOut,
    AttendanceRecord? existingRecord,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AttendanceVerificationDialog(
        date: date,
        isCheckOut: isCheckOut,
        existingRecord: existingRecord,
        attendanceRepository: ref.read(attendanceRepositoryProvider),
        currentEmployee: ref.read(currentEmployeeProvider)!,
        onAttendanceMarked: () {
          final empId = ref.read(currentEmployeeProvider)!.id;
          ref.invalidate(attendanceRecordsProvider(empId));
          ref.invalidate(todayAttendanceRecordProvider(empId));
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
    required this.isCheckOut,
    this.existingRecord,
    required this.attendanceRepository,
    required this.currentEmployee,
    required this.onAttendanceMarked,
  });

  final DateTime date;
  final bool isCheckOut;
  final AttendanceRecord? existingRecord;
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
  bool? _withinAllowedRadius;
  String? _locationMessage;
  static const double _maxAllowedGpsAccuracyMeters = 50;

  String _formatKey(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';

  Future<void> _refreshLocationGate() async {
    try {
      final settings = await widget.attendanceRepository.getAttendanceSettings();
      if (!settings.requireGpsVerification) {
        if (!mounted) return;
        setState(() {
          _withinAllowedRadius = true;
          _locationMessage = null;
        });
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _withinAllowedRadius = false;
          _locationMessage = 'Location services are turned off on this device.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() {
          _withinAllowedRadius = false;
          _locationMessage = 'Location permission was denied.';
        });
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _withinAllowedRadius = false;
          _locationMessage = 'Location permission is permanently denied. Enable it in system settings.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final distance = Geolocator.distanceBetween(
        settings.officeLatitude,
        settings.officeLongitude,
        position.latitude,
        position.longitude,
      );
      final withinRadius = !(settings.officeLatitude == 0 && settings.officeLongitude == 0) &&
          distance <= settings.allowedAttendanceRadiusMeters;
      if (!mounted) return;
      setState(() {
        _withinAllowedRadius = withinRadius;
        _locationMessage = withinRadius
            ? null
            : 'You are not at the office. Please go to the office location.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _withinAllowedRadius = false;
        _locationMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _refreshLocationGate();
  }

  Widget _checkItem({
    required String label,
    required bool done,
    required IconData icon,
  }) {
    final color = done ? AppColors.primary : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(done ? Icons.check_circle : icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: done ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _authenticateAndProceed() async {
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

      final actionTitle = widget.isCheckOut ? 'Check Out' : 'Check In';
      final authenticated = await _auth.authenticate(
        localizedReason: 'Verify your identity to $actionTitle attendance',
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
        final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        if (position.accuracy > _maxAllowedGpsAccuracyMeters) {
          throw Exception(
            'GPS accuracy is too low (${position.accuracy.toStringAsFixed(1)}m). Move to an open area and try again.',
          );
        }
        if (position.isMocked) {
          throw Exception('Mock location detected. Turn off fake GPS and try again.');
        }

        AttendanceVerificationResult verifyResult;
        if (widget.isCheckOut) {
          verifyResult = await widget.attendanceRepository.verifyCheckOut(
            employeeId: widget.currentEmployee.id,
            employeeName: widget.currentEmployee.fullName,
            date: dateKey,
            profileImageUrl: widget.currentEmployee.profileImageUrl,
            currentLatitude: position.latitude,
            currentLongitude: position.longitude,
          );
        } else {
          verifyResult = await widget.attendanceRepository.verifyAttendance(
            employeeId: widget.currentEmployee.id,
            employeeName: widget.currentEmployee.fullName,
            date: dateKey,
            profileImageUrl: widget.currentEmployee.profileImageUrl,
            scheduledCheckInTime: widget.currentEmployee.inTime,
            currentLatitude: position.latitude,
            currentLongitude: position.longitude,
          );
        }

        if (!verifyResult.allowed) {
          if (!mounted) return;
          setState(() => _message = verifyResult.message);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(verifyResult.message)));
          return;
        }
        if (!mounted) return;
        setState(() => _message = verifyResult.message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$actionTitle completed successfully.')),
        );
        widget.onAttendanceMarked();
        Navigator.of(context).pop();
      } else {
        await widget.attendanceRepository.logAttendanceAttempt(
          employeeId: widget.currentEmployee.id,
          employeeName: widget.currentEmployee.fullName,
          date: dateKey,
          time: time,
          verificationStatus: widget.isCheckOut ? 'CheckOut Failed' : 'Failed',
          similarityScore: 0.0,
          message: 'Biometric verification failed. Please try again.',
        );
        if (!mounted) return;
        setState(() => _message = 'Biometric verification failed. Please try again.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric verification failed. Please try again.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = e.toString().replaceFirst('Exception: ', ''));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance unmarked successfully.')),
      );
      widget.onAttendanceMarked();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = e.toString().replaceFirst('Exception: ', ''));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _cancel() async {
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final canPerformAction = _withinAllowedRadius ?? false;
    final actionText = widget.isCheckOut ? 'Check Out' : 'Check In';

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      title: Text('$actionText Attendance'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                DateFormat('dd/MM/yyyy').format(widget.date),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('EEEE').format(widget.date),
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F8FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      widget.isCheckOut ? Icons.logout : Icons.fingerprint,
                      size: 56,
                      color: AppColors.active,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Use biometric authentication to confirm $actionText.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Verification checklist',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    _checkItem(
                      label: 'GPS location is within office radius',
                      done: _withinAllowedRadius == true,
                      icon: Icons.location_on_outlined,
                    ),
                    _checkItem(
                      label: widget.currentEmployee.profileImageUrl.isNotEmpty
                          ? 'Employee profile photo is available for verification'
                          : 'Employee profile photo is missing for verification',
                      done: widget.currentEmployee.profileImageUrl.isNotEmpty,
                      icon: Icons.badge_outlined,
                    ),
                    _checkItem(
                      label: 'Biometric prompt ready',
                      done: !_verifying,
                      icon: Icons.fingerprint,
                    ),
                  ],
                ),
              ),

              if (_message != null) ...[
                const SizedBox(height: 8),
                Text(
                  _message!,
                  style: TextStyle(
                    color: _message!.contains('successful')
                        ? AppColors.primary
                        : const Color(0xFFE53935),
                  ),
                ),
              ],
              if (_locationMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _locationMessage!,
                  style: TextStyle(
                    color: _withinAllowedRadius == true
                        ? AppColors.primary
                        : const Color(0xFFE53935),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _cancel, child: const Text('Cancel')),
        if (widget.existingRecord != null)
          TextButton(
            onPressed: _verifying ? null : _unmarkAttendance,
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFE53935)),
            child: Text(_verifying ? 'Working...' : 'Unmark Attendance'),
          ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.isCheckOut ? const Color(0xFF414A51) : AppColors.active,
            foregroundColor: Colors.white,
          ),
          onPressed: canPerformAction ? _authenticateAndProceed : null,
          child: Text(_verifying ? 'Verifying...' : actionText),
        ),
      ],
    );
  }
}
