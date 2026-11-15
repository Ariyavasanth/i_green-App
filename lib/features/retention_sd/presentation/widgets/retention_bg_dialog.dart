import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:flutter_application_1/features/retention_sd/domain/models/retention_sd_record.dart';
import 'package:flutter_application_1/features/retention_sd/providers/retention_sd_providers.dart';

class RetentionBgDialog extends ConsumerStatefulWidget {
  const RetentionBgDialog({
    super.key,
    required this.record,
  });

  final RetentionSdRecord record;

  @override
  ConsumerState<RetentionBgDialog> createState() => _RetentionBgDialogState();
}

class _RetentionBgDialogState extends ConsumerState<RetentionBgDialog> {
  late final TextEditingController _bgNumberCtrl;
  late final TextEditingController _bankNameCtrl;
  late final TextEditingController _branchCtrl;
  late final TextEditingController _bgAmountCtrl;
  late final TextEditingController _remarksCtrl;

  DateTime? _issueDate;
  DateTime? _expiryDate;
  DateTime? _claimExpiryDate;
  String _status = 'Active';
  final List<PlatformFile> _pickedFiles = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final bg = widget.record.bg;
    _bgNumberCtrl = TextEditingController(
      text: bg?.bgNumber.isNotEmpty == true
          ? bg!.bgNumber
          : widget.record.sdAgreementNo,
    );
    _bankNameCtrl = TextEditingController(text: bg?.bankName ?? '');
    _branchCtrl = TextEditingController(text: bg?.branchName ?? '');
    _bgAmountCtrl = TextEditingController(
      text: (bg?.bgAmount ?? 0.0) > 0
          ? bg!.bgAmount.toStringAsFixed(2)
          : (widget.record.sdAmount > 0
              ? widget.record.sdAmount.toStringAsFixed(2)
              : ''),
    );
    _remarksCtrl = TextEditingController(text: bg?.remarks ?? '');
    _issueDate = bg?.issueDate ?? widget.record.sdDueDate;
    _expiryDate = bg?.expiryDate;
    _claimExpiryDate = bg?.claimExpiryDate;
    _status = bg?.status ?? 'Active';
  }

  @override
  void dispose() {
    _bgNumberCtrl.dispose();
    _bankNameCtrl.dispose();
    _branchCtrl.dispose();
    _bgAmountCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  int? get _daysUntilExpiry {
    if (_expiryDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target =
        DateTime(_expiryDate!.year, _expiryDate!.month, _expiryDate!.day);
    return target.difference(today).inDays;
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result != null && mounted) {
      setState(() {
        _pickedFiles.addAll(result.files);
      });
    }
  }

  Future<void> _submit() async {
    final bgNum = _bgNumberCtrl.text.trim();
    if (bgNum.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Bank Guarantee number'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(retentionSdRepositoryProvider);
      final double amt =
          double.tryParse(_bgAmountCtrl.text.replaceAll(',', '').trim()) ?? 0.0;

      final existingBg = widget.record.bg;
      final updatedBg = BankGuaranteeDetail(
        bgNumber: bgNum,
        bankName: _bankNameCtrl.text.trim(),
        branchName: _branchCtrl.text.trim(),
        bgAmount: amt,
        issueDate: _issueDate,
        expiryDate: _expiryDate,
        claimExpiryDate: _claimExpiryDate,
        status: _status,
        remarks: _remarksCtrl.text.trim(),
        documents: existingBg?.documents ?? const [],
      );

      await repo.updateBgDetails(
        recordId: widget.record.id,
        bg: updatedBg,
        documents: _pickedFiles.isNotEmpty ? _pickedFiles : null,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bank Guarantee details saved successfully',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving BG details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('dd-MM-yyyy');
    final days = _daysUntilExpiry;
    final isExpiringSoon = days != null && days <= 30 && days >= 0;
    final isExpired = days != null && days < 0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFEA580C).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Color(0xFFEA580C),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bank Guarantee (BG) Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF22282D),
                  ),
                ),
                Text(
                  '${widget.record.projectCode} • ${widget.record.projectName}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF69737A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Expiry Alert Inside Dialog
              if (isExpired) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEF4444)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Color(0xFFDC2626), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'BANK GUARANTEE EXPIRED ${-days} day${-days == 1 ? '' : 's'} ago (${dateFormatter.format(_expiryDate!)})!',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (isExpiringSoon) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFD97706), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'WARNING: BG expires in $days day${days == 1 ? '' : 's'} on ${dateFormatter.format(_expiryDate!)}! Take immediate renewal or claim action.',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // BG Number & Value
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _bgNumberCtrl,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'BG Number *',
                        hintText: 'e.g. BG-2024-SBI-1092',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _bgAmountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*')),
                      ],
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(
                        labelText: 'BG Amount (₹)',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Bank Name & Branch
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _bankNameCtrl,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Issuing Bank Name',
                        hintText: 'e.g. State Bank of India',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _branchCtrl,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Bank Branch',
                        hintText: 'e.g. Industrial Finance Branch',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Issue Date & Expiry Date
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Issue Date',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF414A51),
                          ),
                        ),
                        const SizedBox(height: 5),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _issueDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() => _issueDate = picked);
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: const Color(0xFFCBD5E1)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded,
                                    size: 15, color: Color(0xFF414A51)),
                                const SizedBox(width: 8),
                                Text(
                                  _issueDate != null
                                      ? dateFormatter.format(_issueDate!)
                                      : 'Select Date',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: _issueDate != null
                                        ? const Color(0xFF22282D)
                                        : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'BG Expiry Date *',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF414A51),
                              ),
                            ),
                            if (isExpiringSoon || isExpired)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isExpired
                                      ? const Color(0xFFFEE2E2)
                                      : const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isExpired ? 'EXPIRED' : '≤30 DAYS',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: isExpired
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFFD97706),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _expiryDate ??
                                  DateTime.now().add(const Duration(days: 365)),
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 3650)),
                            );
                            if (picked != null) {
                              setState(() => _expiryDate = picked);
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isExpired
                                    ? const Color(0xFFDC2626)
                                    : (isExpiringSoon
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFFCBD5E1)),
                                width: (isExpiringSoon || isExpired) ? 1.5 : 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.event_busy_rounded,
                                    size: 15,
                                    color: isExpired
                                        ? const Color(0xFFDC2626)
                                        : (isExpiringSoon
                                            ? const Color(0xFFD97706)
                                            : const Color(0xFF414A51))),
                                const SizedBox(width: 8),
                                Text(
                                  _expiryDate != null
                                      ? dateFormatter.format(_expiryDate!)
                                      : 'Select Expiry',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: (isExpiringSoon || isExpired)
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                    color: isExpired
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF22282D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Claim Expiry Date & Status
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Claim Expiry Date',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF414A51),
                          ),
                        ),
                        const SizedBox(height: 5),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _claimExpiryDate ??
                                  (_expiryDate != null
                                      ? _expiryDate!.add(const Duration(days: 30))
                                      : DateTime.now()),
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 3650)),
                            );
                            if (picked != null) {
                              setState(() => _claimExpiryDate = picked);
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: const Color(0xFFCBD5E1)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.schedule_rounded,
                                    size: 15, color: Color(0xFF414A51)),
                                const SizedBox(width: 8),
                                Text(
                                  _claimExpiryDate != null
                                      ? dateFormatter.format(_claimExpiryDate!)
                                      : 'Select Claim Date',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: _claimExpiryDate != null
                                        ? const Color(0xFF22282D)
                                        : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'BG Status',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF414A51),
                          ),
                        ),
                        const SizedBox(height: 5),
                        DropdownButtonFormField<String>(
                          value: _status,
                          items: const [
                            DropdownMenuItem(value: 'Active', child: Text('Active')),
                            DropdownMenuItem(
                                value: 'Extended', child: Text('Extended')),
                            DropdownMenuItem(
                                value: 'Claimed', child: Text('Claimed')),
                            DropdownMenuItem(
                                value: 'Released', child: Text('Released')),
                            DropdownMenuItem(
                                value: 'Expired', child: Text('Expired')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _status = val);
                          },
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Remarks
              TextFormField(
                controller: _remarksCtrl,
                maxLines: 2,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'BG Remarks / Extension Details',
                  hintText: 'e.g. 1st Extension up to 31-12-2025 in progress',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 14),

              // Documents Attached
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Attach BG Copy or Extension Letters',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF414A51),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pickFiles,
                    icon: const Icon(Icons.attach_file_rounded, size: 16),
                    label: const Text('Add Files',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              if (_pickedFiles.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _pickedFiles.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final f = entry.value;
                    return Chip(
                      label: Text(
                        f.name,
                        style: const TextStyle(fontSize: 11),
                      ),
                      deleteIcon:
                          const Icon(Icons.close_rounded, size: 14),
                      onDeleted: () =>
                          setState(() => _pickedFiles.removeAt(idx)),
                      backgroundColor: const Color(0xFFF1F5F9),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF414A51),
            foregroundColor: const Color(0xFF9CC70A),
          ),
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF9CC70A),
                  ),
                )
              : const Text('Save BG Details'),
        ),
      ],
    );
  }
}
