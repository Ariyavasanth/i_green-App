import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../leave/domain/leave_request.dart';
import '../../leave/providers/leave_providers.dart';
import '../data/sqlite_attendance_repository.dart';
import '../domain/attendance_record.dart';
import '../domain/attendance_repository.dart';
import '../../attendance_settings/providers/attendance_settings_providers.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>(
  (ref) => SqliteAttendanceRepository(),
);

final attendanceRecordsProvider = FutureProvider.family<List<AttendanceRecord>, int>(
  (ref, employeeId) => ref.watch(attendanceRepositoryProvider).getAttendanceRecords(employeeId),
);

final attendanceLeaveRequestsProvider = FutureProvider.family<List<LeaveRequest>, int>(
  (ref, employeeId) async {
    final repo = ref.watch(leaveRepositoryProvider);
    return repo.getLeaveRequests(employeeId);
  },
);
