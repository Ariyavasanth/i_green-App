import '../../attendance/domain/attendance_settings.dart';

abstract class AttendanceSettingsRepository {
  Future<AttendanceSettings> getAttendanceSettings();
  Future<void> saveAttendanceSettings(AttendanceSettings settings);
}
