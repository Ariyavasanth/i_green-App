import '../../attendance/domain/attendance_record.dart';
import 'attendance_management_stats.dart';

abstract class AttendanceManagementRepository {
  Future<List<AttendanceRecord>> getAllAttendanceRecords({
    int? employeeId,
    String? monthYear,
    String? statusFilter,
  });

  Future<AttendanceManagementStats> getAttendanceStats({String? date});

  Future<void> saveOrOverrideAttendance(AttendanceRecord record);

  Future<void> deleteAttendanceRecord(int employeeId, String date);

  Future<List<Map<String, dynamic>>> getAuditAttempts({int? employeeId, int limit = 100});

  Future<void> bulkMarkAttendance({
    required List<int> employeeIds,
    required String date,
    required String status,
    required String checkInTime,
  });
}
