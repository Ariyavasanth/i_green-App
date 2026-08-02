import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/theme/app_colors.dart';

class AttendanceLocationFields extends StatefulWidget {
  const AttendanceLocationFields({
    super.key,
    required this.latitudeController,
    required this.longitudeController,
    required this.radiusController,
    required this.requireGpsVerification,
    required this.onRequireGpsChanged,
    this.latitudeLabel = 'Office Latitude',
    this.longitudeLabel = 'Office Longitude',
    this.radiusLabel = 'Allowed Attendance Radius (meters)',
    this.requireGpsLabel = 'Require GPS Verification',
    this.isMobile = false,
    this.enabled = true,
  });

  final TextEditingController latitudeController;
  final TextEditingController longitudeController;
  final TextEditingController radiusController;
  final bool requireGpsVerification;
  final ValueChanged<bool>? onRequireGpsChanged;
  final String latitudeLabel;
  final String longitudeLabel;
  final String radiusLabel;
  final String requireGpsLabel;
  final bool isMobile;
  final bool enabled;

  static double? parseCoordinate(String value) {
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

  static String? validateCoordinate(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    if (parseCoordinate(value) == null) return 'Enter a valid coordinate';
    return null;
  }

  static String? validateRadius(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed < 0) return 'Enter a valid number';
    return null;
  }

  @override
  State<AttendanceLocationFields> createState() => _AttendanceLocationFieldsState();
}

class _AttendanceLocationFieldsState extends State<AttendanceLocationFields> {
  bool _fetchingLocation = false;

  Future<void> _useCurrentLocation() async {
    if (_fetchingLocation || !widget.enabled) return;
    setState(() => _fetchingLocation = true);

    try {
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

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() {
        widget.latitudeController.text = position.latitude.toStringAsFixed(6);
        widget.longitudeController.text = position.longitude.toStringAsFixed(6);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current location filled successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to get current location: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _fetchingLocation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: widget.enabled && !_fetchingLocation ? _useCurrentLocation : null,
            icon: _fetchingLocation
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.gps_fixed, size: 18),
            label: Text(_fetchingLocation ? 'Fetching GPS...' : 'Use Current Location'),
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: widget.latitudeController,
          enabled: widget.enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: InputDecoration(
            labelText: widget.latitudeLabel,
            border: const OutlineInputBorder(),
          ),
          validator: AttendanceLocationFields.validateCoordinate,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: widget.longitudeController,
          enabled: widget.enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: InputDecoration(
            labelText: widget.longitudeLabel,
            border: const OutlineInputBorder(),
          ),
          validator: AttendanceLocationFields.validateCoordinate,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: widget.radiusController,
          enabled: widget.enabled,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: widget.radiusLabel,
            border: const OutlineInputBorder(),
          ),
          validator: AttendanceLocationFields.validateRadius,
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(widget.requireGpsLabel),
          value: widget.requireGpsVerification,
          onChanged: widget.enabled ? widget.onRequireGpsChanged : null,
        ),
      ],
    );
  }
}
