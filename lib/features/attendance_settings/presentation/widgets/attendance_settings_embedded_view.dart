import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../attendance/domain/attendance_settings.dart';
import '../../providers/attendance_settings_providers.dart';
import 'attendance_location_fields.dart';
import 'workplace_location_dialog.dart';

class AttendanceSettingsEmbeddedView extends ConsumerStatefulWidget {
  const AttendanceSettingsEmbeddedView({super.key});

  @override
  ConsumerState<AttendanceSettingsEmbeddedView> createState() => _AttendanceSettingsEmbeddedViewState();
}

class _AttendanceSettingsEmbeddedViewState extends ConsumerState<AttendanceSettingsEmbeddedView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _graceController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _radiusController;
  bool _requireGpsVerification = true;
  List<AttendanceLocationItem> _workplaceLocations = [];
  bool _saving = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _graceController = TextEditingController();
    _latitudeController = TextEditingController();
    _longitudeController = TextEditingController();
    _radiusController = TextEditingController();
  }

  @override
  void dispose() {
    _graceController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  void _populateFields(AttendanceSettings settings) {
    if (_initialized) return;
    _initialized = true;
    _graceController.text = settings.gracePeriodMinutes.toString();
    _latitudeController.text = settings.officeLatitude.toStringAsFixed(6);
    _longitudeController.text = settings.officeLongitude.toStringAsFixed(6);
    _radiusController.text = settings.allowedAttendanceRadiusMeters.toString();
    _requireGpsVerification = settings.requireGpsVerification;
    _workplaceLocations = List.from(settings.locations);
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
                // Workplace Locations Card
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.location_city_outlined, color: Color(0xFF9CC70A), size: 24),
                                SizedBox(width: 10),
                                Text(
                                  'Workplace Locations',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF9CC70A),
                                side: const BorderSide(color: Color(0xFF9CC70A)),
                              ),
                              onPressed: _saving ? null : () => _addOrEditLocation(),
                              icon: const Icon(Icons.add_location_alt_outlined, size: 16),
                              label: const Text('Add Workplace'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Configure geofences for each workplace (Head Office, Factory, Warehouse, etc.). Employees check in against their assigned location.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const Divider(height: 24),
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
                                    'No specific workplaces added yet. Employees will validate against the default office fallback location below.',
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
                                        color: const Color(0xFF9CC70A).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(Icons.business, color: Color(0xFF9CC70A), size: 20),
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

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
                        _buildNumberField(_graceController, 'Grace Period (Mins)', Icons.access_alarm),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Office Location & Geofence Card (Fallback)
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
                              'Global / Default Office Fallback Geofence',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Fallback coordinates used when an employee has no specific workplace match.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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

