import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/features/fund_requester/domain/models/fund_request.dart';
import 'package:flutter_application_1/features/fund_management/providers/fund_management_providers.dart';

class ApproveFundDialog extends ConsumerStatefulWidget {
  final FundRequest request;
  final Function(double approvedAmount, String? remarks) onConfirm;

  const ApproveFundDialog({
    super.key,
    required this.request,
    required this.onConfirm,
  });

  @override
  ConsumerState<ApproveFundDialog> createState() => _ApproveFundDialogState();
}

class _ApproveFundDialogState extends ConsumerState<ApproveFundDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _remarksController;
  double _approvedAmount = 0.0;
  String? _errorMessage;

  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _approvedAmount = widget.request.requestAmount;
    _amountController = TextEditingController(
      text: _approvedAmount.toStringAsFixed(2),
    );
    _remarksController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String val) {
    final parsed = double.tryParse(val.trim());
    setState(() {
      if (parsed == null || parsed <= 0) {
        _errorMessage = 'Please enter a valid amount greater than 0';
        _approvedAmount = 0.0;
      } else if (parsed > widget.request.requestAmount) {
        _errorMessage =
            'Approved amount cannot exceed requested amount (${_currency.format(widget.request.requestAmount)})';
        _approvedAmount = parsed;
      } else {
        _errorMessage = null;
        _approvedAmount = parsed;
      }
    });
  }

  void _submit() {
    if (_errorMessage != null || _approvedAmount <= 0) {
      return;
    }
    Navigator.of(context).pop();
    widget.onConfirm(_approvedAmount, _remarksController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final isPartial = _approvedAmount < (widget.request.requestAmount - 0.01);
    final projectAsync = ref.watch(projectByCodeProvider(widget.request.projectCode));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: Colors.white,
      elevation: 12,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF2E7D32),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPartial ? 'Partially Approve Fund Request' : 'Approve Fund Request',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF22282D),
                          ),
                        ),
                        Text(
                          'Request: ${widget.request.requestNumber.isNotEmpty ? widget.request.requestNumber : widget.request.id} • ${widget.request.employeeName}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF69737A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Color(0xFF69737A)),
                  ),
                ],
              ),
              const Divider(height: 28),

              // Requested info box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Requested Amount:',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _currency.format(widget.request.requestAmount),
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Project Code: ',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            widget.request.projectCode,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              color: Color(0xFF334155),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.request.message.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reason / Note: ',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              widget.request.message,
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                color: Color(0xFF475569),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Project Actual Balance & Live Deduction Calculation
              projectAsync.when(
                data: (project) {
                  final currentActual = project?.actualProjectValue ?? 0.0;
                  final remaining = (currentActual - _approvedAmount).clamp(0.0, double.infinity);

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 18,
                              color: Color(0xFF16A34A),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Project Budget Deduction Preview',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF166534),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Current Project Actual Value:',
                                style: TextStyle(fontSize: 13, color: Color(0xFF374151))),
                            Text(
                              _currency.format(currentActual),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isPartial ? 'Partial Deduct Amount:' : 'Deduct Approved Amount:',
                              style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626)),
                            ),
                            Text(
                              '- ${_currency.format(_approvedAmount)}',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 14, color: Color(0xFF86EFAC)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Remaining Actual Value After Approval:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF166534),
                              ),
                            ),
                            Text(
                              _currency.format(remaining),
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 18),

              // Approved Amount Field
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Approved Amount (₹)',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF22282D),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isPartial ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isPartial ? 'Partial Approval' : 'Full Approval',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isPartial ? const Color(0xFFB45309) : const Color(0xFF15803D),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: _onAmountChanged,
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
                  ),
                ),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),

              const SizedBox(height: 16),

              // Admin Remarks
              const Text(
                'Approval Remarks / Instructions (Optional)',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _remarksController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Enter approval comments...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _errorMessage != null || _approvedAmount <= 0 ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5CB85C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: Text(
                      isPartial ? 'PARTIALLY APPROVE' : 'APPROVE',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

