import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../attendance/domain/attendance_settings.dart';
import 'attendance_location_fields.dart';

class WorkplaceLocationDialog extends StatefulWidget {
  const WorkplaceLocationDialog({
    super.key,
    this.location,
  });

  final AttendanceLocationItem? location;

  @override
  State<WorkplaceLocationDialog> createState() => _WorkplaceLocationDialogState();
}

class _WorkplaceLocationDialogState extends State<WorkplaceLocationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _radiusController;
  late bool _requireGps;

  @override
  void initState() {
    super.initState();
    final loc = widget.location;
    _nameController = TextEditingController(text: loc?.name ?? '');
    _latController = TextEditingController(
      text: loc != null && loc.latitude != 0 ? loc.latitude.toStringAsFixed(6) : '',
    );
    _lngController = TextEditingController(
      text: loc != null && loc.longitude != 0 ? loc.longitude.toStringAsFixed(6) : '',
    );
    _radiusController = TextEditingController(
      text: (loc?.radiusMeters ?? 15).toString(),
    );
    _requireGps = loc?.requireGpsVerification ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final lat = AttendanceLocationFields.parseCoordinate(_latController.text) ?? 0.0;
    final lng = AttendanceLocationFields.parseCoordinate(_lngController.text) ?? 0.0;
    final radius = int.tryParse(_radiusController.text.trim()) ?? 15;

    final id = widget.location?.id.isNotEmpty == true
        ? widget.location!.id
        : 'loc_${DateTime.now().millisecondsSinceEpoch}';

    final result = AttendanceLocationItem(
      id: id,
      name: _nameController.text.trim(),
      latitude: lat,
      longitude: lng,
      radiusMeters: radius,
      requireGpsVerification: _requireGps,
    );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.location != null;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          Icon(
            isEditing ? Icons.edit_location_alt_outlined : Icons.add_location_alt_outlined,
            color: const Color(0xFF9CC70A),
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            isEditing ? 'Edit Workplace Location' : 'Add Workplace Location',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Workplace Name *',
                    hintText: 'e.g. Head Office, Factory, Warehouse',
                    prefixIcon: Icon(Icons.business_outlined, size: 20),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Please enter a workplace name';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AttendanceLocationFields(
                  latitudeController: _latController,
                  longitudeController: _lngController,
                  radiusController: _radiusController,
                  requireGpsVerification: _requireGps,
                  onRequireGpsChanged: (val) => setState(() => _requireGps = val),
                  latitudeLabel: 'Workplace Latitude *',
                  longitudeLabel: 'Workplace Longitude *',
                  radiusLabel: 'Allowed Geofence Radius (meters) *',
                  requireGpsLabel: 'Require GPS Verification for this Location',
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF9CC70A),
            foregroundColor: Colors.white,
          ),
          onPressed: _submit,
          child: Text(isEditing ? 'Save Changes' : 'Add Location'),
        ),
      ],
    );
  }
}
