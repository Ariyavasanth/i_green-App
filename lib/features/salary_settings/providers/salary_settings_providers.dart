import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase_salary_settings_repository.dart';
import '../domain/salary_settings.dart';
import '../domain/salary_settings_repository.dart';

final salarySettingsRepositoryProvider = Provider<SalarySettingsRepository>((ref) {
  return FirebaseSalarySettingsRepository();
});

class SalarySettingsNotifier extends StateNotifier<AsyncValue<SalarySettings>> {
  final SalarySettingsRepository _repository;

  SalarySettingsNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    state = const AsyncValue.loading();
    try {
      final settings = await _repository.getSalarySettings();
      state = AsyncValue.data(settings);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> saveSettings(SalarySettings settings) async {
    try {
      await _repository.saveSalarySettings(settings);
      state = AsyncValue.data(settings);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final salarySettingsNotifierProvider =
    StateNotifierProvider<SalarySettingsNotifier, AsyncValue<SalarySettings>>((ref) {
  final repository = ref.watch(salarySettingsRepositoryProvider);
  return SalarySettingsNotifier(repository);
});
