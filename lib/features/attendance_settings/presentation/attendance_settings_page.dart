import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../attendance/domain/attendance_settings.dart';
import '../providers/attendance_settings_providers.dart';
import 'widgets/attendance_location_fields.dart';

class AttendanceSettingsPage extends ConsumerStatefulWidget {
  const AttendanceSettingsPage({super.key});

  @override
  ConsumerState<AttendanceSettingsPage> createState() => _AttendanceSettingsPageState();
}

class _AttendanceSettingsPageState extends ConsumerState<AttendanceSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _graceController;
  late final TextEditingController _lateController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _radiusController;
  bool _requireGpsVerification = true;
  bool _saving = false;
  AttendanceSettings? _lastAppliedSettings;

  @override
  void initState() {
    super.initState();
    final settings = AttendanceSettings.defaults();
    _graceController = TextEditingController(text: settings.gracePeriodMinutes.toString());
    _lateController = TextEditingController(text: settings.lateLimitMinutes.toString());
    _latitudeController = TextEditingController(text: settings.officeLatitude.toStringAsFixed(6));
    _longitudeController = TextEditingController(text: settings.officeLongitude.toStringAsFixed(6));
    _radiusController = TextEditingController(text: settings.allowedAttendanceRadiusMeters.toString());
    _requireGpsVerification = settings.requireGpsVerification;
  }

  @override
  void dispose() {
    _graceController.dispose();
    _lateController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);

    final latitude = AttendanceLocationFields.parseCoordinate(_latitudeController.text);
    final longitude = AttendanceLocationFields.parseCoordinate(_longitudeController.text);
    if (latitude == null || longitude == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid latitude and longitude values.')),
      );
      setState(() => _saving = false);
      return;
    }

    final settings = AttendanceSettings(
      gracePeriodMinutes: int.parse(_graceController.text.trim()),
      lateLimitMinutes: int.parse(_lateController.text.trim()),
      officeLatitude: latitude,
      officeLongitude: longitude,
      allowedAttendanceRadiusMeters: int.parse(_radiusController.text.trim()),
      requireGpsVerification: _requireGpsVerification,
    );

    try {
      await ref.read(attendanceSettingsRepositoryProvider).saveAttendanceSettings(settings);
      _applySettingsToForm(settings);
      ref.invalidate(attendanceSettingsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance settings saved successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save attendance settings: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _applySettingsToForm(AttendanceSettings settings) {
    if (_lastAppliedSettings == settings) return;
    _lastAppliedSettings = settings;
    _graceController.text = settings.gracePeriodMinutes.toString();
    _lateController.text = settings.lateLimitMinutes.toString();
    _latitudeController.text = settings.officeLatitude.toStringAsFixed(6);
    _longitudeController.text = settings.officeLongitude.toStringAsFixed(6);
    _radiusController.text = settings.allowedAttendanceRadiusMeters.toString();
    setState(() {
      _requireGpsVerification = settings.requireGpsVerification;
    });
  }

  String? _validator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed < 0) return 'Enter a valid number';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(attendanceSettingsProvider);
    settingsAsync.whenData((settings) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applySettingsToForm(settings);
      });
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FA),
      body: RefreshIndicator(
        color: AppColors.active,
        onRefresh: () async {
          ref.invalidate(attendanceSettingsProvider);
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (context.canPop())
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back to Attendance Management',
                      onPressed: () => context.pop(),
                    ),
                  ),
                const Icon(Icons.schedule_outlined, size: 24, color: AppColors.active),
                const SizedBox(width: 8),
                const Text(
                  'Attendance Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider),
              ),
              child: Form(
                key: _formKey,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Configure the global attendance policy for all employees.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AttendanceLocationFields(
                        latitudeController: _latitudeController,
                        longitudeController: _longitudeController,
                        radiusController: _radiusController,
                        requireGpsVerification: _requireGpsVerification,
                        onRequireGpsChanged: (val) => setState(() => _requireGpsVerification = val),
                        enabled: !_saving,
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _graceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Grace Period (minutes)',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validator,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _lateController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Late Limit (maximum minutes after grace period)',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validator,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.active,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _saving ? null : _save,
                            icon: const Icon(Icons.save_outlined, size: 18),
                            label: Text(_saving ? 'Saving...' : 'Save Settings'),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Each employee still uses their own Check-In Time from the employee profile.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  }
}
