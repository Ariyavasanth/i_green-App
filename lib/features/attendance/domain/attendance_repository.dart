import 'attendance_record.dart';

abstract class AttendanceRepository {
  Future<List<AttendanceRecord>> getAttendanceRecords(int employeeId);
  Future<void> markAttendance(int employeeId, String date);
}
