import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../employee/providers/employee_providers.dart';
import '../../../site_visit_attendance/domain/site_visit_record.dart';
import '../../../site_visit_attendance/providers/site_visit_attendance_providers.dart';
import '../../providers/site_visit_attendance_management_providers.dart';

class AdminManualSiteVisitDialog extends ConsumerStatefulWidget {
  const AdminManualSiteVisitDialog({
    super.key,
    this.existingVisit,
    this.initialEmployeeId,
    this.initialDate,
    required this.onSaved,
  });

  final SiteVisitRecord? existingVisit;
  final int? initialEmployeeId;
  final String? initialDate;
  final VoidCallback onSaved;

  @override
  ConsumerState<AdminManualSiteVisitDialog> createState() => _AdminManualSiteVisitDialogState();
}

class _AdminManualSiteVisitDialogState extends ConsumerState<AdminManualSiteVisitDialog> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedEmployeeId;
  String _selectedEmployeeName = '';
  late TextEditingController _dateController;
  late TextEditingController _timeController;
  late TextEditingController _siteNameController;
  late TextEditingController _addressController;
  late TextEditingController _latController;
  late TextEditingController _lngController;
  late TextEditingController _notesController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final visit = widget.existingVisit;
    _selectedEmployeeId = visit?.employeeId ?? widget.initialEmployeeId;
    _selectedEmployeeName = visit?.employeeName ?? '';
    _dateController = TextEditingController(
      text: visit?.visitDate ?? widget.initialDate ?? DateFormat('dd-MM-yyyy').format(DateTime.now()),
    );
    _timeController = TextEditingController(
      text: visit?.visitTime ?? DateFormat('HH:mm:ss').format(DateTime.now()),
    );
    _siteNameController = TextEditingController(text: visit?.siteName ?? '');
    _addressController = TextEditingController(text: visit?.address ?? '');
    _latController = TextEditingController(text: visit?.latitude != null ? visit!.latitude.toString() : '0.0');
    _lngController = TextEditingController(text: visit?.longitude != null ? visit!.longitude.toString() : '0.0');
    _notesController = TextEditingController(text: visit?.notes ?? '');
  }

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _siteNameController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmployeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an employee.')),
      );
      return;
    }
    setState(() => _saving = true);

    try {
      final repo = ref.read(siteVisitAttendanceRepositoryProvider);
      final record = SiteVisitRecord(
        id: widget.existingVisit?.id ?? 0,
        employeeId: _selectedEmployeeId!,
        employeeName: _selectedEmployeeName,
        siteName: _siteNameController.text.trim(),
        visitDate: _dateController.text.trim(),
        visitTime: _timeController.text.trim(),
        photoUrl: widget.existingVisit?.photoUrl ?? '',
        photoPublicId: widget.existingVisit?.photoPublicId ?? '',
        latitude: double.tryParse(_latController.text.trim()) ?? 0.0,
        longitude: double.tryParse(_lngController.text.trim()) ?? 0.0,
        address: _addressController.text.trim(),
        notes: _notesController.text.trim(),
        createdAt: widget.existingVisit?.createdAt ?? DateTime.now().toIso8601String(),
      );

      await repo.saveVisit(record);
      ref.invalidate(allSiteVisitsProvider);
      ref.invalidate(siteVisitRecordsProvider);
      widget.onSaved();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Site visit record saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving site visit record: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesProvider);
    final isMobile = MediaQuery.of(context).size.width < 500;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 540,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dialog Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add_location_alt_outlined, color: Color(0xFF9CC70A), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.existingVisit != null ? 'Edit Site Visit' : 'Manual Site Visit Entry',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Employee Selection
                employeesAsync.when(
                  loading: () => const LinearProgressIndicator(color: Color(0xFF9CC70A)),
                  error: (e, _) => Text('Error loading employees: $e'),
                  data: (employees) {
                    if (_selectedEmployeeId != null && _selectedEmployeeName.isEmpty) {
                      final match = employees.where((e) => e.id == _selectedEmployeeId).firstOrNull;
                      if (match != null) _selectedEmployeeName = match.name;
                    }
                    return DropdownButtonFormField<int>(
                      value: _selectedEmployeeId,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: 'Select Employee *',
                        prefixIcon: const Icon(Icons.person_outline, size: 20, color: Color(0xFF9CC70A)),
                        filled: true,
                        fillColor: const Color(0xFFFAFAFA),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF9CC70A)),
                        ),
                      ),
                      items: employees.map((emp) {
                        return DropdownMenuItem<int>(
                          value: emp.id,
                          child: Text('${emp.name} (${emp.department ?? 'N/A'})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          final selected = employees.firstWhere((e) => e.id == val);
                          setState(() {
                            _selectedEmployeeId = val;
                            _selectedEmployeeName = selected.name;
                          });
                        }
                      },
                      validator: (val) => val == null ? 'Employee is required' : null,
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Site Name
                TextFormField(
                  controller: _siteNameController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Site Name / Project Location *',
                    prefixIcon: const Icon(Icons.location_city_outlined, size: 20, color: Color(0xFF9CC70A)),
                    filled: true,
                    fillColor: const Color(0xFFFAFAFA),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF9CC70A)),
                    ),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Site name is required' : null,
                ),
                const SizedBox(height: 16),

                // Date & Time Fields
                isMobile
                    ? Column(
                        children: [
                          _buildDateField(),
                          const SizedBox(height: 16),
                          _buildTimeField(),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: _buildDateField()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTimeField()),
                        ],
                      ),
                const SizedBox(height: 16),

                // Address
                TextFormField(
                  controller: _addressController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Full Address / Location Landmark',
                    prefixIcon: const Icon(Icons.map_outlined, size: 20, color: Color(0xFF9CC70A)),
                    filled: true,
                    fillColor: const Color(0xFFFAFAFA),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF9CC70A)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Coordinates (Lat/Lng)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latController,
                        style: const TextStyle(fontSize: 13),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: InputDecoration(
                          labelText: 'Latitude',
                          prefixIcon: const Icon(Icons.my_location, size: 18, color: Color(0xFF9CC70A)),
                          filled: true,
                          fillColor: const Color(0xFFFAFAFA),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF9CC70A)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lngController,
                        style: const TextStyle(fontSize: 13),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: InputDecoration(
                          labelText: 'Longitude',
                          prefixIcon: const Icon(Icons.my_location, size: 18, color: Color(0xFF9CC70A)),
                          filled: true,
                          fillColor: const Color(0xFFFAFAFA),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF9CC70A)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Notes
                TextFormField(
                  controller: _notesController,
                  style: const TextStyle(fontSize: 13),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Visit Purpose / Notes',
                    prefixIcon: const Icon(Icons.notes, size: 20, color: Color(0xFF9CC70A)),
                    filled: true,
                    fillColor: const Color(0xFFFAFAFA),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF9CC70A)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9CC70A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: Text(_saving ? 'Saving...' : 'Save Site Visit', style: const TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildDateField() {
    return TextFormField(
      controller: _dateController,
      readOnly: true,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: 'Visit Date (dd-MM-yyyy) *',
        prefixIcon: const Icon(Icons.calendar_today, size: 18, color: Color(0xFF9CC70A)),
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF9CC70A)),
        ),
      ),
      onTap: () async {
        final parsed = DateFormat('dd-MM-yyyy').tryParse(_dateController.text) ?? DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: parsed,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          _dateController.text = DateFormat('dd-MM-yyyy').format(picked);
        }
      },
      validator: (val) => val == null || val.trim().isEmpty ? 'Date required' : null,
    );
  }

  Widget _buildTimeField() {
    return TextFormField(
      controller: _timeController,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: 'Visit Time (HH:mm:ss) *',
        prefixIcon: const Icon(Icons.access_time, size: 18, color: Color(0xFF9CC70A)),
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF9CC70A)),
        ),
      ),
      onTap: () async {
        final now = TimeOfDay.now();
        final picked = await showTimePicker(context: context, initialTime: now);
        if (picked != null) {
          final hh = picked.hour.toString().padLeft(2, '0');
          final mm = picked.minute.toString().padLeft(2, '0');
          _timeController.text = '$hh:$mm:00';
        }
      },
      validator: (val) => val == null || val.trim().isEmpty ? 'Time required' : null,
    );
  }
}
