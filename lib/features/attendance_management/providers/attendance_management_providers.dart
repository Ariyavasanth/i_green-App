import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../attendance/domain/attendance_record.dart';
import '../data/firebase_attendance_management_repository.dart';
import '../domain/attendance_management_repository.dart';
import '../domain/attendance_management_stats.dart';

final attendanceManagementRepositoryProvider = Provider<AttendanceManagementRepository>(
  (ref) => FirebaseAttendanceManagementRepository(),
);

final attendanceManagementStatsProvider = FutureProvider.family<AttendanceManagementStats, String?>(
  (ref, date) => ref.watch(attendanceManagementRepositoryProvider).getAttendanceStats(date: date),
);

final attendanceManagementRecordsProvider = FutureProvider.family<List<AttendanceRecord>, ({int? employeeId, String? monthYear, String? statusFilter})>(
  (ref, query) => ref.watch(attendanceManagementRepositoryProvider).getAllAttendanceRecords(
        employeeId: query.employeeId,
        monthYear: query.monthYear,
        statusFilter: query.statusFilter,
      ),
);

final attendanceManagementAuditProvider = FutureProvider.family<List<Map<String, dynamic>>, int?>(
  (ref, employeeId) => ref.watch(attendanceManagementRepositoryProvider).getAuditAttempts(employeeId: employeeId),
);
