import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_searchable_dropdown.dart';
import '../../../employee/providers/employee_providers.dart';
import '../../../projects/domain/models/project_document.dart';
import '../../domain/models/tender.dart';
import '../../providers/tender_providers.dart';
import '../widgets/tender_document_actions.dart';

class TenderFormScreen extends ConsumerStatefulWidget {
  const TenderFormScreen({super.key, this.tender});

  final Tender? tender;

  @override
  ConsumerState<TenderFormScreen> createState() => _TenderFormScreenState();
}

class _TenderFormScreenState extends ConsumerState<TenderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Section 1: Tender Identification
  final _tenderIdController = TextEditingController();
  final _tenderRefNoController = TextEditingController();
  final _titleController = TextEditingController();
  final _clientNameController = TextEditingController();

  // Section 2: Tender Type
  String _tenderType = 'Open';
  final _tenderAmountController = TextEditingController();

  // Section 3: Tender Notice
  final List<PlatformFile> _tenderNoticeFiles = [];
  List<ProjectDocument> _existingTenderNoticeDocs = [];
  DateTime? _noticeUploadedAt;

  // Section 4: Tender Spec / Enquiry Spec
  final _tenderSpecRemarkController = TextEditingController();
  final List<PlatformFile> _tenderSpecFiles = [];
  List<ProjectDocument> _existingTenderSpecDocs = [];

  // Section 5: Opening Date & Time
  final _openingDateRemarkController = TextEditingController();
  DateTime? _openingDate;
  TimeOfDay? _openingTime;

  // Section 6: Closing Date & Time
  final _closingDateRemarkController = TextEditingController();
  DateTime? _closingDate;
  TimeOfDay? _closingTime;

  // Section 7: BQR
  final _bqrRemarkController = TextEditingController();
  final List<PlatformFile> _bqrFiles = [];
  List<ProjectDocument> _existingBqrDocs = [];

  // Section 8: EMD / EMD Exemption
  String _isEmdExempted = 'No';
  final _emdAmountController = TextEditingController();
  final List<PlatformFile> _emdExemptionFiles = [];
  List<ProjectDocument> _existingEmdExemptionDocs = [];
  final _emdRemarkController = TextEditingController();
  final List<PlatformFile> _emdFiles = [];
  List<ProjectDocument> _existingEmdDocs = [];

  @override
  void initState() {
    super.initState();
    final t = widget.tender;
    if (t != null) {
      _tenderIdController.text = t.tenderId;
      _tenderRefNoController.text = t.tenderRefNo;
      _titleController.text = t.title;
      _clientNameController.text = t.clientName;
      _tenderType = ['Open', 'Closed', 'Qualified'].contains(t.tenderType)
          ? t.tenderType
          : (t.tenderType.toLowerCase().contains('close')
              ? 'Closed'
              : (t.tenderType.toLowerCase().contains('qual')
                  ? 'Qualified'
                  : 'Open'));
      if (t.tenderAmount > 0) {
        _tenderAmountController.text = t.tenderAmount % 1 == 0
            ? t.tenderAmount.toInt().toString()
            : t.tenderAmount.toString();
      }
      _existingTenderNoticeDocs = List.from(t.tenderNoticeDocuments);
      _noticeUploadedAt = t.noticeUploadedAt;
      _tenderSpecRemarkController.text = t.tenderSpecRemark;
      _existingTenderSpecDocs = List.from(t.tenderSpecDocuments);

      if (t.openingDate != null) {
        _openingDate = t.openingDate;
        _openingTime = TimeOfDay(
          hour: t.openingDate!.hour,
          minute: t.openingDate!.minute,
        );
      }
      _openingDateRemarkController.text = t.openingDateRemark;

      if (t.closingDate != null) {
        _closingDate = t.closingDate;
        _closingTime = TimeOfDay(
          hour: t.closingDate!.hour,
          minute: t.closingDate!.minute,
        );
      }
      _closingDateRemarkController.text = t.closingDateRemark;

      _bqrRemarkController.text = t.bqrRemark;
      _existingBqrDocs = List.from(t.bqrDocuments);

      _isEmdExempted = t.isEmdExempted.isNotEmpty ? t.isEmdExempted : 'No';
      if (t.emdAmount > 0) {
        _emdAmountController.text = t.emdAmount % 1 == 0
            ? t.emdAmount.toInt().toString()
            : t.emdAmount.toString();
      }
      _existingEmdExemptionDocs = List.from(t.emdExemptionDocuments);
      _emdRemarkController.text = t.emdRemark;
      _existingEmdDocs = List.from(t.emdDocuments);
    } else {
      _generateTenderId();
    }
  }

  Future<void> _generateTenderId() async {
    final nextId =
        await ref.read(tenderRepositoryProvider).generateNextTenderId();
    if (mounted) {
      setState(() {
        _tenderIdController.text = nextId;
      });
    }
  }

  @override
  void dispose() {
    _tenderIdController.dispose();
    _tenderRefNoController.dispose();
    _titleController.dispose();
    _clientNameController.dispose();
    _tenderAmountController.dispose();
    _tenderSpecRemarkController.dispose();
    _openingDateRemarkController.dispose();
    _closingDateRemarkController.dispose();
    _bqrRemarkController.dispose();
    _emdAmountController.dispose();
    _emdRemarkController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles(List<PlatformFile> targetList,
      {List<ProjectDocument>? existingDocs, bool singleOnly = false}) async {
    final remaining = singleOnly
        ? 1
        : 5 - (existingDocs?.length ?? 0) - targetList.length;
    if (remaining <= 0) {
      _showToast('You can upload a maximum of ${singleOnly ? 1 : 5} files.');
      return;
    }

    final result = await FilePicker.pickFiles(
      allowMultiple: !singleOnly,
      withData: true,
    );

    if (result != null) {
      final allowed = result.files.take(remaining).toList();
      setState(() {
        if (singleOnly) {
          targetList.clear();
        }
        targetList.addAll(allowed);
      });
    }
  }

  Future<void> _pickDate(BuildContext context, DateTime? initial,
      ValueChanged<DateTime?> onSelected) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
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
      onSelected(picked);
    }
  }

  Future<void> _pickTime(BuildContext context, TimeOfDay? initial,
      ValueChanged<TimeOfDay?> onSelected) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? TimeOfDay.now(),
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
      onSelected(picked);
    }
  }

  DateTime? _combineDateAndTime(DateTime? date, TimeOfDay? time) {
    if (date == null) return null;
    if (time == null) {
      return DateTime(date.year, date.month, date.day);
    }
    return DateTime(
        date.year, date.month, date.day, time.hour, time.minute);
  }

  double _parseNumber(String input) {
    if (input.trim().isEmpty) return 0.0;
    final cleaned = input.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  void _showToast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? Colors.red.shade700 : const Color(0xFF414A51),
      ),
    );
  }

  Future<void> _saveTender() async {
    if (_tenderIdController.text.trim().isEmpty) {
      _showToast('Please generate or enter a Tender ID', isError: true);
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      _showToast('Please enter Tender Title / Name', isError: true);
      return;
    }

    if (_isEmdExempted == 'No') {
      final emd = double.tryParse(_emdAmountController.text.trim()) ?? 0.0;
      if (emd <= 0 && _tenderAmountController.text.trim().isNotEmpty) {
        // EMD Amount should be provided when not exempted
      }
    }

    setState(() => _isSaving = true);

    try {
      final currentEmp = ref.read(currentEmployeeProvider);
      final userName = currentEmp != null
          ? '${currentEmp.firstName} ${currentEmp.lastName}'.trim()
          : 'User';

      final fullOpeningDate = _combineDateAndTime(_openingDate, _openingTime);
      final fullClosingDate = _combineDateAndTime(_closingDate, _closingTime);

      final tender = Tender(
        id: widget.tender?.id ?? '',
        tenderId: _tenderIdController.text.trim(),
        tenderRefNo: _tenderRefNoController.text.trim(),
        title: _titleController.text.trim(),
        clientName: _clientNameController.text.trim(),
        tenderType: _tenderType,
        qualified: _tenderType == 'Qualified' ? 'Yes' : 'No',
        tenderAmount: _parseNumber(_tenderAmountController.text),
        tenderNoticeDocuments: _existingTenderNoticeDocs,
        noticeUploadedAt: _noticeUploadedAt ??
            (_tenderNoticeFiles.isNotEmpty ? DateTime.now() : null),
        tenderSpecRemark: _tenderSpecRemarkController.text.trim(),
        tenderSpecDocuments: _existingTenderSpecDocs,
        openingDate: fullOpeningDate,
        openingDateRemark: _openingDateRemarkController.text.trim(),
        closingDate: fullClosingDate,
        closingDateRemark: _closingDateRemarkController.text.trim(),
        bqrRemark: _bqrRemarkController.text.trim(),
        bqrDocuments: _existingBqrDocs,
        isEmdExempted: _isEmdExempted,
        emdAmount: _isEmdExempted == 'No'
            ? _parseNumber(_emdAmountController.text)
            : 0.0,
        emdExemptionDocuments: _existingEmdExemptionDocs,
        emdRemark: _emdRemarkController.text.trim(),
        emdDocuments: _existingEmdDocs,
        status: widget.tender?.status ?? 'Submitted',
        awardDocType: widget.tender?.awardDocType ?? '',
        awardDocNumber: widget.tender?.awardDocNumber ?? '',
        awardDate: widget.tender?.awardDate,
        awardedValue: widget.tender?.awardedValue ?? 0.0,
        awardDocuments: widget.tender?.awardDocuments ?? const [],
        competitorName: widget.tender?.competitorName ?? '',
        competitorQuotedValue: widget.tender?.competitorQuotedValue ?? 0.0,
        ourQuotedValue: widget.tender?.ourQuotedValue ?? 0.0,
        reasonForLoss: widget.tender?.reasonForLoss ?? '',
        createdAt: widget.tender?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: widget.tender?.createdBy.isNotEmpty == true
            ? widget.tender!.createdBy
            : userName,
        lastModifiedBy: userName,
      );

      final filesByCategory = <String, List<PlatformFile>>{
        'tender_notice': _tenderNoticeFiles,
        'tender_spec': _tenderSpecFiles,
        'bqr': _bqrFiles,
        'emd': _emdFiles,
        'emd_exemption': _emdExemptionFiles,
      };

      final repo = ref.read(tenderRepositoryProvider);
      if (widget.tender == null) {
        await repo.createTender(tender, filesByCategory: filesByCategory);
        _showToast('Tender created successfully');
      } else {
        await repo.updateTender(tender, filesByCategory: filesByCategory);
        _showToast('Tender updated successfully');
      }

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      _showToast('Failed to save tender: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF414A51)),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/projects/tenders');
            }
          },
        ),
        title: Text(
          widget.tender == null ? 'NEW TENDER' : 'EDIT TENDER',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF414A51),
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9CC70A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onPressed: _isSaving ? null : _saveTender,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(_isSaving ? 'SAVING...' : 'SAVE TENDER'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // SECTION 1: TENDER IDENTIFICATION
                  _buildSectionCard(
                    sectionNumber: 'SECTION 1',
                    sectionTitle: 'TENDER IDENTIFICATION',
                    icon: Icons.vpn_key_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isMobile) ...[
                          _buildTextField(
                            label: 'Tender Title / Name *',
                            controller: _titleController,
                            hint: 'e.g. Substation Maintenance 2026',
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            label: 'Client / Authority Name',
                            controller: _clientNameController,
                            hint: 'e.g. TNEB, TNPDCL, BHEL, etc.',
                          ),
                        ] else
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  label: 'Tender Title / Name *',
                                  controller: _titleController,
                                  hint: 'e.g. Substation Maintenance 2026',
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextField(
                                  label: 'Client / Authority Name',
                                  controller: _clientNameController,
                                  hint: 'e.g. TNEB, TNPDCL, BHEL, etc.',
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),
                        if (isMobile) ...[
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  label: 'Tender ID *',
                                  controller: _tenderIdController,
                                  hint: 'e.g. TE-2026-0001',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(top: 22),
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF414A51),
                                    side: const BorderSide(
                                        color: Color(0xFF9CC70A), width: 1.5),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: _generateTenderId,
                                  child: const Icon(Icons.auto_awesome,
                                      size: 16, color: Color(0xFF9CC70A)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            label: 'Tender Reference No.',
                            controller: _tenderRefNoController,
                            hint: 'e.g. TNPDCL/2026/001',
                          ),
                        ] else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 6,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildTextField(
                                        label: 'Tender ID *',
                                        controller: _tenderIdController,
                                        hint: 'e.g. TE-2026-0001',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 22),
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFF414A51),
                                          side: const BorderSide(
                                              color: Color(0xFF9CC70A),
                                              width: 1.5),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        onPressed: _generateTenderId,
                                        icon: const Icon(Icons.auto_awesome,
                                            size: 16,
                                            color: Color(0xFF9CC70A)),
                                        label: const Text(
                                          'GENERATE',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 5,
                                child: _buildTextField(
                                  label: 'Tender Reference No.',
                                  controller: _tenderRefNoController,
                                  hint: 'e.g. TNPDCL/2026/001',
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // SECTION 2: TENDER TYPE & AMOUNT
                  _buildSectionCard(
                    sectionNumber: 'SECTION 2',
                    sectionTitle: 'TENDER TYPE & AMOUNT',
                    icon: Icons.assignment_outlined,
                    child: isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppSearchableDropdown<String>(
                                label: 'Tender Type',
                                value: _tenderType,
                                items: const ['Open', 'Closed', 'Qualified'],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _tenderType = val);
                                  }
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildTextField(
                                label: 'Tender Amount',
                                controller: _tenderAmountController,
                                hint: 'Enter amount (₹)',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                              ),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: AppSearchableDropdown<String>(
                                  label: 'Tender Type',
                                  value: _tenderType,
                                  items: const ['Open', 'Closed', 'Qualified'],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _tenderType = val);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextField(
                                  label: 'Tender Amount',
                                  controller: _tenderAmountController,
                                  hint: 'Enter amount (₹)',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 18),

                  // SECTION 3: TENDER NOTICE (Client Requirement: Separate Notice PDF)
                  _buildSectionCard(
                    sectionNumber: 'SECTION 3',
                    sectionTitle: 'TENDER NOTICE',
                    icon: Icons.picture_as_pdf_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Upload the official government/client Tender Notice announcement PDF.',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF718096)),
                        ),
                        const SizedBox(height: 12),
                        _buildFileUploadWidget(
                          label: 'Tender Notice PDF',
                          files: _tenderNoticeFiles,
                          existingDocs: _existingTenderNoticeDocs,
                          singleOnly: true,
                        ),
                        if (_noticeUploadedAt != null ||
                            widget.tender?.createdBy.isNotEmpty == true) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline,
                                    size: 15, color: Color(0xFF414A51)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    [
                                      if (_noticeUploadedAt != null)
                                        'Notice Uploaded: ${DateFormat('dd/MM/yyyy HH:mm').format(_noticeUploadedAt!)}',
                                      if (widget.tender?.createdBy.isNotEmpty ==
                                          true)
                                        'Entered By: ${widget.tender!.createdBy}',
                                      if (widget.tender?.updatedAt != null)
                                        'Last Modified: ${DateFormat('dd/MM/yyyy HH:mm').format(widget.tender!.updatedAt)}',
                                    ].join('  •  '),
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF414A51),
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // SECTION 4: TENDER SPEC / ENQUIRY SPEC
                  _buildSectionCard(
                    sectionNumber: 'SECTION 4',
                    sectionTitle: 'TENDER SPEC / ENQUIRY SPEC',
                    icon: Icons.description_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          label: 'Specification Remarks',
                          controller: _tenderSpecRemarkController,
                          hint: 'Technical details or notes',
                        ),
                        const SizedBox(height: 14),
                        _buildFileUploadWidget(
                          label: 'Tender Spec Documents',
                          files: _tenderSpecFiles,
                          existingDocs: _existingTenderSpecDocs,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // SECTION 5: OPENING DATE & TIME
                  _buildSectionCard(
                    sectionNumber: 'SECTION 5',
                    sectionTitle: 'OPENING DATE & TIME',
                    icon: Icons.calendar_today_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          label: 'Remark Text',
                          controller: _openingDateRemarkController,
                          hint: 'Opening notes/remarks',
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              flex: 6,
                              child: _buildDatePickerField(
                                label: 'Opening Date',
                                date: _openingDate,
                                onTap: () => _pickDate(
                                  context,
                                  _openingDate,
                                  (d) => setState(() => _openingDate = d),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 5,
                              child: _buildTimePickerField(
                                label: 'Opening Time',
                                time: _openingTime,
                                onTap: () => _pickTime(
                                  context,
                                  _openingTime,
                                  (t) => setState(() => _openingTime = t),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // SECTION 6: CLOSING DATE & TIME
                  _buildSectionCard(
                    sectionNumber: 'SECTION 6',
                    sectionTitle: 'CLOSING DATE & TIME',
                    icon: Icons.event_busy_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          label: 'Remark Text',
                          controller: _closingDateRemarkController,
                          hint: 'Closing notes/remarks',
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              flex: 6,
                              child: _buildDatePickerField(
                                label: 'Closing Date',
                                date: _closingDate,
                                onTap: () => _pickDate(
                                  context,
                                  _closingDate,
                                  (d) => setState(() => _closingDate = d),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 5,
                              child: _buildTimePickerField(
                                label: 'Closing Time',
                                time: _closingTime,
                                onTap: () => _pickTime(
                                  context,
                                  _closingTime,
                                  (t) => setState(() => _closingTime = t),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // SECTION 7: BQR (Bidder Qualification Requirements)
                  _buildSectionCard(
                    sectionNumber: 'SECTION 7',
                    sectionTitle: 'BQR',
                    icon: Icons.fact_check_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          label: 'BQR Details',
                          controller: _bqrRemarkController,
                          hint: 'Bidder qualification requirements text',
                        ),
                        const SizedBox(height: 14),
                        _buildFileUploadWidget(
                          label: 'BQR Documents',
                          files: _bqrFiles,
                          existingDocs: _existingBqrDocs,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // SECTION 8: EMD & EMD EXEMPTION (Conditional Logic)
                  _buildSectionCard(
                    sectionNumber: 'SECTION 8',
                    sectionTitle: 'EMD / EMD EXEMPTION',
                    icon: Icons.account_balance_wallet_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          label: 'Remark Text',
                          controller: _emdRemarkController,
                          hint: 'EMD remarks',
                        ),
                        const SizedBox(height: 16),
                        // EMD Exemption Selector (Yes / No)
                        const Text(
                          'EMD Exemption',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF414A51),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildChoiceChip(
                              label: 'No (EMD Required)',
                              isSelected: _isEmdExempted == 'No',
                              onSelected: () =>
                                  setState(() => _isEmdExempted = 'No'),
                            ),
                            const SizedBox(width: 12),
                            _buildChoiceChip(
                              label: 'Yes (Exempted)',
                              isSelected: _isEmdExempted == 'Yes',
                              onSelected: () =>
                                  setState(() => _isEmdExempted = 'Yes'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Conditional Display based on EMD Exemption
                        if (_isEmdExempted == 'No') ...[
                          _buildTextField(
                            label: 'EMD Amount (₹) *',
                            controller: _emdAmountController,
                            hint: 'e.g. 50000',
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                          ),
                          const SizedBox(height: 14),
                          _buildFileUploadWidget(
                            label: 'EMD Proof Documents',
                            files: _emdFiles,
                            existingDocs: _existingEmdDocs,
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAF8),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: const Color(0xFF9CC70A)
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.verified_user_outlined,
                                        size: 16, color: Color(0xFF9CC70A)),
                                    SizedBox(width: 8),
                                    Text(
                                      'Upload EMD Exemption Certificate / MSME / NSIC document',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF414A51)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildFileUploadWidget(
                                  label: 'Exemption Document *',
                                  files: _emdExemptionFiles,
                                  existingDocs: _existingEmdExemptionDocs,
                                  singleOnly: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF9CC70A).withValues(alpha: 0.15)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF9CC70A)
                : const Color(0xFFCBD5E1),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              size: 16,
              color: isSelected
                  ? const Color(0xFF9CC70A)
                  : const Color(0xFF718096),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF414A51)
                    : const Color(0xFF718096),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String sectionNumber,
    required String sectionTitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E8E2), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 18, color: const Color(0xFF414A51)),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sectionNumber,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF9CC70A),
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    sectionTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF414A51),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF0F2ED)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF414A51),
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 13, color: Color(0xFF2D3748)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFA0AEC0)),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFF9CC70A), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF414A51),
            ),
          ),
          const SizedBox(height: 6),
        ],
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date != null
                      ? DateFormat('dd/MM/yyyy').format(date)
                      : 'Select Date',
                  style: TextStyle(
                    fontSize: 13,
                    color: date != null
                        ? const Color(0xFF2D3748)
                        : const Color(0xFFA0AEC0),
                  ),
                ),
                const Icon(Icons.calendar_today_outlined,
                    size: 16, color: Color(0xFF718096)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePickerField({
    required String label,
    required TimeOfDay? time,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF414A51),
            ),
          ),
          const SizedBox(height: 6),
        ],
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  time != null ? time.format(context) : 'Select Time',
                  style: TextStyle(
                    fontSize: 13,
                    color: time != null
                        ? const Color(0xFF2D3748)
                        : const Color(0xFFA0AEC0),
                  ),
                ),
                const Icon(Icons.access_time_rounded,
                    size: 16, color: Color(0xFF718096)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileUploadWidget({
    required String label,
    required List<PlatformFile> files,
    List<ProjectDocument>? existingDocs,
    bool singleOnly = false,
  }) {
    final totalCount = (existingDocs?.length ?? 0) + files.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF414A51),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              ),
              onPressed: () => _pickFiles(files,
                  existingDocs: existingDocs, singleOnly: singleOnly),
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: Text(
                  singleOnly ? 'Upload Document' : 'Upload Documents',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 12),
            Text(
              totalCount == 0
                  ? 'No documents attached'
                  : '$totalCount document(s) attached',
              style: const TextStyle(fontSize: 12, color: Color(0xFF718096)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          singleOnly
              ? 'Supported: PDF (Max 10MB)'
              : 'Supported: PDF, Word, Excel, PNG, JPG (Max 5 files, 10MB each)',
          style: const TextStyle(fontSize: 11, color: Color(0xFF718096)),
        ),
        if (existingDocs != null && existingDocs.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final doc in existingDocs)
            TenderDocumentChip(
              document: doc,
              onDelete: () => setState(() => existingDocs.remove(doc)),
            ),
        ],
        if (files.isNotEmpty) ...[
          const SizedBox(height: 6),
          for (final file in files)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.attach_file,
                      size: 16, color: Color(0xFF9CC70A)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      file.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.red),
                    onPressed: () => setState(() => files.remove(file)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
