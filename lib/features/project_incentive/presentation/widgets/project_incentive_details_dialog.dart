import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/models/project_incentive_record.dart';

class ProjectIncentiveDetailsDialog extends StatelessWidget {
  const ProjectIncentiveDetailsDialog({
    super.key,
    required this.record,
  });

  final ProjectIncentiveRecord record;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    final dateFmt = DateFormat('dd-MM-yyyy');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Dialog Header ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF414A51),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9CC70A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.military_tech_outlined,
                      size: 20,
                      color: Color(0xFF414A51),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'INCENTIVE CALCULATION: ${record.projectCode}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${record.projectName} • ${record.clientName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ── Scrollable Content ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Disqualification Banner (if incident logged) ──
                    if (record.isDisqualified) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF87171)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Color(0xFFDC2626),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'AUTOMATICALLY DISQUALIFIED FROM INCENTIVE',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: Color(0xFF991B1B),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    record.disqualificationReason,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFB91C1C),
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Under corporate safety policy, logging an incident forfeits 100% of the project incentive. Site restoration costs are tracked separately below.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontStyle: FontStyle.italic,
                                      color: Color(0xFF7F1D1D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline_rounded,
                              color: Color(0xFF16A34A),
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Zero Site Incidents Recorded — Project is Fully Eligible for Incentive',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                  color: Color(0xFF166534),
                                ),
                              ),
                            ),
                            Text(
                              currency.format(record.netPayableIncentive),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Color(0xFF166534),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Final Payable Highlight Card ──
                    _buildSummaryCard(currency),
                    const SizedBox(height: 18),

                    // ── Factor 1: Daily Progress ──
                    _buildSectionCard(
                      title: '1. Daily Progress Incentive',
                      icon: Icons.trending_up_rounded,
                      color: const Color(0xFF414A51),
                      children: [
                        _buildRow('Target Volume', '${record.totalQuantityTarget.toStringAsFixed(1)} ${record.unit}'),
                        _buildRow('Approved Quantity Accomplished', '${record.approvedQuantityDone.toStringAsFixed(1)} ${record.unit} (${record.approvedEntriesCount} approved daily logs)'),
                        _buildRow('Completion Rate', '${record.progressCompletionPercentage.toStringAsFixed(1)}%'),
                        const Divider(height: 16, color: Color(0xFFE5E8E2)),
                        _buildRow(
                          'Base Progress Incentive',
                          currency.format(record.baseProgressIncentive),
                          isBold: true,
                          highlightColor: const Color(0xFF414A51),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Factor 2: Timely Bill Submission ──
                    _buildSectionCard(
                      title: '2. Timely Bill Submission',
                      icon: Icons.receipt_long_rounded,
                      color: const Color(0xFF414A51),
                      children: [
                        _buildRow('Bill Submission Status', record.isBillSubmitted ? 'Submitted (${record.flowOfBillsStatus.isNotEmpty ? record.flowOfBillsStatus : "Verified"})' : 'Pending Submission'),
                        if (record.billTargetDate != null)
                          _buildRow('Target Billing Date', dateFmt.format(record.billTargetDate!)),
                        if (record.billSubmissionDate != null)
                          _buildRow('Actual Submission Date', dateFmt.format(record.billSubmissionDate!)),
                        _buildRow(
                          'Submission Timeliness',
                          record.isBillTimely ? 'On-Time (+10% Timely Bonus)' : 'Delayed / Overdue (-15% Penalty)',
                          isBold: true,
                          highlightColor: record.isBillTimely ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        ),
                        const Divider(height: 16, color: Color(0xFFE5E8E2)),
                        _buildRow(
                          'Timely Bill Adjustment',
                          (record.timelyBillAdjustmentAmount >= 0 ? '+' : '') +
                              currency.format(record.timelyBillAdjustmentAmount),
                          isBold: true,
                          highlightColor: record.timelyBillAdjustmentAmount >= 0
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Factor 3: Payment Collection ──
                    _buildSectionCard(
                      title: '3. Payment Collection Consideration',
                      icon: Icons.account_balance_wallet_outlined,
                      color: const Color(0xFF414A51),
                      children: [
                        _buildRow('Contract / Project Value', currency.format(record.contractValue)),
                        _buildRow('Client Payment Received', currency.format(record.paymentCollectedAmount)),
                        _buildRow('Collection Efficiency', '${record.paymentCollectionPercentage.toStringAsFixed(1)}%'),
                        _buildRow('Collection Release Factor', '${(record.paymentCollectionFactor * 100).toStringAsFixed(1)}% payout factor applied'),
                        const Divider(height: 16, color: Color(0xFFE5E8E2)),
                        _buildRow(
                          'Collection Adjusted Incentive',
                          currency.format(record.grossEarnedIncentive),
                          isBold: true,
                          highlightColor: const Color(0xFF414A51),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Factor 4 & 5: Incidents & Dedicated Restoration Costs ──
                    _buildSectionCard(
                      title: '4 & 5. Site Incidents & Dedicated Restoration Costs',
                      icon: Icons.warning_amber_rounded,
                      color: record.hasRestorationCosts ? const Color(0xFFEA580C) : const Color(0xFF414A51),
                      trailingBadge: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'TRACKED SEPARATELY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFC2410C),
                          ),
                        ),
                      ),
                      children: [
                        _buildRow('Recorded Incidents Count', '${record.incidentCount} incident(s)'),
                        _buildRow(
                          'Total Restoration Costs',
                          currency.format(record.totalRestorationCost),
                          isBold: true,
                          highlightColor: record.hasRestorationCosts ? const Color(0xFFDC2626) : const Color(0xFF414A51),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Note: Under project policy, restoration costs are tracked in a dedicated damage recovery ledger and are NOT offset as negative balances in employee incentive accounts.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        if (record.restorationIncidents.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Itemized Incident Restoration Ledger:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF414A51),
                            ),
                          ),
                          const SizedBox(height: 6),
                          ...record.restorationIncidents.map((inc) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.handyman_outlined, size: 16, color: Color(0xFFDC2626)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Incident on ${dateFmt.format(inc.incidentDate)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                        Text(
                                          inc.remarks,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                        if (inc.photoUrls.isNotEmpty)
                                          Text(
                                            '${inc.photoUrls.length} evidence photo(s) attached',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              color: Color(0xFF0284C7),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    currency.format(inc.restorationCost),
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Dialog Bottom Bar ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Calculated on: ${dateFmt.format(record.calculatedAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF414A51),
                      foregroundColor: const Color(0xFF9CC70A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(NumberFormat currency) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: record.isDisqualified
            ? const Color(0xFFFEF2F2)
            : const Color(0xFF414A51),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: record.isDisqualified
              ? const Color(0xFFFCA5A5)
              : const Color(0xFF414A51),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NET PAYABLE INCENTIVE',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: record.isDisqualified
                      ? const Color(0xFF991B1B)
                      : const Color(0xFF9CC70A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                currency.format(record.netPayableIncentive),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: record.isDisqualified
                      ? const Color(0xFFDC2626)
                      : Colors.white,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: record.isDisqualified
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF9CC70A),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              record.status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: record.isDisqualified
                    ? Colors.white
                    : const Color(0xFF414A51),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    Widget? trailingBadge,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E8E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF414A51),
                  ),
                ),
              ),
              if (trailingBadge != null) trailingBadge,
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    bool isBold = false,
    Color? highlightColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                color: highlightColor ?? const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
