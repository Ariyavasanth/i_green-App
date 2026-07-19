import 'package:flutter/material.dart';

import '../../core/layout/responsive_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Whether an operation is performed in-house or sent to a vendor.
enum ProcessRemarks {
  inhouse('Inhouse'),
  outsourcing('Outsourcing');

  const ProcessRemarks(this.label);
  final String label;
}

/// A single sequential step (e.g. "Operation 1", "Operation 2", ...) in a
/// part's manufacturing process flow.
class ProcessFlowOperation {
  const ProcessFlowOperation({
    required this.operationNumber,
    required this.operationName,
    required this.machine,
    required this.remarks,
    required this.duration,
    this.vendor,
  });

  final int operationNumber;
  final String operationName;
  final String machine;
  final ProcessRemarks remarks;
  final String duration;

  /// Only meaningful (and only ever shown) when [remarks] is
  /// [ProcessRemarks.outsourcing].
  final String? vendor;
}

/// Mock process-flow data keyed by the same part identifier used by
/// [BomDetailsScreen]/`_bomParts`. A part with no entry here (or an empty
/// list) has no process flow to show.
const processFlowByPart = <String, List<ProcessFlowOperation>>{
  'Shaft': [
    ProcessFlowOperation(
      operationNumber: 1,
      operationName: 'Turning',
      machine: 'CNC Lathe',
      remarks: ProcessRemarks.inhouse,
      duration: '45 min',
    ),
    ProcessFlowOperation(
      operationNumber: 2,
      operationName: 'Grinding',
      machine: 'Cylindrical Grinder',
      remarks: ProcessRemarks.inhouse,
      duration: '30 min',
    ),
    ProcessFlowOperation(
      operationNumber: 3,
      operationName: 'Heat Treatment',
      machine: 'Induction Hardening Unit',
      remarks: ProcessRemarks.outsourcing,
      duration: '2 hr',
      vendor: 'Precision Heat Treaters Pvt Ltd',
    ),
  ],
  'Bearing Housing': [
    ProcessFlowOperation(
      operationNumber: 1,
      operationName: 'Turning',
      machine: 'CNC',
      remarks: ProcessRemarks.inhouse,
      duration: '90 mins',
    ),
    ProcessFlowOperation(
      operationNumber: 2,
      operationName: 'Hardening 30-32 HRC',
      machine: 'Electric Furnace',
      remarks: ProcessRemarks.outsourcing,
      duration: '24 hrs',
      vendor: 'Immanuvel Heat treatment',
    ),
    ProcessFlowOperation(
      operationNumber: 3,
      operationName: 'Descaling',
      machine: 'Manual',
      remarks: ProcessRemarks.inhouse,
      duration: '15 mins',
    ),
    ProcessFlowOperation(
      operationNumber: 4,
      operationName: 'ID Grinding',
      machine: 'Grinding',
      remarks: ProcessRemarks.outsourcing,
      duration: '60 mins',
      vendor: 'Ambika Gringing works',
    ),
    ProcessFlowOperation(
      operationNumber: 5,
      operationName: 'QC',
      machine: 'Manual',
      remarks: ProcessRemarks.inhouse,
      duration: '15 mins',
    ),
  ],
  'Depth Screw R15': [
    ProcessFlowOperation(
      operationNumber: 1,
      operationName: 'Turning',
      machine: 'CNC Lathe',
      remarks: ProcessRemarks.inhouse,
      duration: '20 min',
    ),
    ProcessFlowOperation(
      operationNumber: 2,
      operationName: 'Thread Rolling',
      machine: 'Thread Rolling Machine',
      remarks: ProcessRemarks.outsourcing,
      duration: '35 min',
      vendor: 'Apex Threading Works',
    ),
  ],
};

/// Displays the sequential process-flow operations for a single BOM part.
class ProcessFlowScreen extends StatelessWidget {
  const ProcessFlowScreen({
    required this.partIdentifier,
    required this.partName,
    super.key,
  });

  final String partIdentifier;
  final String partName;

  @override
  Widget build(BuildContext context) {
    final operations = processFlowByPart[partIdentifier] ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Process Flow'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: EdgeInsets.all(AppLayout.gutter(constraints.maxWidth)),
          child: ResponsiveContent(
            maxWidth: AppLayout.maxFormWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(partName, style: AppTextStyles.pageTitle),
                const SizedBox(height: 4),
                Text(
                  '${operations.length} operation'
                  '${operations.length == 1 ? '' : 's'}',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 20),
                for (final operation in operations) ...[
                  _ProcessFlowCard(operation: operation),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProcessFlowCard extends StatelessWidget {
  const _ProcessFlowCard({required this.operation});

  final ProcessFlowOperation operation;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Operation ${operation.operationNumber}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _ProcessFlowRow(
              label: 'Operation Name',
              value: operation.operationName,
            ),
            _ProcessFlowRow(label: 'Machine', value: operation.machine),
            _ProcessFlowRow(label: 'Duration', value: operation.duration),
            _ProcessFlowRow(label: 'Remarks', value: operation.remarks.label),
            _ProcessFlowRow(label: 'Vendor', value: operation.vendor ?? '-'),
          ],
        ),
      ),
    );
  }
}

class _ProcessFlowRow extends StatelessWidget {
  const _ProcessFlowRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 120, child: Text(label, style: AppTextStyles.caption)),
        const SizedBox(width: 12),
        Expanded(child: Text(value, style: AppTextStyles.body)),
      ],
    ),
  );
}
