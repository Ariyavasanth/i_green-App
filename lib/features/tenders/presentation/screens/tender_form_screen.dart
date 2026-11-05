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

class TenderFormScreen extends ConsumerStatefulWidget {
  const TenderFormScreen({super.key, this.tender});

  final Tender? tender;

  @override
  ConsumerState<TenderFormScreen> createState() => _TenderFormScreenState();
}

class _TenderFormScreenState extends ConsumerState<TenderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Tender Identification
  final _tenderIdController = TextEditingController();
  final _titleController = TextEditingController();
  final _clientNameController = TextEditingController();

  // Section 3: Tender Type
  String _tenderType = 'Open';
  String _qualified = 'Yes';
  final _tenderAmountController = TextEditingController();

  // Section 4: Tender Spec / Enquiry Spec
  final _tenderSpecRemarkController = TextEditingController();
  final List<PlatformFile> _tenderSpecFiles = [];
  List<ProjectDocument> _existingTenderSpecDocs = [];

  // Section 6: Opening Date
  final _openingDateRemarkController = TextEditingController();
  DateTime? _openingDate;

  // Section 7: Closing Date
  final _closingDateRemarkController = TextEditingController();
  DateTime? _closingDate;

  // Section 8: BQR
  final _bqrRemarkController = TextEditingController();
  final List<PlatformFile> _bqrFiles = [];
  List<ProjectDocument> _existingBqrDocs = [];

  // Section 9: EMD / EMD Exemption
  final _emdRemarkController = TextEditingController();
  final List<PlatformFile> _emdFiles = [];
  List<ProjectDocument> _existingEmdDocs = [];

  @override
  void initState() {
    super.initState();
    final t = widget.tender;
    if (t != null) {
      _tenderIdController.text = t.tenderId;
      _titleController.text = t.title;
      _clientNameController.text = t.clientName;
      _tenderType = t.tenderType.isNotEmpty ? t.tenderType : 'Open';
      _qualified = t.qualified.isNotEmpty ? t.qualified : 'Yes';
      if (t.tenderAmount > 0) {
        _tenderAmountController.text = t.tenderAmount.toStringAsFixed(2);
      }
      _tenderSpecRemarkController.text = t.tenderSpecRemark;
      _existingTenderSpecDocs = List.from(t.tenderSpecDocuments);
      _openingDate = t.openingDate;
      _openingDateRemarkController.text = t.openingDateRemark;
      _closingDate = t.closingDate;
      _closingDateRemarkController.text = t.closingDateRemark;
      _bqrRemarkController.text = t.bqrRemark;
      _existingBqrDocs = List.from(t.bqrDocuments);
      _emdRemarkController.text = t.emdRemark;
      _existingEmdDocs = List.from(t.emdDocuments);
    } else {
      _generateTenderId();
    }
  }

  Future<void> _generateTenderId() async {
    final nextId = await ref.read(tenderRepositoryProvider).generateNextTenderId();
    if (mounted) {
      setState(() {
        _tenderIdController.text = nextId;
      });
    }
  }

  @override
  void dispose() {
    _tenderIdController.dispose();
    _titleController.dispose();
    _clientNameController.dispose();
    _tenderAmountController.dispose();
    _tenderSpecRemarkController.dispose();
    _openingDateRemarkController.dispose();
    _closingDateRemarkController.dispose();
    _bqrRemarkController.dispose();
    _emdRemarkController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles(List<PlatformFile> targetList,
      {List<ProjectDocument>? existingDocs}) async {
    final remaining = 5 - (existingDocs?.length ?? 0) - targetList.length;
    if (remaining <= 0) {
      _showToast('You can upload a maximum of 5 files.');
      return;
    }

    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      withData: true,
    );

    if (result != null) {
      final allowed = result.files.take(remaining).toList();
      setState(() {
        targetList.addAll(allowed);
      });
    }
  }

  Future<void> _pickDate(
      BuildContext context, DateTime? initial, ValueChanged<DateTime?> onSelected) async {
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

  void _showToast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF414A51),
      ),
    );
  }

  Future<void> _saveTender() async {
    if (_tenderIdController.text.trim().isEmpty) {
      _showToast('Please generate or enter a Tender ID', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final currentEmp = ref.read(currentEmployeeProvider);
      final createdByName = currentEmp?.firstName ?? '';

      final tender = Tender(
        id: widget.tender?.id ?? '',
        tenderId: _tenderIdController.text.trim(),
        title: _titleController.text.trim(),
        clientName: _clientNameController.text.trim(),
        tenderType: _tenderType,
        qualified: _qualified,
        tenderAmount: double.tryParse(_tenderAmountController.text.trim()) ?? 0.0,
        tenderSpecRemark: _tenderSpecRemarkController.text.trim(),
        tenderSpecDocuments: _existingTenderSpecDocs,
        openingDate: _openingDate,
        openingDateRemark: _openingDateRemarkController.text.trim(),
        closingDate: _closingDate,
        closingDateRemark: _closingDateRemarkController.text.trim(),
        bqrRemark: _bqrRemarkController.text.trim(),
        bqrDocuments: _existingBqrDocs,
        emdRemark: _emdRemarkController.text.trim(),
        emdDocuments: _existingEmdDocs,
        createdAt: widget.tender?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: widget.tender?.createdBy ?? createdByName,
      );

      final filesByCategory = <String, List<PlatformFile>>{
        'tender_spec': _tenderSpecFiles,
        'bqr': _bqrFiles,
        'emd': _emdFiles,
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
                  // Section: TENDER IDENTIFICATION
                  _buildSectionCard(
                    sectionNumber: 'SECTION 1',
                    sectionTitle: 'TENDER IDENTIFICATION',
                    icon: Icons.vpn_key_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isMobile) ...[
                          _buildTextField(
                            label: 'Tender Title / Name',
                            controller: _titleController,
                            hint: 'e.g. Substation Maintenance 2026',
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            label: 'Client / Authority Name',
                            controller: _clientNameController,
                            hint: 'e.g. TNEB, BHEL, etc.',
                          ),
                        ] else
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  label: 'Tender Title / Name',
                                  controller: _titleController,
                                  hint: 'e.g. Substation Maintenance 2026',
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextField(
                                  label: 'Client / Authority Name',
                                  controller: _clientNameController,
                                  hint: 'e.g. TNEB, BHEL, etc.',
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),
                        // Tender ID action row
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                label: 'Tender ID *',
                                controller: _tenderIdController,
                                hint: 'e.g. TE-2026-0001',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Padding(
                              padding: const EdgeInsets.only(top: 22),
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF414A51),
                                  side: const BorderSide(
                                      color: Color(0xFF9CC70A), width: 1.5),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: _generateTenderId,
                                icon: const Icon(Icons.auto_awesome,
                                    size: 16, color: Color(0xFF9CC70A)),
                                label: const Text(
                                  'GENERATE ID',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Section 3: TENDER TYPE (Reference Screenshot 2)
                  _buildSectionCard(
                    sectionNumber: 'SECTION 3',
                    sectionTitle: 'TENDER TYPE',
                    icon: Icons.assignment_outlined,
                    child: isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppSearchableDropdown<String>(
                                label: 'Tender Type',
                                value: _tenderType,
                                items: const ['Open', 'Close', 'Limited', 'Single'],
                                onChanged: (val) {
                                  if (val != null) setState(() => _tenderType = val);
                                },
                              ),
                              const SizedBox(height: 14),
                              AppSearchableDropdown<String>(
                                label: 'Qualified',
                                value: _qualified,
                                items: const ['Yes', 'No'],
                                onChanged: (val) {
                                  if (val != null) setState(() => _qualified = val);
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildTextField(
                                label: 'Tender Amount',
                                controller: _tenderAmountController,
                                hint: 'Enter amount',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                                  items: const ['Open', 'Close', 'Limited', 'Single'],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _tenderType = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: AppSearchableDropdown<String>(
                                  label: 'Qualified',
                                  value: _qualified,
                                  items: const ['Yes', 'No'],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _qualified = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextField(
                                  label: 'Tender Amount',
                                  controller: _tenderAmountController,
                                  hint: 'Enter amount',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 18),

                  // Section 4: TENDER SPEC / ENQUIRY SPEC (Reference Screenshot 2)
                  _buildSectionCard(
                    sectionNumber: 'SECTION 4',
                    sectionTitle: 'TENDER SPEC / ENQUIRY SPEC',
                    icon: Icons.description_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          label: '',
                          controller: _tenderSpecRemarkController,
                          hint: 'Remark Text',
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

                  // Section 6: OPENING DATE (Reference Screenshot 3)
                  _buildSectionCard(
                    sectionNumber: 'SECTION 6',
                    sectionTitle: 'OPENING DATE',
                    icon: Icons.calendar_today_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          label: '',
                          controller: _openingDateRemarkController,
                          hint: 'Remark Text',
                        ),
                        const SizedBox(height: 14),
                        _buildDatePickerField(
                          label: 'Opening Date',
                          date: _openingDate,
                          onTap: () => _pickDate(
                            context,
                            _openingDate,
                            (d) => setState(() => _openingDate = d),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Section 7: CLOSING DATE (Reference Screenshot 3)
                  _buildSectionCard(
                    sectionNumber: 'SECTION 7',
                    sectionTitle: 'CLOSING DATE',
                    icon: Icons.event_busy_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          label: '',
                          controller: _closingDateRemarkController,
                          hint: 'Remark Text',
                        ),
                        const SizedBox(height: 14),
                        _buildDatePickerField(
                          label: 'Closing Date',
                          date: _closingDate,
                          onTap: () => _pickDate(
                            context,
                            _closingDate,
                            (d) => setState(() => _closingDate = d),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Section 8: BQR (Reference Screenshot 3)
                  _buildSectionCard(
                    sectionNumber: 'SECTION 8',
                    sectionTitle: 'BQR',
                    icon: Icons.fact_check_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          label: '',
                          controller: _bqrRemarkController,
                          hint: 'Remark Text',
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

                  // Section 9: EMD / EMD EXEMPTION (Reference Screenshot 3)
                  _buildSectionCard(
                    sectionNumber: 'SECTION 9',
                    sectionTitle: 'EMD / EMD EXEMPTION',
                    icon: Icons.account_balance_wallet_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          label: '',
                          controller: _emdRemarkController,
                          hint: 'Remark Text',
                        ),
                        const SizedBox(height: 14),
                        _buildFileUploadWidget(
                          label: 'EMD Documents',
                          files: _emdFiles,
                          existingDocs: _existingEmdDocs,
                        ),
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

  Widget _buildFileUploadWidget({
    required String label,
    required List<PlatformFile> files,
    List<ProjectDocument>? existingDocs,
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
              onPressed: () => _pickFiles(files, existingDocs: existingDocs),
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text('Upload Documents',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
        const Text(
          'Supported: PDF, Word, Excel, PNG, JPG (Max 5 files, 10MB each)',
          style: TextStyle(fontSize: 11, color: Color(0xFF718096)),
        ),
        if (existingDocs != null && existingDocs.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final doc in existingDocs)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAF8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E8E2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file_outlined,
                      size: 16, color: Color(0xFF9CC70A)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      doc.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.red),
                    onPressed: () =>
                        setState(() => existingDocs.remove(doc)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
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

