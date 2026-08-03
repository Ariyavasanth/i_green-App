import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:camera/camera.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/web_camera_preview.dart';
import '../domain/attendance_record.dart';
import '../../employee/domain/employee.dart';
import '../../leave/domain/leave_request.dart';
import '../../leave/providers/leave_providers.dart';
import '../domain/attendance_repository.dart';
import '../providers/attendance_providers.dart';
import '../../face_registration/domain/face_registration_repository.dart';
import '../../face_registration/providers/face_registration_providers.dart';
import '../services/face_verification_service.dart' hide FaceVerificationResult;

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
      body: SafeArea(
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
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

            // Today's Status Banner Hero Card
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
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text('Error loading today\'s attendance: $e'),
      ),
      data: (todayRecord) {
        final hasCheckedIn = todayRecord != null && todayRecord.effectiveCheckInTime.isNotEmpty;
        final hasCheckedOut = todayRecord != null && todayRecord.checkOutTime.isNotEmpty;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Title + Date + Status Pill
              Row(
                children: [
                  const Icon(Icons.access_time_filled, color: AppColors.active, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Today\'s Overview',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          dateStr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(todayRecord),
                ],
              ),
              const SizedBox(height: 16),

              // Primary Action Button (Full-width, large touch target)
              if (!hasCheckedIn) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.active,
                      foregroundColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _openVerificationDialog(
                      date: today,
                      isCheckOut: false,
                      existingRecord: todayRecord,
                    ),
                    icon: const Icon(Icons.fingerprint, size: 22),
                    label: const Text(
                      'Check In Attendance',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ] else if (!hasCheckedOut) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF414A51),
                      foregroundColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _openVerificationDialog(
                      date: today,
                      isCheckOut: true,
                      existingRecord: todayRecord,
                    ),
                    icon: const Icon(Icons.logout, size: 22),
                    label: const Text(
                      'Check Out Attendance',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF81C784)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 20, color: Color(0xFF2E7D32)),
                      SizedBox(width: 8),
                      Text(
                        'Shift Attendance Complete',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Secondary Action (Less prominent / outlined)
              if (!hasCheckedIn) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade500,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: null,
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text(
                      'Check Out Attendance',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ] else if (!hasCheckedOut) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2E7D32),
                      side: const BorderSide(color: Color(0xFF81C784)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: null,
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: Text(
                      'Checked In at ${todayRecord.effectiveCheckInTime}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],

              if (hasCheckedIn) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC62828),
                      side: const BorderSide(color: Color(0xFFEF9A9A)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Reset Attendance (Dev Tool)'),
                          content: const Text(
                            'Are you sure you want to remove today\'s attendance record from Cloud Firestore for development testing?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFC62828),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Remove'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        final repo = ref.read(attendanceRepositoryProvider);
                        final dateKey = _formatKey(today);
                        await repo.unmarkAttendance(
                          employeeId: employee.id,
                          date: dateKey,
                        );
                        ref.invalidate(attendanceRecordsProvider(employee.id));
                        ref.invalidate(allAttendanceRecordsProvider);
                        ref.invalidate(todayAttendanceRecordProvider(employee.id));
                        ref.invalidate(attendanceAttemptsProvider);
                        if (mounted) {
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Today\'s attendance record removed from Cloud Firestore (Dev Mode).'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.delete_sweep, size: 16),
                    label: const Text(
                      'Remove Today\'s Attendance (Dev Tool)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              const SizedBox(height: 16),

              // Stat Chips Row (3 equal-width columns below button)
              Row(
                children: [
                  Expanded(
                    child: _buildCompactStatChip(
                      icon: Icons.login,
                      iconColor: const Color(0xFF2E7D32),
                      label: 'Check In',
                      value: hasCheckedIn ? todayRecord.effectiveCheckInTime : '--:--',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCompactStatChip(
                      icon: Icons.logout,
                      iconColor: const Color(0xFFC62828),
                      label: 'Check Out',
                      value: hasCheckedOut ? todayRecord.checkOutTime : '--:--',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCompactStatChip(
                      icon: Icons.timelapse,
                      iconColor: AppColors.active,
                      label: 'Work Hrs',
                      value: todayRecord != null && todayRecord.totalHours > 0
                          ? '${todayRecord.totalHours} hrs'
                          : '--',
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
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
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

  Widget _buildCompactStatChip({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: iconColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
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

    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7;
    final totalGridCells = ((startWeekday + daysInMonth) / 7).ceil() * 7;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(_focusedMonth),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: AppColors.active),
                    onPressed: () => setState(
                      () => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: AppColors.active),
                    onPressed: () => setState(
                      () => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Day of week labels
          Row(
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: const TextStyle(
                          fontSize: 11,
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

          // Responsive 7-Column Calendar Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalGridCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index - startWeekday + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }

              final date = DateTime(year, month, dayNumber);
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

              return MouseRegion(
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
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(8),
                      border: isToday && bg == null
                          ? Border.all(color: AppColors.active, width: 1.5)
                          : isLeave
                              ? Border.all(color: const Color(0xFF9CC70A), width: 1.2)
                              : null,
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            '$dayNumber',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isLeave || isAttendance || isToday
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isAttendance || isLeave ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        if (isLeave)
                          const Positioned(
                            right: 3,
                            top: 3,
                            child: Icon(Icons.event_busy, size: 9, color: Colors.white),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Legend using Wrap for zero overflow on mobile
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                _legend(const Color(0xFFD6ECFF), 'Today'),
                _legend(const Color(0xFFE53935), 'Leave'),
                _legend(const Color(0xFF2E7D32), 'Present / Checked Out'),
                _legend(const Color(0xFFE65100), 'Late'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      );

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

class AttendanceVerificationDialog extends ConsumerStatefulWidget {
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
  ConsumerState<AttendanceVerificationDialog> createState() => _AttendanceVerificationDialogState();
}

class _AttendanceVerificationDialogState extends ConsumerState<AttendanceVerificationDialog> {
  CameraController? _cameraController;
  WebCameraController? _webCameraController;
  bool _isCameraInitialized = false;
  bool _verifying = false;
  bool _isFaceRegistered = false;
  bool _checkingRegistration = true;
  FaceVerificationResult? _faceResult;
  String? _message;
  bool? _withinAllowedRadius;
  String? _locationMessage;
  static const double _maxAllowedGpsAccuracyMeters = 200;

  String _formatKey(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';

  @override
  void initState() {
    super.initState();
    _checkRegistrationStatus();
    _initializeCamera();
    _refreshLocationGate();
  }

  Future<void> _checkRegistrationStatus() async {
    try {
      final repo = ref.read(faceRegistrationRepositoryProvider);
      final registered = await repo.isFaceRegistered(widget.currentEmployee.id);
      if (!mounted) return;
      setState(() {
        _isFaceRegistered = registered;
        _checkingRegistration = false;
        if (!registered) {
          _message = 'Face registration required. Please register your face in the Face Registration section before marking attendance.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checkingRegistration = false;
      });
    }
  }

  Future<void> _initializeCamera() async {
    try {
      if (kIsWeb) {
        _webCameraController = WebCameraController();
        await _webCameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      } else {
        final cameras = await availableCameras();
        if (cameras.isNotEmpty) {
          final frontCamera = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
            orElse: () => cameras.first,
          );
          _cameraController = CameraController(
            frontCamera,
            ResolutionPreset.medium,
            enableAudio: false,
          );
          await _cameraController!.initialize();
          if (mounted) {
            setState(() {
              _isCameraInitialized = true;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Attendance camera initialization error: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _webCameraController?.dispose();
    super.dispose();
  }

  Future<void> _refreshLocationGate() async {
    try {
      final emp = widget.currentEmployee;
      final settings = await widget.attendanceRepository.getAttendanceSettings();
      final bool isSite = emp.isSiteEmployee && (emp.siteLatitude != 0 || emp.siteLongitude != 0);
      final double targetLat = isSite ? emp.siteLatitude : settings.officeLatitude;
      final double targetLng = isSite ? emp.siteLongitude : settings.officeLongitude;
      final int targetRadius = isSite ? emp.siteAllowedRadiusMeters : settings.allowedAttendanceRadiusMeters;
      final bool requireGps = isSite ? emp.siteRequireGpsVerification : settings.requireGpsVerification;

      if (!requireGps) {
        if (!mounted) return;
        setState(() {
          _withinAllowedRadius = true;
          _locationMessage = null;
        });
        return;
      }

      if (!kIsWeb) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          if (!mounted) return;
          setState(() {
            _withinAllowedRadius = false;
            _locationMessage = 'Location services are turned off on this device.';
          });
          return;
        }
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
        targetLat,
        targetLng,
        position.latitude,
        position.longitude,
      );
      final withinRadius = !(targetLat == 0 && targetLng == 0) &&
          distance <= targetRadius;
      if (!mounted) return;
      setState(() {
        _withinAllowedRadius = withinRadius;
        _locationMessage = withinRadius
            ? null
            : isSite
                ? 'You are not at your site location. Please go to your site location.'
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

  Widget _checkItem({
    required String label,
    required bool done,
    required IconData icon,
  }) {
    final color = done ? const Color(0xFF2E7D32) : AppColors.textSecondary;
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

  List<double> _generateFeatureVector({required int seed}) {
    final random = Random(seed);
    final rawVec = List.generate(128, (_) => random.nextDouble() * 2 - 1.0);
    final length = sqrt(rawVec.fold(0.0, (sum, val) => sum + val * val));
    if (length == 0) return rawVec;
    return rawVec.map((v) => v / length).toList();
  }

  Future<void> _authenticateAndProceed() async {
    if (_verifying) return;

    if (!_isFaceRegistered) {
      setState(() {
        _message = 'Face registration required. Please complete Face Registration before marking attendance.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete Face Registration before marking attendance.')),
      );
      return;
    }

    setState(() {
      _verifying = true;
      _message = null;
      _faceResult = null;
    });

    try {
      final actionTitle = widget.isCheckOut ? 'Check Out' : 'Check In';
      final now = DateTime.now();
      final dateKey = _formatKey(widget.date);
      final timeStr = DateFormat('HH:mm:ss').format(now);

      // Step 1: Native Android Phone Hardware Face Unlock / Biometric Verification
      bool isNativeVerified = false;
      try {
        final localAuth = LocalAuthentication();
        final canCheck = await localAuth.canCheckBiometrics;
        final isSupported = await localAuth.isDeviceSupported();
        if (canCheck && isSupported) {
          final biometrics = await localAuth.getAvailableBiometrics();
          if (biometrics.isNotEmpty) {
            isNativeVerified = await localAuth.authenticate(
              localizedReason: 'Scan face biometrics to verify attendance for ${widget.currentEmployee.fullName}',
              options: const AuthenticationOptions(
                biometricOnly: true,
                stickyAuth: true,
                useErrorDialogs: true,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Native phone face unlock error: $e');
      }

      FaceVerificationResult faceVerification;
      if (isNativeVerified) {
        faceVerification = const FaceVerificationResult(
          isMatched: true,
          similarityScore: 1.0,
          verificationStatus: 'VERIFIED_NATIVE',
          message: 'Face Verified via Native Android Face Unlock (100% Match)',
        );
      } else {
        final faceRepo = ref.read(faceRegistrationRepositoryProvider);
        final storedEmbeddings = await faceRepo.getFaceEmbeddings(widget.currentEmployee.id);

        if (storedEmbeddings.isEmpty) {
          if (!mounted) return;
          setState(() {
            _message = 'Face not recognized. Attendance not marked.';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Face not recognized. Attendance not marked.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        XFile? livePhoto;
        Uint8List? webPhotoBytes;

        if (kIsWeb && _webCameraController != null && _webCameraController!.isInitialized) {
          try {
            webPhotoBytes = await _webCameraController!.takePicture();
          } catch (_) {}
        } else if (_isCameraInitialized && _cameraController != null && _cameraController!.value.isInitialized) {
          try {
            livePhoto = await _cameraController!.takePicture();
          } catch (_) {}
        }

        if (livePhoto == null && webPhotoBytes == null) {
          if (!mounted) return;
          setState(() {
            _message = 'No face detected in frame. Please position your face clearly.';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No face detected in frame. Please position your face clearly.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final bytes = webPhotoBytes ?? await livePhoto!.readAsBytes();
        const faceService = FaceVerificationService();

        if (!faceService.isFaceDetected(bytes)) {
          if (!mounted) return;
          setState(() {
            _message = 'No face detected in frame. Please position your face clearly.';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No face detected in frame. Please position your face clearly.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final liveVector = faceService.extractEmbeddingFromImageBytes(bytes);
        if (liveVector.isEmpty) {
          if (!mounted) return;
          setState(() {
            _message = 'No face detected in frame. Please position your face clearly.';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No face detected in frame. Please position your face clearly.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        faceVerification = await faceRepo.verifyLiveEmbedding(
          employeeId: widget.currentEmployee.id,
          employeeName: widget.currentEmployee.fullName,
          date: dateKey,
          time: timeStr,
          actionType: widget.isCheckOut ? 'CHECK_OUT' : 'CHECK_IN',
          liveEmbedding: liveVector,
          liveFrameImagePath: livePhoto?.path ?? '',
        );
      }

      // Temporary log for testing threshold confirmation (commented out before finishing)
      // debugPrint('Face Verification Attempt - Employee ID: ${widget.currentEmployee.id}, Similarity Score: ${(faceVerification.similarityScore * 100).toStringAsFixed(2)}%, IsMatched: ${faceVerification.isMatched}');

      if (!mounted) return;
      setState(() {
        _faceResult = faceVerification;
      });

      if (!faceVerification.isMatched) {
        await widget.attendanceRepository.logAttendanceAttempt(
          employeeId: widget.currentEmployee.id,
          employeeName: widget.currentEmployee.fullName,
          date: dateKey,
          time: timeStr,
          verificationStatus: widget.isCheckOut ? 'CheckOut Failed' : 'Failed',
          similarityScore: faceVerification.similarityScore,
          message: 'Face not recognized. Attendance not marked.',
        );

        if (!mounted) return;
        setState(() {
          _message = 'Face not recognized. Attendance not marked. (${(faceVerification.similarityScore * 100).toStringAsFixed(1)}% match)';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Face not recognized. Attendance not marked.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // GPS Position Verification (checked if GPS verification is required for global or site employee)
      final emp = widget.currentEmployee;
      final settings = await widget.attendanceRepository.getAttendanceSettings();
      final bool isSite = emp.isSiteEmployee && (emp.siteLatitude != 0 || emp.siteLongitude != 0);
      final bool requireGps = isSite ? emp.siteRequireGpsVerification : settings.requireGpsVerification;
      double currentLat = 0.0;
      double currentLng = 0.0;

      if (requireGps) {
        final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        if (position.accuracy > _maxAllowedGpsAccuracyMeters) {
          throw Exception(
            'GPS accuracy is too low (${position.accuracy.toStringAsFixed(1)}m). Move to an open area and try again.',
          );
        }
        if (!kIsWeb && position.isMocked) {
          throw Exception('Mock location detected. Turn off fake GPS and try again.');
        }
        currentLat = position.latitude;
        currentLng = position.longitude;
      }

      AttendanceVerificationResult verifyResult;
      if (widget.isCheckOut) {
        verifyResult = await widget.attendanceRepository.verifyCheckOut(
          employeeId: widget.currentEmployee.id,
          employeeName: widget.currentEmployee.fullName,
          date: dateKey,
          profileImageUrl: widget.currentEmployee.profileImageUrl,
          currentLatitude: currentLat,
          currentLongitude: currentLng,
          faceMatched: faceVerification.isMatched,
          similarityScore: faceVerification.similarityScore,
        );
      } else {
        verifyResult = await widget.attendanceRepository.verifyAttendance(
          employeeId: widget.currentEmployee.id,
          employeeName: widget.currentEmployee.fullName,
          date: dateKey,
          profileImageUrl: widget.currentEmployee.profileImageUrl,
          scheduledCheckInTime: widget.currentEmployee.inTime,
          currentLatitude: currentLat,
          currentLongitude: currentLng,
          faceMatched: faceVerification.isMatched,
          similarityScore: faceVerification.similarityScore,
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
        SnackBar(content: Text('$actionTitle completed successfully with Face Verification!')),
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
    final canPerformAction = (_withinAllowedRadius ?? false) && _isFaceRegistered;
    final actionText = widget.isCheckOut ? 'Check Out' : 'Check In';

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text('$actionText Attendance'),
      content: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        width: MediaQuery.of(context).size.width,
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

              // Live Camera Preview Frame for Automatic Face Verification
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _faceResult == null
                        ? AppColors.active
                        : (_faceResult!.isMatched ? const Color(0xFF2E7D32) : Colors.red),
                    width: 2.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_isCameraInitialized && kIsWeb && _webCameraController != null)
                        WebCameraPreview(controller: _webCameraController!)
                      else if (_isCameraInitialized && _cameraController != null)
                        CameraPreview(_cameraController!)
                      else
                        const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.face_retouching_natural, size: 48, color: Colors.white54),
                            SizedBox(height: 6),
                            Text('Camera Feed Ready', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),

                      // Oval Face Overlay
                      Container(
                        width: 130,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.circular(80),
                          border: Border.all(
                            color: _faceResult == null
                                ? AppColors.active
                                : (_faceResult!.isMatched ? const Color(0xFF2E7D32) : Colors.red),
                            width: 2,
                          ),
                        ),
                      ),

                      if (_verifying)
                        Container(
                          color: Colors.black54,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: AppColors.active),
                              SizedBox(height: 10),
                              Text(
                                'Recognizing Face...',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
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
                      label: _checkingRegistration
                          ? 'Checking registered face profile...'
                          : (_isFaceRegistered
                              ? 'Face embeddings profile registered in Cloud Firestore'
                              : 'Face profile NOT registered'),
                      done: _isFaceRegistered,
                      icon: Icons.badge_outlined,
                    ),
                    _checkItem(
                      label: _faceResult != null && _faceResult!.isMatched
                          ? 'Live Face Recognition matched (${(_faceResult!.similarityScore * 100).toStringAsFixed(1)}%)'
                          : 'Live camera face verification on $actionText',
                      done: _faceResult?.isMatched == true,
                      icon: Icons.camera_front,
                    ),
                  ],
                ),
              ),

              if (_message != null) ...[
                const SizedBox(height: 8),
                Text(
                  _message!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _message!.contains('completed') || _message!.contains('successful')
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFE53935),
                  ),
                ),
              ],
              if (_locationMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _locationMessage!,
                  style: TextStyle(
                    fontSize: 12,
                    color: _withinAllowedRadius == true
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFE53935),
                  ),
                ),
              ],
              if (!_isFaceRegistered || (_faceResult != null && !_faceResult!.isMatched)) ...[
                const SizedBox(height: 10),
                Center(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF414A51)),
                    onPressed: () {
                      Navigator.of(context).pop();
                      GoRouter.of(context).go('/face-registration');
                    },
                    icon: const Icon(Icons.face_retouching_natural, size: 18),
                    label: const Text(
                      'Re-register or Delete Face Profile',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                    ),
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
