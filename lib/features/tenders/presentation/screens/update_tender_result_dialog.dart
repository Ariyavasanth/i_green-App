import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../projects/domain/models/project_document.dart';
import '../../domain/models/tender.dart';
import '../../providers/tender_providers.dart';
import '../widgets/tender_document_actions.dart';

class UpdateTenderResultDialog extends ConsumerStatefulWidget {
  const UpdateTenderResultDialog({super.key, required this.tender});

  final Tender tender;

  static Future<void> show(BuildContext context, Tender tender) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateTenderResultDialog(tender: tender),
    );
  }

  @override
  ConsumerState<UpdateTenderResultDialog> createState() =>
      _UpdateTenderResultDialogState();
}

class _UpdateTenderResultDialogState
    extends ConsumerState<UpdateTenderResultDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  late String _status;

  // Won fields
  late String _awardDocType;
  final _awardDocNumberController = TextEditingController();
  DateTime? _awardDate;
  final _awardedValueController = TextEditingController();
  final List<PlatformFile> _awardFiles = [];
  List<ProjectDocument> _existingAwardDocs = [];

  // Rejected fields
  final _competitorNameController = TextEditingController();
  final _competitorQuotedValueController = TextEditingController();
  final _ourQuotedValueController = TextEditingController();
  final _reasonForLossController = TextEditingController();

  static const _statusOptions = [
    'Submitted',
    'Under Evaluation',
    'Won',
    'Rejected',
  ];

  static const _awardDocTypes = [
    'Work Order',
    'Letter of Acceptance (LOA)',
    'Agreement',
    'Purchase Order',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final t = widget.tender;
    _status = _statusOptions.contains(t.status) ? t.status : 'Submitted';

    _awardDocType = _awardDocTypes.contains(t.awardDocType)
        ? t.awardDocType
        : _awardDocTypes.first;
    _awardDocNumberController.text = t.awardDocNumber;
    _awardDate = t.awardDate;
    if (t.awardedValue > 0) {
      _awardedValueController.text = t.awardedValue.toStringAsFixed(2);
    } else if (t.tenderAmount > 0) {
      _awardedValueController.text = t.tenderAmount.toStringAsFixed(2);
    }
    _existingAwardDocs = List.from(t.awardDocuments);

    _competitorNameController.text = t.competitorName;
    if (t.competitorQuotedValue > 0) {
      _competitorQuotedValueController.text =
          t.competitorQuotedValue.toStringAsFixed(2);
    }
    if (t.ourQuotedValue > 0) {
      _ourQuotedValueController.text = t.ourQuotedValue.toStringAsFixed(2);
    } else if (t.tenderAmount > 0) {
      _ourQuotedValueController.text = t.tenderAmount.toStringAsFixed(2);
    }
    _reasonForLossController.text = t.reasonForLoss;
  }

  @override
  void dispose() {
    _awardDocNumberController.dispose();
    _awardedValueController.dispose();
    _competitorNameController.dispose();
    _competitorQuotedValueController.dispose();
    _ourQuotedValueController.dispose();
    _reasonForLossController.dispose();
    super.dispose();
  }

  Future<void> _pickAwardFiles() async {
    final remaining = 5 - _existingAwardDocs.length - _awardFiles.length;
    if (remaining <= 0) return;

    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result != null) {
      setState(() {
        _awardFiles.addAll(result.files.take(remaining));
      });
    }
  }

  Future<void> _pickAwardDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _awardDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF9CC70A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF414A51),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _awardDate = picked);
    }
  }

  double _parseNumber(String input) {
    if (input.trim().isEmpty) return 0.0;
    final cleaned = input.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  Future<void> _saveResult() async {
    setState(() => _isSaving = true);

    try {
      final updated = widget.tender.copyWith(
        status: _status,
        awardDocType: _status == 'Won' ? _awardDocType : '',
        awardDocNumber:
            _status == 'Won' ? _awardDocNumberController.text.trim() : '',
        awardDate: _status == 'Won' ? _awardDate : null,
        awardedValue:
            _status == 'Won' ? _parseNumber(_awardedValueController.text) : 0.0,
        awardDocuments: _status == 'Won' ? _existingAwardDocs : const [],
        competitorName:
            _status == 'Rejected' ? _competitorNameController.text.trim() : '',
        competitorQuotedValue: _status == 'Rejected'
            ? _parseNumber(_competitorQuotedValueController.text)
            : 0.0,
        ourQuotedValue: _status == 'Rejected'
            ? _parseNumber(_ourQuotedValueController.text)
            : 0.0,
        reasonForLoss:
            _status == 'Rejected' ? _reasonForLossController.text.trim() : '',
        updatedAt: DateTime.now(),
      );

      final filesByCategory = <String, List<PlatformFile>>{
        if (_status == 'Won' && _awardFiles.isNotEmpty)
          'award_documents': _awardFiles,
      };

      await ref
          .read(tenderRepositoryProvider)
          .updateTender(updated, filesByCategory: filesByCategory);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tender result updated to "$_status"'),
            backgroundColor: const Color(0xFF414A51),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update result: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF9CC70A).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.rate_review_outlined,
                              size: 20, color: Color(0xFF414A51)),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'UPDATE TENDER RESULT',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF414A51),
                                letterSpacing: 0.3,
                              ),
                            ),
                            Text(
                              '${widget.tender.tenderId}  •  ${widget.tender.title}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF718096),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.close, color: Color(0xFF718096)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 20),

                // Status Selector
                const Text(
                  'Tender Status *',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF414A51),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _statusOptions.map((st) {
                    final isSel = _status == st;
                    Color statusColor = const Color(0xFF718096);
                    if (st == 'Won') statusColor = const Color(0xFF9CC70A);
                    if (st == 'Rejected') statusColor = Colors.red.shade600;
                    if (st == 'Under Evaluation') {
                      statusColor = Colors.orange.shade700;
                    }

                    return InkWell(
                      onTap: () => setState(() => _status = st),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSel
                              ? statusColor.withValues(alpha: 0.12)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSel
                                ? statusColor
                                : const Color(0xFFCBD5E1),
                            width: isSel ? 1.8 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSel
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              size: 16,
                              color: isSel
                                  ? statusColor
                                  : const Color(0xFFA0AEC0),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              st,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSel
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSel
                                    ? const Color(0xFF414A51)
                                    : const Color(0xFF718096),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Dynamic Sections based on Status
                if (_status == 'Won') ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAF8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              const Color(0xFF9CC70A).withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.emoji_events_outlined,
                                size: 18, color: Color(0xFF9CC70A)),
                            SizedBox(width: 8),
                            Text(
                              'AWARD DETAILS (WON TENDER)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF414A51),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Award Document Type',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF414A51)),
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: _awardDocType,
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                            color: Color(0xFFCBD5E1)),
                                      ),
                                    ),
                                    items: _awardDocTypes
                                        .map((t) => DropdownMenuItem(
                                            value: t,
                                            child: Text(t,
                                                style: const TextStyle(
                                                    fontSize: 13))))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _awardDocType = val);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildInputField(
                                label: 'Award Document Number',
                                controller: _awardDocNumberController,
                                hint: 'e.g. WO-2026-998',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Award Date',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF414A51)),
                                  ),
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: _pickAwardDate,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 11),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        border: Border.all(
                                            color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _awardDate != null
                                                ? DateFormat('dd/MM/yyyy')
                                                    .format(_awardDate!)
                                                : 'Select Award Date',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: _awardDate != null
                                                  ? const Color(0xFF2D3748)
                                                  : const Color(0xFFA0AEC0),
                                            ),
                                          ),
                                          const Icon(
                                              Icons.calendar_today_outlined,
                                              size: 16,
                                              color: Color(0xFF718096)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildInputField(
                                label: 'Awarded Value (₹)',
                                controller: _awardedValueController,
                                hint: 'Enter final awarded value',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Award Document Upload (LOA / WO / Contract PDF)',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF414A51)),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF414A51),
                            side:
                                const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _pickAwardFiles,
                          icon: const Icon(Icons.upload_file_rounded,
                              size: 16),
                          label: const Text('Attach Award PDF',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                        if (_existingAwardDocs.isNotEmpty ||
                            _awardFiles.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          for (final d in _existingAwardDocs)
                            TenderDocumentChip(
                              document: d,
                              onDelete: () =>
                                  setState(() => _existingAwardDocs.remove(d)),
                            ),
                          for (final f in _awardFiles)
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: const Color(0xFFBBF7D0)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.attach_file,
                                      size: 16, color: Color(0xFF9CC70A)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      f.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close,
                                        size: 16, color: Colors.red),
                                    onPressed: () =>
                                        setState(() => _awardFiles.remove(f)),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ] else if (_status == 'Rejected') ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.cancel_outlined,
                                size: 18, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            const Text(
                              'COMPETITOR & LOSS DETAILS (REJECTED TENDER)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF414A51),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _buildInputField(
                          label: 'Winning Competitor Name',
                          controller: _competitorNameController,
                          hint: 'e.g. ABC Infra Ltd',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInputField(
                                label: 'Competitor Quoted Value (₹)',
                                controller: _competitorQuotedValueController,
                                hint: 'e.g. 450000',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildInputField(
                                label: 'Our Quoted Value (₹)',
                                controller: _ourQuotedValueController,
                                hint: 'e.g. 480000',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildInputField(
                          label: 'Reason for Loss',
                          controller: _reasonForLossController,
                          hint:
                              'e.g. Higher price, non-compliance with technical clause...',
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _isSaving ? null : () => Navigator.of(context).pop(),
                      child: const Text('CANCEL',
                          style: TextStyle(color: Color(0xFF718096))),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9CC70A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isSaving ? null : _saveResult,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check, size: 18),
                      label:
                          Text(_isSaving ? 'SAVING...' : 'SAVE RESULT'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF414A51),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 13, color: Color(0xFF2D3748)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(fontSize: 13, color: Color(0xFFA0AEC0)),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: Color(0xFF9CC70A), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

