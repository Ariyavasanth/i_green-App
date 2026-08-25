import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../domain/payroll.dart';
import '../providers/payroll_providers.dart';
import '../../leave/providers/leave_providers.dart';
import 'widgets/access_denied_view.dart';

class PayrollSettingsScreen extends ConsumerStatefulWidget {
  const PayrollSettingsScreen({super.key});

  @override
  ConsumerState<PayrollSettingsScreen> createState() => _PayrollSettingsScreenState();
}

class _PayrollSettingsScreenState extends ConsumerState<PayrollSettingsScreen> {
  final _allowedLateController = TextEditingController();
  final _penaltyController = TextEditingController();
  final _workingDaysController = TextEditingController();

  final _pfPercentController = TextEditingController();
  final _taxPercentController = TextEditingController();
  final _profTaxPercentController = TextEditingController();

  final _cutoffController = TextEditingController();
  final _paymentController = TextEditingController();

  bool _initialized = false;

  @override
  void dispose() {
    _allowedLateController.dispose();
    _penaltyController.dispose();
    _workingDaysController.dispose();
    _pfPercentController.dispose();
    _taxPercentController.dispose();
    _profTaxPercentController.dispose();
    _cutoffController.dispose();
    _paymentController.dispose();
    super.dispose();
  }

  void _initializeValues(PayrollSettings settings) {
    if (_initialized) return;
    _initialized = true;

    _allowedLateController.text = settings.allowedLateDays.toString();
    _penaltyController.text = settings.penaltyPerLateDay.toStringAsFixed(1);
    _workingDaysController.text = settings.workingDaysInMonth.toStringAsFixed(1);

    _pfPercentController.text = settings.pfPercentage.toStringAsFixed(1);
    _taxPercentController.text = settings.taxPercentage.toStringAsFixed(1);
    _profTaxPercentController.text = settings.professionalTaxPercentage.toStringAsFixed(1);

    _cutoffController.text = settings.payrollCutoffDay.toString();
    _paymentController.text = settings.paymentDay.toString();
  }

  Future<void> _saveSettings() async {
    final settings = PayrollSettings(
      id: 1,
      allowedLateDays: int.tryParse(_allowedLateController.text) ?? 3,
      penaltyPerLateDay: double.tryParse(_penaltyController.text) ?? 0.5,
      workingDaysInMonth: double.tryParse(_workingDaysController.text) ?? 30.0,
      pfPercentage: double.tryParse(_pfPercentController.text) ?? 12.0,
      taxPercentage: double.tryParse(_taxPercentController.text) ?? 10.0,
      professionalTaxPercentage: double.tryParse(_profTaxPercentController.text) ?? 2.0,
      payrollCutoffDay: int.tryParse(_cutoffController.text) ?? 20,
      paymentDay: int.tryParse(_paymentController.text) ?? 5,
    );

    try {
      await ref.read(payrollRepositoryProvider).savePayrollSettings(settings);
      ref.invalidate(payrollSettingsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Payroll settings updated successfully!'),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(payrollSettingsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: settingsAsync.when(
        data: (settings) {
          _initializeValues(settings);

          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < AppBreakpoints.tablet;
              final gutter = AppLayout.gutter(constraints.maxWidth);

              return SingleChildScrollView(
                padding: EdgeInsets.all(gutter),
                child: ResponsiveContent(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      _buildHeader(),
                      const SizedBox(height: 24),

                      // Responsive card structure
                      isMobile
                          ? Column(
                              children: [
                                _buildAttendanceRulesCard(),
                                const SizedBox(height: 16),
                                _buildStatutoryCard(),
                                const SizedBox(height: 16),
                                _buildPaymentDatesCard(),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      _buildAttendanceRulesCard(),
                                      const SizedBox(height: 16),
                                      _buildPaymentDatesCard(),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildStatutoryCard(),
                                ),
                              ],
                            ),
                      const SizedBox(height: 32),

                      // Action Button
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: _saveSettings,
                          icon: const Icon(Icons.save_outlined, size: 18),
                          label: const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.orange),
                const SizedBox(height: 16),
                const Text(
                  'Unable to connect to server',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Check your internet connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(payrollSettingsProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payroll Settings', style: AppTextStyles.pageTitle),
        const SizedBox(height: 4),
        const Text(
          'Configure statutory values, payment schedules, and attendance rules',
          style: AppTextStyles.caption,
        ),
      ],
    );
  }

  Widget _buildAttendanceRulesCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.calendar_month_outlined, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Attendance Rules',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInputField('Allowed Late Days (Grace Period)', _allowedLateController, isInt: true),
            const SizedBox(height: 12),
            _buildInputField('Penalty per Late Day (Salary Days Deducted)', _penaltyController),
            const SizedBox(height: 12),
            _buildInputField('Working Days in Month', _workingDaysController),
          ],
        ),
      ),
    );
  }

  Widget _buildStatutoryCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.percent_outlined, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Statutory Contributions (%)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInputField('Provident Fund (PF) Rate', _pfPercentController, suffix: '%'),
            const SizedBox(height: 12),
            _buildInputField('TDS / Income Tax Rate', _taxPercentController, suffix: '%'),
            const SizedBox(height: 12),
            _buildInputField('Professional Tax Rate', _profTaxPercentController, suffix: '%'),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDatesCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.payment_outlined, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Payment Dates',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInputField('Payroll Cutoff Day of Month (e.g. 20th)', _cutoffController, isInt: true),
            const SizedBox(height: 12),
            _buildInputField('Salary Payment Day of Month (e.g. 5th)', _paymentController, isInt: true),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller, {
    bool isInt = false,
    String? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: !isInt),
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            suffixText: suffix,
            suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}
