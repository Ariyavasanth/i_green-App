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
                BomInfoCard(part: part),
                const SizedBox(height: 16),
                const BomImageSection(),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Download PDF'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
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

class BomImageSection extends StatelessWidget {
  const BomImageSection({super.key});

  @override
  Widget build(BuildContext context) => Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('BOM Image', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_outlined, size: 48),
                SizedBox(height: 8),
                Text('Image placeholder'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class BomInfoCard extends StatelessWidget {
  const BomInfoCard({required this.part, super.key});

  final _BomPart part;

  @override
  Widget build(BuildContext context) => Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BomInfoRow(label: 'Sl. No.', value: part.serialNumber),
          BomInfoRow(label: 'Part Name', value: part.name),
          BomInfoRow(label: 'Part No.', value: part.partNumber),
          BomInfoRow(label: 'RM Grade', value: part.rmGrade),
          BomInfoRow(label: 'RM Size', value: part.rmSize),
          BomInfoRow(label: 'RM Weight', value: part.rmWeight),
          BomInfoRow(label: 'FG Weight', value: part.fgWeight),
          BomInfoRow(label: 'Quantity', value: part.quantity),
        ],
      ),
    ),
  );
}

class BomInfoRow extends StatelessWidget {
  const BomInfoRow({required this.label, required this.value, super.key});
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
  'Bearing Shaft': _BomPart('2', 'Bearing Shaft', 'IG-PS-3.5-BRS', 'EN8',
      'Dia 76 × 185L', '8 kg', '5 kg', '1'),
  'Bearing Housing': _BomPart('3', 'Bearing Housing', 'IG-PS-3.5-BRH', 'EN8',
      'Dia 89 × 135L', '15 kg', '8 kg', '1'),
  'Oil Seal': _BomPart('3', 'Oil Seal', 'IG-PS-3.5-OS', 'NBR',
      '50 x 72 x 10', '0.2kg', '0.2kg', '1'),
  'Bearing': _BomPart('4', 'Bearing', 'IG-PS-3.5-BR', 'Bearing Steel',
      '50 x 90 x 20', '0.8kg', '0.8kg', '1'),
  'Lock Nut': _BomPart('1', 'Lock Nut', 'IG-PS-3.5-BRLN', 'EN8',
      'Dia 50 × 25L', '2 kg', '1 kg', '1'),
  'Depth Screw R15': _BomPart('6', 'Depth Screw R15', 'IG-PS-3.5-DSR15',
      'EN8', 'Dia 20 x 45L', '0.3kg', '0.2kg', '1'),
  'Housing Lock Nut': _BomPart('4', 'Housing Lock Nut', 'IG-PS-3.5-HLN',
      'EN8', 'Dia 90 × 140L', '16 kg', '9 kg', '1'),
};
