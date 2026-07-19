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

/// Process-flow data keyed by the part identifier passed from BOM Details.
const processFlowByPart = <String, List<ProcessFlowOperation>>{
  'Lock Nut': [
    ProcessFlowOperation(
      operationNumber: 1,
      operationName: 'Turning',
      machine: 'CNC',
      remarks: ProcessRemarks.inhouse,
      duration: '40 mins',
    ),
    ProcessFlowOperation(
      operationNumber: 2,
      operationName: 'Milling',
      machine: 'VMC / Manual Milling',
      remarks: ProcessRemarks.inhouse,
      duration: '30 mins',
    ),
    ProcessFlowOperation(
      operationNumber: 3,
      operationName: 'Hardening (30–32 HRC)',
      machine: 'Electric Furnace',
      remarks: ProcessRemarks.outsourcing,
      duration: '24 hrs',
      vendor: 'Immanuel Heat Treatment',
    ),
    ProcessFlowOperation(
      operationNumber: 4,
      operationName: 'Descaling',
      machine: 'Manual',
      remarks: ProcessRemarks.inhouse,
      duration: '15 mins',
    ),
    ProcessFlowOperation(
      operationNumber: 5,
      operationName: 'QC',
      machine: 'Manual',
      remarks: ProcessRemarks.inhouse,
      duration: '15 mins',
    ),
  ],
  'Bearing Shaft': [
    ProcessFlowOperation(
      operationNumber: 1,
      operationName: 'Turning',
      machine: 'CNC',
      remarks: ProcessRemarks.inhouse,
      duration: '60 mins',
    ),
    ProcessFlowOperation(
      operationNumber: 2,
      operationName: 'Milling',
      machine: 'VMC / Manual Milling',
      remarks: ProcessRemarks.inhouse,
      duration: '30 mins',
    ),
    ProcessFlowOperation(
      operationNumber: 3,
      operationName: 'Hardening (30–32 HRC)',
      machine: 'Electric Furnace',
      remarks: ProcessRemarks.outsourcing,
      duration: '24 hrs',
      vendor: 'Immanuel Heat Treatment',
    ),
    ProcessFlowOperation(
      operationNumber: 4,
      operationName: 'Descaling',
      machine: 'Manual',
      remarks: ProcessRemarks.inhouse,
      duration: '15 mins',
    ),
    ProcessFlowOperation(
      operationNumber: 5,
      operationName: 'OD Grinding',
      machine: 'Grinding',
      remarks: ProcessRemarks.outsourcing,
      duration: '60 mins',
      vendor: 'Ambika Grinding Works',
    ),
    ProcessFlowOperation(
      operationNumber: 6,
      operationName: 'QC',
      machine: 'Manual',
      remarks: ProcessRemarks.inhouse,
      duration: '15 mins',
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
      operationName: 'Hardening (30–32 HRC)',
      machine: 'Electric Furnace',
      remarks: ProcessRemarks.outsourcing,
      duration: '24 hrs',
      vendor: 'Immanuel Heat Treatment',
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
      vendor: 'Ambika Grinding Works',
    ),
    ProcessFlowOperation(
      operationNumber: 5,
      operationName: 'QC',
      machine: 'Manual',
      remarks: ProcessRemarks.inhouse,
      duration: '15 mins',
    ),
  ],
  'Housing Lock Nut': [
    ProcessFlowOperation(
      operationNumber: 1,
      operationName: 'Turning',
      machine: 'CNC',
      remarks: ProcessRemarks.inhouse,
      duration: '90 mins',
    ),
    ProcessFlowOperation(
      operationNumber: 2,
      operationName: 'Milling',
      machine: 'VMC',
      remarks: ProcessRemarks.inhouse,
      duration: '90 mins',
    ),
    ProcessFlowOperation(
      operationNumber: 3,
      operationName: 'Hardening (30–32 HRC)',
      machine: 'Electric Furnace',
      remarks: ProcessRemarks.outsourcing,
      duration: '24 hrs',
      vendor: 'Immanuel Heat Treatment',
    ),
    ProcessFlowOperation(
      operationNumber: 4,
      operationName: 'Descaling',
      machine: 'Manual',
      remarks: ProcessRemarks.inhouse,
      duration: '15 mins',
    ),
    ProcessFlowOperation(
      operationNumber: 5,
      operationName: 'QC',
      machine: 'Manual',
      remarks: ProcessRemarks.inhouse,
      duration: '15 mins',
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
                ProcessHeader(
                  partName: partName,
                  operationCount: operations.length,
                ),
                const SizedBox(height: 20),
                for (final operation in operations) ...[
                  ProcessFlowCard(operation: operation),
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

class ProcessHeader extends StatelessWidget {
  const ProcessHeader({
    required this.partName,
    required this.operationCount,
    super.key,
  });

  final String partName;
  final int operationCount;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(partName, style: AppTextStyles.pageTitle),
      const SizedBox(height: 4),
      Text(
        '$operationCount ${operationCount == 1 ? 'Operation' : 'Operations'}',
        style: AppTextStyles.caption,
      ),
    ],
  );
}

class ProcessFlowCard extends StatelessWidget {
  const ProcessFlowCard({required this.operation, super.key});

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
            ProcessInfoRow(
              label: 'Operation Name',
              value: operation.operationName,
            ),
            ProcessInfoRow(label: 'Machine', value: operation.machine),
            ProcessInfoRow(label: 'Duration', value: operation.duration),
            ProcessInfoRow(label: 'Remarks', value: operation.remarks.label),
            ProcessInfoRow(label: 'Vendor', value: operation.vendor ?? '-'),
          ],
        ),
      ),
    );
  }
}

class ProcessInfoRow extends StatelessWidget {
  const ProcessInfoRow({
    required this.label,
    required this.value,
    super.key,
  });
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
