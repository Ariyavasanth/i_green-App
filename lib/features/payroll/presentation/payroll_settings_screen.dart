import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../domain/payroll.dart';
import '../providers/payroll_providers.dart';
import '../../leave/providers/leave_providers.dart';

class PayrollSettingsScreen extends ConsumerStatefulWidget {
  const PayrollSettingsScreen({super.key});

  @override
  ConsumerState<PayrollSettingsScreen> createState() => _PayrollSettingsScreenState();
}

class _PayrollSettingsScreenState extends ConsumerState<PayrollSettingsScreen> {
  final _allowedLateController = TextEditingController();
  final _penaltyController = TextEditingController();
  final _workingDaysController = TextEditingController();

  final _startDayController = TextEditingController();
  final _endDayController = TextEditingController();
  final _processingDayController = TextEditingController();
  final _paymentController = TextEditingController();

  bool _initialized = false;

  @override
  void dispose() {
    _allowedLateController.dispose();
    _penaltyController.dispose();
    _workingDaysController.dispose();
    _startDayController.dispose();
    _endDayController.dispose();
    _processingDayController.dispose();
    _paymentController.dispose();
    super.dispose();
  }

  void _initializeValues(PayrollSettings settings) {
    if (_initialized) return;
    _initialized = true;

    _allowedLateController.text = settings.allowedLateDays.toString();
    _penaltyController.text = settings.penaltyPerLateDay.toStringAsFixed(1);
    _workingDaysController.text = settings.workingDaysInMonth.toStringAsFixed(1);

    _startDayController.text = settings.payrollStartDay.toString();
    _endDayController.text = settings.payrollEndDay.toString();
    _processingDayController.text = settings.processingDay.toString();
    _paymentController.text = settings.paymentDay.toString();
  }

  Future<void> _saveSettings() async {
    final settings = PayrollSettings(
      id: 1,
      allowedLateDays: int.tryParse(_allowedLateController.text) ?? 3,
      penaltyPerLateDay: double.tryParse(_penaltyController.text) ?? 0.5,
      workingDaysInMonth: double.tryParse(_workingDaysController.text) ?? 30.0,
      payrollStartDay: int.tryParse(_startDayController.text) ?? 20,
      payrollEndDay: int.tryParse(_endDayController.text) ?? 20,
      processingDay: int.tryParse(_processingDayController.text) ?? 21,
      paymentDay: int.tryParse(_paymentController.text) ?? 21,
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
      backgroundColor: AppColors.canvas,
      body: settingsAsync.when(
        data: (settings) {
          _initializeValues(settings);

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWideDesktop = constraints.maxWidth >= AppBreakpoints.desktop;
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

                      // Grouped Settings Sections (3 Cards: Payroll Rules, Attendance Rules, Payment Schedule)
                      if (!isWideDesktop) ...[
                        _buildPayrollRulesCard(),
                        const SizedBox(height: 16),
                        _buildAttendanceRulesCard(),
                        const SizedBox(height: 16),
                        _buildPaymentScheduleCard(),
                      ] else ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildPayrollRulesCard()),
                            const SizedBox(width: 16),
                            Expanded(child: _buildAttendanceRulesCard()),
                            const SizedBox(width: 16),
                            Expanded(child: _buildPaymentScheduleCard()),
                          ],
                        ),
                      ],
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
          'Configure company payroll schedules and attendance rules',
          style: AppTextStyles.caption,
        ),
      ],
    );
  }

  Widget _buildPayrollRulesCard() {
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
                Icon(Icons.rule_folder_outlined, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Payroll Rules',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInputField(
              'Payroll Cycle Start Date',
              _startDayController,
              isInt: true,
              helperText: 'Example: 21st of the previous month.',
            ),
            const SizedBox(height: 16),
            _buildInputField(
              'Payroll Cycle End Date',
              _endDayController,
              isInt: true,
              helperText: 'Example: 20th of the current month.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text(
                        'Active Period Calculation Example:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'For August 2026 Payroll:\n'
                    '• Attendance Period: ${_startDayController.text.isEmpty ? "21" : _startDayController.text} July 2026 – ${_endDayController.text.isEmpty ? "20" : _endDayController.text} August 2026\n'
                    '• HR Processing: ${_processingDayController.text.isEmpty ? "21" : _processingDayController.text} August 2026\n'
                    '• Salary Disbursement: ${_paymentController.text.isEmpty ? "21" : _paymentController.text} August 2026',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
            _buildInputField(
              'Allowed Late Days (Grace Period)',
              _allowedLateController,
              isInt: true,
              helperText: 'Maximum permitted late check-ins per month.',
            ),
            const SizedBox(height: 16),
            _buildInputField(
              'Penalty per Late Day',
              _penaltyController,
              helperText: 'Salary days deducted per excess late day.',
            ),
            const SizedBox(height: 16),
            _buildInputField(
              'Working Days in Month',
              _workingDaysController,
              helperText: 'Standard billable working days per month.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentScheduleCard() {
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
                Icon(Icons.schedule_outlined, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Payment Schedule',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInputField(
              'HR Processing Day',
              _processingDayController,
              isInt: true,
              helperText: 'Example: 21st of the following month.',
            ),
            const SizedBox(height: 16),
            _buildInputField(
              'Salary Payment Day',
              _paymentController,
              isInt: true,
              helperText: 'Example: 21st of the following month.',
            ),
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
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textPrimary),
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
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}
