import 'package:flutter/material.dart';
import '../../domain/on_duty_site.dart';
import 'destination_map_picker.dart';

class AddSiteDialog extends StatefulWidget {
  const AddSiteDialog({
    super.key,
    this.siteNumber = 1,
    this.existingSite,
  });

  final int siteNumber;
  final OnDutySite? existingSite;

  @override
  State<AddSiteDialog> createState() => _AddSiteDialogState();
}

class _AddSiteDialogState extends State<AddSiteDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _siteNameController;
  late final TextEditingController _purposeController;
  late final TextEditingController _notesController;

  SelectedDestination? _destination;
  int _selectedRadius = 100;

  static const _radiusOptions = [50, 100, 200, 500];

  @override
  void initState() {
    super.initState();
    final existing = widget.existingSite;
    _siteNameController = TextEditingController(text: existing?.siteName ?? '');
    _purposeController = TextEditingController(text: existing?.purpose ?? '');
    _notesController = TextEditingController(text: existing?.notes ?? '');

    if (existing != null) {
      _selectedRadius = existing.radius > 0 ? existing.radius : 100;
      if (existing.latitude != null && existing.longitude != null) {
        _destination = SelectedDestination(
          name: existing.destinationName.isNotEmpty ? existing.destinationName : existing.destination,
          address: existing.destinationAddress,
          latitude: existing.latitude!,
          longitude: existing.longitude!,
          radius: _selectedRadius,
        );
      }
    }
  }

  @override
  void dispose() {
    _siteNameController.dispose();
    _purposeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDestinationOnMap() async {
    final result = await showDialog<SelectedDestination>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          height: 600,
          padding: const EdgeInsets.all(16),
          child: DestinationMapPicker(
            initialDestination: _destination,
            onDestinationSelected: (dest) {
              Navigator.of(ctx).pop(dest);
            },
          ),
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _destination = result;
        _selectedRadius = result.radius;
        if (_siteNameController.text.trim().isEmpty && result.name.isNotEmpty) {
          _siteNameController.text = result.name;
        }
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please search and select a site location on the map'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final siteName = _siteNameController.text.trim();
    final site = OnDutySite(
      siteId: widget.existingSite?.siteId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      siteName: siteName,
      purpose: _purposeController.text.trim(),
      destination: _destination!.name.isNotEmpty ? _destination!.name : siteName,
      destinationAddress: _destination!.address,
      latitude: _destination!.latitude,
      longitude: _destination!.longitude,
      radius: _selectedRadius,
      status: widget.existingSite?.status ?? 'PENDING',
      notes: _notesController.text.trim(),
    );

    Navigator.of(context).pop(site);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = const Color(0xFF9CC70A);
    final darkAccent = const Color(0xFF414A51);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.add_location_alt_rounded, color: darkAccent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.existingSite != null ? 'Edit Site ${widget.siteNumber}' : 'Add Site ${widget.siteNumber}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: darkAccent,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Site Name Input
                Text(
                  'Site Name / Destination *',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _siteNameController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Tambaram Site / Client Office',
                    prefixIcon: const Icon(Icons.business_rounded, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter site name' : null,
                ),
                const SizedBox(height: 14),

                // Site Purpose
                Text(
                  'Site Purpose *',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _purposeController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Customer meeting / Site inspection',
                    prefixIcon: const Icon(Icons.assignment_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter purpose for this site' : null,
                ),
                const SizedBox(height: 14),

                // Location Map Selection Card
                Text(
                  'Location & Geofence *',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickDestinationOnMap,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _destination != null ? primaryColor.withOpacity(0.08) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _destination != null ? primaryColor : Colors.grey.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.map_outlined,
                          color: _destination != null ? darkAccent : Colors.grey.shade600,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _destination != null
                                    ? (_destination!.name.isNotEmpty ? _destination!.name : 'Selected Location')
                                    : 'Search & Pick Location on Map',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _destination != null ? darkAccent : Colors.grey.shade700,
                                ),
                              ),
                              if (_destination != null && _destination!.address.isNotEmpty)
                                Text(
                                  _destination!.address,
                                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (_destination != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Lat: ${_destination!.latitude.toStringAsFixed(4)}, Lng: ${_destination!.longitude.toStringAsFixed(4)}',
                                    style: TextStyle(fontSize: 11, color: primaryColor.withValues(alpha: 0.9), fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          _destination != null ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                          color: _destination != null ? primaryColor : Colors.grey.shade500,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Geofence Radius Selection
                Text(
                  'Allowed Geofence Radius',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _radiusOptions.map((r) {
                    final selected = _selectedRadius == r;
                    return ChoiceChip(
                      label: Text('${r}m'),
                      selected: selected,
                      selectedColor: primaryColor,
                      backgroundColor: Colors.grey.shade200,
                      labelStyle: TextStyle(
                        color: selected ? Colors.black : Colors.grey.shade800,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _selectedRadius = r;
                            if (_destination != null) {
                              _destination = SelectedDestination(
                                name: _destination!.name,
                                address: _destination!.address,
                                latitude: _destination!.latitude,
                                longitude: _destination!.longitude,
                                radius: r,
                              );
                            }
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Additional Notes
                Text(
                  'Notes / Remarks (Optional)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Add instructions or reference info',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _submit,
                      icon: const Icon(Icons.check, size: 18, color: Colors.black),
                      label: Text(
                        widget.existingSite != null ? 'Update Site' : 'Save Site',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
