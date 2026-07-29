import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:camera/camera.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/attendance_record.dart';
import '../../employee/domain/employee.dart';
import '../../leave/domain/leave_request.dart';
import '../../leave/providers/leave_providers.dart';
import '../domain/attendance_repository.dart';
import '../providers/attendance_providers.dart';
import '../services/face_verification_service.dart';

class AttendancePage extends ConsumerStatefulWidget {
  const AttendancePage({super.key});

  @override
  ConsumerState<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends ConsumerState<AttendancePage> {
  DateTime _focusedMonth = DateTime.now();
  bool _isVerifying = false;
  final _faceVerificationService = const FaceVerificationService();

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
        faceVerificationService: _faceVerificationService,
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
    required this.faceVerificationService,
    required this.attendanceRepository,
    required this.currentEmployee,
    required this.onAttendanceMarked,
  });

  final DateTime date;
  final bool isLeave;
  final bool isAttendance;
  final FaceVerificationService faceVerificationService;
  final AttendanceRepository attendanceRepository;
  final Employee currentEmployee;
  final VoidCallback onAttendanceMarked;

  @override
  State<AttendanceVerificationDialog> createState() => _AttendanceVerificationDialogState();
}

class _AttendanceVerificationDialogState extends State<AttendanceVerificationDialog> {
  CameraController? _controller;
  bool _loading = true;
  bool _verifying = false;
  String? _message;

  String _formatKey(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (!mounted) return;
    if (cameras.isEmpty) {
      setState(() {
        _loading = false;
        _message = 'Camera not available on this device.';
      });
      return;
    }
    _controller = CameraController(cameras.first, ResolutionPreset.medium, enableAudio: false);
    await _controller!.initialize();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _captureAndVerify() async {
    if (_controller == null || !_controller!.value.isInitialized || _verifying) return;
    setState(() {
      _verifying = true;
      _message = null;
    });
    try {
      final file = await _controller!.takePicture();
      final bytes = await file.readAsBytes();
      final result = await widget.faceVerificationService.verifyCapturedBytes(
        capturedBytes: bytes,
        profileImageUrl: widget.currentEmployee.profileImageUrl,
        threshold: 0.9,
        capturedImagePath: file.path,
      );
      final repo = widget.attendanceRepository as dynamic;
      await repo.logAttendanceAttempt(
        employeeId: widget.currentEmployee.id,
        employeeName: widget.currentEmployee.fullName,
        date: _formatKey(widget.date),
        time: DateFormat('HH:mm:ss').format(DateTime.now()),
        verificationStatus: result.allowed ? 'Verified' : 'Failed',
        similarityScore: result.similarityScore,
        message: result.message,
      );
      if (result.allowed && !(await repo.hasAttendanceForDate(widget.currentEmployee.id, _formatKey(widget.date)))) {
        await repo.markAttendance(
          employeeId: widget.currentEmployee.id,
          employeeName: widget.currentEmployee.fullName,
          date: _formatKey(widget.date),
          time: DateFormat('HH:mm:ss').format(DateTime.now()),
          verificationStatus: 'Verified',
          similarityScore: result.similarityScore,
        );
      }
      if (!mounted) return;
      setState(() => _message = result.message);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
      if (result.allowed) {
        widget.onAttendanceMarked();
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _retry() async {
    setState(() => _message = null);
    await _controller?.resumePreview();
  }

  Future<void> _cancel() async {
    await _controller?.dispose();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
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
                SizedBox(
                  height: 360,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: Colors.black,
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                if (_controller != null) CameraPreview(_controller!),
                                Center(
                                  child: Container(
                                    width: 200,
                                    height: 250,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: const Color(0xFF9CC70A), width: 3),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                ),
                                const Positioned(
                                  left: 16,
                                  right: 16,
                                  bottom: 16,
                                  child: Text(
                                    'Please position your face within the frame for verification.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                    ),
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
        TextButton(onPressed: _retry, child: const Text('Retry')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.active, foregroundColor: Colors.white),
          onPressed: widget.isLeave || widget.isAttendance ? null : _captureAndVerify,
          child: Text(_verifying ? 'Verifying...' : 'Capture'),
        ),
      ],
    );
  }
}
