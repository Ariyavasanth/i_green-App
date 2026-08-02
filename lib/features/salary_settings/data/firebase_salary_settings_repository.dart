import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/salary_settings.dart';
import '../domain/salary_settings_repository.dart';

class FirebaseSalarySettingsRepository implements SalarySettingsRepository {
  final FirebaseFirestore _firestore;

  FirebaseSalarySettingsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _docRef =>
      _firestore.collection('salary_settings').doc('default');

  @override
  Future<SalarySettings> getSalarySettings() async {
    try {
      final doc = await _docRef.get();
      if (!doc.exists || doc.data() == null) {
        const defaultSettings = SalarySettings();
        await _docRef.set(defaultSettings.toMap());
        return defaultSettings;
      }
      return SalarySettings.fromMap(doc.data()!);
    } catch (_) {
      return const SalarySettings();
    }
  }

  @override
  Future<void> saveSalarySettings(SalarySettings settings) async {
    try {
      await _docRef.set(settings.toMap(), SetOptions(merge: true));
    } catch (_) {}
  }
}
