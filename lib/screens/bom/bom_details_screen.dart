import 'package:flutter/material.dart';

import '../../core/layout/responsive_layout.dart';
import '../../core/theme/app_text_styles.dart';
import 'process_flow_screen.dart';

/// Displays the BOM record for the single part selected in the exploded view.
class BomDetailsScreen extends StatelessWidget {
  const BomDetailsScreen({required this.partIdentifier, super.key});

  final String partIdentifier;

  @override
  Widget build(BuildContext context) {
    final part = _bomParts[partIdentifier] ?? _BomPart.fallback(partIdentifier);
    final hasProcessFlow =
        processFlowByPart[partIdentifier]?.isNotEmpty ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('BOM Details')),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: EdgeInsets.all(AppLayout.gutter(constraints.maxWidth)),
          child: ResponsiveContent(
            maxWidth: AppLayout.maxFormWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _BomDetailRow(
                            label: 'Sl. No.', value: part.serialNumber),
                        _BomDetailRow(label: 'Part name', value: part.name),
                        _BomDetailRow(
                            label: 'Part no.', value: part.partNumber),
                        _BomDetailRow(label: 'Rm Grade', value: part.rmGrade),
                        _BomDetailRow(label: 'RM size', value: part.rmSize),
                        _BomDetailRow(
                            label: 'RM weight', value: part.rmWeight),
                        _BomDetailRow(
                            label: 'FG Weight', value: part.fgWeight),
                        _BomDetailRow(label: 'Qty', value: part.quantity),
                      ],
                    ),
                  ),
                ),
                if (hasProcessFlow) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProcessFlowScreen(
                          partIdentifier: partIdentifier,
                          partName: part.name,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.account_tree_outlined),
                    label: const Text('View Process Flow'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BomDetailRow extends StatelessWidget {
  const _BomDetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 170, child: Text(label, style: AppTextStyles.caption)),
        const SizedBox(width: 12),
        Expanded(child: Text(value, style: AppTextStyles.body)),
      ],
    ),
  );
}

class _BomPart {
  const _BomPart(this.serialNumber, this.name, this.partNumber, this.rmGrade,
      this.rmSize, this.rmWeight, this.fgWeight, this.quantity);

  factory _BomPart.fallback(String identifier) =>
      _BomPart('-', identifier, '-', '-', '-', '-', '-', '-');

  final String serialNumber;
  final String name;
  final String partNumber;
  final String rmGrade;
  final String rmSize;
  final String rmWeight;
  final String fgWeight;
  final String quantity;
}

const _bomParts = <String, _BomPart>{
  'Shaft': _BomPart('1', 'Shaft', 'IG-PS-3.5-SH', 'EN8',
      'Dia 50 x 250L', '4kg', '3kg', '1'),
  'Bearing Housing': _BomPart('2', 'Bearing Housing', 'IG-PS-3.5-BH', 'EN8',
      'Dia 90 x 60L', '5kg', '3kg', '1'),
  'Oil Seal': _BomPart('3', 'Oil Seal', 'IG-PS-3.5-OS', 'NBR',
      '50 x 72 x 10', '0.2kg', '0.2kg', '1'),
  'Bearing': _BomPart('4', 'Bearing', 'IG-PS-3.5-BR', 'Bearing Steel',
      '50 x 90 x 20', '0.8kg', '0.8kg', '1'),
  'Lock Nut': _BomPart('5', 'Lock nut', 'IG-PS-3.5-BRLN', 'EN8',
      'Dia 50 x 25L', '2kg', '1kg', '1'),
  'Depth Screw R15': _BomPart('6', 'Depth Screw R15', 'IG-PS-3.5-DSR15',
      'EN8', 'Dia 20 x 45L', '0.3kg', '0.2kg', '1'),
  'Housing Lock Nut': _BomPart('7', 'Housing Lock Nut', 'IG-PS-3.5-HLN',
      'EN8', 'Dia 90 x 20L', '1.5kg', '1kg', '1'),
};
