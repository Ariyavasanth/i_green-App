import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:flutter_application_1/features/retention_sd/domain/models/retention_sd_record.dart';
import 'package:flutter_application_1/features/retention_sd/providers/retention_sd_providers.dart';

class RetentionClaimUpdateDialog extends ConsumerStatefulWidget {
  const RetentionClaimUpdateDialog({
    super.key,
    required this.record,
  });

  final RetentionSdRecord record;

  @override
  ConsumerState<RetentionClaimUpdateDialog> createState() =>
      _RetentionClaimUpdateDialogState();
}

class _RetentionClaimUpdateDialogState
    extends ConsumerState<RetentionClaimUpdateDialog> {
  late RetentionClaimStatus _selectedStatus;
  late DateTime _submissionDate;
  late DateTime _releasedDate;
  late final TextEditingController _referenceCtrl;
  late final TextEditingController _releasedAmountCtrl;
  late final TextEditingController _remarksCtrl;
  final List<PlatformFile> _pickedFiles = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.record.claimStatus;
    _submissionDate =
        widget.record.claimSubmissionDate ?? DateTime.now();
    _releasedDate = widget.record.releasedDate ?? DateTime.now();
    _referenceCtrl =
        TextEditingController(text: widget.record.claimReferenceNo);
    _releasedAmountCtrl = TextEditingController(
      text: widget.record.releasedAmount > 0
          ? widget.record.releasedAmount.toStringAsFixed(2)
          : widget.record.totalFollowUpAmount.toStringAsFixed(2),
    );
    _remarksCtrl = TextEditingController(
      text: widget.record.claimStatus == RetentionClaimStatus.released
          ? widget.record.releaseRemarks
          : widget.record.claimRemarks,
    );
  }

  @override
  void dispose() {
    _referenceCtrl.dispose();
    _releasedAmountCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
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
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(retentionSdRepositoryProvider);
      final double? relAmt =
          double.tryParse(_releasedAmountCtrl.text.replaceAll(',', '').trim());

      await repo.updateClaimStatus(
        recordId: widget.record.id,
        status: _selectedStatus,
        submissionDate: _selectedStatus == RetentionClaimStatus.submitted
            ? _submissionDate
            : null,
        referenceNo: _referenceCtrl.text.trim(),
        releasedDate: _selectedStatus == RetentionClaimStatus.released
            ? _releasedDate
            : null,
        releasedAmount: relAmt,
        remarks: _remarksCtrl.text.trim(),
        documents: _pickedFiles.isNotEmpty ? _pickedFiles : null,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Claim status updated to ${_selectedStatus.label}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating claim: $e'),
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
    final theme = Theme.of(context);
    final dateFormatter = DateFormat('dd-MM-yyyy');

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
              color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.track_changes_rounded,
              color: Color(0xFF414A51),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Update Claim Status',
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
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Claim Lifecycle Status *',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF414A51),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: RetentionClaimStatus.values.map((s) {
                  final isSelected = _selectedStatus == s;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: InkWell(
                        onTap: () => setState(() => _selectedStatus = s),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF414A51)
                                : s.badgeBackground,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF414A51)
                                  : s.badgeColor.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                s.icon,
                                size: 18,
                                color: isSelected
                                    ? const Color(0xFF9CC70A)
                                    : s.badgeColor,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                s.label,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF22282D),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Form fields based on selected status
              if (_selectedStatus == RetentionClaimStatus.submitted) ...[
                // Submission Date
                const Text(
                  'Claim Submission Date *',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF414A51),
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _submissionDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => _submissionDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded,
                            size: 16, color: Color(0xFF414A51)),
                        const SizedBox(width: 8),
                        Text(
                          dateFormatter.format(_submissionDate),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF22282D),
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Change',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF0284C7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Claim Reference No / Letter No
                TextFormField(
                  controller: _referenceCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Claim Letter / Outward Ref No',
                    hintText: 'e.g. IGT/CLAIM/RET/2024/091',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
              ] else if (_selectedStatus == RetentionClaimStatus.released) ...[
                // Release Date
                const Text(
                  'Date Released / Received *',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF414A51),
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _releasedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => _releasedDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded,
                            size: 16, color: Color(0xFF16A34A)),
                        const SizedBox(width: 8),
                        Text(
                          dateFormatter.format(_releasedDate),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF22282D),
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Change',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF0284C7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Released Amount
                TextFormField(
                  controller: _releasedAmountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    labelText: 'Amount Released (₹) *',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Remarks
              TextFormField(
                controller: _remarksCtrl,
                maxLines: 2,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Remarks / Action Notes',
                  hintText: 'Enter follow-up details, client response, or notes',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 14),

              // File Attachments
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Attach Documents (Challan, Claim Letter, Receipt)',
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
                      onDeleted: () => setState(() => _pickedFiles.removeAt(idx)),
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
              : const Text('Save Claim Status'),
        ),
      ],
    );
  }
}
