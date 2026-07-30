import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

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

    final latitude = _parseCoordinate(_latitudeController.text);
    final longitude = _parseCoordinate(_longitudeController.text);
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
      absentThresholdMinutes: int.parse(_absentController.text.trim()),
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

  Future<void> _useCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are turned off on this device.')),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission was denied.')),
      );
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission is permanently denied. Enable it in system settings.')),
      );
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() {
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current location filled successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to get current location: $e')),
      );
    }
  }

  String? _validator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed < 0) return 'Enter a valid number';
    return null;
  }

  String? _coordinateValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    if (_parseCoordinate(value) == null) return 'Enter a valid coordinate';
    return null;
  }

  double? _parseCoordinate(String value) {
    final trimmed = value.trim();
    final decimal = double.tryParse(trimmed);
    if (decimal != null) return decimal;

    final normalized = trimmed.toUpperCase().replaceAll(RegExp(r'\s+'), '');
    final match = RegExp(
      r'^(\d+(?:\.\d+)?)[^0-9NSEW]+(\d+(?:\.\d+)?)[^0-9NSEW]+(\d+(?:\.\d+)?)(?:[^0-9NSEW]+)?([NSEW])$',
    ).firstMatch(normalized);
    if (match == null) return null;

    final degrees = double.parse(match.group(1)!);
    final minutes = double.parse(match.group(2)!);
    final seconds = double.parse(match.group(3)!);
    var result = degrees + (minutes / 60) + (seconds / 3600);
    final direction = match.group(4)!;
    if (direction == 'S' || direction == 'W') {
      result = -result;
    }
    return result;
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
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : _useCurrentLocation,
                          icon: const Icon(Icons.gps_fixed, size: 18),
                          label: const Text('Use Current Location'),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _latitudeController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: const InputDecoration(
                          labelText: 'Office Latitude',
                          border: OutlineInputBorder(),
                        ),
                        validator: _coordinateValidator,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _longitudeController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: const InputDecoration(
                          labelText: 'Office Longitude',
                          border: OutlineInputBorder(),
                        ),
                        validator: _coordinateValidator,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _radiusController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Allowed Attendance Radius (meters)',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validator,
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Require GPS Verification'),
                        value: _requireGpsVerification,
                        onChanged: _saving ? null : (value) => setState(() => _requireGpsVerification = value),
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
