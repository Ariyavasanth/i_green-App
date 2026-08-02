import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/salary_settings.dart';
import '../providers/salary_settings_providers.dart';

class SalarySettingsPage extends ConsumerStatefulWidget {
  const SalarySettingsPage({super.key});

  @override
  ConsumerState<SalarySettingsPage> createState() => _SalarySettingsPageState();
}

class _SalarySettingsPageState extends ConsumerState<SalarySettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _hraController = TextEditingController();
  final _specialAllowanceController = TextEditingController();
  final _eduAllowanceController = TextEditingController();
  final _travelAllowanceController = TextEditingController();
  final _pfController = TextEditingController();
  final _taxController = TextEditingController();
  final _profTaxController = TextEditingController();

  bool _isSaving = false;
  SalarySettings? _loadedSettings;

  @override
  void dispose() {
    _hraController.dispose();
    _specialAllowanceController.dispose();
    _eduAllowanceController.dispose();
    _travelAllowanceController.dispose();
    _pfController.dispose();
    _taxController.dispose();
    _profTaxController.dispose();
    super.dispose();
  }

  void _populateControllers(SalarySettings settings) {
    if (_loadedSettings == settings) return;
    _loadedSettings = settings;
    _hraController.text = settings.hraPercentage.toStringAsFixed(1);
    _specialAllowanceController.text =
        settings.specialAllowancePercentage.toStringAsFixed(1);
    _eduAllowanceController.text =
        settings.educationAllowancePercentage.toStringAsFixed(1);
    _travelAllowanceController.text =
        settings.travelAllowancePercentage.toStringAsFixed(1);
    _pfController.text = settings.pfPercentage.toStringAsFixed(1);
    _taxController.text = settings.taxPercentage.toStringAsFixed(1);
    _profTaxController.text =
        settings.professionalTaxPercentage.toStringAsFixed(1);
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() => _isSaving = true);

    final settings = SalarySettings(
      hraPercentage: double.tryParse(_hraController.text.trim()) ?? 0.0,
      specialAllowancePercentage:
          double.tryParse(_specialAllowanceController.text.trim()) ?? 0.0,
      educationAllowancePercentage:
          double.tryParse(_eduAllowanceController.text.trim()) ?? 0.0,
      travelAllowancePercentage:
          double.tryParse(_travelAllowanceController.text.trim()) ?? 0.0,
      pfPercentage: double.tryParse(_pfController.text.trim()) ?? 0.0,
      taxPercentage: double.tryParse(_taxController.text.trim()) ?? 0.0,
      professionalTaxPercentage:
          double.tryParse(_profTaxController.text.trim()) ?? 0.0,
    );

    final success = await ref
        .read(salarySettingsNotifierProvider.notifier)
        .saveSettings(settings);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Salary structure default percentages saved successfully!'
                : 'Failed to save salary settings. Please try again.',
          ),
          backgroundColor: success ? const Color(0xFF2E7D32) : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(salarySettingsNotifierProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Salary Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFEAECF0), height: 1),
        ),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error loading salary settings: $err'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref
                    .read(salarySettingsNotifierProvider.notifier)
                    .loadSettings(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (settings) {
          _populateControllers(settings);

          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;

              return SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 12 : 24),
                child: Form(
                  key: _formKey,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFFEAECF0)),
                        ),
                        color: Colors.white,
                        child: Padding(
                          padding: EdgeInsets.all(isMobile ? 16 : 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header section
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.active.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.tune_outlined,
                                      color: AppColors.active,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          'Default Salary Structure Percentages',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Set organization defaults for salary components. These auto-fill in employee forms and can be overridden per employee.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              const Divider(color: Color(0xFFEAECF0)),
                              const SizedBox(height: 16),

                              // Info card regarding Basic Pay
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2F4F7),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFD0D5DD),
                                  ),
                                ),
                                child: Row(
                                  children: const [
                                    Icon(
                                      Icons.info_outline,
                                      size: 20,
                                      color: Color(0xFF344054),
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Basic Pay is fixed at 50% of Total Salary across the organization and is not configurable.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF344054),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Section: Allowance Percentages
                              const Text(
                                'Allowances (% of Total Salary)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 14),

                              _buildPercentageGrid(
                                isMobile: isMobile,
                                children: [
                                  _buildPercentageField(
                                    label: 'House Rent Allowance (HRA)',
                                    basis: '% of Total Salary',
                                    controller: _hraController,
                                  ),
                                  _buildPercentageField(
                                    label: 'Special Allowance',
                                    basis: '% of Total Salary',
                                    controller: _specialAllowanceController,
                                  ),
                                  _buildPercentageField(
                                    label: 'Education Allowance',
                                    basis: '% of Total Salary',
                                    controller: _eduAllowanceController,
                                  ),
                                  _buildPercentageField(
                                    label: 'Travel Allowance',
                                    basis: '% of Total Salary',
                                    controller: _travelAllowanceController,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 28),

                              // Section: Deductions & Taxes
                              const Text(
                                'Deductions & Taxes',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 14),

                              _buildPercentageGrid(
                                isMobile: isMobile,
                                children: [
                                  _buildPercentageField(
                                    label: 'Provident Fund (PF)',
                                    basis: '% of Basic',
                                    controller: _pfController,
                                  ),
                                  _buildPercentageField(
                                    label: 'Tax',
                                    basis: '% of Total Salary',
                                    controller: _taxController,
                                  ),
                                  _buildPercentageField(
                                    label: 'Professional Tax',
                                    basis: '% of Total Salary',
                                    controller: _profTaxController,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),

                              // Save Button Action Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.active,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    onPressed: _isSaving ? null : _handleSave,
                                    icon: _isSaving
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.save_outlined,
                                            size: 18),
                                    label: const Text(
                                      'Save Salary Settings',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
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
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPercentageGrid({
    required bool isMobile,
    required List<Widget> children,
  }) {
    if (isMobile) {
      return Column(
        children: children
            .map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: c,
                ))
            .toList(),
      );
    }
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: children
          .map((c) => SizedBox(
                width: 380,
                child: c,
              ))
          .toList(),
    );
  }

  Widget _buildPercentageField({
    required String label,
    required String basis,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                basis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            isDense: true,
            suffixText: '%',
            suffixStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide:
                  const BorderSide(color: Color(0xFFD0D5DD), width: 0.8),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide:
                  const BorderSide(color: Color(0xFFD0D5DD), width: 0.8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide:
                  const BorderSide(color: AppColors.active, width: 1.2),
            ),
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Required';
            }
            final parsed = double.tryParse(val.trim());
            if (parsed == null || parsed < 0 || parsed > 100) {
              return 'Enter valid % (0-100)';
            }
            return null;
          },
        ),
      ],
    );
  }
}
