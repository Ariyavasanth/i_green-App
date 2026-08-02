import 'attendance_record.dart';
import 'attendance_settings.dart';

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
  Future<List<AttendanceRecord>> getAllAttendanceRecords();
  Future<AttendanceRecord?> getAttendanceRecordForDate(int employeeId, String date);
  Future<bool> hasAttendanceForDate(int employeeId, String date);
  Future<AttendanceSettings> getAttendanceSettings();
  Future<void> saveAttendanceSettings(AttendanceSettings settings);
  Future<AttendanceVerificationResult> verifyAttendance({
    required int employeeId,
    required String date,
    required String employeeName,
    required String profileImageUrl,
    required String scheduledCheckInTime,
    required double currentLatitude,
    required double currentLongitude,
    bool faceMatched = true,
    double similarityScore = 1.0,
  });
  Future<AttendanceVerificationResult> verifyCheckOut({
    required int employeeId,
    required String date,
    required String employeeName,
    required String profileImageUrl,
    required double currentLatitude,
    required double currentLongitude,
    bool faceMatched = true,
    double similarityScore = 1.0,
  });
  Future<void> markAttendance({
    required int employeeId,
    required String employeeName,
    required String date,
    required String time,
    required String verificationStatus,
    required double similarityScore,
    required String status,
  });
  Future<void> checkOut({
    required int employeeId,
    required String date,
    required String checkOutTime,
    required String verificationStatus,
    required double similarityScore,
  });
  Future<void> adminSaveAttendance(AttendanceRecord record);
  Future<void> unmarkAttendance({
    required int employeeId,
    required String date,
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
  Future<List<Map<String, dynamic>>> getAttendanceAttempts();
}
