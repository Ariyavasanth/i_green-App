import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../attendance/domain/attendance_settings.dart';
import '../data/firebase_attendance_settings_repository.dart';
import '../domain/attendance_settings_repository.dart';

final attendanceSettingsRepositoryProvider = Provider<AttendanceSettingsRepository>(
  (ref) => FirebaseAttendanceSettingsRepository(),
);

final attendanceSettingsProvider = FutureProvider<AttendanceSettings>(
  (ref) => ref.watch(attendanceSettingsRepositoryProvider).getAttendanceSettings(),
);
