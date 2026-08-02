import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../attendance/domain/attendance_settings.dart';
import '../../../attendance_settings/presentation/widgets/attendance_location_fields.dart';
import '../../../attendance_settings/providers/attendance_settings_providers.dart';

class AttendanceSettingsDialog extends ConsumerStatefulWidget {
  const AttendanceSettingsDialog({super.key});

  @override
  ConsumerState<AttendanceSettingsDialog> createState() => _AttendanceSettingsDialogState();
}

class _AttendanceSettingsDialogState extends ConsumerState<AttendanceSettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _graceController;
  late final TextEditingController _lateController;
  late final TextEditingController _absentController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _radiusController;
  bool _requireGpsVerification = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(attendanceSettingsProvider).valueOrNull ?? AttendanceSettings.defaults();
    _graceController = TextEditingController(text: settings.gracePeriodMinutes.toString());
    _lateController = TextEditingController(text: settings.lateLimitMinutes.toString());
    _absentController = TextEditingController(text: settings.absentThresholdMinutes.toString());
    _latitudeController = TextEditingController(text: settings.officeLatitude.toStringAsFixed(6));
    _longitudeController = TextEditingController(text: settings.officeLongitude.toStringAsFixed(6));
    _radiusController = TextEditingController(text: settings.allowedAttendanceRadiusMeters.toString());
    _requireGpsVerification = settings.requireGpsVerification;
  }

  @override
  void dispose() {
    _graceController.dispose();
    _lateController.dispose();
    _absentController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    final settings = AttendanceSettings(
      gracePeriodMinutes: int.parse(_graceController.text.trim()),
      lateLimitMinutes: int.parse(_lateController.text.trim()),
      absentThresholdMinutes: int.parse(_absentController.text.trim()),
      officeLatitude: double.parse(_latitudeController.text.trim()),
      officeLongitude: double.parse(_longitudeController.text.trim()),
      allowedAttendanceRadiusMeters: int.parse(_radiusController.text.trim()),
      requireGpsVerification: _requireGpsVerification,
    );
    await ref.read(attendanceSettingsRepositoryProvider).saveAttendanceSettings(settings);
    ref.invalidate(attendanceSettingsProvider);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Attendance Settings'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: _graceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Grace Period (minutes)'), validator: _validator),
              TextFormField(controller: _lateController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Late Limit (minutes)'), validator: _validator),
              TextFormField(controller: _absentController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Absent Threshold (minutes)'), validator: _validator),
              AttendanceLocationFields(
                latitudeController: _latitudeController,
                longitudeController: _longitudeController,
                radiusController: _radiusController,
                requireGpsVerification: _requireGpsVerification,
                onRequireGpsChanged: (val) => setState(() => _requireGpsVerification = val),
                enabled: !_saving,
              ),
              const SizedBox(height: 8),
              const Text('Each employee still uses their own Check-In Time from the profile.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _saving ? null : _save, style: ElevatedButton.styleFrom(backgroundColor: AppColors.active), child: Text(_saving ? 'Saving...' : 'Save')),
      ],
    );
  }

  String? _validator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    if (int.tryParse(value.trim()) == null) return 'Enter a valid number';
    return null;
  }
}
