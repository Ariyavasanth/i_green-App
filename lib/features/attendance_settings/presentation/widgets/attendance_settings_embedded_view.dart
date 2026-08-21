import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../attendance/domain/attendance_settings.dart';
import '../../providers/attendance_settings_providers.dart';
import 'attendance_location_fields.dart';

class AttendanceSettingsEmbeddedView extends ConsumerStatefulWidget {
  const AttendanceSettingsEmbeddedView({super.key});

  @override
  ConsumerState<AttendanceSettingsEmbeddedView> createState() => _AttendanceSettingsEmbeddedViewState();
}

class _AttendanceSettingsEmbeddedViewState extends ConsumerState<AttendanceSettingsEmbeddedView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _graceController;
  late final TextEditingController _lateController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _radiusController;
  bool _requireGpsVerification = true;
  bool _saving = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _graceController = TextEditingController();
    _lateController = TextEditingController();
    _latitudeController = TextEditingController();
    _longitudeController = TextEditingController();
    _radiusController = TextEditingController();
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

  void _populateFields(AttendanceSettings settings) {
    if (_initialized) return;
    _initialized = true;
    _graceController.text = settings.gracePeriodMinutes.toString();
    _lateController.text = settings.lateLimitMinutes.toString();
    _latitudeController.text = settings.officeLatitude.toStringAsFixed(6);
    _longitudeController.text = settings.officeLongitude.toStringAsFixed(6);
    _radiusController.text = settings.allowedAttendanceRadiusMeters.toString();
    _requireGpsVerification = settings.requireGpsVerification;
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
      ref.invalidate(attendanceSettingsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance settings updated successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save settings: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(attendanceSettingsProvider);
    final isMobile = MediaQuery.of(context).size.width < 650;

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          children: [
            Text('Error loading attendance settings: $error', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => ref.refresh(attendanceSettingsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (settings) {
        _populateFields(settings);
        return SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timing Rules Card
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.timer_outlined, color: Color(0xFF9CC70A), size: 24),
                            SizedBox(width: 10),
                            Text(
                              'Attendance Timing Rules',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        isMobile
                            ? Column(
                                children: [
                                  _buildNumberField(_graceController, 'Grace Period (Mins)', Icons.access_alarm),
                                  const SizedBox(height: 12),
                                  _buildNumberField(_lateController, 'Late Limit (Mins)', Icons.warning_amber),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(child: _buildNumberField(_graceController, 'Grace Period (Mins)', Icons.access_alarm)),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildNumberField(_lateController, 'Late Limit (Mins)', Icons.warning_amber)),
                                ],
                              ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Office Location & Geofence Card
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.pin_drop_outlined, color: Color(0xFF9CC70A), size: 24),
                            SizedBox(width: 10),
                            Text(
                              'Office Location & Geofence Settings',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        AttendanceLocationFields(
                          latitudeController: _latitudeController,
                          longitudeController: _longitudeController,
                          radiusController: _radiusController,
                          requireGpsVerification: _requireGpsVerification,
                          onRequireGpsChanged: (val) => setState(() => _requireGpsVerification = val),
                          isMobile: isMobile,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Save Action Button
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9CC70A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_outlined, size: 20),
                    label: Text(
                      _saving ? 'Saving Settings...' : 'Save Settings',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNumberField(TextEditingController controller, String label, IconData icon) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Field is required';
        if (int.tryParse(value.trim()) == null) return 'Enter a valid number';
        return null;
      },
    );
  }
}
