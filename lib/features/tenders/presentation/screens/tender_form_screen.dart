import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_searchable_dropdown.dart';
import '../../../employee/providers/employee_providers.dart';
import '../../../on_duty/presentation/widgets/destination_map_picker.dart';
import '../../../projects/domain/models/project_document.dart';
import '../../domain/models/bqr_requirement_item.dart';
import '../../domain/models/site_visit_record.dart';
import '../../domain/models/tender.dart';
import '../../providers/company_document_providers.dart';
import '../../providers/tender_providers.dart';
import '../dialogs/company_document_picker_dialog.dart';
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
  bool _isAiAutoFilling = false;
  bool _isGeneratingTenderId = false;

  // Section 1: Tender Identification
  final _tenderIdController = TextEditingController();
  final _tenderRefNoController = TextEditingController();
  final _titleController = TextEditingController();
  final _clientNameController = TextEditingController();

  // Section 2: Tender Type
  String _tenderType = 'Open';
  final _tenderAmountController = TextEditingController();

  // Pre-Tender: Site Visit & Financial Bid
  List<SiteVisitRecord> _siteVisits = [];
  final List<PlatformFile> _financialBidFiles = [];
  List<ProjectDocument> _existingFinancialBidDocs = [];

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
  List<BqrRequirementItem> _bqrRequirements = [];
  final Set<String> _uploadingBqrItemIds = {};

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

      _siteVisits = List.from(t.siteVisits);
      _existingFinancialBidDocs = List.from(t.financialBidDocuments);
      _bqrRemarkController.text = t.bqrRemark;
      _existingBqrDocs = List.from(t.bqrDocuments);
      _bqrRequirements = List.from(t.bqrRequirements);

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

  Future<void> _generateTenderId({bool showFeedback = false}) async {
    if (_isGeneratingTenderId) return;
    if (showFeedback) {
      setState(() => _isGeneratingTenderId = true);
    } else {
      _isGeneratingTenderId = true;
    }
    try {
      final previousId = _tenderIdController.text.trim();
      final nextId =
          await ref.read(tenderRepositoryProvider).generateNextTenderId();
      if (!mounted) return;
      setState(() {
        _tenderIdController.text = nextId;
      });
      if (showFeedback) {
        _showToast(
          previousId == nextId
              ? 'Tender ID is already set to the next available ID ($nextId)'
              : 'Generated Tender ID: $nextId',
        );
      }
    } catch (e) {
      if (mounted && showFeedback) {
        _showToast('Failed to generate Tender ID: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingTenderId = false);
      }
    }
  }

  Future<void> _uploadAndAutoFillWithAi() async {
    if (_isAiAutoFilling || _isSaving) return;

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;
      setState(() => _isAiAutoFilling = true);
      _showToast('Analyzing tender document "${file.name}" with AI...');

      final aiService = ref.read(tenderAiServiceProvider);
      final data = await aiService.extractTenderData(file);

      if (!mounted) return;

      setState(() {
        // Section 1: Tender Identification
        if (data.title.isNotEmpty) {
          _titleController.text = data.title;
        }
        if (data.clientName.isNotEmpty) {
          _clientNameController.text = data.clientName;
        }
        if (data.tenderRefNo.isNotEmpty) {
          _tenderRefNoController.text = data.tenderRefNo;
        }
        if (data.tenderId.isNotEmpty &&
            _tenderIdController.text.trim().isEmpty) {
          _tenderIdController.text = data.tenderId;
        }

        // Section 2: Tender Type & Amount
        if (['Open', 'Closed', 'Qualified'].contains(data.tenderType)) {
          _tenderType = data.tenderType;
        }
        if (data.tenderAmount > 0) {
          _tenderAmountController.text = data.tenderAmount % 1 == 0
              ? data.tenderAmount.toInt().toString()
              : data.tenderAmount.toString();
        }

        // Section 3: Tender Notice Document (Attach the uploaded document)
        _tenderNoticeFiles.clear();
        _tenderNoticeFiles.add(file);
        _noticeUploadedAt = DateTime.now();

        // Section 4: Tender Spec / Enquiry Spec
        if (data.tenderSpecRemark.isNotEmpty) {
          _tenderSpecRemarkController.text = data.tenderSpecRemark;
        }

        // Section 5: Opening Date & Time
        if (data.openingDate != null) {
          _openingDate = data.openingDate;
          _openingTime = TimeOfDay(
            hour: data.openingDate!.hour,
            minute: data.openingDate!.minute,
          );
        }
        if (data.openingDateRemark.isNotEmpty) {
          _openingDateRemarkController.text = data.openingDateRemark;
        }

        // Section 6: Closing Date & Time
        if (data.closingDate != null) {
          _closingDate = data.closingDate;
          _closingTime = TimeOfDay(
            hour: data.closingDate!.hour,
            minute: data.closingDate!.minute,
          );
        }
        if (data.closingDateRemark.isNotEmpty) {
          _closingDateRemarkController.text = data.closingDateRemark;
        }

        // Section 7: BQR
        if (data.bqrRemark.isNotEmpty) {
          _bqrRemarkController.text = data.bqrRemark;
        }
        final extractedBqrItems = data.bqrRequirements.isNotEmpty
            ? data.bqrRequirements
            : _parseBqrRequirementsFromText(data.bqrRemark);
        if (extractedBqrItems.isNotEmpty) {
          _bqrRequirements = _mergeExtractedBqrRequirements(extractedBqrItems);
        }

        // Section 8: EMD / EMD Exemption
        if (data.emdAmount > 0) {
          _isEmdExempted = 'No';
          _emdAmountController.text = data.emdAmount % 1 == 0
              ? data.emdAmount.toInt().toString()
              : data.emdAmount.toString();
        } else if (data.isEmdExempted.isNotEmpty) {
          _isEmdExempted = data.isEmdExempted;
        }
        if (data.emdRemark.isNotEmpty) {
          _emdRemarkController.text = data.emdRemark;
        }
      });

      _showToast(
        'Tender document analyzed! All 8 sections populated. Please review details.',
      );
    } catch (e) {
      if (mounted) {
        _showToast('Failed to auto-fill tender with AI: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isAiAutoFilling = false);
      }
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
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor:
            isError ? Colors.red.shade700 : const Color(0xFF414A51),
        duration: Duration(seconds: isError ? 5 : 4),
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
        siteVisits: _siteVisits,
        financialBidDocuments: _existingFinancialBidDocs,
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
        bqrRequirements: _bqrRequirements,
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

      final hasNewTenderDocs = _tenderNoticeFiles.isNotEmpty ||
          _tenderSpecFiles.isNotEmpty ||
          _bqrFiles.isNotEmpty ||
          _financialBidFiles.isNotEmpty;
      if (hasNewTenderDocs && _siteVisits.isEmpty) {
        _showToast(
          'Please record a Site Visit (photo, visited by, date & remarks) before uploading tender documents.',
          isError: true,
        );
        return;
      }

      final filesByCategory = <String, List<PlatformFile>>{
        'tender_notice': _tenderNoticeFiles,
        'tender_spec': _tenderSpecFiles,
        'bqr': _bqrFiles,
        'financial_bid': _financialBidFiles,
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
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF414A51),
                side: const BorderSide(color: Color(0xFF9CC70A), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: (_isSaving || _isAiAutoFilling)
                  ? null
                  : _uploadAndAutoFillWithAi,
              icon: _isAiAutoFilling
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF9CC70A)),
                    )
                  : const Icon(Icons.auto_awesome,
                      size: 16, color: Color(0xFF9CC70A)),
              label: Text(
                _isAiAutoFilling ? 'ANALYZING...' : 'AI AUTO-FILL',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
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
                  // AI AUTO-FILL BANNER
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF9CC70A),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF9CC70A).withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF9CC70A)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.auto_awesome,
                                  color: Color(0xFF414A51), size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'AI-Powered Tender Auto-Fill',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF414A51),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Upload a tender document (PDF, DOC, DOCX) to automatically extract and populate all 8 form sections.',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF718096)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF9CC70A),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: (_isSaving || _isAiAutoFilling)
                                  ? null
                                  : _uploadAndAutoFillWithAi,
                              icon: _isAiAutoFilling
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.document_scanner_outlined,
                                      size: 18),
                              label: Text(
                                _isAiAutoFilling
                                    ? 'ANALYZING DOCUMENT WITH AI...'
                                    : 'Upload Tender Document (AI Auto-Fill)',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const Text(
                              'Supported: PDF, DOC, DOCX (Max 20MB)',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF718096),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

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
                            minLines: 1,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            label: 'Client / Authority Name',
                            controller: _clientNameController,
                            hint: 'e.g. TNEB, TNPDCL, BHEL, etc.',
                            minLines: 1,
                            maxLines: 2,
                          ),
                        ] else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  label: 'Tender Title / Name *',
                                  controller: _titleController,
                                  hint: 'e.g. Substation Maintenance 2026',
                                  minLines: 1,
                                  maxLines: 3,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextField(
                                  label: 'Client / Authority Name',
                                  controller: _clientNameController,
                                  hint: 'e.g. TNEB, TNPDCL, BHEL, etc.',
                                  minLines: 1,
                                  maxLines: 2,
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
                                  onPressed: _isGeneratingTenderId
                                      ? null
                                      : () =>
                                          _generateTenderId(showFeedback: true),
                                  child: _isGeneratingTenderId
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF9CC70A),
                                          ),
                                        )
                                      : const Icon(Icons.auto_awesome,
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
                                        onPressed: _isGeneratingTenderId
                                            ? null
                                            : () => _generateTenderId(
                                                showFeedback: true),
                                        icon: _isGeneratingTenderId
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Color(0xFF9CC70A),
                                                ),
                                              )
                                            : const Icon(Icons.auto_awesome,
                                                size: 16,
                                                color: Color(0xFF9CC70A)),
                                        label: Text(
                                          _isGeneratingTenderId
                                              ? 'GENERATING...'
                                              : 'GENERATE',
                                          style: const TextStyle(
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

                  // SECTION 2.1: MANDATORY SITE VISIT (Pre-requisite for uploading tender)
                  _buildSectionCard(
                    sectionNumber: 'PRE-REQUISITE',
                    sectionTitle: 'SITE VISIT RECORD',
                    icon: Icons.camera_alt_outlined,
                    child: _buildSiteVisitSection(),
                  ),
                  const SizedBox(height: 18),

                  // SECTION 2.2: FINANCIAL BID UPLOAD
                  _buildSectionCard(
                    sectionNumber: 'FINANCIAL BID',
                    sectionTitle: 'FINANCIAL BID UPLOAD',
                    icon: Icons.monetization_on_outlined,
                    child: _buildFileUploadWidget(
                      label: 'Financial Bid Document (Must be uploaded first)',
                      files: _financialBidFiles,
                      existingDocs: _existingFinancialBidDocs,
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
                          minLines: 3,
                          maxLines: 8,
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
                          minLines: 2,
                          maxLines: 5,
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
                          minLines: 2,
                          maxLines: 5,
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
                          minLines: 3,
                          maxLines: 8,
                        ),
                        const SizedBox(height: 14),
                        _buildBqrLineItemsSection(),
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
                          minLines: 2,
                          maxLines: 5,
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
    return GestureDetector(
      onTap: onSelected,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
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
                size: 18,
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
    int? minLines,
    int? maxLines = 1,
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
          keyboardType: keyboardType ??
              (maxLines != 1 ? TextInputType.multiline : TextInputType.text),
          minLines: minLines ?? 1,
          maxLines: maxLines,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF2D3748),
            height: 1.45,
          ),
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

  Widget _buildSiteVisitSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _siteVisits.isEmpty
                    ? 'Required before uploading tender documents (auto date/time & location).'
                    : '${_siteVisits.length} site visit(s) recorded.',
                style: TextStyle(
                  fontSize: 12,
                  color: _siteVisits.isEmpty
                      ? const Color(0xFFB45309)
                      : const Color(0xFF16A34A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF9CC70A),
                foregroundColor: const Color(0xFF414A51),
              ),
              onPressed: _showAddSiteVisitDialog,
              icon: const Icon(Icons.add_a_photo_outlined, size: 16),
              label: const Text('Add Site Visit'),
            ),
          ],
        ),
        if (_siteVisits.isNotEmpty) ...[
          const SizedBox(height: 10),
          ..._siteVisits.map(
            (v) {
              final photos = v.allPhotos;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAF8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E8E2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.verified_outlined,
                            size: 18, color: Color(0xFF16A34A)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Visited by ${v.visitedBy} • ${DateFormat("dd-MM-yyyy hh:mm a").format(v.visitDateTime)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF414A51),
                                ),
                              ),
                              if (v.locationAddress.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    'Location: ${v.locationAddress}',
                                    style: const TextStyle(
                                        fontSize: 11, color: Color(0xFF718096)),
                                  ),
                                ),
                              if (v.latitude != null && v.longitude != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    'GPS: ${v.latitude!.toStringAsFixed(4)}, ${v.longitude!.toStringAsFixed(4)}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF9CC70A),
                                    ),
                                  ),
                                ),
                              if (v.remarks.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    v.remarks,
                                    style: const TextStyle(
                                        fontSize: 11, color: Color(0xFF414A51)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Photo count badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: photos.isNotEmpty
                                ? const Color(0xFF9CC70A).withOpacity(0.15)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: photos.isNotEmpty
                                  ? const Color(0xFF9CC70A).withOpacity(0.4)
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.photo_library_outlined,
                                size: 13,
                                color: photos.isNotEmpty
                                    ? const Color(0xFF414A51)
                                    : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                photos.isEmpty
                                    ? 'No photo'
                                    : '${photos.length} Photo${photos.length > 1 ? "s" : ""}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: photos.isNotEmpty
                                      ? const Color(0xFF414A51)
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: Colors.redAccent),
                          tooltip: 'Remove site visit',
                          onPressed: () {
                            setState(() {
                              _siteVisits.remove(v);
                            });
                          },
                        ),
                      ],
                    ),
                    // Thumbnails list
                    if (photos.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: photos.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final url = entry.value;
                          return Tooltip(
                            message: 'Click to preview photo #${idx + 1}',
                            child: _buildPhotoThumbnail(
                              url,
                              size: 56,
                              onTap: () => _showPhotoPreview(
                                context,
                                url,
                                'Site Visit Photo #${idx + 1} (${v.visitedBy})',
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildPhotoThumbnail(String url, {double size = 52, VoidCallback? onTap}) {
    Uint8List? memoryBytes;
    if (url.startsWith('data:')) {
      final comma = url.indexOf(',');
      final b64 = comma != -1 ? url.substring(comma + 1) : url;
      try {
        memoryBytes = base64Decode(b64);
      } catch (_) {}
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFCBD5E1)),
          color: const Color(0xFFF1F5F9),
        ),
        clipBehavior: Clip.antiAlias,
        child: memoryBytes != null
            ? Image.memory(memoryBytes, fit: BoxFit.cover)
            : (url.isNotEmpty
                ? Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      size: 20,
                      color: Color(0xFF94A3B8),
                    ),
                  )
                : const Icon(
                    Icons.image_outlined,
                    size: 20,
                    color: Color(0xFF94A3B8),
                  )),
      ),
    );
  }

  void _showPhotoPreview(BuildContext context, String url, String title) {
    Uint8List? memoryBytes;
    if (url.startsWith('data:')) {
      final comma = url.indexOf(',');
      final b64 = comma != -1 ? url.substring(comma + 1) : url;
      try {
        memoryBytes = base64Decode(b64);
      } catch (_) {}
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.photo_outlined, size: 20, color: Color(0xFF9CC70A)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF414A51),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  color: const Color(0xFF0F172A),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(8),
                  child: InteractiveViewer(
                    maxScale: 4.0,
                    child: memoryBytes != null
                        ? Image.memory(memoryBytes, fit: BoxFit.contain)
                        : (url.isNotEmpty
                            ? Image.network(
                                url,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Text('Unable to load photo', style: TextStyle(color: Colors.white70)),
                                ),
                              )
                            : const Center(
                                child: Text('No image data', style: TextStyle(color: Colors.white70)),
                              )),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddSiteVisitDialog() async {
    final visitedByCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    SelectedDestination? selectedDestination;
    List<PlatformFile> photoFiles = [];
    final visitTimestamp = DateTime.now();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> pickLocationOnMap() async {
            final result = await Navigator.of(context).push<SelectedDestination>(
              MaterialPageRoute(
                builder: (mapCtx) => DestinationMapPickerScreen(
                  initialDestination: selectedDestination,
                  primaryColor: const Color(0xFF9CC70A),
                  darkTextColor: const Color(0xFF414A51),
                ),
              ),
            );
            if (result != null) {
              setDialogState(() {
                selectedDestination = result;
                locationCtrl.text = result.fullDisplayText;
              });
            }
          }

          return AlertDialog(
            title: const Text('Record Site Visit'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Timestamp: ${DateFormat("dd-MM-yyyy hh:mm a").format(visitTimestamp)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF414A51),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: visitedByCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Visited By (Name) *',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Interactive Map Picker trigger card
                    InkWell(
                      onTap: pickLocationOnMap,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selectedDestination != null
                              ? const Color(0xFF9CC70A).withOpacity(0.08)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selectedDestination != null
                                ? const Color(0xFF9CC70A)
                                : const Color(0xFFCBD5E1),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: selectedDestination != null
                                    ? const Color(0xFF9CC70A).withOpacity(0.2)
                                    : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.location_on_rounded,
                                size: 22,
                                color: selectedDestination != null
                                    ? const Color(0xFF414A51)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedDestination != null
                                        ? (selectedDestination!.name.isNotEmpty
                                            ? selectedDestination!.name
                                            : 'Selected Location')
                                        : 'Site Location *',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: selectedDestination != null
                                          ? const Color(0xFF414A51)
                                          : const Color(0xFF475569),
                                    ),
                                  ),
                                  if (selectedDestination != null &&
                                      selectedDestination!.address.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      selectedDestination!.address,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  if (selectedDestination != null) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF9CC70A)
                                            .withOpacity(0.25),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Lat: ${selectedDestination!.latitude.toStringAsFixed(4)} | Lng: ${selectedDestination!.longitude.toStringAsFixed(4)}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF414A51),
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Search or pick location on map (GPS supported)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              selectedDestination != null
                                  ? Icons.edit_location_alt_outlined
                                  : Icons.map_outlined,
                              size: 20,
                              color: const Color(0xFF414A51),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: remarksCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Short Remarks *',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Photo upload with multiple image support & preview
                    OutlinedButton.icon(
                      onPressed: () async {
                        final res = await FilePicker.pickFiles(
                          type: FileType.image,
                          withData: true,
                          allowMultiple: true,
                        );
                        if (res != null && res.files.isNotEmpty) {
                          setDialogState(() {
                            photoFiles = [...photoFiles, ...res.files];
                          });
                        }
                      },
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: Text(
                        photoFiles.isEmpty
                            ? 'Select Site Visit Photo(s) *'
                            : 'Add More Photos (${photoFiles.length} selected)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (photoFiles.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Attached Photos (${photoFiles.length}):',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF414A51),
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: Colors.redAccent,
                            ),
                            onPressed: () => setDialogState(() => photoFiles.clear()),
                            child: const Text('Clear All', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 72,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: photoFiles.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (ctx, idx) {
                            final f = photoFiles[idx];
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                    color: const Color(0xFFF1F5F9),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: f.bytes != null
                                      ? Image.memory(f.bytes!, fit: BoxFit.cover)
                                      : const Center(
                                          child: Icon(Icons.image, size: 24, color: Color(0xFF94A3B8)),
                                        ),
                                ),
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: GestureDetector(
                                    onTap: () {
                                      setDialogState(() {
                                        photoFiles.removeAt(idx);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.redAccent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, size: 12, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF9CC70A),
                  foregroundColor: const Color(0xFF414A51),
                ),
                onPressed: () async {
                  if (visitedByCtrl.text.trim().isEmpty ||
                      remarksCtrl.text.trim().isEmpty ||
                      photoFiles.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill all required fields and attach at least one site visit photo.'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    return;
                  }
                  if (selectedDestination == null && locationCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select a site location on the map.'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    return;
                  }
                  Navigator.of(ctx).pop();

                  final uploadedUrls = <String>[];
                  for (final file in photoFiles) {
                    final doc = await ref
                        .read(tenderRepositoryProvider)
                        .uploadTenderAttachment(
                          _tenderIdController.text.trim(),
                          'site_visit',
                          file,
                        );
                    if (doc.downloadUrl.isNotEmpty) {
                      uploadedUrls.add(doc.downloadUrl);
                    }
                  }

                  if (!mounted) return;
                  setState(() {
                    _siteVisits.add(
                      SiteVisitRecord(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        tenderId: _tenderIdController.text.trim(),
                        photoUrl: uploadedUrls.isNotEmpty ? uploadedUrls.first : '',
                        photoUrls: uploadedUrls,
                        visitDateTime: visitTimestamp,
                        latitude: selectedDestination?.latitude,
                        longitude: selectedDestination?.longitude,
                        locationAddress: selectedDestination != null
                            ? selectedDestination!.fullDisplayText
                            : locationCtrl.text.trim(),
                        visitedBy: visitedByCtrl.text.trim(),
                        remarks: remarksCtrl.text.trim(),
                        createdAt: DateTime.now(),
                      ),
                    );
                  });
                },
                child: const Text('Save Site Visit'),
              ),
            ],
          );
        },
      ),
    );
  }

  List<BqrRequirementItem> _parseBqrRequirementsFromText(String rawText) {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) return const [];

    List<String> parts = trimmed
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (parts.length <= 1 && trimmed.contains(';')) {
      parts = trimmed
          .split(';')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();
    }

    final baseTs = DateTime.now().millisecondsSinceEpoch;
    final seen = <String>{};
    final items = <BqrRequirementItem>[];

    for (var i = 0; i < parts.length; i++) {
      final cleaned = parts[i]
          .replaceFirst(RegExp(r'^([•\-\*\u2022]+|\d+[\.\)]\s*|\([a-zA-Z0-9]+\)\s*|[a-zA-Z][\.\)]\s*)'), '')
          .trim();
      if (cleaned.isEmpty) continue;
      if (!seen.add(cleaned.toLowerCase())) continue;

      items.add(
        BqrRequirementItem(
          id: 'bqr_${baseTs}_$i',
          title: cleaned,
          status: 'pending',
        ),
      );
    }

    return items;
  }

  List<BqrRequirementItem> _mergeExtractedBqrRequirements(
    List<BqrRequirementItem> extracted,
  ) {
    final merged = List<BqrRequirementItem>.from(_bqrRequirements);
    final existingByTitle = <String, int>{
      for (var i = 0; i < merged.length; i++)
        merged[i].title.trim().toLowerCase(): i,
    };

    for (final item in extracted) {
      final key = item.title.trim().toLowerCase();
      if (key.isEmpty) continue;
      final existingIdx = existingByTitle[key];
      if (existingIdx != null) {
        final existing = merged[existingIdx];
        if (existing.description.isEmpty && item.description.isNotEmpty) {
          merged[existingIdx] = existing.copyWith(description: item.description);
        }
      } else {
        existingByTitle[key] = merged.length;
        merged.add(item);
      }
    }

    return merged;
  }

  Future<void> _uploadFilesForBqrItem(
    int index, {
    bool replaceAll = false,
    int? replaceDocIndex,
  }) async {
    if (index < 0 || index >= _bqrRequirements.length) return;
    final targetItem = _bqrRequirements[index];
    if (_uploadingBqrItemIds.contains(targetItem.id)) return;

    final res = await FilePicker.pickFiles(
      allowMultiple: replaceDocIndex == null,
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;

    setState(() => _uploadingBqrItemIds.add(targetItem.id));

    try {
      final repo = ref.read(tenderRepositoryProvider);
      final tenderId = _tenderIdController.text.trim();
      final category = 'bqr_${targetItem.id}';
      final uploadedDocs = <ProjectDocument>[];

      for (final file in res.files) {
        final doc = await repo.uploadTenderAttachment(
          tenderId,
          category,
          file,
        );
        uploadedDocs.add(doc);
      }

      if (!mounted) return;
      final currentIdx =
          _bqrRequirements.indexWhere((r) => r.id == targetItem.id);
      if (currentIdx == -1) return;

      final currentItem = _bqrRequirements[currentIdx];
      late final List<ProjectDocument> updatedDocs;

      if (replaceDocIndex != null &&
          replaceDocIndex >= 0 &&
          replaceDocIndex < currentItem.documents.length) {
        updatedDocs = List<ProjectDocument>.from(currentItem.documents);
        updatedDocs[replaceDocIndex] = uploadedDocs.first;
      } else if (replaceAll) {
        updatedDocs = uploadedDocs;
      } else {
        updatedDocs = [...currentItem.documents, ...uploadedDocs];
      }

      setState(() {
        _bqrRequirements[currentIdx] = currentItem.copyWith(
          documents: updatedDocs,
          status: updatedDocs.isNotEmpty ? 'uploaded' : 'pending',
        );
      });

      final isReplace = replaceAll || replaceDocIndex != null;
      _showToast(
        isReplace
            ? 'Updated document for "${currentItem.title}".'
            : 'Uploaded ${uploadedDocs.length} document(s) for "${currentItem.title}".',
      );
    } catch (e) {
      if (mounted) {
        _showToast('Failed to upload BQR document: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingBqrItemIds.remove(targetItem.id));
      }
    }
  }

  void _removeBqrItemDocument(int itemIndex, int docIndex) {
    if (itemIndex < 0 || itemIndex >= _bqrRequirements.length) return;
    final item = _bqrRequirements[itemIndex];
    if (docIndex < 0 || docIndex >= item.documents.length) return;

    final updatedDocs = List<ProjectDocument>.from(item.documents)
      ..removeAt(docIndex);
    setState(() {
      _bqrRequirements[itemIndex] = item.copyWith(
        documents: updatedDocs,
        status: updatedDocs.isNotEmpty ? 'uploaded' : 'pending',
      );
    });
  }

  Widget _buildBqrLineItemsSection() {
    final pendingCount = _bqrRequirements.where((r) => !r.isUploaded).length;
    final daysUntilClose = _closingDate?.difference(DateTime.now()).inDays;
    final showClosingReminder =
        daysUntilClose != null && daysUntilClose >= 0 && daysUntilClose <= 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showClosingReminder)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF59E0B)),
            ),
            child: Text(
              'Closing Reminder: $daysUntilClose day(s) left • $pendingCount pending BQR document(s).',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF92400E),
              ),
            ),
          ),
        Row(
          children: [
            const Expanded(
              child: Text(
                'BQR Line-Item Checklist',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF414A51),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final picked =
                    await CompanyDocumentPickerDialog.show(context);
                if (picked == null || picked.isEmpty || !mounted) return;
                setState(() {
                  for (final item in picked) {
                    final alreadyAdded = _existingBqrDocs.any(
                      (d) => d.storagePath == item.document.storagePath,
                    );
                    if (!alreadyAdded) {
                      _existingBqrDocs.add(item.document);
                    }
                  }
                });
                _showToast(
                  'Attached ${picked.length} document(s) from Company Vault.',
                );
              },
              icon: const Icon(Icons.folder_shared_outlined, size: 16),
              label: const Text('Vault'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () async {
                if (_bqrRequirements.isEmpty &&
                    _bqrRemarkController.text.trim().isNotEmpty) {
                  final parsed =
                      _parseBqrRequirementsFromText(_bqrRemarkController.text);
                  if (parsed.isNotEmpty) {
                    setState(() {
                      _bqrRequirements = parsed;
                    });
                  }
                }
                if (_bqrRequirements.isEmpty) {
                  _showToast(
                    'Add BQR items or run AI Auto-Fill first to fetch matching Vault documents.',
                  );
                  return;
                }
                final companyDocs =
                    ref.read(companyDocumentsStreamProvider).valueOrNull ??
                        await ref
                            .read(companyDocumentRepositoryProvider)
                            .getDocuments();
                if (!mounted) return;
                final previousCount = _bqrRequirements
                    .expand((r) => r.documents)
                    .length;
                setState(() {
                  _bqrRequirements =
                      matchCompanyDocsToBqr(_bqrRequirements, companyDocs);
                });
                final newCount = _bqrRequirements
                    .expand((r) => r.documents)
                    .length;
                final added = newCount - previousCount;
                if (companyDocs.isEmpty) {
                  _showToast(
                    'Company Vault is empty. Tap "Vault" to upload company documents.',
                    isError: true,
                  );
                } else if (added > 0) {
                  _showToast('AI attached $added document(s) from Company Vault to BQR items.');
                } else {
                  _showToast('No matching documents found in Vault for current BQR items.');
                }
              },
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('AI Fetch Docs'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF9CC70A),
                foregroundColor: const Color(0xFF414A51),
              ),
              onPressed: _showAddBqrRequirementDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add BQR Item'),
            ),
          ],
        ),
        if (_bqrRequirements.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...List.generate(_bqrRequirements.length, (index) {
            final item = _bqrRequirements[index];
            final isDone = item.isUploaded;
            final isUploading = _uploadingBqrItemIds.contains(item.id);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAF8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E8E2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF414A51),
                              ),
                            ),
                            if (item.description.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                item.description,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                            const SizedBox(height: 2),
                            Text(
                              item.documents.isEmpty
                                  ? 'No file uploaded'
                                  : '${item.documents.length} file(s) attached',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF718096),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (isDone
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFD97706))
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isDone ? 'Uploaded' : 'Pending',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDone
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFD97706),
                              ),
                            ),
                          ),
                          if (isUploading)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF9CC70A),
                              ),
                            )
                          else ...[
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF414A51),
                                side: const BorderSide(
                                    color: Color(0xFFCBD5E1)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              onPressed: () => _uploadFilesForBqrItem(index),
                              icon: const Icon(Icons.upload_file_rounded,
                                  size: 15),
                              label: const Text(
                                'Upload Document',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (item.documents.isNotEmpty)
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF414A51),
                                  side: const BorderSide(
                                      color: Color(0xFF9CC70A)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                onPressed: () => _uploadFilesForBqrItem(
                                  index,
                                  replaceAll: true,
                                ),
                                icon: const Icon(Icons.sync_rounded,
                                    size: 15, color: Color(0xFF9CC70A)),
                                label: const Text(
                                  'Replace Document',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  if (item.documents.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...List.generate(item.documents.length, (docIdx) {
                      final doc = item.documents[docIdx];
                      return Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.attach_file,
                                size: 15, color: Color(0xFF9CC70A)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                doc.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF2D3748),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'View Document',
                              icon: const Icon(Icons.visibility_outlined,
                                  size: 16, color: Color(0xFF414A51)),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () =>
                                  TenderDocumentActions.viewDocument(
                                      context, doc),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Download Document',
                              icon: const Icon(Icons.download_rounded,
                                  size: 16, color: Color(0xFF9CC70A)),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () =>
                                  TenderDocumentActions.downloadDocument(
                                      context, doc),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Replace Document',
                              icon: const Icon(Icons.sync_rounded,
                                  size: 16, color: Color(0xFF414A51)),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: isUploading
                                  ? null
                                  : () => _uploadFilesForBqrItem(
                                        index,
                                        replaceDocIndex: docIdx,
                                      ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Remove Document',
                              icon: const Icon(Icons.close,
                                  size: 16, color: Colors.red),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: isUploading
                                  ? null
                                  : () =>
                                      _removeBqrItemDocument(index, docIdx),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Future<void> _showAddBqrRequirementDialog() async {
    final titleCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add BQR Requirement'),
        content: TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(
            labelText: 'Requirement (e.g. ITR 3 Years, GST, Experience Cert)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = titleCtrl.text.trim();
              if (text.isEmpty) return;
              Navigator.of(ctx).pop();
              setState(() {
                _bqrRequirements.add(
                  BqrRequirementItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: text,
                    status: 'pending',
                  ),
                );
              });
            },
            child: const Text('Add'),
          ),
        ],
      ),
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
