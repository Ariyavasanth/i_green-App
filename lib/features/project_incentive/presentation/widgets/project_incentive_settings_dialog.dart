import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/project_incentive_settings.dart';
import '../../providers/project_incentive_providers.dart';

class ProjectIncentiveSettingsDialog extends ConsumerStatefulWidget {
  const ProjectIncentiveSettingsDialog({
    super.key,
    required this.initialSettings,
  });

  final ProjectIncentiveSettings initialSettings;

  @override
  ConsumerState<ProjectIncentiveSettingsDialog> createState() =>
      _ProjectIncentiveSettingsDialogState();
}

class _ProjectIncentiveSettingsDialogState
    extends ConsumerState<ProjectIncentiveSettingsDialog> {
  late final TextEditingController _baseRateCtrl;
  late final TextEditingController _timelyBonusCtrl;
  late final TextEditingController _delayPenaltyCtrl;
  late final TextEditingController _minCollectionCtrl;
  late bool _autoDisqualify;
  late bool _trackRestorationSeparate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.initialSettings;
    _baseRateCtrl = TextEditingController(text: s.baseRatePerUnit.toStringAsFixed(1));
    _timelyBonusCtrl = TextEditingController(text: s.timelyBillBonusPercentage.toStringAsFixed(1));
    _delayPenaltyCtrl = TextEditingController(text: s.delayedBillPenaltyPercentage.toStringAsFixed(1));
    _minCollectionCtrl = TextEditingController(text: s.minCollectionThresholdPct.toStringAsFixed(1));
    _autoDisqualify = s.autoDisqualifyOnIncident;
    _trackRestorationSeparate = s.trackRestorationCostSeparately;
  }

  @override
  void dispose() {
    _baseRateCtrl.dispose();
    _timelyBonusCtrl.dispose();
    _delayPenaltyCtrl.dispose();
    _minCollectionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final newSettings = widget.initialSettings.copyWith(
        baseRatePerUnit: double.tryParse(_baseRateCtrl.text) ?? 50.0,
        timelyBillBonusPercentage: double.tryParse(_timelyBonusCtrl.text) ?? 10.0,
        delayedBillPenaltyPercentage: double.tryParse(_delayPenaltyCtrl.text) ?? 15.0,
        minCollectionThresholdPct: double.tryParse(_minCollectionCtrl.text) ?? 80.0,
        autoDisqualifyOnIncident: _autoDisqualify,
        trackRestorationCostSeparately: _trackRestorationSeparate,
      );

      final repo = ref.read(projectIncentiveRepositoryProvider);
      await repo.updateSettings(newSettings);
      await repo.recalculateAllIncentives();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incentive engine settings updated and recalculated!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFF414A51),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.settings_suggest_rounded, color: Color(0xFF9CC70A), size: 22),
                    const SizedBox(width: 12),
                    const Text(
                      'INCENTIVE ENGINE RULES',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Base rate per unit
                    _buildNumberField(
                      label: 'Base Rate per Unit Done (₹/metre)',
                      controller: _baseRateCtrl,
                      hint: '50.0',
                      icon: Icons.speed_rounded,
                    ),
                    const SizedBox(height: 14),

                    // Timely bill bonus %
                    _buildNumberField(
                      label: 'Timely Bill Submission Bonus (%)',
                      controller: _timelyBonusCtrl,
                      hint: '10.0',
                      icon: Icons.receipt_long_rounded,
                    ),
                    const SizedBox(height: 14),

                    // Delayed bill penalty %
                    _buildNumberField(
                      label: 'Delayed Bill Penalty (%)',
                      controller: _delayPenaltyCtrl,
                      hint: '15.0',
                      icon: Icons.timer_off_outlined,
                    ),
                    const SizedBox(height: 14),

                    // Min collection threshold %
                    _buildNumberField(
                      label: 'Min Payment Collection Threshold (%)',
                      controller: _minCollectionCtrl,
                      hint: '80.0',
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFE5E8E2)),
                    const SizedBox(height: 12),

                    // Auto disqualify switch
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _autoDisqualify,
                      activeColor: const Color(0xFF9CC70A),
                      activeTrackColor: const Color(0xFF414A51),
                      title: const Text(
                        'Auto-Disqualify on Incident',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF414A51)),
                      ),
                      subtitle: const Text(
                        'Automatically forfeits 100% of the incentive if any utility damage or safety accident is logged.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                      onChanged: (val) => setState(() => _autoDisqualify = val),
                    ),
                    const SizedBox(height: 8),

                    // Separate restoration costs switch
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _trackRestorationSeparate,
                      activeColor: const Color(0xFF9CC70A),
                      activeTrackColor: const Color(0xFF414A51),
                      title: const Text(
                        'Track Restoration Costs Separately',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF414A51)),
                      ),
                      subtitle: const Text(
                        'Maintains restoration costs in a dedicated site damage ledger without offsetting negative balances.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                      onChanged: (val) => setState(() => _trackRestorationSeparate = val),
                    ),
                  ],
                ),
              ),

              // Actions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF414A51),
                        foregroundColor: const Color(0xFF9CC70A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF9CC70A)),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Save & Apply Rules'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF414A51),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: const Color(0xFF414A51)),
            hintText: hint,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF414A51), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
