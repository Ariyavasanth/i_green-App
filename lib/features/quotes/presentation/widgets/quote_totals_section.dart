import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

enum TaxAdjustmentType { none, tds, tcs }

/// Preset TDS/TCS rates a user can pick once [TaxAdjustmentType] is not
/// [TaxAdjustmentType.none] — mirrors the common Indian statutory slabs.
const taxAdjustmentRateOptions = <double>[1, 2, 5, 10];

/// The right-aligned totals box under the item table: sub total, discount,
/// TDS/TCS, an optional advance-receive entry, and the bold grand total.
class QuoteTotalsSection extends StatelessWidget {
  const QuoteTotalsSection({
    required this.subTotal,
    required this.taxTotal,
    required this.discountController,
    required this.discountIsPercent,
    required this.onDiscountModeChanged,
    required this.taxAdjustmentType,
    required this.onTaxAdjustmentTypeChanged,
    required this.taxAdjustmentRate,
    required this.onTaxAdjustmentRateChanged,
    required this.advanceReceiveEnabled,
    required this.onAdvanceReceiveToggled,
    required this.advanceAmountController,
    required this.onChanged,
    this.compact = false,
    super.key,
  });

  final double subTotal;
  final double taxTotal;
  final TextEditingController discountController;
  final bool discountIsPercent;
  final ValueChanged<bool> onDiscountModeChanged;
  final TaxAdjustmentType taxAdjustmentType;
  final ValueChanged<TaxAdjustmentType> onTaxAdjustmentTypeChanged;
  final double taxAdjustmentRate;
  final ValueChanged<double> onTaxAdjustmentRateChanged;
  final bool advanceReceiveEnabled;
  final ValueChanged<bool> onAdvanceReceiveToggled;
  final TextEditingController advanceAmountController;
  final VoidCallback onChanged;

  /// Tighter padding/gaps used on mobile so the totals card takes less
  /// vertical space; desktop always passes the default `false`.
  final bool compact;

  double get _discountValue => double.tryParse(discountController.text) ?? 0;
  double get discountAmount => discountIsPercent ? subTotal * _discountValue / 100 : _discountValue;
  double get taxAdjustmentAmount =>
      taxAdjustmentType == TaxAdjustmentType.none ? 0 : (subTotal - discountAmount) * taxAdjustmentRate / 100;
  double get total => (subTotal - discountAmount + taxTotal - taxAdjustmentAmount).clamp(0, double.infinity);

  @override
  Widget build(BuildContext context) {
    final gap = SizedBox(height: compact ? 8 : 12);
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _row('Sub Total', '₹${subTotal.toStringAsFixed(2)}'),
          gap,
          _discountRow(),
          if (taxTotal > 0) ...[gap, _row('Tax', '₹${taxTotal.toStringAsFixed(2)}')],
          gap,
          _taxAdjustmentRow(),
          gap,
          _advanceReceiveRow(),
          Padding(padding: EdgeInsets.symmetric(vertical: compact ? 8 : 12), child: const Divider(height: 1)),
          Row(
            children: [
              const Text('Total (₹)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const Spacer(),
              Text(
                '₹${total.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.textPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Row(
    children: [
      Text(label),
      const Spacer(),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
    ],
  );

  Widget _discountRow() => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      const Text('Discount'),
      const Spacer(),
      SizedBox(
        width: 96,
        child: TextField(
          controller: discountController,
          textAlign: TextAlign.right,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => onChanged(),
          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
        ),
      ),
      const SizedBox(width: 8),
      _ModeToggle(
        isPercent: discountIsPercent,
        onChanged: (isPercent) {
          onDiscountModeChanged(isPercent);
          onChanged();
        },
      ),
    ],
  );

  Widget _taxAdjustmentRow() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SegmentedButton<TaxAdjustmentType>(
        segments: const [
          ButtonSegment(value: TaxAdjustmentType.none, label: Text('None')),
          ButtonSegment(value: TaxAdjustmentType.tds, label: Text('TDS')),
          ButtonSegment(value: TaxAdjustmentType.tcs, label: Text('TCS')),
        ],
        selected: {taxAdjustmentType},
        onSelectionChanged: (values) {
          onTaxAdjustmentTypeChanged(values.first);
          onChanged();
        },
      ),
      if (taxAdjustmentType != TaxAdjustmentType.none) ...[
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<double>(
                initialValue: taxAdjustmentRateOptions.contains(taxAdjustmentRate) ? taxAdjustmentRate : taxAdjustmentRateOptions.first,
                isDense: true,
                decoration: const InputDecoration(labelText: 'Select a Tax', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                items: taxAdjustmentRateOptions
                    .map((rate) => DropdownMenuItem(value: rate, child: Text('${taxAdjustmentType == TaxAdjustmentType.tds ? 'TDS' : 'TCS'} @ ${rate.toStringAsFixed(0)}%')))
                    .toList(),
                onChanged: (value) {
                  onTaxAdjustmentRateChanged(value ?? taxAdjustmentRateOptions.first);
                  onChanged();
                },
              ),
            ),
            const SizedBox(width: 12),
            Text('- ₹${taxAdjustmentAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.redAccent)),
          ],
        ),
      ],
    ],
  );

  Widget _advanceReceiveRow() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Expanded(
            child: Row(
              children: [
                Text('Advance Receive'),
                SizedBox(width: 4),
                Tooltip(
                  message: 'Record an advance payment received for this quote. It is tracked separately and does not reduce the total below.',
                  child: Icon(Icons.info_outline, size: 15, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: advanceReceiveEnabled,
            onChanged: (value) {
              onAdvanceReceiveToggled(value);
              onChanged();
            },
          ),
        ],
      ),
      if (advanceReceiveEnabled)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: TextField(
            controller: advanceAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(labelText: 'Amount Received', prefixText: '₹ ', isDense: true),
          ),
        ),
    ],
  );
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.isPercent, required this.onChanged});
  final bool isPercent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(border: Border.all(color: AppColors.divider), borderRadius: BorderRadius.circular(8)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _segment('%', isPercent, () => onChanged(true)),
        _segment('₹', !isPercent, () => onChanged(false)),
      ],
    ),
  );

  Widget _segment(String label, bool selected, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: selected ? AppColors.active : Colors.transparent, borderRadius: BorderRadius.circular(7)),
      child: Text(label, style: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
    ),
  );
}
