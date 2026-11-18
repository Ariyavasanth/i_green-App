import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../attendance/domain/attendance_record.dart';
import '../../employee/providers/employee_providers.dart';
import '../data/firebase_attendance_management_repository.dart';
import '../domain/attendance_management_repository.dart';
import '../domain/attendance_management_stats.dart';

final attendanceManagementRepositoryProvider = Provider<AttendanceManagementRepository>(
  (ref) => FirebaseAttendanceManagementRepository(),
);

final attendanceManagementStatsProvider = StreamProvider.family<AttendanceManagementStats, String?>(
  (ref, date) {
    // Re-subscribe whenever employee list/statuses change (e.g., marked Inactive/Suspended/Archived)
    ref.watch(employeesProvider);
    return ref.watch(attendanceManagementRepositoryProvider).watchAttendanceStats(date: date);
  },
);

final attendanceManagementRecordsProvider = StreamProvider.family<List<AttendanceRecord>, ({int? employeeId, String? monthYear, String? statusFilter})>(
  (ref, query) {
    ref.watch(employeesProvider);
    return ref.watch(attendanceManagementRepositoryProvider).watchAllAttendanceRecords(
          employeeId: query.employeeId,
          monthYear: query.monthYear,
          statusFilter: query.statusFilter,
        );
  },
);

final attendanceManagementAuditProvider = FutureProvider.family<List<Map<String, dynamic>>, int?>(
  (ref, employeeId) {
    ref.watch(employeesProvider);
    return ref.watch(attendanceManagementRepositoryProvider).getAuditAttempts(employeeId: employeeId);
  },
);
