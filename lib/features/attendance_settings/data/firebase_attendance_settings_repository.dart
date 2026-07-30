import '../../attendance/domain/attendance_settings.dart';
import '../domain/attendance_settings_repository.dart';

class FirebaseAttendanceSettingsRepository implements AttendanceSettingsRepository {
  @override
  Future<AttendanceSettings> getAttendanceSettings() async {
    return AttendanceSettings.defaults();
  }

  @override
  Future<void> saveAttendanceSettings(AttendanceSettings settings) async {}
}
