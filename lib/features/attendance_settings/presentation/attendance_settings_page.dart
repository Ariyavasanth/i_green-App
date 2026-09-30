import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../attendance/domain/attendance_settings.dart';
import '../providers/attendance_settings_providers.dart';
import 'widgets/attendance_location_fields.dart';
import 'widgets/workplace_location_dialog.dart';

class AttendanceSettingsPage extends ConsumerStatefulWidget {
  const AttendanceSettingsPage({super.key});

  @override
  ConsumerState<AttendanceSettingsPage> createState() => _AttendanceSettingsPageState();
}

class _AttendanceSettingsPageState extends ConsumerState<AttendanceSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _graceController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _radiusController;
  bool _requireGpsVerification = true;
  List<AttendanceLocationItem> _workplaceLocations = [];
  bool _saving = false;
  AttendanceSettings? _lastAppliedSettings;

  @override
  void initState() {
    super.initState();
    final settings = AttendanceSettings.defaults();
    _graceController = TextEditingController(text: settings.gracePeriodMinutes.toString());
    _latitudeController = TextEditingController(text: settings.officeLatitude.toStringAsFixed(6));
    _longitudeController = TextEditingController(text: settings.officeLongitude.toStringAsFixed(6));
    _radiusController = TextEditingController(text: settings.allowedAttendanceRadiusMeters.toString());
    _requireGpsVerification = settings.requireGpsVerification;
    _workplaceLocations = List.from(settings.locations);
  }

  @override
  void dispose() {
    _graceController.dispose();
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
      officeLatitude: latitude,
      officeLongitude: longitude,
      allowedAttendanceRadiusMeters: int.parse(_radiusController.text.trim()),
      requireGpsVerification: _requireGpsVerification,
      locations: _workplaceLocations,
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
    _latitudeController.text = settings.officeLatitude.toStringAsFixed(6);
    _longitudeController.text = settings.officeLongitude.toStringAsFixed(6);
    _radiusController.text = settings.allowedAttendanceRadiusMeters.toString();
    setState(() {
      _requireGpsVerification = settings.requireGpsVerification;
      _workplaceLocations = List.from(settings.locations);
    });
  }

  Future<void> _addOrEditLocation([AttendanceLocationItem? existing]) async {
    final result = await showDialog<AttendanceLocationItem>(
      context: context,
      builder: (ctx) => WorkplaceLocationDialog(location: existing),
    );
    if (result == null || !mounted) return;

    setState(() {
      if (existing != null) {
        final index = _workplaceLocations.indexWhere((l) => l.id == existing.id);
        if (index != -1) {
          _workplaceLocations[index] = result;
        } else {
          _workplaceLocations.add(result);
        }
      } else {
        _workplaceLocations.add(result);
      }
    });
  }

  void _deleteLocation(AttendanceLocationItem loc) {
    setState(() {
      _workplaceLocations.removeWhere((l) => l.id == loc.id);
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
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Configure attendance policies and multi-location geofencing for your employees.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Section 1: Workplace Locations (Office, Factory, Warehouse, etc.)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.location_city, color: AppColors.active, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Workplace Locations',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.active,
                                side: const BorderSide(color: AppColors.active),
                              ),
                              onPressed: _saving ? null : () => _addOrEditLocation(),
                              icon: const Icon(Icons.add_location_alt, size: 16),
                              label: const Text('Add Workplace'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Employees check in against the GPS of their assigned Work Location (e.g. Head Office, Factory, Warehouse).',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),

                        if (_workplaceLocations.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline, color: AppColors.textSecondary, size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'No specific workplaces added yet. All employees will use the global fallback coordinates below.',
                                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _workplaceLocations.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (ctx, idx) {
                              final loc = _workplaceLocations[idx];
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAFCFF),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.active.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(Icons.business, color: AppColors.active, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            loc.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)} • Radius: ${loc.radiusMeters}m • GPS: ${loc.requireGpsVerification ? "Required" : "Optional"}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF414A51)),
                                      tooltip: 'Edit Location',
                                      onPressed: _saving ? null : () => _addOrEditLocation(loc),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                      tooltip: 'Delete Location',
                                      onPressed: _saving ? null : () => _deleteLocation(loc),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),

                        // Section 2: Global Fallback Location
                        const Row(
                          children: [
                            Icon(Icons.pin_drop_outlined, color: AppColors.active, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Global / Default Office Fallback Settings',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Used when an employee does not have a specific assigned workplace or location match.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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

                        // Section 3: Timing Rules
                        const Text(
                          'Timing Rules',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _graceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Grace Period (minutes)',
                            border: OutlineInputBorder(),
                          ),
                          validator: _validator,
                        ),
                        const SizedBox(height: 24),

                        Row(
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.active,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
