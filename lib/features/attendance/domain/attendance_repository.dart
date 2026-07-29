import 'attendance_record.dart';

class AttendanceVerificationResult {
  const AttendanceVerificationResult({
    required this.allowed,
    required this.similarityScore,
    required this.verificationStatus,
    required this.message,
    required this.capturedImagePath,
  });

  final bool allowed;
  final double similarityScore;
  final String verificationStatus;
  final String message;
  final String capturedImagePath;
}

abstract class AttendanceRepository {
  Future<List<AttendanceRecord>> getAttendanceRecords(int employeeId);
  Future<bool> hasAttendanceForDate(int employeeId, String date);
  Future<AttendanceVerificationResult> verifyAttendance({
    required int employeeId,
    required String date,
    required String employeeName,
    required String profileImageUrl,
  });
  Future<void> markAttendance({
    required int employeeId,
    required String employeeName,
    required String date,
    required String time,
    required String verificationStatus,
    required double similarityScore,
  });
  Future<void> logAttendanceAttempt({
    required int employeeId,
    required String employeeName,
    required String date,
    required String time,
    required String verificationStatus,
    required double similarityScore,
    required String message,
  });
}
