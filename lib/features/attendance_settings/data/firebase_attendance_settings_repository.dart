import 'package:cloud_firestore/cloud_firestore.dart';

import '../../attendance/domain/attendance_settings.dart';
import '../domain/attendance_settings_repository.dart';

class FirebaseAttendanceSettingsRepository implements AttendanceSettingsRepository {
  FirebaseAttendanceSettingsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _settingsRef =>
      _firestore.collection('attendance_settings').doc('global');

  @override
  Future<AttendanceSettings> getAttendanceSettings() async {
    final snap = await _settingsRef.get();
    if (!snap.exists || snap.data() == null) {
      return AttendanceSettings.defaults();
    }
    return AttendanceSettings.fromMap(snap.data()!);
  }

  @override
  Future<void> saveAttendanceSettings(AttendanceSettings settings) async {
    await _settingsRef.set(settings.toMap(), SetOptions(merge: true));
  }
}
