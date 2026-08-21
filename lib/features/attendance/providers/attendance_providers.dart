import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../leave/domain/leave_request.dart';
import '../../leave/providers/leave_providers.dart';
import '../data/firebase_attendance_repository.dart';
import '../domain/attendance_record.dart';
import '../domain/attendance_repository.dart';
export '../../app_shell/presentation/app_shell.dart' show attendanceActiveTabProvider;

final attendanceRepositoryProvider = Provider<AttendanceRepository>(
  (ref) => FirebaseAttendanceRepository(),
);

final attendanceRecordsProvider = FutureProvider.family<List<AttendanceRecord>, int>(
  (ref, employeeId) => ref.watch(attendanceRepositoryProvider).getAttendanceRecords(employeeId),
);

final allAttendanceRecordsProvider = FutureProvider<List<AttendanceRecord>>(
  (ref) => ref.watch(attendanceRepositoryProvider).getAllAttendanceRecords(),
);

final todayAttendanceRecordProvider = FutureProvider.family<AttendanceRecord?, int>(
  (ref, employeeId) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return ref.watch(attendanceRepositoryProvider).getAttendanceRecordForDate(employeeId, today);
  },
);

final attendanceAttemptsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(attendanceRepositoryProvider).getAttendanceAttempts(),
);

final attendanceLeaveRequestsProvider = FutureProvider.family<List<LeaveRequest>, int>(
  (ref, employeeId) async {
    final repo = ref.watch(leaveRepositoryProvider);
    return repo.getLeaveRequests(employeeId);
  },
);
