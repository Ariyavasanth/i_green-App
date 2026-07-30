import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../attendance/domain/attendance_settings.dart';
import '../providers/attendance_settings_providers.dart';

class AttendanceSettingsPage extends ConsumerStatefulWidget {
  const AttendanceSettingsPage({super.key});

  @override
  ConsumerState<AttendanceSettingsPage> createState() => _AttendanceSettingsPageState();
}

class _AttendanceSettingsPageState extends ConsumerState<AttendanceSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _graceController;
  late final TextEditingController _lateController;
  late final TextEditingController _absentController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(attendanceSettingsProvider).valueOrNull ?? AttendanceSettings.defaults();
    _graceController = TextEditingController(text: settings.gracePeriodMinutes.toString());
    _lateController = TextEditingController(text: settings.lateLimitMinutes.toString());
    _absentController = TextEditingController(text: settings.absentThresholdMinutes.toString());
  }

  @override
  void dispose() {
    _graceController.dispose();
    _lateController.dispose();
    _absentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    final settings = AttendanceSettings(
      gracePeriodMinutes: int.parse(_graceController.text.trim()),
      lateLimitMinutes: int.parse(_lateController.text.trim()),
      absentThresholdMinutes: int.parse(_absentController.text.trim()),
    );
    await ref.read(attendanceSettingsRepositoryProvider).saveAttendanceSettings(settings);
    ref.invalidate(attendanceSettingsProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Attendance settings saved successfully.')),
    );
    setState(() => _saving = false);
  }

  String? _validator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed < 0) return 'Enter a valid number';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.schedule_outlined, size: 24, color: AppColors.active),
                SizedBox(width: 8),
                Text(
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
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _absentController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Absent Threshold (maximum delay after scheduled check-in)',
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
    );
  }
}
