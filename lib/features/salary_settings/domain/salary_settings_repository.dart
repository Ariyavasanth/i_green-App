import 'salary_settings.dart';

abstract class SalarySettingsRepository {
  Future<SalarySettings> getSalarySettings();
  Future<void> saveSalarySettings(SalarySettings settings);
}
