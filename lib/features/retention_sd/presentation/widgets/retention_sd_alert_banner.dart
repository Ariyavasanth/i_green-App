import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/features/retention_sd/domain/models/retention_sd_record.dart';

class RetentionSdAlertBanner extends StatelessWidget {
  const RetentionSdAlertBanner({
    super.key,
    required this.expiringRecords,
    required this.onRecordTap,
  });

  final List<RetentionSdRecord> expiringRecords;
  final void Function(RetentionSdRecord record) onRecordTap;

  @override
  Widget build(BuildContext context) {
    if (expiringRecords.isEmpty) return const SizedBox.shrink();

    final currency = NumberFormat.compactCurrency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 1,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFD97706),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '30-Day Bank Guarantee Expiry Alert (${expiringRecords.length} Action${expiringRecords.length > 1 ? 's' : ''} Needed)',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF92400E),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'The following Bank Guarantees expire within 30 days or are overdue. Initiate claim submission or obtain BG validity extension.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF78350F),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: expiringRecords.map((r) {
                final bg = r.bg;
                final isExpired = r.isBgExpired;
                final days = bg?.daysUntilExpiry;
                final statusText = isExpired
                    ? 'EXPIRED (${-(days ?? 0)}d ago)'
                    : 'Expires in ${days ?? 0}d';

                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () => onRecordTap(r),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isExpired
                              ? const Color(0xFFDC2626)
                              : const Color(0xFFF59E0B),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isExpired
                                  ? const Color(0xFFFEE2E2)
                                  : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: isExpired
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFFD97706),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${r.projectCode} • ${bg?.bgNumber.isNotEmpty == true ? bg!.bgNumber : "BG"}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF22282D),
                                ),
                              ),
                              Text(
                                '${bg?.bankName.isNotEmpty == true ? bg!.bankName : r.clientName} • ${currency.format(bg?.bgAmount ?? 0.0)}',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
