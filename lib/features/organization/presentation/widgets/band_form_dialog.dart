import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_searchable_dropdown.dart';
import '../../domain/organization_band.dart';
import '../../providers/organization_providers.dart';

class BandFormDialog extends ConsumerStatefulWidget {
  const BandFormDialog({
    this.band,
    this.initialOrganizationId,
    this.initialOrganizationName,
    super.key,
  });

  final OrganizationBand? band;
  final String? initialOrganizationId;
  final String? initialOrganizationName;

  static Future<bool?> show(
    BuildContext context, {
    OrganizationBand? band,
    String? initialOrganizationId,
    String? initialOrganizationName,
  }) {
    final isMobile =
        MediaQuery.of(context).size.width < 640 ||
        MediaQuery.of(context).size.height < 700;
    if (isMobile) {
      return showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: BandFormDialog(
            band: band,
            initialOrganizationId: initialOrganizationId,
            initialOrganizationName: initialOrganizationName,
          ),
        ),
      );
    } else {
      return showDialog<bool>(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            width: 520,
            child: BandFormDialog(
              band: band,
              initialOrganizationId: initialOrganizationId,
              initialOrganizationName: initialOrganizationName,
            ),
          ),
        ),
      );
    }
  }

  @override
  ConsumerState<BandFormDialog> createState() => _BandFormDialogState();
}

class _BandFormDialogState extends ConsumerState<BandFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _codeController;
  late final TextEditingController _titleController;
  late final TextEditingController _descController;

  String? _selectedOrgId;
  String? _selectedOrgName;
  int _selectedLevel = 7;
  int? _selectedColorHex;
  bool _isSaving = false;

  static const List<int> _colorPalette = [
    0xFF9CC70A, // Primary Green
    0xFF414A51, // Slate Grey
    0xFF2563EB, // Blue
    0xFF7C3AED, // Purple
    0xFFD97706, // Amber
    0xFF059669, // Emerald
    0xFFDC2626, // Red
    0xFF0891B2, // Cyan
  ];

  static const Map<int, String> _levelDescriptions = {
    7: 'Level 7 — Top Leadership (e.g. Managing Director / C-Suite)',
    6: 'Level 6 — Senior Leadership (e.g. Director / Head of Department)',
    5: 'Level 5 — Senior Management (e.g. Senior Manager / Lead)',
    4: 'Level 4 — Middle Management / Specialist (e.g. Manager)',
    3: 'Level 3 — Senior Professional / Associate (e.g. Senior Engineer)',
    2: 'Level 2 — Operational / Associate (e.g. Executive / Officer)',
    1: 'Level 1 — Entry Level / Trainee (e.g. Junior / Intern)',
  };

  @override
  void initState() {
    super.initState();
    final b = widget.band;
    _codeController = TextEditingController(text: b?.bandCode ?? 'Band 7');
    _titleController = TextEditingController(text: b?.title ?? '');
    _descController = TextEditingController(text: b?.description ?? '');
    _selectedLevel = b?.level ?? 7;
    _selectedColorHex = b?.colorHex ?? _colorPalette.first;
    _selectedOrgId = b?.organizationId ?? widget.initialOrganizationId;
    _selectedOrgName = b?.organizationName ?? widget.initialOrganizationName;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _onLevelChanged(int? newLevel) {
    if (newLevel == null) return;
    final oldDefaultCode = 'Band $_selectedLevel';
    setState(() {
      _selectedLevel = newLevel;
      // Auto-update code if the user hasn't typed a custom code
      if (_codeController.text.trim().isEmpty ||
          _codeController.text.trim() == oldDefaultCode) {
        _codeController.text = 'Band $newLevel';
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedOrgId == null || _selectedOrgId!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an Organization.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(organizationRepositoryProvider);
      final isEdit = widget.band != null;

      final bandItem = OrganizationBand(
        id: widget.band?.id ?? '',
        organizationId: _selectedOrgId!.trim(),
        organizationName: _selectedOrgName?.trim() ?? '',
        level: _selectedLevel,
        bandCode: _codeController.text.trim(),
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        colorHex: _selectedColorHex,
        designationCount: widget.band?.designationCount ?? 0,
      );

      if (isEdit) {
        await repo.updateBand(bandItem);
      } else {
        await repo.addBand(bandItem);
      }

      ref.invalidate(organizationBandsProvider);
      ref.invalidate(filteredBandsProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ArgumentError
                  ? e.message.toString()
                  : 'Error saving Band: $e',
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.band != null;
    final orgsAsync = ref.watch(organizationsProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.layers_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEdit
                          ? 'Edit Organization Band'
                          : 'Add Organization Band',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 20,
                    color: Color(0xFF667085),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEAECF0)),

          // Form Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Organization Selector
                    orgsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (err, _) => Text(
                        'Error loading organizations: $err',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                      data: (orgs) {
                        if (_selectedOrgId == null && orgs.isNotEmpty) {
                          _selectedOrgId = orgs.first.canonicalId;
                          _selectedOrgName = orgs.first.name;
                        }

                        final orgNames = orgs.map((o) => o.name).toList();
                        final currentOrgName =
                            orgs
                                .where((o) => o.canonicalId == _selectedOrgId)
                                .firstOrNull
                                ?.name ??
                            _selectedOrgName;

                        return AppSearchableDropdown<String>(
                          label: 'Organization *',
                          value: currentOrgName,
                          items: orgNames,
                          placeholder: 'Select Organization',
                          searchHint: 'Search organization...',
                          enabled: !isEdit,
                          onChanged: (val) {
                            if (!isEdit && val != null) {
                              final match = orgs
                                  .where((o) => o.name == val)
                                  .firstOrNull;
                              setState(() {
                                _selectedOrgId = match?.canonicalId;
                                _selectedOrgName = match?.name;
                              });
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Band Level (1 - 7)
                    const Text(
                      'Band Level *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF344054),
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedLevel,
                      isExpanded: true,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFD0D5DD),
                          ),
                        ),
                      ),
                      items: [7, 6, 5, 4, 3, 2, 1].map((lvl) {
                        return DropdownMenuItem<int>(
                          value: lvl,
                          child: Text(
                            _levelDescriptions[lvl] ?? 'Level $lvl',
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: _onLevelChanged,
                    ),
                    const SizedBox(height: 16),

                    // Band Code
                    const Text(
                      'Band Code *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF344054),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _codeController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'e.g. Band 7, Band 6',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFD0D5DD),
                          ),
                        ),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Band code is required'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Designation Dropdown (Only created designations)
                    Builder(
                      builder: (context) {
                        final desigsAsync = ref.watch(allDesignationsProvider);
                        final allDesigs = desigsAsync.valueOrNull ?? [];
                        final orgDesigs = allDesigs.where((d) {
                          if (_selectedOrgId != null &&
                              _selectedOrgId!.isNotEmpty &&
                              d.organizationId.isNotEmpty) {
                            return d.organizationId == _selectedOrgId;
                          }
                          if (_selectedOrgName != null &&
                              _selectedOrgName!.isNotEmpty &&
                              d.organizationName.isNotEmpty) {
                            return d.organizationName.toLowerCase() ==
                                _selectedOrgName!.toLowerCase();
                          }
                          return true;
                        }).toList();

                        // Only actual designations created in the organization
                        final desigItems = orgDesigs
                            .map((d) => d.designationName.trim())
                            .where((name) => name.isNotEmpty)
                            .toSet()
                            .toList();

                        desigItems.sort(
                          (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
                        );

                        final currentTitle = _titleController.text.trim();
                        final selectedValue = currentTitle.isNotEmpty &&
                                desigItems.contains(currentTitle)
                            ? currentTitle
                            : null;

                        return AppSearchableDropdown<String>(
                          label: 'Designation *',
                          value: selectedValue,
                          items: desigItems,
                          placeholder: desigItems.isEmpty
                              ? 'No designations available'
                              : 'Select Designation',
                          searchHint: 'Search designation...',
                          isRequired: true,
                          validator: (v) {
                            if (_titleController.text.trim().isEmpty) {
                              return 'Designation is required';
                            }
                            return null;
                          },
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _titleController.text = val);
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description (Optional)
                    const Text(
                      'Description (Optional)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF344054),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descController,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText:
                            'Key responsibilities, seniority expectations, or organizational scope',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFD0D5DD),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Color Accent Picker
                    const Text(
                      'Band Color Accent',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF344054),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _colorPalette.map((hex) {
                        final isSelected = _selectedColorHex == hex;
                        return InkWell(
                          onTap: () => setState(() => _selectedColorHex = hex),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Color(hex),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.black
                                    : Colors.transparent,
                                width: 2,
                              ),
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(
                                    color: Color(hex).withValues(alpha: 0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                              ],
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Divider(height: 1, color: Color(0xFFEAECF0)),

          // Bottom Action Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF344054),
                    side: const BorderSide(color: Color(0xFFD0D5DD)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                  ),
                  onPressed: _isSaving
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 10,
                    ),
                  ),
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isEdit ? 'Save Changes' : 'Create Band',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
