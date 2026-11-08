import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../employee/domain/employee.dart';
import '../../../employee/providers/employee_providers.dart';
import '../../domain/models/deduction_entry.dart';
import '../../domain/models/project_breakdown_item.dart';
import '../../domain/models/project_budget.dart';
import '../../domain/models/project_document.dart';
import '../../domain/models/site_project.dart';
import '../../domain/models/tender_description_item.dart';
import '../../providers/project_providers.dart';
import '../dialogs/project_audit_history_dialog.dart';
import '../screens/project_budget_screen.dart';

// ─── Scope of work equipment/resource catalog ───
const List<Map<String, dynamic>> _kScopeCatalog = [
  {'key': 'hdd', 'label': 'HDD', 'icon': Icons.precision_manufacturing_outlined},
  {'key': 'excavatorsSmall', 'label': 'Excavators (Small)', 'icon': Icons.agriculture_outlined},
  {'key': 'hydraSmall', 'label': 'Hydra (Small)', 'icon': Icons.construction_outlined},
  {'key': 'hydraBig', 'label': 'Hydra (Big)', 'icon': Icons.construction},
  {'key': 'generator', 'label': 'Generator', 'icon': Icons.bolt_outlined},
  {'key': 'weldingMachine', 'label': 'Welding Machine', 'icon': Icons.flash_on_outlined},
  {'key': 'grindingMachine', 'label': 'Grinding Machine', 'icon': Icons.handyman_outlined},
  {'key': 'clamp', 'label': 'Clamp', 'icon': Icons.hardware_outlined},
  {'key': 'rollersSmall', 'label': 'Rollers (Small)', 'icon': Icons.circle_outlined},
  {'key': 'rollersBig', 'label': 'Rollers (Big)', 'icon': Icons.album_outlined},
  {'key': 'cradels', 'label': 'Cradles', 'icon': Icons.view_sidebar_outlined},
  {'key': 'drumStands', 'label': 'Drum Stands', 'icon': Icons.table_restaurant_outlined},
  {'key': 'winchMachine', 'label': 'Winch Machine', 'icon': Icons.settings_suggest_outlined},
  {'key': 'manPower', 'label': 'Manpower', 'icon': Icons.groups_outlined},
];

class EditProjectFormScreen extends ConsumerStatefulWidget {
  const EditProjectFormScreen({
    super.key,
    this.project,
    this.projectId,
  });

  final SiteProject? project;
  final String? projectId;

  @override
  ConsumerState<EditProjectFormScreen> createState() =>
      _EditProjectFormScreenState();
}

class _EditProjectFormScreenState extends ConsumerState<EditProjectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  bool _isSubmitting = false;
  SiteProject? _loadedProject;

  // ─── Metadata State ───
  String _lastUpdatedEmployee = '';
  String _lastUpdatedEmployeeId = '';
  DateTime? _lastUpdatedDate;

  // ─── SD Agreement & Work Commencement ───
  final _sdAmountCtrl = TextEditingController();
  final _sdAgreementNoCtrl = TextEditingController();
  DateTime? _sdAgreementDate;
  DateTime? _siteHandoverDate;
  DateTime? _workStartDate;
  DateTime? _targetCompletionDate;

  // ─── Supply Items (Materials) ───
  final List<ProjectBreakdownItem> _supplyItems = [];
  final _supplyDescCtrl = TextEditingController();
  final _supplyUnitCtrl = TextEditingController();
  final _supplyQtyCtrl = TextEditingController();
  final _supplyRateCtrl = TextEditingController();
  final _supplyAmountCtrl = TextEditingController();

  // ─── Service Items (Works) ───
  final List<ProjectBreakdownItem> _serviceItems = [];
  final _serviceDescCtrl = TextEditingController();
  final _serviceUnitCtrl = TextEditingController();
  final _serviceQtyCtrl = TextEditingController();
  final _serviceRateCtrl = TextEditingController();
  final _serviceAmountCtrl = TextEditingController();

  // ─── Section 1: Tender & Assignment ───
  String _qualified = 'Yes';
  String _selectedTenderType = '';
  final _tenderAmountCtrl = TextEditingController();
  final _approximateProjectValueCtrl = TextEditingController();
  final _actualProjectValueCtrl = TextEditingController();

  final _tenderSpecRemarkCtrl = TextEditingController();
  final List<PlatformFile> _tenderSpecFiles = [];
  List<ProjectDocument> _existingTenderSpecDocs = [];

  final List<TenderDescriptionItem> _tenderDescriptions = [];
  final _tdDescCtrl = TextEditingController();
  final _tdUnitCtrl = TextEditingController();
  final _tdQtyCtrl = TextEditingController();
  final _tdRateCtrl = TextEditingController();
  final _tdAmountCtrl = TextEditingController();

  final List<Employee> _selectedAssignedEmployees = [];
  bool _assignedInitialized = false;

  // ─── Section 2: Key Dates & Documents ───
  final _openingDateRemarkCtrl = TextEditingController();
  DateTime? _openingDate;

  final _closingDateRemarkCtrl = TextEditingController();
  DateTime? _closingDate;

  final _bqrRemarkCtrl = TextEditingController();
  final List<PlatformFile> _bqrFiles = [];
  List<ProjectDocument> _existingBqrDocs = [];

  final _emdRemarkCtrl = TextEditingController();
  final List<PlatformFile> _emdFiles = [];
  List<ProjectDocument> _existingEmdDocs = [];

  final _tenderLostRemarkCtrl = TextEditingController();
  String _tenderLostStatus = '';
  final _competitorNameCtrl = TextEditingController();
  final _quotedAmountCtrl = TextEditingController();
  final List<PlatformFile> _tenderLostFiles = [];
  List<ProjectDocument> _existingTenderLostDocs = [];

  // ─── Section 3: Technical Execution & Specs ───
  final _sdDateRemarkCtrl = TextEditingController();
  final List<PlatformFile> _sdDateFiles = [];
  List<ProjectDocument> _existingSdDateDocs = [];

  final _boqRemarkCtrl = TextEditingController();
  final List<PlatformFile> _boqFiles = [];
  List<ProjectDocument> _existingBoqDocs = [];

  final _projectDetailsRemarkCtrl = TextEditingController();
  final List<PlatformFile> _projectDetailsFiles = [];
  List<ProjectDocument> _existingProjectDetailsDocs = [];

  final _workOrderRemarkCtrl = TextEditingController();
  final List<PlatformFile> _workOrderFiles = [];
  List<ProjectDocument> _existingWorkOrderDocs = [];

  final _profileDrawingRemarkCtrl = TextEditingController();
  final _profileDrawingDocCtrl = TextEditingController();
  final List<PlatformFile> _profileDrawingFiles = [];
  List<ProjectDocument> _existingProfileDrawingDocs = [];

  final _agreementRemarkCtrl = TextEditingController();
  final List<PlatformFile> _agreementFiles = [];
  List<ProjectDocument> _existingAgreementDocs = [];

  final _supplyMaterialsRemarkCtrl = TextEditingController();
  final List<PlatformFile> _supplyMaterialsFiles = [];
  List<ProjectDocument> _existingSupplyMaterialsDocs = [];

  String _subContract = 'No';
  final _scopeOfWorkRemarkCtrl = TextEditingController();
  final Set<String> _scopeItems = {};
  final _otherScopeCtrl = TextEditingController();
  final _ownMachineRemarkCtrl = TextEditingController();
  String _ownOrSubcontract = '';

  // ─── Section 4: Billing, Payments & Retentions ───
  final _billingDetailsRemarkCtrl = TextEditingController();
  final List<PlatformFile> _billingDetailsFiles = [];
  List<ProjectDocument> _existingBillingDetailsDocs = [];

  final _flowOfBillsRemarkCtrl = TextEditingController();
  String _flowOfBillsStatus = '';

  final _paymentRemarkCtrl = TextEditingController();
  final _paymentAmountCtrl = TextEditingController();
  String _deductionType = '';
  final _deductionAmountCtrl = TextEditingController();
  final List<DeductionEntry> _deductions = [];

  final _emdRetentionRemarkCtrl = TextEditingController();
  final _emdRetentionAmountCtrl = TextEditingController();
  DateTime? _emdRetentionDate;
  final List<PlatformFile> _emdRetentionFiles = [];
  List<ProjectDocument> _existingEmdRetentionDocs = [];

  final _sdRetentionRemarkCtrl = TextEditingController();
  final _sdRetentionAmountCtrl = TextEditingController();
  DateTime? _sdRetentionDate;
  final List<PlatformFile> _sdRetentionFiles = [];
  List<ProjectDocument> _existingSdRetentionDocs = [];

  final _otherRetentionRemarkCtrl = TextEditingController();
  final _otherRetentionAmountCtrl = TextEditingController();
  DateTime? _otherRetentionDate;
  final _otherRetentionDocLabelCtrl = TextEditingController();
  final List<PlatformFile> _otherRetentionFiles = [];
  List<ProjectDocument> _existingOtherRetentionDocs = [];

  // Dropdown options
  static const List<String> _qualifiedOptions = ['Yes', 'No', 'Exempted'];
  static const List<String> _tenderLostOptions = [
    '',
    'Won',
    'Lost',
    'Cancelled',
    'In Progress',
  ];
  static const List<String> _flowOfBillsOptions = [
    '',
    'JE',
    'AE',
    'AD',
    'DE',
    'SE',
    'CE',
    'MM',
    'DFC',
    'APS',
    'DO',
    'AO',
    'Cash',
  ];
  static const List<String> _ownOrSubcontractOptions = [
    '',
    'Own Machine',
    'Subcontract',
    'Both',
  ];
  static const List<String> _deductionTypeOptions = [
    '',
    'TDS',
    'GST',
    'Retention',
    'LD',
    'EMD',
    'SD',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.project != null) {
      _loadedProject = widget.project;
      _populateFromProject(widget.project!);
    } else if (widget.projectId != null && widget.projectId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final p = await ref
            .read(projectRepositoryProvider)
            .getProjectById(widget.projectId!);
        if (p != null && mounted) {
          setState(() {
            _loadedProject = p;
            _populateFromProject(p);
          });
        }
      });
    }
  }

  void _populateFromProject(SiteProject p) {
    _lastUpdatedEmployee = p.updatedByName ?? p.employeeName;
    _lastUpdatedEmployeeId = p.updatedBy ?? p.employeeId ?? '';
    _lastUpdatedDate = p.updatedAt;

    _qualified = p.qualified.isNotEmpty ? p.qualified : 'Yes';
    _selectedTenderType = p.tenderType;
    _tenderAmountCtrl.text =
        p.tenderAmount > 0 ? (p.tenderAmount % 1 == 0 ? p.tenderAmount.toInt().toString() : p.tenderAmount.toString()) : '';
    _approximateProjectValueCtrl.text = p.approximateProjectValue > 0
        ? (p.approximateProjectValue % 1 == 0
            ? p.approximateProjectValue.toInt().toString()
            : p.approximateProjectValue.toString())
        : '';
    _actualProjectValueCtrl.text = p.actualProjectValue > 0
        ? (p.actualProjectValue % 1 == 0
            ? p.actualProjectValue.toInt().toString()
            : p.actualProjectValue.toString())
        : '';

    _tenderSpecRemarkCtrl.text = p.tenderSpecRemark;
    _existingTenderSpecDocs = List.from(p.tenderSpecDocuments);

    _tenderDescriptions.addAll(p.tenderDescriptions);

    _openingDate = p.openingDate;
    _openingDateRemarkCtrl.text = p.openingDateRemark;

    _closingDate = p.closingDate;
    _closingDateRemarkCtrl.text = p.closingDateRemark;

    _bqrRemarkCtrl.text = p.bqrRemark;
    _existingBqrDocs = List.from(p.bqrDocuments);

    _emdRemarkCtrl.text = p.emdRemark;
    _existingEmdDocs = List.from(p.emdDocuments);

    _tenderLostRemarkCtrl.text = p.tenderLostRemark;
    _tenderLostStatus = p.tenderLostStatus;
    _competitorNameCtrl.text = p.competitorName;
    _quotedAmountCtrl.text =
        p.quotedAmount > 0 ? p.quotedAmount.toString() : '';
    _existingTenderLostDocs = List.from(p.tenderLostDocuments);

    _sdDateRemarkCtrl.text = p.sdDateRemark;
    _existingSdDateDocs = List.from(p.sdDateDocuments);
    _sdAmountCtrl.text = p.sdAmount > 0
        ? (p.sdAmount % 1 == 0
            ? p.sdAmount.toInt().toString()
            : p.sdAmount.toString())
        : '';
    _sdAgreementNoCtrl.text = p.sdAgreementNo;
    _sdAgreementDate = p.sdAgreementDate;

    _siteHandoverDate = p.siteHandoverDate;
    _workStartDate = p.workStartDate;
    _targetCompletionDate = p.targetCompletionDate;

    _supplyItems.clear();
    _supplyItems.addAll(p.breakdownMaterials);

    _serviceItems.clear();
    _serviceItems.addAll(p.breakdownServices);
    if (_serviceItems.isEmpty && p.tenderDescriptions.isNotEmpty) {
      for (final td in p.tenderDescriptions) {
        _serviceItems.add(ProjectBreakdownItem.create(
          description: td.description,
          unit: td.unit,
          quantity: td.quantity,
          rate: td.rate,
          type: BreakdownItemType.service,
        ));
      }
    }

    _boqRemarkCtrl.text = p.boqRemark;
    _existingBoqDocs = List.from(p.boqDocuments);

    _projectDetailsRemarkCtrl.text = p.projectDetailsRemark;
    _existingProjectDetailsDocs = List.from(p.projectDetailsDocuments);

    _workOrderRemarkCtrl.text = p.workOrderRemark;
    _existingWorkOrderDocs = List.from(p.workOrderDocuments);

    _profileDrawingRemarkCtrl.text = p.profileDrawingRemark;
    _existingProfileDrawingDocs = List.from(p.profileDrawingDocuments);

    _agreementRemarkCtrl.text = p.agreementRemark;
    _existingAgreementDocs = List.from(p.agreementDocuments);

    _supplyMaterialsRemarkCtrl.text = p.supplyMaterialsRemark;
    _existingSupplyMaterialsDocs = List.from(p.supplyMaterialsDocuments);

    _subContract = p.subContract.isNotEmpty ? p.subContract : 'No';

    _scopeOfWorkRemarkCtrl.text = p.scopeOfWorkRemark;
    _scopeItems.addAll(p.scopeItems);
    _otherScopeCtrl.text = p.otherScope;

    _ownMachineRemarkCtrl.text = p.ownMachineRemark;
    _ownOrSubcontract = p.ownOrSubcontract;

    _billingDetailsRemarkCtrl.text = p.billingDetailsRemark;
    _existingBillingDetailsDocs = List.from(p.billingDetailsDocuments);

    _flowOfBillsRemarkCtrl.text = p.flowOfBillsRemark;
    _flowOfBillsStatus = p.flowOfBillsStatus;

    _paymentRemarkCtrl.text = p.paymentReceivedRemark;
    _paymentAmountCtrl.text =
        p.paymentAmount > 0 ? p.paymentAmount.toString() : '';
    _deductions.addAll(p.deductions);

    _emdRetentionRemarkCtrl.text = p.emdRetentionRemark;
    _emdRetentionAmountCtrl.text =
        p.emdRetentionAmount > 0 ? p.emdRetentionAmount.toString() : '';
    _emdRetentionDate = p.emdRetentionDate;
    _existingEmdRetentionDocs = List.from(p.emdRetentionDocuments);

    _sdRetentionRemarkCtrl.text = p.sdRetentionRemark;
    _sdRetentionAmountCtrl.text =
        p.sdRetentionAmount > 0 ? p.sdRetentionAmount.toString() : '';
    _sdRetentionDate = p.sdRetentionDate;
    _existingSdRetentionDocs = List.from(p.sdRetentionDocuments);

    _otherRetentionRemarkCtrl.text = p.otherRetentionRemark;
    _otherRetentionAmountCtrl.text =
        p.otherRetentionAmount > 0 ? p.otherRetentionAmount.toString() : '';
    _otherRetentionDate = p.otherRetentionDate;
    _otherRetentionDocLabelCtrl.text = p.otherRetentionDocumentLabel;
    _existingOtherRetentionDocs = List.from(p.otherRetentionDocuments);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tenderAmountCtrl.dispose();
    _approximateProjectValueCtrl.dispose();
    _actualProjectValueCtrl.dispose();
    _tenderSpecRemarkCtrl.dispose();
    _tdDescCtrl.dispose();
    _tdUnitCtrl.dispose();
    _tdQtyCtrl.dispose();
    _tdRateCtrl.dispose();
    _tdAmountCtrl.dispose();
    _openingDateRemarkCtrl.dispose();
    _closingDateRemarkCtrl.dispose();
    _bqrRemarkCtrl.dispose();
    _emdRemarkCtrl.dispose();
    _tenderLostRemarkCtrl.dispose();
    _competitorNameCtrl.dispose();
    _quotedAmountCtrl.dispose();
    _sdDateRemarkCtrl.dispose();
    _sdAmountCtrl.dispose();
    _sdAgreementNoCtrl.dispose();
    _supplyDescCtrl.dispose();
    _supplyUnitCtrl.dispose();
    _supplyQtyCtrl.dispose();
    _supplyRateCtrl.dispose();
    _supplyAmountCtrl.dispose();
    _serviceDescCtrl.dispose();
    _serviceUnitCtrl.dispose();
    _serviceQtyCtrl.dispose();
    _serviceRateCtrl.dispose();
    _serviceAmountCtrl.dispose();
    _boqRemarkCtrl.dispose();
    _projectDetailsRemarkCtrl.dispose();
    _workOrderRemarkCtrl.dispose();
    _profileDrawingRemarkCtrl.dispose();
    _profileDrawingDocCtrl.dispose();
    _agreementRemarkCtrl.dispose();
    _supplyMaterialsRemarkCtrl.dispose();
    _scopeOfWorkRemarkCtrl.dispose();
    _otherScopeCtrl.dispose();
    _ownMachineRemarkCtrl.dispose();
    _billingDetailsRemarkCtrl.dispose();
    _flowOfBillsRemarkCtrl.dispose();
    _paymentRemarkCtrl.dispose();
    _paymentAmountCtrl.dispose();
    _deductionAmountCtrl.dispose();
    _emdRetentionRemarkCtrl.dispose();
    _emdRetentionAmountCtrl.dispose();
    _sdRetentionRemarkCtrl.dispose();
    _sdRetentionAmountCtrl.dispose();
    _otherRetentionRemarkCtrl.dispose();
    _otherRetentionAmountCtrl.dispose();
    _otherRetentionDocLabelCtrl.dispose();
    super.dispose();
  }

  bool get _isMobile => MediaQuery.sizeOf(context).width < 768;

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF414A51),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _pickFiles(
    List<PlatformFile> target, {
    List<ProjectDocument>? existing,
  }) async {
    try {
      final result =
          await FilePicker.pickFiles(allowMultiple: true, withData: true);
      if (result == null) return;
      final existingCount = (existing?.length ?? 0) + target.length;
      final remaining = 5 - existingCount;
      if (remaining <= 0) {
        _toast('Maximum 5 files allowed.', isError: true);
        return;
      }
      final valid = <PlatformFile>[];
      for (final f in result.files) {
        if (f.size > 10 * 1024 * 1024) {
          _toast('${f.name} exceeds 10 MB limit.', isError: true);
          continue;
        }
        valid.add(f);
      }
      setState(() => target.addAll(valid.take(remaining)));
    } catch (e) {
      _toast('Could not pick files: $e', isError: true);
    }
  }

  Future<void> _pickDate({
    required DateTime? current,
    required void Function(DateTime) onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF9CC70A),
            onPrimary: Colors.white,
            onSurface: Color(0xFF414A51),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) onPicked(picked);
  }

  void _previewFile({
    required String name,
    String? url,
    Uint8List? bytes,
    int? size,
    bool isLocal = false,
  }) {
    final lower = name.toLowerCase();
    final isImage = lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 600),
          child: Container(
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  color: const Color(0xFF414A51),
                  child: Row(
                    children: [
                      Icon(
                        isImage
                            ? Icons.image_outlined
                            : Icons.description_outlined,
                        color: const Color(0xFF9CC70A),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (url != null && url.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.open_in_new_rounded,
                              color: Colors.white70, size: 20),
                          tooltip: 'Open in Browser / External App',
                          onPressed: () async {
                            final uri = Uri.tryParse(url);
                            if (uri != null) {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white70, size: 20),
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                // Body
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Center(
                      child: isImage
                          ? (bytes != null
                              ? Image.memory(bytes, fit: BoxFit.contain)
                              : (url != null && url.isNotEmpty
                                  ? Image.network(
                                      url,
                                      fit: BoxFit.contain,
                                      loadingBuilder: (c, w, p) => p == null
                                          ? w
                                          : const CircularProgressIndicator(
                                              color: Color(0xFF9CC70A)),
                                      errorBuilder: (ctx, err, stack) =>
                                          const Text(
                                              'Could not load image preview.'),
                                    )
                                  : const Text('No image data available.')))
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  lower.endsWith('.pdf')
                                      ? Icons.picture_as_pdf_rounded
                                      : Icons.insert_drive_file_rounded,
                                  size: 64,
                                  color: const Color(0xFF414A51),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (size != null && size > 0)
                                  Text(
                                    'File Size: ${(size / 1024).toStringAsFixed(1)} KB',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600),
                                  ),
                                const SizedBox(height: 18),
                                if (url != null && url.isNotEmpty)
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      final uri = Uri.tryParse(url);
                                      if (uri != null) {
                                        await launchUrl(uri,
                                            mode: LaunchMode
                                                .externalApplication);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF414A51),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 12),
                                    ),
                                    icon: const Icon(Icons.download_rounded,
                                        size: 18),
                                    label: const Text('Open / Download File'),
                                  )
                                else if (isLocal)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF9CC70A)
                                          .withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: const Color(0xFF9CC70A)),
                                    ),
                                    child: const Text(
                                      'This file has been selected from your device. It will be uploaded to cloud storage when you update the project.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF2E3811),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleUpdate() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      _toast('Please review required fields before submitting.', isError: true);
      return;
    }
    if (_loadedProject == null) {
      _toast('Project data not loaded yet.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final currentEmp = ref.read(currentEmployeeProvider);

      final updatedProject = _loadedProject!.copyWith(
        tenderType: _selectedTenderType.isNotEmpty
            ? _selectedTenderType
            : _loadedProject!.tenderType,
        qualified:
            _qualified.isNotEmpty ? _qualified : _loadedProject!.qualified,
        tenderAmount: double.tryParse(_tenderAmountCtrl.text.trim()) ??
            _loadedProject!.tenderAmount,
        approximateProjectValue:
            double.tryParse(_approximateProjectValueCtrl.text.trim()) ?? 0.0,
        actualProjectValue:
            double.tryParse(_actualProjectValueCtrl.text.trim()) ?? 0.0,
        sdAmount: double.tryParse(_sdAmountCtrl.text.trim()) ?? 0.0,
        sdAgreementNo: _sdAgreementNoCtrl.text.trim(),
        sdAgreementDate: _sdAgreementDate,
        siteHandoverDate: _siteHandoverDate,
        workStartDate: _workStartDate,
        targetCompletionDate: _targetCompletionDate,
        breakdownMaterials: List.from(_supplyItems),
        breakdownServices: List.from(_serviceItems),
        tenderDescriptions: _serviceItems.isNotEmpty
            ? _serviceItems
                .map<TenderDescriptionItem>((s) => TenderDescriptionItem(
                      description: s.description,
                      unit: s.unit,
                      quantity: s.quantity,
                      rate: s.rate,
                      amount: s.amount,
                    ))
                .toList()
            : List<TenderDescriptionItem>.from(_tenderDescriptions),
        tenderSpecRemark: _tenderSpecRemarkCtrl.text.trim(),
        tenderSpecDocuments: _existingTenderSpecDocs,
        assignedToEmployeeNames:
            _selectedAssignedEmployees.map((e) => e.fullName).toList(),
        assignedToEmployeeIds:
            _selectedAssignedEmployees.map((e) => e.employeeId).toList(),
        assignedToEmployeeName:
            _selectedAssignedEmployees.map((e) => e.fullName).join(', '),
        assignedToEmployeeId:
            _selectedAssignedEmployees.map((e) => e.employeeId).join(', '),
        assignedToDesignation: _selectedAssignedEmployees.isNotEmpty
            ? _selectedAssignedEmployees.first.designation
            : (_loadedProject?.assignedToDesignation ?? ''),
        assignedToContactNumber: _selectedAssignedEmployees.isNotEmpty
            ? (_selectedAssignedEmployees.first.phoneNumber.isNotEmpty
                ? _selectedAssignedEmployees.first.phoneNumber
                : _selectedAssignedEmployees.first.personalMobile)
            : (_loadedProject?.assignedToContactNumber ?? ''),
        assignedToEmail: _selectedAssignedEmployees.isNotEmpty
            ? _selectedAssignedEmployees.first.emailAddress
            : (_loadedProject?.assignedToEmail ?? ''),
        assignedDate: _loadedProject?.assignedDate,
        openingDate: _loadedProject?.openingDate,
        openingDateRemark: _loadedProject?.openingDateRemark ?? '',
        closingDate: _loadedProject?.closingDate,
        closingDateRemark: _loadedProject?.closingDateRemark ?? '',
        bqrRemark: _loadedProject?.bqrRemark ?? '',
        bqrDocuments: _existingBqrDocs.isNotEmpty
            ? _existingBqrDocs
            : (_loadedProject?.bqrDocuments ?? const []),
        emdRemark: _loadedProject?.emdRemark ?? '',
        emdDocuments: _existingEmdDocs.isNotEmpty
            ? _existingEmdDocs
            : (_loadedProject?.emdDocuments ?? const []),
        tenderLostRemark: _loadedProject?.tenderLostRemark ?? '',
        tenderLostStatus: _loadedProject?.tenderLostStatus ?? '',
        competitorName: _loadedProject?.competitorName ?? '',
        quotedAmount: _loadedProject?.quotedAmount ?? 0.0,
        tenderLostDocuments: _loadedProject?.tenderLostDocuments ?? const [],
        sdDateRemark: _sdDateRemarkCtrl.text.trim(),
        sdDateDocuments: _existingSdDateDocs,
        boqRemark: _boqRemarkCtrl.text.trim(),
        boqDocuments: _existingBoqDocs,
        projectDetailsRemark: _projectDetailsRemarkCtrl.text.trim(),
        projectDetailsDocuments: _existingProjectDetailsDocs,
        workOrderRemark: _workOrderRemarkCtrl.text.trim(),
        workOrderDocuments: _existingWorkOrderDocs,
        profileDrawingRemark: _profileDrawingRemarkCtrl.text.trim(),
        profileDrawingDocuments: _existingProfileDrawingDocs,
        agreementRemark: _agreementRemarkCtrl.text.trim(),
        agreementDocuments: _existingAgreementDocs,
        supplyMaterialsRemark: _supplyMaterialsRemarkCtrl.text.trim(),
        supplyMaterialsDocuments: _existingSupplyMaterialsDocs,
        subContract: _subContract,
        scopeOfWorkRemark: _scopeOfWorkRemarkCtrl.text.trim(),
        scopeItems: _scopeItems.toList(),
        otherScope: _otherScopeCtrl.text.trim(),
        ownMachineRemark: _ownMachineRemarkCtrl.text.trim(),
        ownOrSubcontract: _ownOrSubcontract,
        billingDetailsRemark: _billingDetailsRemarkCtrl.text.trim(),
        billingDetailsDocuments: _existingBillingDetailsDocs,
        flowOfBillsRemark: _flowOfBillsRemarkCtrl.text.trim(),
        flowOfBillsStatus: _flowOfBillsStatus,
        paymentReceivedRemark: _paymentRemarkCtrl.text.trim(),
        paymentAmount:
            double.tryParse(_paymentAmountCtrl.text.trim()) ?? 0.0,
        deductions: List.from(_deductions),
        emdRetentionRemark: _emdRetentionRemarkCtrl.text.trim(),
        emdRetentionAmount:
            double.tryParse(_emdRetentionAmountCtrl.text.trim()) ?? 0.0,
        emdRetentionDate: _emdRetentionDate,
        emdRetentionDocuments: _existingEmdRetentionDocs,
        sdRetentionRemark: _sdRetentionRemarkCtrl.text.trim(),
        sdRetentionAmount:
            double.tryParse(_sdRetentionAmountCtrl.text.trim()) ?? 0.0,
        sdRetentionDate: _sdRetentionDate,
        sdRetentionDocuments: _existingSdRetentionDocs,
        otherRetentionRemark: _otherRetentionRemarkCtrl.text.trim(),
        otherRetentionAmount:
            double.tryParse(_otherRetentionAmountCtrl.text.trim()) ?? 0.0,
        otherRetentionDate: _otherRetentionDate,
        otherRetentionDocuments: _existingOtherRetentionDocs,
        otherRetentionDocumentLabel:
            _otherRetentionDocLabelCtrl.text.trim(),
        updatedAt: DateTime.now(),
        updatedBy: currentEmp?.employeeId ?? currentEmp?.id.toString() ?? '',
        updatedByName: currentEmp?.fullName ?? currentEmp?.name ?? 'Admin',
      );

      final filesByCategory = <String, List<PlatformFile>>{
        'tender_spec': _tenderSpecFiles,
        'bqr': _bqrFiles,
        'emd': _emdFiles,
        'tender_lost': _tenderLostFiles,
        'sd_date': _sdDateFiles,
        'boq': _boqFiles,
        'project_details': _projectDetailsFiles,
        'work_order': _workOrderFiles,
        'profile_drawing': _profileDrawingFiles,
        'agreement': _agreementFiles,
        'supply_materials': _supplyMaterialsFiles,
        'billing_details': _billingDetailsFiles,
        'emd_retention': _emdRetentionFiles,
        'sd_retention': _sdRetentionFiles,
        'other_retention': _otherRetentionFiles,
      };

      // Formulate detailed human-readable audit change notes
      final changes = <String>[];
      final old = _loadedProject!;
      if (old.tenderAmount != updatedProject.tenderAmount) {
        changes.add(
            'Tender Amount updated from ₹${old.tenderAmount} to ₹${updatedProject.tenderAmount}');
      }
      if (old.approximateProjectValue != updatedProject.approximateProjectValue) {
        changes.add(
            'Approximate Project Value updated to ₹${updatedProject.approximateProjectValue}');
      }
      if (old.actualProjectValue != updatedProject.actualProjectValue) {
        changes.add(
            'Actual Project Value updated to ₹${updatedProject.actualProjectValue}');
      }
      if (old.tenderType != updatedProject.tenderType) {
        changes.add('Tender Type updated to "${updatedProject.tenderType}"');
      }
      if (old.qualified != updatedProject.qualified) {
        changes.add('Qualified Status set to "${updatedProject.qualified}"');
      }
      if (old.subContract != updatedProject.subContract) {
        changes.add('Sub Contract set to "${updatedProject.subContract}"');
      }
      if (old.openingDate != updatedProject.openingDate) {
        changes.add('Opening Date modified');
      }
      if (old.closingDate != updatedProject.closingDate) {
        changes.add('Closing Date modified');
      }
      if (old.paymentAmount != updatedProject.paymentAmount) {
        changes.add('Payment Received updated: ₹${updatedProject.paymentAmount}');
      }
      if (old.deductions.length != updatedProject.deductions.length) {
        changes.add(
            'Deductions updated (${updatedProject.deductions.length} entries)');
      }
      if (old.assignedToEmployeeNames !=
          updatedProject.assignedToEmployeeNames) {
        changes.add(
            'Assigned Team modified (${updatedProject.assignedToEmployeeName})');
      }
      if (old.tenderLostStatus != updatedProject.tenderLostStatus) {
        changes.add(
            'Tender Outcome Status set to "${updatedProject.tenderLostStatus}"');
      }

      int totalNewFiles = 0;
      filesByCategory.forEach((_, list) => totalNewFiles += list.length);
      if (totalNewFiles > 0) {
        changes.add('Uploaded $totalNewFiles new document(s)');
      }

      final changeNote = changes.isNotEmpty
          ? changes.join('; ')
          : 'Updated site project details and specifications.';

      await ref.read(projectRepositoryProvider).updateProject(
            updatedProject,
            filesByCategory: filesByCategory,
            auditNote: changeNote,
            auditEmployeeId: currentEmp?.employeeId ??
                currentEmp?.id.toString() ??
                'EMP-001',
            auditEmployeeName:
                currentEmp?.fullName ?? currentEmp?.name ?? 'Super Admin',
            auditDesignation: currentEmp?.designation ?? 'Site Engineer',
          );

      ref.invalidate(projectsStreamProvider);

      if (mounted) {
        _toast('Project "${updatedProject.projectCode}" updated successfully!');
        if (context.canPop()) {
          context.pop(true);
        } else {
          context.go('/projects/assigned');
        }
      }
    } catch (e) {
      _toast('Update failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ─── BUILD ───

  @override
  Widget build(BuildContext context) {
    final allEmployeesAsync = ref.watch(allEmployeesProvider);
    final tenderTypesAsync = ref.watch(tenderTypesProvider);

    if (!_assignedInitialized && _loadedProject != null) {
      allEmployeesAsync.whenData((allEmps) {
        if (!_assignedInitialized) {
          final ids = _loadedProject!.assignedToEmployeeIds;
          final names = _loadedProject!.assignedToEmployeeNames;
          final matched = allEmps.where((e) {
            return ids.contains(e.employeeId) ||
                ids.contains(e.id.toString()) ||
                names.contains(e.fullName);
          }).toList();
          if (mounted) {
            setState(() {
              _selectedAssignedEmployees.clear();
              _selectedAssignedEmployees.addAll(matched);
              _assignedInitialized = true;
            });
          }
        }
      });
    }

    final allEmployees = allEmployeesAsync.valueOrNull ?? [];

    if (_loadedProject == null) {
      return Scaffold(
        appBar: _buildAppBar(),
        backgroundColor: const Color(0xFFF8FAFC),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF9CC70A)),
        ),
      );
    }

    final p = _loadedProject!;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: _buildAppBar(),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: _isMobile ? 12 : 20,
            vertical: _isMobile ? 14 : 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Hero Summary Header Card ──
                  _buildProjectIdentityCard(p),
                  const SizedBox(height: 18),

                  // ── SECTION 01: Agreement & Security Deposit (SD Agreement) ──
                  _buildSectionContainer(
                    badge: 'SECTION 01',
                    title: 'Agreement & Security Deposit (SD)',
                    subtitle: 'Record finalized contract value, work order / LOA, and security deposit agreement.',
                    icon: Icons.assignment_turned_in_outlined,
                    children: [
                      _buildSubheading('AWARDED CONTRACT VALUES'),
                      _buildAwardValueModule(),
                      const SizedBox(height: 18),
                      _buildSubheading('SD AGREEMENT & BANK GUARANTEE'),
                      _buildSdAgreementModule(),
                      const SizedBox(height: 18),
                      _buildSubheading('WORK ORDER / LOA & CONTRACT AGREEMENT'),
                      _buildContractDocumentsModule(),
                      const SizedBox(height: 20),
                      _buildSubheading('TEAM ALLOCATION'),
                      _buildAssignedTeamModule(allEmployees),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ── SECTION 02: Work Start & Site Handover ──
                  _buildSectionContainer(
                    badge: 'SECTION 02',
                    title: 'Work Start & Site Handover',
                    subtitle: 'Track site possession, work commencement date, and target completion schedule.',
                    icon: Icons.calendar_month_outlined,
                    children: [
                      _buildWorkStartModule(),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ── SECTION 03: Project Budget ──
                  _buildSectionContainer(
                    badge: 'SECTION 03',
                    title: 'Project Budget & Cost Estimation',
                    subtitle: 'Track approved expenditure across materials, services, machinery, and subcontracts.',
                    icon: Icons.pie_chart_outline_rounded,
                    children: [
                      _buildProjectBudgetOverviewModule(p),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ── SECTION 04: Supply Items (Materials) ──
                  _buildSectionContainer(
                    badge: 'SECTION 04',
                    title: 'Supply Items (Materials)',
                    subtitle: 'Itemize physical materials supplied for execution (HDPE pipes, MS pipes, cables, clamps, fittings).',
                    icon: Icons.inventory_2_outlined,
                    children: [
                      _buildSupplyItemsModule(),
                      const SizedBox(height: 16),
                      _buildSubheading('SUPPLY DOCUMENTS & DELIVERY CHALLANS'),
                      _buildModernUploadRow(
                        remarkCtrl: _supplyMaterialsRemarkCtrl,
                        remarkHint: 'Supply delivery challans, material test reports, or purchase order notes...',
                        files: _supplyMaterialsFiles,
                        existingDocs: _existingSupplyMaterialsDocs,
                        onExistingRemoved: (doc) => setState(() => _existingSupplyMaterialsDocs.remove(doc)),
                        label: 'Supply Documents / Challans',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ── SECTION 05: Service Items & Scope of Work ──
                  _buildSectionContainer(
                    badge: 'SECTION 05',
                    title: 'Service Items & Execution Scope',
                    subtitle: 'Itemize work activities (HDD drilling, pipe laying, trenching, welding) and resource mobilization.',
                    icon: Icons.handyman_outlined,
                    children: [
                      _buildServiceItemsModule(),
                      const SizedBox(height: 20),
                      _buildSubheading('SUBCONTRACT & MACHINERY USAGE'),
                      _buildSubcontractAndMachineryModule(),
                      const SizedBox(height: 20),
                      _buildSubheading('OUR SCOPE OF WORK (EQUIPMENT & RESOURCES)'),
                      _buildScopeOfWorkModule(),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ── SECTION 06: Work Profile Drawings & Technical Specs ──
                  _buildSectionContainer(
                    badge: 'SECTION 06',
                    title: 'Work Profile Drawings & Technical Specs',
                    subtitle: 'Upload technical pipeline profiles, alignment sheets, crossing points, and BOQ documents.',
                    icon: Icons.architecture_rounded,
                    children: [
                      _buildProfileDrawingModule(),
                      const SizedBox(height: 16),
                      _buildSubheading('BOQ & SPECIFICATION REFERENCES'),
                      _buildModernUploadRow(
                        remarkCtrl: _boqRemarkCtrl,
                        remarkHint: 'Bill of Quantities (BOQ) remarks or amendment notes...',
                        files: _boqFiles,
                        existingDocs: _existingBoqDocs,
                        onExistingRemoved: (doc) => setState(() => _existingBoqDocs.remove(doc)),
                        label: 'BOQ Document',
                      ),
                      if (_existingTenderSpecDocs.isNotEmpty || _tenderSpecRemarkCtrl.text.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _buildTenderSpecReferenceCard(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ── SECTION 07: Bill Preparation & Upload (RA Bills) ──
                  _buildSectionContainer(
                    badge: 'SECTION 07',
                    title: 'Bill Preparation & Upload (RA Bills)',
                    subtitle: 'Prepare and upload Running Account (RA) bills, final bills, and measurement sheets.',
                    icon: Icons.receipt_long_outlined,
                    children: [
                      _buildBillUploadModule(),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ── SECTION 08: Flow of Bills / Approval Cycle ──
                  _buildSectionContainer(
                    badge: 'SECTION 08',
                    title: 'Bill Flow & Verification Status',
                    subtitle:
                        'Track departmental verification flow: JE → AE → AD → DE → SE → CE → MM → DFC → APS → DO → AO → Cash.',
                    icon: Icons.sync_alt_rounded,
                    children: [
                      _buildBillFlowTrackingModule(),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ── SECTION 09: Payment Received & Deductions ──
                  _buildSectionContainer(
                    badge: 'SECTION 09',
                    title: 'Payment Received & Deductions Breakdown',
                    subtitle: 'Record net amount received from client and track itemized deductions (TDS, GST, LD, Retention).',
                    icon: Icons.payments_outlined,
                    children: [
                      _buildPaymentAndDeductionModule(),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ── SECTION 10: Security Deposit & Retention Tracking ──
                  _buildSectionContainer(
                    badge: 'SECTION 10',
                    title: 'Security Deposit & Retention Recovery',
                    subtitle: 'Track money held by client (SD, EMD, RA Retentions) and receivable release dates.',
                    icon: Icons.account_balance_outlined,
                    children: [
                      _buildRetentionCard(
                        title: 'EMD Retention Receivable Date',
                        remarkCtrl: _emdRetentionRemarkCtrl,
                        amountCtrl: _emdRetentionAmountCtrl,
                        date: _emdRetentionDate,
                        onPickDate: () => _pickDate(
                          current: _emdRetentionDate,
                          onPicked: (d) => setState(() => _emdRetentionDate = d),
                        ),
                        files: _emdRetentionFiles,
                        existingDocs: _existingEmdRetentionDocs,
                        onExistingRemoved: (doc) => setState(
                            () => _existingEmdRetentionDocs.remove(doc)),
                      ),
                      const SizedBox(height: 12),
                      _buildRetentionCard(
                        title: 'SD Retention Receivable Date',
                        remarkCtrl: _sdRetentionRemarkCtrl,
                        amountCtrl: _sdRetentionAmountCtrl,
                        date: _sdRetentionDate,
                        onPickDate: () => _pickDate(
                          current: _sdRetentionDate,
                          onPicked: (d) => setState(() => _sdRetentionDate = d),
                        ),
                        files: _sdRetentionFiles,
                        existingDocs: _existingSdRetentionDocs,
                        onExistingRemoved: (doc) => setState(
                            () => _existingSdRetentionDocs.remove(doc)),
                      ),
                      const SizedBox(height: 12),
                      _buildRetentionCard(
                        title: 'Other Retention Receivable Date',
                        remarkCtrl: _otherRetentionRemarkCtrl,
                        amountCtrl: _otherRetentionAmountCtrl,
                        date: _otherRetentionDate,
                        onPickDate: () => _pickDate(
                          current: _otherRetentionDate,
                          onPicked: (d) =>
                              setState(() => _otherRetentionDate = d),
                        ),
                        files: _otherRetentionFiles,
                        existingDocs: _existingOtherRetentionDocs,
                        onExistingRemoved: (doc) => setState(
                            () => _existingOtherRetentionDocs.remove(doc)),
                        docLabel: 'Other Documents',
                        extraChild: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: TextFormField(
                            controller: _otherRetentionDocLabelCtrl,
                            style: const TextStyle(fontSize: 12.5),
                            decoration: _inputDeco(
                              'Document Label / Description',
                              hint: 'e.g. Performance Guarantee',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── Modern Floating / Elevated Actions ──
                  _buildFooterActionCard(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── App Bar ───

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF414A51)),
        onPressed: () {
          if (context.canPop()) {
            context.pop(false);
          } else {
            context.go('/projects/assigned');
          }
        },
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.edit_note_rounded,
                size: 20, color: Color(0xFF414A51)),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'UPDATE SITE PROJECT',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF414A51),
                    letterSpacing: 0.4,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Modify project scope, tender specs, execution timelines, and billings',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFE2E8F0), height: 1),
      ),
    );
  }

  // ─── Project Identity & Metadata Hero Card ───

  Widget _buildProjectIdentityCard(SiteProject p) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.all(_isMobile ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isMobile) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF414A51),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.qr_code_2_rounded,
                      color: Color(0xFF9CC70A), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text(
                              'ASSIGNED PROJECT',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF414A51),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Text(
                              p.subOrOwn.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        p.projectCode,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Mobile Last Update & Audit History buttons
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule_rounded,
                            size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'LAST UPDATED',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF94A3B8),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                _lastUpdatedEmployee.isNotEmpty
                                    ? _lastUpdatedEmployee
                                    : 'System Admin',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_lastUpdatedDate != null)
                                Text(
                                  DateFormat('dd MMM yyyy')
                                      .format(_lastUpdatedDate!),
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => ProjectAuditHistoryDialog(
                          projectId: p.id,
                          projectCode: p.projectCode,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF414A51),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Color(0xFF9CC70A),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.info_outline_rounded,
                              size: 13,
                              color: Color(0xFF414A51),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'AUDIT LOGS',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Desktop Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF414A51),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.qr_code_2_rounded,
                      color: Color(0xFF9CC70A), size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'ASSIGNED PROJECT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF414A51),
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Text(
                              p.subOrOwn.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        p.projectCode,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                // Last Update Pill + Audit History (i) button
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule_rounded,
                              size: 18, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'LAST UPDATED',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF94A3B8),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                _lastUpdatedEmployee.isNotEmpty
                                    ? '$_lastUpdatedEmployee (${_lastUpdatedEmployeeId.isNotEmpty ? _lastUpdatedEmployeeId : "Staff"})'
                                    : 'System Admin',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155),
                                ),
                              ),
                              if (_lastUpdatedDate != null)
                                Text(
                                  DateFormat('dd MMM yyyy, hh:mm a')
                                      .format(_lastUpdatedDate!),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Audit History Info Button (i)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => ProjectAuditHistoryDialog(
                              projectId: p.id,
                              projectCode: p.projectCode,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF414A51),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF414A51)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF9CC70A),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.info_outline_rounded,
                                  size: 14,
                                  color: Color(0xFF414A51),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'AUDIT HISTORY',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  Text(
                                    'Tap to view change logs',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // Horizontal Parameter Badges
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _buildMetaTag(
                  Icons.business_rounded, 'Client', p.clientName),
              _buildMetaTag(Icons.map_outlined, 'State', p.state),
              _buildMetaTag(
                  Icons.location_city_outlined, 'District', p.district),
              _buildMetaTag(Icons.place_outlined, 'Area', p.area),
              _buildMetaTag(Icons.calendar_today_outlined, 'Month / Year',
                  _extractFromProjectCode(p)),
              _buildMetaTag(Icons.tag_rounded, 'Serial Num',
                  _extractSerialFromCode(p.projectCode)),
              if (p.approximateProjectValue > 0)
                _buildMetaTag(Icons.currency_rupee_rounded, 'Approx Value',
                    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(p.approximateProjectValue)),
              if (p.actualProjectValue > 0)
                _buildMetaTag(Icons.currency_rupee_rounded, 'Actual Value',
                    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(p.actualProjectValue)),
            ],
          ),
          if (p.isMappedToTender == 'Yes' || p.tenderRefNo.isNotEmpty || p.tenderAmount > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFF9CC70A).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF9CC70A).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF414A51),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.verified_outlined, size: 16, color: Color(0xFF9CC70A)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'ORIGINAL TENDER RECORD (INHERITED)',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF414A51),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF9CC70A),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'WON / AWARDED',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF414A51),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Tender Ref: ${p.tenderRefNo.isNotEmpty ? p.tenderRefNo : "—"}  •  Type: ${p.tenderType.isNotEmpty ? p.tenderType : (p.tenderCategory.isNotEmpty ? p.tenderCategory : "Open")}  •  Original Tender Value: ${NumberFormat.currency(locale: 'en_IN', symbol: '₹ ', decimalDigits: 0).format(p.tenderAmount)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaTag(IconData icon, String label, String val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          Text(
            val.isNotEmpty ? val : '—',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section Container Frame ───

  Widget _buildSectionContainer({
    required String badge,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.all(_isMobile ? 14 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF9CC70A).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: const Color(0xFF414A51)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      badge,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF9CC70A),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 16),
            child: Text(
              subtitle,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSubheading(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF475569),
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  // ─── Input Decoration Template ───

  InputDecoration _inputDeco(
    String label, {
    String? hint,
    Widget? suffix,
    Widget? prefixIcon,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
      suffixIcon: suffix,
      prefixIcon: prefixIcon,
      prefixText: prefixText,
      prefixStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF475569),
      ),
      filled: true,
      fillColor: const Color(0xFFFAFAFA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: Color(0xFF9CC70A), width: 1.6),
      ),
    );
  }

  // ─── 1. Award Values Module ───

  Widget _buildAwardValueModule() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                  color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.currency_rupee_rounded,
                    size: 16, color: Color(0xFF414A51)),
              ),
              const SizedBox(width: 8),
              const Text(
                'FINAL CONTRACT / AWARD VALUES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF414A51),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isMobile) ...[
            TextFormField(
              controller: _actualProjectValueCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
              ],
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B)),
              decoration: _inputDeco('Actual Project Value (Awarded)',
                  prefixText: '₹ ', hint: 'Final awarded contract value'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _approximateProjectValueCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
              ],
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569)),
              decoration: _inputDeco('Approximate Project Estimate',
                  prefixText: '₹ ', hint: 'Original tender estimate'),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _actualProjectValueCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                    ],
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B)),
                    decoration: _inputDeco('Actual Project Value (Awarded)',
                        prefixText: '₹ ', hint: 'Final awarded contract value'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextFormField(
                    controller: _approximateProjectValueCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                    ],
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569)),
                    decoration: _inputDeco('Approximate Project Estimate',
                        prefixText: '₹ ', hint: 'Original tender estimate'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── SD Agreement & Bank Guarantee Module ───

  Widget _buildSdAgreementModule() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isMobile) ...[
            TextFormField(
              controller: _sdAgreementNoCtrl,
              style: const TextStyle(fontSize: 12.5),
              decoration: _inputDeco('SD Agreement / BG Number',
                  hint: 'e.g. BG-2024-001 or SD-AGR-42'),
            ),
            const SizedBox(height: 10),
            _buildModernDateInput(
              label: 'SD Agreement Date',
              date: _sdAgreementDate,
              onPick: () => _pickDate(
                current: _sdAgreementDate,
                onPicked: (d) => setState(() => _sdAgreementDate = d),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _sdAmountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
              ],
              style:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              decoration: _inputDeco('SD Amount / Bank Guarantee Value',
                  prefixText: '₹ '),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _sdAgreementNoCtrl,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('SD Agreement / BG Number',
                        hint: 'e.g. BG-2024-001 or SD-AGR-42'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildModernDateInput(
                    label: 'SD Agreement Date',
                    date: _sdAgreementDate,
                    onPick: () => _pickDate(
                      current: _sdAgreementDate,
                      onPicked: (d) => setState(() => _sdAgreementDate = d),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _sdAmountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                    ],
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600),
                    decoration: _inputDeco('SD Amount / Bank Guarantee Value',
                        prefixText: '₹ '),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          _buildModernUploadRow(
            remarkCtrl: _sdDateRemarkCtrl,
            remarkHint:
                'Security deposit agreement terms, bank guarantee notes, deduction terms...',
            files: _sdDateFiles,
            existingDocs: _existingSdDateDocs,
            onExistingRemoved: (doc) =>
                setState(() => _existingSdDateDocs.remove(doc)),
            label: 'SD Agreement / Bank Guarantee Document',
          ),
        ],
      ),
    );
  }

  // ─── Work Order & Contract Agreement Documents Module ───

  Widget _buildContractDocumentsModule() {
    if (_isMobile) {
      return Column(
        children: [
          _buildModernUploadRow(
            remarkCtrl: _workOrderRemarkCtrl,
            remarkHint: 'Work order / Letter of Award (LOA) notes...',
            files: _workOrderFiles,
            existingDocs: _existingWorkOrderDocs,
            onExistingRemoved: (doc) =>
                setState(() => _existingWorkOrderDocs.remove(doc)),
            label: 'Work Order / Letter of Award (LOA)',
          ),
          const SizedBox(height: 12),
          _buildModernUploadRow(
            remarkCtrl: _agreementRemarkCtrl,
            remarkHint:
                'Contract agreement clauses and signed agreement notes...',
            files: _agreementFiles,
            existingDocs: _existingAgreementDocs,
            onExistingRemoved: (doc) =>
                setState(() => _existingAgreementDocs.remove(doc)),
            label: 'Signed Contract Agreement Document',
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildModernUploadRow(
            remarkCtrl: _workOrderRemarkCtrl,
            remarkHint: 'Work order / Letter of Award (LOA) notes...',
            files: _workOrderFiles,
            existingDocs: _existingWorkOrderDocs,
            onExistingRemoved: (doc) =>
                setState(() => _existingWorkOrderDocs.remove(doc)),
            label: 'Work Order / Letter of Award (LOA)',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildModernUploadRow(
            remarkCtrl: _agreementRemarkCtrl,
            remarkHint:
                'Contract agreement clauses and signed agreement notes...',
            files: _agreementFiles,
            existingDocs: _existingAgreementDocs,
            onExistingRemoved: (doc) =>
                setState(() => _existingAgreementDocs.remove(doc)),
            label: 'Signed Contract Agreement Document',
          ),
        ),
      ],
    );
  }

  // ─── Work Start & Mobilization Module ───

  Widget _buildWorkStartModule() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isMobile) ...[
            _buildModernDateInput(
              label: 'Site Handover Date',
              date: _siteHandoverDate,
              onPick: () => _pickDate(
                current: _siteHandoverDate,
                onPicked: (d) => setState(() => _siteHandoverDate = d),
              ),
            ),
            const SizedBox(height: 10),
            _buildModernDateInput(
              label: 'Work Start Date (Actual / Planned)',
              date: _workStartDate,
              onPick: () => _pickDate(
                current: _workStartDate,
                onPicked: (d) => setState(() => _workStartDate = d),
              ),
            ),
            const SizedBox(height: 10),
            _buildModernDateInput(
              label: 'Scheduled Completion Target',
              date: _targetCompletionDate,
              onPick: () => _pickDate(
                current: _targetCompletionDate,
                onPicked: (d) => setState(() => _targetCompletionDate = d),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _buildModernDateInput(
                    label: 'Site Handover Date',
                    date: _siteHandoverDate,
                    onPick: () => _pickDate(
                      current: _siteHandoverDate,
                      onPicked: (d) => setState(() => _siteHandoverDate = d),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildModernDateInput(
                    label: 'Work Start Date (Actual / Planned)',
                    date: _workStartDate,
                    onPick: () => _pickDate(
                      current: _workStartDate,
                      onPicked: (d) => setState(() => _workStartDate = d),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildModernDateInput(
                    label: 'Scheduled Completion Target',
                    date: _targetCompletionDate,
                    onPick: () => _pickDate(
                      current: _targetCompletionDate,
                      onPicked: (d) => setState(() => _targetCompletionDate = d),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          _buildModernUploadRow(
            remarkCtrl: _projectDetailsRemarkCtrl,
            remarkHint:
                'Site handover report, site possession letter, work commencement notice...',
            files: _projectDetailsFiles,
            existingDocs: _existingProjectDetailsDocs,
            onExistingRemoved: (doc) =>
                setState(() => _existingProjectDetailsDocs.remove(doc)),
            label: 'Site Handover / Work Commencement Document',
          ),
        ],
      ),
    );
  }

  // ─── Project Budget Overview Module ───

  Widget _buildProjectBudgetOverviewModule(SiteProject p) {
    final totalMaterials =
        _supplyItems.fold(0.0, (acc, item) => acc + item.amount);
    final totalServices =
        _serviceItems.fold(0.0, (acc, item) => acc + item.amount);
    final totalDirectCost = totalMaterials + totalServices;
    final contractVal =
        double.tryParse(_actualProjectValueCtrl.text.trim()) ?? p.contractValue;
    final margin = contractVal > 0 ? (contractVal - totalDirectCost) : 0.0;
    final marginPct = contractVal > 0 ? (margin / contractVal * 100) : 0.0;

    final currFmt = NumberFormat.currency(
        locale: 'en_IN', symbol: '₹ ', decimalDigits: 0);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.analytics_outlined,
                    size: 18, color: Color(0xFF414A51)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ESTIMATED EXPENDITURE VS CONTRACT VALUE',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF414A51),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Aggregated from Supply Materials and Service Work Items',
                      style: TextStyle(
                          fontSize: 10.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF414A51),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProjectBudgetScreen(
                        projectId: p.id,
                        initialProject: p,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.tune_rounded, size: 15),
                label: const Text('Open Budget Planner',
                    style:
                        TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _buildBudgetMetricCard(
                  'Contract Value',
                  currFmt.format(contractVal),
                  const Color(0xFF1E293B),
                  Icons.assignment_turned_in_outlined),
              _buildBudgetMetricCard('Materials Cost',
                  currFmt.format(totalMaterials),
                  const Color(0xFF2563EB),
                  Icons.inventory_2_outlined),
              _buildBudgetMetricCard('Services Cost',
                  currFmt.format(totalServices),
                  const Color(0xFFD97706),
                  Icons.handyman_outlined),
              _buildBudgetMetricCard(
                  'Total Direct Cost',
                  currFmt.format(totalDirectCost),
                  const Color(0xFF475569),
                  Icons.calculate_outlined),
              if (contractVal > 0)
                _buildBudgetMetricCard(
                    'Projected Margin',
                    '${currFmt.format(margin)} (${marginPct.toStringAsFixed(1)}%)',
                    margin >= 0
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                    Icons.trending_up_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetMetricCard(
      String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600)),
              Text(value,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Supply Items Module (Materials) ───

  void _calcSupplyAmount() {
    final qty = double.tryParse(_supplyQtyCtrl.text.trim()) ?? 0;
    final rate = double.tryParse(_supplyRateCtrl.text.trim()) ?? 0;
    _supplyAmountCtrl.text = (qty * rate).toStringAsFixed(2);
  }

  void _addSupplyItem() {
    final desc = _supplyDescCtrl.text.trim();
    if (desc.isEmpty) {
      _toast('Enter material description.', isError: true);
      return;
    }
    final qty = double.tryParse(_supplyQtyCtrl.text.trim()) ?? 0;
    final rate = double.tryParse(_supplyRateCtrl.text.trim()) ?? 0;
    setState(() {
      _supplyItems.add(ProjectBreakdownItem.create(
        description: desc,
        unit: _supplyUnitCtrl.text.trim().isNotEmpty
            ? _supplyUnitCtrl.text.trim()
            : 'nos',
        quantity: qty,
        rate: rate,
        type: BreakdownItemType.material,
      ));
      _supplyDescCtrl.clear();
      _supplyUnitCtrl.clear();
      _supplyQtyCtrl.clear();
      _supplyRateCtrl.clear();
      _supplyAmountCtrl.clear();
    });
  }

  Widget _buildSupplyItemsModule() {
    final totalSupply =
        _supplyItems.fold(0.0, (acc, item) => acc + item.amount);
    final currFmt = NumberFormat.currency(
        locale: 'en_IN', symbol: '₹ ', decimalDigits: 2);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isMobile) ...[
            TextFormField(
              controller: _supplyDescCtrl,
              style: const TextStyle(fontSize: 12.5),
              decoration: _inputDeco('Material Description',
                  hint: 'e.g. HDPE Pipe 110mm PN10, MS Casing, Cables'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _supplyUnitCtrl,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Unit', hint: 'm / nos / kg'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _supplyQtyCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                    ],
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Quantity'),
                    onChanged: (_) => _calcSupplyAmount(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _supplyRateCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                    ],
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Rate', prefixText: '₹ '),
                    onChanged: (_) => _calcSupplyAmount(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _supplyAmountCtrl,
                    readOnly: true,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700),
                    decoration: _inputDeco('Amount', prefixText: '₹ '),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF414A51),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _addSupplyItem,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Material',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 11.5)),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    controller: _supplyDescCtrl,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Material Description',
                        hint:
                            'e.g. HDPE Pipe 110mm PN10, MS Casing, Valves, Clamps'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _supplyUnitCtrl,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Unit', hint: 'm / nos / kg'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _supplyQtyCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                    ],
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Quantity'),
                    onChanged: (_) => _calcSupplyAmount(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _supplyRateCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                    ],
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Rate', prefixText: '₹ '),
                    onChanged: (_) => _calcSupplyAmount(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _supplyAmountCtrl,
                    readOnly: true,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700),
                    decoration: _inputDeco('Amount', prefixText: '₹ '),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF414A51),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _addSupplyItem,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Material',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 11.5)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),

          // Items Table
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tableWidth = math.max(constraints.maxWidth, 600.0);
                return ScrollConfiguration(
                  behavior:
                      ScrollConfiguration.of(context).copyWith(scrollbars: false),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      child: Table(
                      border: TableBorder.all(color: const Color(0xFFE2E8F0)),
                      columnWidths: const {
                        0: FlexColumnWidth(4),
                        1: FlexColumnWidth(2),
                        2: FlexColumnWidth(2),
                        3: FlexColumnWidth(2),
                        4: FlexColumnWidth(2),
                        5: FixedColumnWidth(36),
                      },
                      children: [
                        TableRow(
                          decoration:
                              const BoxDecoration(color: Color(0xFF414A51)),
                          children: const [
                            Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                child: Text('Material Item',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white))),
                            Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                child: Text('Unit',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white))),
                            Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                child: Text('Quantity',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white))),
                            Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                child: Text('Rate',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white))),
                            Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                child: Text('Amount (₹)',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white))),
                            Padding(
                                padding: EdgeInsets.all(8), child: Text('')),
                          ],
                        ),
                        if (_supplyItems.isEmpty)
                          TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 10),
                                child: Text(
                                    'No supply materials itemized yet.',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.grey.shade500)),
                              ),
                              const SizedBox(),
                              const SizedBox(),
                              const SizedBox(),
                              const SizedBox(),
                              const SizedBox(),
                            ],
                          )
                        else
                          ..._supplyItems.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;
                            return TableRow(
                              decoration: BoxDecoration(
                                color: idx.isEven
                                    ? Colors.white
                                    : const Color(0xFFF8FAFC),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  child: Text(item.description,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  child: Text(item.unit,
                                      style: const TextStyle(fontSize: 12)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  child: Text(
                                      item.quantity % 1 == 0
                                          ? item.quantity.toInt().toString()
                                          : item.quantity.toString(),
                                      style: const TextStyle(fontSize: 12)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  child: Text(
                                      NumberFormat.currency(
                                              locale: 'en_IN',
                                              symbol: '₹ ',
                                              decimalDigits: 2)
                                          .format(item.rate),
                                      style: const TextStyle(fontSize: 12)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  child: Text(
                                      NumberFormat.currency(
                                              locale: 'en_IN',
                                              symbol: '₹ ',
                                              decimalDigits: 2)
                                          .format(item.amount),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1E293B))),
                                ),
                                Center(
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(Icons.delete_outline,
                                        size: 16, color: Color(0xFFEF4444)),
                                    onPressed: () => setState(
                                        () => _supplyItems.removeAt(idx)),
                                  ),
                                ),
                              ],
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              );
            },
            ),
          ),
          if (_supplyItems.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'TOTAL SUPPLY MATERIALS: ${currFmt.format(totalSupply)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E40AF),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── Service Items Module (Works / Services) ───

  void _calcServiceAmount() {
    final qty = double.tryParse(_serviceQtyCtrl.text.trim()) ?? 0;
    final rate = double.tryParse(_serviceRateCtrl.text.trim()) ?? 0;
    _serviceAmountCtrl.text = (qty * rate).toStringAsFixed(2);
  }

  void _addServiceItem() {
    final desc = _serviceDescCtrl.text.trim();
    if (desc.isEmpty) {
      _toast('Enter service description.', isError: true);
      return;
    }
    final qty = double.tryParse(_serviceQtyCtrl.text.trim()) ?? 0;
    final rate = double.tryParse(_serviceRateCtrl.text.trim()) ?? 0;
    setState(() {
      _serviceItems.add(ProjectBreakdownItem.create(
        description: desc,
        unit: _serviceUnitCtrl.text.trim().isNotEmpty
            ? _serviceUnitCtrl.text.trim()
            : 'mtr',
        quantity: qty,
        rate: rate,
        type: BreakdownItemType.service,
      ));
      _serviceDescCtrl.clear();
      _serviceUnitCtrl.clear();
      _serviceQtyCtrl.clear();
      _serviceRateCtrl.clear();
      _serviceAmountCtrl.clear();
    });
  }

  Widget _buildServiceItemsModule() {
    final totalServices =
        _serviceItems.fold(0.0, (acc, item) => acc + item.amount);
    final currFmt = NumberFormat.currency(
        locale: 'en_IN', symbol: '₹ ', decimalDigits: 2);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isMobile) ...[
            TextFormField(
              controller: _serviceDescCtrl,
              style: const TextStyle(fontSize: 12.5),
              decoration: _inputDeco('Service / Scope Description',
                  hint:
                      'e.g. HDD drilling, trench excavation, joint welding, testing'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _serviceUnitCtrl,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Unit', hint: 'm / nos / joint'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _serviceQtyCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                    ],
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Quantity'),
                    onChanged: (_) => _calcServiceAmount(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _serviceRateCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                    ],
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Rate', prefixText: '₹ '),
                    onChanged: (_) => _calcServiceAmount(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _serviceAmountCtrl,
                    readOnly: true,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700),
                    decoration: _inputDeco('Amount', prefixText: '₹ '),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF414A51),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _addServiceItem,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Service',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 11.5)),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    controller: _serviceDescCtrl,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Service / Scope Description',
                        hint:
                            'e.g. HDD drilling, trench excavation, joint welding, testing'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _serviceUnitCtrl,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Unit', hint: 'm / nos / joint'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _serviceQtyCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                    ],
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Quantity'),
                    onChanged: (_) => _calcServiceAmount(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _serviceRateCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                    ],
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Rate', prefixText: '₹ '),
                    onChanged: (_) => _calcServiceAmount(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _serviceAmountCtrl,
                    readOnly: true,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700),
                    decoration: _inputDeco('Amount', prefixText: '₹ '),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF414A51),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _addServiceItem,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Service',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 11.5)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),

          // Items Table
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tableWidth = math.max(constraints.maxWidth, 600.0);
                return ScrollConfiguration(
                  behavior:
                      ScrollConfiguration.of(context).copyWith(scrollbars: false),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      child: Table(
                      border: TableBorder.all(color: const Color(0xFFE2E8F0)),
                      columnWidths: const {
                        0: FlexColumnWidth(4),
                        1: FlexColumnWidth(2),
                        2: FlexColumnWidth(2),
                        3: FlexColumnWidth(2),
                        4: FlexColumnWidth(2),
                        5: FixedColumnWidth(36),
                      },
                      children: [
                        TableRow(
                          decoration:
                              const BoxDecoration(color: Color(0xFF414A51)),
                          children: const [
                            Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                child: Text('Service / Scope Item',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white))),
                            Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                child: Text('Unit',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white))),
                            Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                child: Text('Quantity',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white))),
                            Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                child: Text('Rate',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white))),
                            Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                child: Text('Amount (₹)',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white))),
                            Padding(
                                padding: EdgeInsets.all(8), child: Text('')),
                          ],
                        ),
                        if (_serviceItems.isEmpty)
                          TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 10),
                                child: Text(
                                    'No service work items itemized yet.',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.grey.shade500)),
                              ),
                              const SizedBox(),
                              const SizedBox(),
                              const SizedBox(),
                              const SizedBox(),
                              const SizedBox(),
                            ],
                          )
                        else
                          ..._serviceItems.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;
                            return TableRow(
                              decoration: BoxDecoration(
                                color: idx.isEven
                                    ? Colors.white
                                    : const Color(0xFFF8FAFC),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  child: Text(item.description,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  child: Text(item.unit,
                                      style: const TextStyle(fontSize: 12)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  child: Text(
                                      item.quantity % 1 == 0
                                          ? item.quantity.toInt().toString()
                                          : item.quantity.toString(),
                                      style: const TextStyle(fontSize: 12)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  child: Text(
                                      NumberFormat.currency(
                                              locale: 'en_IN',
                                              symbol: '₹ ',
                                              decimalDigits: 2)
                                          .format(item.rate),
                                      style: const TextStyle(fontSize: 12)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  child: Text(
                                      NumberFormat.currency(
                                              locale: 'en_IN',
                                              symbol: '₹ ',
                                              decimalDigits: 2)
                                          .format(item.amount),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1E293B))),
                                ),
                                Center(
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(Icons.delete_outline,
                                        size: 16, color: Color(0xFFEF4444)),
                                    onPressed: () => setState(
                                        () => _serviceItems.removeAt(idx)),
                                  ),
                                ),
                              ],
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              );
            },
            ),
          ),
          if (_serviceItems.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: const Color(0xFFD97706).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'TOTAL SERVICE SCOPE: ${currFmt.format(totalServices)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── Inherited Tender Spec Reference Card ───

  Widget _buildTenderSpecReferenceCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.description_outlined,
                  size: 16, color: Color(0xFF64748B)),
              SizedBox(width: 8),
              Text(
                'INHERITED TENDER SPECIFICATIONS (READ-ONLY REFERENCE)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          if (_tenderSpecRemarkCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _tenderSpecRemarkCtrl.text,
              style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
            ),
          ],
          if (_existingTenderSpecDocs.isNotEmpty ||
              _tenderSpecFiles.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ..._existingTenderSpecDocs.map((d) => _buildDocChip(
                      name: d.name,
                      isExisting: true,
                      onRemove: () =>
                          setState(() => _existingTenderSpecDocs.remove(d)),
                      onView: () => _previewFile(
                        name: d.name,
                        url: d.downloadUrl,
                        size: d.size,
                        isLocal: false,
                      ),
                    )),
                ..._tenderSpecFiles.map((f) => _buildDocChip(
                      name: f.name,
                      isExisting: false,
                      onRemove: () =>
                          setState(() => _tenderSpecFiles.remove(f)),
                      onView: () => _previewFile(
                        name: f.name,
                        bytes: f.bytes,
                        size: f.size,
                        isLocal: true,
                      ),
                    )),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── Bill Preparation & Upload Module ───

  Widget _buildBillUploadModule() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isMobile) ...[
            TextFormField(
              controller: _billingDetailsRemarkCtrl,
              style: const TextStyle(fontSize: 12.5),
              decoration: _inputDeco('Bill Submission Details / Reference',
                  hint: 'e.g. RA Bill #01 for 350m HDD cable laying'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF414A51),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9)),
                    ),
                    onPressed: () => _pickFiles(_billingDetailsFiles,
                        existing: _existingBillingDetailsDocs),
                    icon: const Icon(Icons.receipt_long_outlined, size: 16),
                    label: Text(
                      _existingBillingDetailsDocs.isEmpty &&
                              _billingDetailsFiles.isEmpty
                          ? 'Upload Bills / Sheets'
                          : 'Bills (${_existingBillingDetailsDocs.length + _billingDetailsFiles.length})',
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9CC70A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9)),
                    ),
                    onPressed: () => _toast('Opening Billing Chat...'),
                    icon: const Icon(Icons.chat_bubble_outline_rounded,
                        size: 15),
                    label: const Text('BILL CHAT',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5),
                        overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    controller: _billingDetailsRemarkCtrl,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Bill Submission Details / Reference',
                        hint: 'e.g. RA Bill #01 for 350m HDD cable laying'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF414A51),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                  onPressed: () => _pickFiles(_billingDetailsFiles,
                      existing: _existingBillingDetailsDocs),
                  icon: const Icon(Icons.receipt_long_outlined, size: 16),
                  label: Text(
                    _existingBillingDetailsDocs.isEmpty &&
                            _billingDetailsFiles.isEmpty
                        ? 'Upload Bills / Sheets'
                        : 'Bills (${_existingBillingDetailsDocs.length + _billingDetailsFiles.length})',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9CC70A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                  onPressed: () => _toast('Opening Billing Chat...'),
                  icon: const Icon(Icons.chat_bubble_outline_rounded,
                      size: 16),
                  label: const Text('OPEN BILL CHAT',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5)),
                ),
              ],
            ),
          ],
          if (_existingBillingDetailsDocs.isNotEmpty ||
              _billingDetailsFiles.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ..._existingBillingDetailsDocs.map((d) => _buildDocChip(
                      name: d.name,
                      isExisting: true,
                      onRemove: () =>
                          setState(() => _existingBillingDetailsDocs.remove(d)),
                      onView: () => _previewFile(
                        name: d.name,
                        url: d.downloadUrl,
                        size: d.size,
                        isLocal: false,
                      ),
                    )),
                ..._billingDetailsFiles.map((f) => _buildDocChip(
                      name: f.name,
                      isExisting: false,
                      onRemove: () =>
                          setState(() => _billingDetailsFiles.remove(f)),
                      onView: () => _previewFile(
                        name: f.name,
                        bytes: f.bytes,
                        size: f.size,
                        isLocal: true,
                      ),
                    )),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── Flow of Bills / Approval Cycle Module ───

  Widget _buildBillFlowTrackingModule() {
    final flowOptions = {
      ..._flowOfBillsOptions,
      if (_flowOfBillsStatus.isNotEmpty) _flowOfBillsStatus,
    }.toList();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isMobile) ...[
            DropdownButtonFormField<String>(
              initialValue: flowOptions.contains(_flowOfBillsStatus)
                  ? _flowOfBillsStatus
                  : null,
              decoration: _inputDeco('Flow Of Bills'),
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B)),
              items: flowOptions
                  .map((o) => DropdownMenuItem(
                      value: o,
                      child: Text(o.isEmpty ? '-- Select Status --' : o)))
                  .toList(),
              onChanged: (v) => setState(() => _flowOfBillsStatus = v ?? ''),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _flowOfBillsRemarkCtrl,
              style: const TextStyle(fontSize: 12.5),
              decoration: _inputDeco('Flow Remarks & Verification Notes',
                  hint:
                      'Client engineer certification status, verification date, notes...'),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: DropdownButtonFormField<String>(
                    initialValue: flowOptions.contains(_flowOfBillsStatus)
                        ? _flowOfBillsStatus
                        : null,
                    decoration: _inputDeco('Flow Of Bills'),
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B)),
                    items: flowOptions
                        .map((o) => DropdownMenuItem(
                            value: o,
                            child:
                                Text(o.isEmpty ? '-- Select Status --' : o)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _flowOfBillsStatus = v ?? ''),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 6,
                  child: TextFormField(
                    controller: _flowOfBillsRemarkCtrl,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Flow Remarks & Verification Notes',
                        hint:
                            'Client engineer certification status, verification date, notes...'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── Legacy Tender Type Grid (Retained for Reference/Fallback) ───

  Widget _buildTenderTypeGrid(List<String> tenderTypes) {
    return _buildAwardValueModule();
  }

  // ─── Modern Upload Component ───

  Widget _buildModernUploadRow({
    required TextEditingController remarkCtrl,
    required String remarkHint,
    required List<PlatformFile> files,
    required List<ProjectDocument> existingDocs,
    required void Function(ProjectDocument) onExistingRemoved,
    required String label,
  }) {
    final totalCount = existingDocs.length + files.length;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isMobile) ...[
            TextFormField(
              controller: remarkCtrl,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B)),
              decoration: _inputDeco(label.isNotEmpty ? label : 'Remark / Notes', hint: remarkHint),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF414A51),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9)),
                ),
                onPressed: () => _pickFiles(files, existing: existingDocs),
                icon: const Icon(Icons.attach_file_rounded, size: 16),
                label: Text(
                  totalCount == 0 ? 'Attach Documents' : 'Attached Files ($totalCount)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 5,
                  child: TextFormField(
                    controller: remarkCtrl,
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B)),
                    decoration: _inputDeco('Remark / Notes', hint: remarkHint),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF414A51),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                  onPressed: () => _pickFiles(files, existing: existingDocs),
                  icon: const Icon(Icons.attach_file_rounded, size: 18),
                  label: Text(
                    totalCount == 0 ? 'Attach Documents' : 'Add Files ($totalCount)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
          if (totalCount > 0) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ...existingDocs.map((doc) => _buildDocChip(
                      name: doc.name,
                      isExisting: true,
                      onRemove: () => onExistingRemoved(doc),
                      onView: () => _previewFile(
                        name: doc.name,
                        url: doc.downloadUrl,
                        size: doc.size,
                        isLocal: false,
                      ),
                    )),
                ...files.map((f) => _buildDocChip(
                      name: f.name,
                      isExisting: false,
                      onRemove: () => setState(() => files.remove(f)),
                      onView: () => _previewFile(
                        name: f.name,
                        bytes: f.bytes,
                        size: f.size,
                        isLocal: true,
                      ),
                    )),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDocChip({
    required String name,
    required bool isExisting,
    required VoidCallback onRemove,
    required VoidCallback onView,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isExisting
            ? const Color(0xFFF1F5F9)
            : const Color(0xFF9CC70A).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isExisting
              ? const Color(0xFFCBD5E1)
              : const Color(0xFF9CC70A).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isExisting
                ? Icons.insert_drive_file_outlined
                : Icons.upload_file_rounded,
            size: 14,
            color: const Color(0xFF414A51),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onView,
            borderRadius: BorderRadius.circular(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 190),
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                      decoration: TextDecoration.underline,
                      decorationColor: Color(0xFF94A3B8),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                const Tooltip(
                  message: 'View / Preview file',
                  child: Icon(
                    Icons.visibility_outlined,
                    size: 14,
                    color: Color(0xFF414A51),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onRemove,
            child: const Tooltip(
              message: 'Remove file',
              child:
                  Icon(Icons.close_rounded, size: 14, color: Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tender Description Breakdown Module ───

  Widget _buildTenderDescriptionModule() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isMobile) ...[
            TextFormField(
              controller: _tdDescCtrl,
              style: const TextStyle(fontSize: 12.5),
              decoration: _inputDeco('Item Description', hint: 'e.g. HDD boring, road cut'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _tdUnitCtrl,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Unit', hint: 'm / nos'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _tdQtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                    ],
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Quantity'),
                    onChanged: (_) => _calcTdAmount(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _tdRateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                    ],
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Rate', prefixText: '₹ '),
                    onChanged: (_) => _calcTdAmount(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _tdAmountCtrl,
                    readOnly: true,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    decoration: _inputDeco('Amount', prefixText: '₹ '),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF414A51),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _addTenderDescItem,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    controller: _tdDescCtrl,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Item Description', hint: 'e.g. HDD boring, road cut'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _tdUnitCtrl,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Unit', hint: 'm / nos / kg'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _tdQtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                    ],
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Quantity'),
                    onChanged: (_) => _calcTdAmount(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _tdRateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                    ],
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Rate', prefixText: '₹ '),
                    onChanged: (_) => _calcTdAmount(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _tdAmountCtrl,
                    readOnly: true,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    decoration: _inputDeco('Amount', prefixText: '₹ '),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF414A51),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _addTenderDescItem,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),

          // Items Table
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tableWidth = math.max(constraints.maxWidth, 600.0);
                return ScrollConfiguration(
                  behavior:
                      ScrollConfiguration.of(context).copyWith(scrollbars: false),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      child: Table(
                      border: TableBorder.all(color: const Color(0xFFE2E8F0)),
                      columnWidths: const {
                        0: FlexColumnWidth(4),
                        1: FlexColumnWidth(2),
                        2: FlexColumnWidth(2),
                        3: FlexColumnWidth(2),
                        4: FlexColumnWidth(2),
                        5: FixedColumnWidth(36),
                      },
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(color: Color(0xFF414A51)),
                          children: const [
                            Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                child: Text('Description',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white))),
                            Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                child: Text('Unit',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white))),
                            Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                child: Text('Quantity',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white))),
                            Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                child: Text('Rate',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white))),
                            Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                child: Text('Amount (₹)',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white))),
                            Padding(padding: EdgeInsets.all(8), child: Text('')),
                          ],
                        ),
                        if (_tenderDescriptions.isEmpty)
                          TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                child: Text('No breakdown items added yet.',
                                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
                              ),
                              const SizedBox(),
                              const SizedBox(),
                              const SizedBox(),
                              const SizedBox(),
                              const SizedBox(),
                            ],
                          )
                        else
                          ..._tenderDescriptions.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;
                            return TableRow(
                              decoration: BoxDecoration(
                                color: idx.isEven ? Colors.white : const Color(0xFFF8FAFC),
                              ),
                              children: [
                                Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    child: Text(item.description, style: const TextStyle(fontSize: 12))),
                                Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    child: Text(item.unit, style: const TextStyle(fontSize: 12))),
                                Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    child: Text(item.quantity.toString(), style: const TextStyle(fontSize: 12))),
                                Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    child: Text('₹${item.rate.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12))),
                                Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    child: Text('₹${item.amount.toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                                  onPressed: () => setState(() => _tenderDescriptions.removeAt(idx)),
                                ),
                              ],
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              );
            },
            ),
          ),
        ],
      ),
    );
  }

  void _calcTdAmount() {
    final qty = double.tryParse(_tdQtyCtrl.text.trim()) ?? 0;
    final rate = double.tryParse(_tdRateCtrl.text.trim()) ?? 0;
    _tdAmountCtrl.text = (qty * rate).toStringAsFixed(2);
  }

  void _addTenderDescItem() {
    final desc = _tdDescCtrl.text.trim();
    if (desc.isEmpty) {
      _toast('Enter a description.', isError: true);
      return;
    }
    final qty = double.tryParse(_tdQtyCtrl.text.trim()) ?? 0;
    final rate = double.tryParse(_tdRateCtrl.text.trim()) ?? 0;
    setState(() {
      _tenderDescriptions.add(TenderDescriptionItem(
        description: desc,
        unit: _tdUnitCtrl.text.trim(),
        quantity: qty,
        rate: rate,
        amount: qty * rate,
      ));
      _tdDescCtrl.clear();
      _tdUnitCtrl.clear();
      _tdQtyCtrl.clear();
      _tdRateCtrl.clear();
      _tdAmountCtrl.clear();
    });
  }

  // ─── Assigned Team Module ───

  Widget _buildAssignedTeamModule(List<Employee> allEmployees) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _showAssignedDialog(allEmployees),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.people_alt_outlined, size: 18, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedAssignedEmployees.isEmpty
                                ? 'Click to select team members...'
                                : '${_selectedAssignedEmployees.length} employee(s) allocated',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: _selectedAssignedEmployees.isEmpty
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF1E293B),
                              fontWeight: _selectedAssignedEmployees.isEmpty
                                  ? FontWeight.normal
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF414A51),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _showAssignedDialog(allEmployees),
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                label: const Text('ASSIGN TEAM',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (_selectedAssignedEmployees.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedAssignedEmployees.map((emp) {
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: const Color(0xFF414A51),
                    child: Text(
                      emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : 'E',
                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  label: Text('${emp.fullName} (${emp.employeeId})',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => setState(() => _selectedAssignedEmployees.remove(emp)),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showAssignedDialog(List<Employee> allEmployees) async {
    String query = '';
    final temp = List<Employee>.from(_selectedAssignedEmployees);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.badge_outlined, color: Color(0xFF414A51)),
                SizedBox(width: 10),
                Text('Select Assigned Team', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ],
            ),
            content: SizedBox(
              width: 440,
              height: 480,
              child: Column(
                children: [
                  TextFormField(
                    decoration: _inputDeco('Search by name or employee ID...'),
                    onChanged: (v) => setD(() => query = v.toLowerCase()),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: allEmployees
                          .where((e) =>
                              query.isEmpty ||
                              e.fullName.toLowerCase().contains(query) ||
                              e.employeeId.toLowerCase().contains(query))
                          .map((emp) {
                        final sel = temp.any((e) => e.employeeId == emp.employeeId);
                        return CheckboxListTile(
                          dense: true,
                          activeColor: const Color(0xFF9CC70A),
                          value: sel,
                          title: Text('${emp.employeeId} — ${emp.fullName}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: emp.designation.isNotEmpty
                              ? Text(emp.designation, style: const TextStyle(fontSize: 11))
                              : null,
                          onChanged: (v) {
                            setD(() {
                              if (v == true) {
                                if (!temp.any((e) => e.employeeId == emp.employeeId)) {
                                  temp.add(emp);
                                }
                              } else {
                                temp.removeWhere((e) => e.employeeId == emp.employeeId);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9CC70A), foregroundColor: Colors.white),
                onPressed: () {
                  setState(() {
                    _selectedAssignedEmployees.clear();
                    _selectedAssignedEmployees.addAll(temp);
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Confirm Selection'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Modern Date Input Field ───

  Widget _buildModernDateInput({
    required String label,
    required DateTime? date,
    TextEditingController? remarkCtrl,
    required VoidCallback onPick,
  }) {
    final dateField = InkWell(
      onTap: onPick,
      child: AbsorbPointer(
        child: TextFormField(
          readOnly: true,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          decoration: _inputDeco(
            label,
            hint: 'dd-mm-yyyy',
            suffix: const Icon(Icons.calendar_today_outlined, size: 16),
          ),
          controller: TextEditingController(
            text: date != null ? DateFormat('dd-MM-yyyy').format(date) : '',
          ),
        ),
      ),
    );

    if (remarkCtrl == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: dateField,
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: _isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                dateField,
                const SizedBox(height: 8),
                TextFormField(
                  controller: remarkCtrl,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: _inputDeco('$label Notes', hint: 'Remarks...'),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  flex: 4,
                  child: dateField,
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: TextFormField(
                    controller: remarkCtrl,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('$label Notes', hint: 'Remarks...'),
                  ),
                ),
              ],
            ),
    );
  }

  // ─── Tender Lost Module ───

  Widget _buildTenderLostModule() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _isMobile
              ? Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _tenderLostOptions.contains(_tenderLostStatus)
                            ? _tenderLostStatus
                            : null,
                        decoration: _inputDeco('Tender Status'),
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        items: _tenderLostOptions
                            .map((o) => DropdownMenuItem(
                                value: o, child: Text(o.isEmpty ? '-- Select --' : o)))
                            .toList(),
                        onChanged: (v) => setState(() => _tenderLostStatus = v ?? ''),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _competitorNameCtrl,
                        style: const TextStyle(fontSize: 12.5),
                        decoration: _inputDeco('Competitor Name'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _quotedAmountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                  ],
                  style: const TextStyle(fontSize: 12.5),
                  decoration: _inputDeco('Quoted Amount', prefixText: '₹ '),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _tenderLostRemarkCtrl,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: _inputDeco('Tender Lost Remarks'),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF414A51),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    ),
                    onPressed: () => _pickFiles(_tenderLostFiles, existing: _existingTenderLostDocs),
                    icon: const Icon(Icons.attach_file_rounded, size: 16),
                    label: Text(
                      (_existingTenderLostDocs.length + _tenderLostFiles.length) == 0
                          ? 'Attach Documents'
                          : 'Files (${_existingTenderLostDocs.length + _tenderLostFiles.length})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        _tenderLostOptions.contains(_tenderLostStatus) ? _tenderLostStatus : null,
                    decoration: _inputDeco('Tender Status'),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    items: _tenderLostOptions
                        .map((o) => DropdownMenuItem(value: o, child: Text(o.isEmpty ? '-- Select --' : o)))
                        .toList(),
                    onChanged: (v) => setState(() => _tenderLostStatus = v ?? ''),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _competitorNameCtrl,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Competitor Name'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _quotedAmountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                    ],
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Quoted Amount', prefixText: '₹ '),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    controller: _tenderLostRemarkCtrl,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Tender Lost Remarks'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF414A51),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  ),
                  onPressed: () => _pickFiles(_tenderLostFiles, existing: _existingTenderLostDocs),
                  icon: const Icon(Icons.attach_file_rounded, size: 18),
                  label: Text(
                    (_existingTenderLostDocs.length + _tenderLostFiles.length) == 0
                        ? 'Attach Documents'
                        : 'Files (${_existingTenderLostDocs.length + _tenderLostFiles.length})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          if ((_existingTenderLostDocs.length + _tenderLostFiles.length) > 0) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ..._existingTenderLostDocs.map((doc) => _buildDocChip(
                      name: doc.name,
                      isExisting: true,
                      onRemove: () => setState(() => _existingTenderLostDocs.remove(doc)),
                      onView: () => _previewFile(
                        name: doc.name,
                        url: doc.downloadUrl,
                        size: doc.size,
                        isLocal: false,
                      ),
                    )),
                ..._tenderLostFiles.map((file) => _buildDocChip(
                      name: file.name,
                      isExisting: false,
                      onRemove: () => setState(() => _tenderLostFiles.remove(file)),
                      onView: () => _previewFile(
                        name: file.name,
                        bytes: file.bytes,
                        size: file.size,
                        isLocal: true,
                      ),
                    )),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── Profile Drawing Module ───

  Widget _buildProfileDrawingModule() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isMobile) ...[
            TextFormField(
              controller: _profileDrawingRemarkCtrl,
              style: const TextStyle(fontSize: 12.5),
              decoration: _inputDeco('Profile Drawing Remarks'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _profileDrawingDocCtrl,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Drawing Reference'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF414A51),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  ),
                  onPressed: () => _pickFiles(_profileDrawingFiles, existing: _existingProfileDrawingDocs),
                  icon: const Icon(Icons.attach_file, size: 16),
                  label: const Text('File', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    controller: _profileDrawingRemarkCtrl,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Profile Drawing Remarks'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    controller: _profileDrawingDocCtrl,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Drawing Reference'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF414A51),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  ),
                  onPressed: () => _pickFiles(_profileDrawingFiles, existing: _existingProfileDrawingDocs),
                  icon: const Icon(Icons.attach_file, size: 16),
                  label: const Text('File', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
          if (_existingProfileDrawingDocs.isNotEmpty || _profileDrawingFiles.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ..._existingProfileDrawingDocs.map((d) => _buildDocChip(
                      name: d.name,
                      isExisting: true,
                      onRemove: () => setState(() => _existingProfileDrawingDocs.remove(d)),
                      onView: () => _previewFile(
                        name: d.name,
                        url: d.downloadUrl,
                        size: d.size,
                        isLocal: false,
                      ),
                    )),
                ..._profileDrawingFiles.map((f) => _buildDocChip(
                      name: f.name,
                      isExisting: false,
                      onRemove: () => setState(() => _profileDrawingFiles.remove(f)),
                      onView: () => _previewFile(
                        name: f.name,
                        bytes: f.bytes,
                        size: f.size,
                        isLocal: true,
                      ),
                    )),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── Subcontract & Machinery Module ───

  Widget _buildSubcontractAndMachineryModule() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(12),
      child: _isMobile
          ? Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: ['Yes', 'No'].contains(_subContract) ? _subContract : 'No',
                        decoration: _inputDeco('Subcontract In Use?'),
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        items: ['Yes', 'No']
                            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                            .toList(),
                        onChanged: (v) => setState(() => _subContract = v ?? 'No'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue:
                            _ownOrSubcontractOptions.contains(_ownOrSubcontract) ? _ownOrSubcontract : null,
                        decoration: _inputDeco('Machinery Usage'),
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        items: _ownOrSubcontractOptions
                            .map((o) => DropdownMenuItem(value: o, child: Text(o.isEmpty ? '-- Select --' : o)))
                            .toList(),
                        onChanged: (v) => setState(() => _ownOrSubcontract = v ?? ''),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _ownMachineRemarkCtrl,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: _inputDeco('Machinery Usage Remarks'),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    initialValue: ['Yes', 'No'].contains(_subContract) ? _subContract : 'No',
                    decoration: _inputDeco('Subcontract In Use?'),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    items: ['Yes', 'No']
                        .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                        .toList(),
                    onChanged: (v) => setState(() => _subContract = v ?? 'No'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        _ownOrSubcontractOptions.contains(_ownOrSubcontract) ? _ownOrSubcontract : null,
                    decoration: _inputDeco('Machinery Usage'),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    items: _ownOrSubcontractOptions
                        .map((o) => DropdownMenuItem(value: o, child: Text(o.isEmpty ? '-- Select --' : o)))
                        .toList(),
                    onChanged: (v) => setState(() => _ownOrSubcontract = v ?? ''),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: TextFormField(
                    controller: _ownMachineRemarkCtrl,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Machinery Usage Remarks'),
                  ),
                ),
              ],
            ),
    );
  }

  // ─── Scope of Work Interactive Matrix Module ───

  Widget _buildScopeOfWorkModule() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _scopeOfWorkRemarkCtrl,
            style: const TextStyle(fontSize: 12.5),
            decoration: _inputDeco('General Scope Remarks / Specifications'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _kScopeCatalog.map((item) {
              final key = item['key'] as String;
              final label = item['label'] as String;
              final icon = item['icon'] as IconData;
              final isChecked = _scopeItems.contains(key);

              return InkWell(
                onTap: () {
                  setState(() {
                    if (isChecked) {
                      _scopeItems.remove(key);
                    } else {
                      _scopeItems.add(key);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isChecked ? const Color(0xFF9CC70A).withValues(alpha: 0.16) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isChecked ? const Color(0xFF9CC70A) : const Color(0xFFCBD5E1),
                      width: isChecked ? 1.4 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: isChecked ? const Color(0xFF414A51) : const Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isChecked ? FontWeight.w700 : FontWeight.w500,
                          color: isChecked ? const Color(0xFF1E293B) : const Color(0xFF475569),
                        ),
                      ),
                      if (isChecked) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF9CC70A)),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 280,
            child: TextFormField(
              controller: _otherScopeCtrl,
              style: const TextStyle(fontSize: 12.5),
              decoration: _inputDeco('Other Scope Elements (Free Text)'),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Billing Details & Flow of Bills Module ───

  Widget _buildBillingAndFlowModule() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isMobile) ...[
            TextFormField(
              controller: _billingDetailsRemarkCtrl,
              style: const TextStyle(fontSize: 12.5),
              decoration: _inputDeco('Billing Specification Remarks'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF414A51),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    ),
                    onPressed: () => _pickFiles(_billingDetailsFiles, existing: _existingBillingDetailsDocs),
                    icon: const Icon(Icons.receipt_long_outlined, size: 16),
                    label: Text(
                      _existingBillingDetailsDocs.isEmpty && _billingDetailsFiles.isEmpty
                          ? 'Upload Bills'
                          : 'Bills (${_existingBillingDetailsDocs.length + _billingDetailsFiles.length})',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9CC70A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    ),
                    onPressed: () => _toast('Opening Billing Chat...'),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                    label: const Text('BILL CHAT',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                        overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    controller: _billingDetailsRemarkCtrl,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Billing Specification Remarks'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF414A51),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  ),
                  onPressed: () => _pickFiles(_billingDetailsFiles, existing: _existingBillingDetailsDocs),
                  icon: const Icon(Icons.receipt_long_outlined, size: 16),
                  label: Text(
                    _existingBillingDetailsDocs.isEmpty && _billingDetailsFiles.isEmpty
                        ? 'Upload Bills'
                        : 'Bills (${_existingBillingDetailsDocs.length + _billingDetailsFiles.length})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9CC70A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  ),
                  onPressed: () => _toast('Opening Billing Chat...'),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('OPEN BILL CHAT',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                ),
              ],
            ),
          ],
          if (_existingBillingDetailsDocs.isNotEmpty || _billingDetailsFiles.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ..._existingBillingDetailsDocs.map((d) => _buildDocChip(
                      name: d.name,
                      isExisting: true,
                      onRemove: () => setState(() => _existingBillingDetailsDocs.remove(d)),
                      onView: () => _previewFile(
                        name: d.name,
                        url: d.downloadUrl,
                        size: d.size,
                        isLocal: false,
                      ),
                    )),
                ..._billingDetailsFiles.map((f) => _buildDocChip(
                      name: f.name,
                      isExisting: false,
                      onRemove: () => setState(() => _billingDetailsFiles.remove(f)),
                      onView: () => _previewFile(
                        name: f.name,
                        bytes: f.bytes,
                        size: f.size,
                        isLocal: true,
                      ),
                    )),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),
          if (_isMobile) ...[
            DropdownButtonFormField<String>(
              initialValue:
                  _flowOfBillsOptions.contains(_flowOfBillsStatus) ? _flowOfBillsStatus : null,
              decoration: _inputDeco('Flow of Bills Status'),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              items: _flowOfBillsOptions
                  .map((o) => DropdownMenuItem(value: o, child: Text(o.isEmpty ? '-- Select --' : o)))
                  .toList(),
              onChanged: (v) => setState(() => _flowOfBillsStatus = v ?? ''),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _flowOfBillsRemarkCtrl,
              style: const TextStyle(fontSize: 12.5),
              decoration: _inputDeco('Flow of Bills Remarks'),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        _flowOfBillsOptions.contains(_flowOfBillsStatus) ? _flowOfBillsStatus : null,
                    decoration: _inputDeco('Flow of Bills Status'),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    items: _flowOfBillsOptions
                        .map((o) => DropdownMenuItem(value: o, child: Text(o.isEmpty ? '-- Select --' : o)))
                        .toList(),
                    onChanged: (v) => setState(() => _flowOfBillsStatus = v ?? ''),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 6,
                  child: TextFormField(
                    controller: _flowOfBillsRemarkCtrl,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Flow of Bills Remarks'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── Payment & Deductions Breakdown Module ───

  Widget _buildPaymentAndDeductionModule() {
    double totalDeductions = 0;
    for (final d in _deductions) {
      totalDeductions += d.deductionAmount;
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isMobile) ...[
            TextFormField(
              controller: _paymentAmountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
              ],
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              decoration: _inputDeco('Payment Received Amount', prefixText: '₹ '),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _paymentRemarkCtrl,
              style: const TextStyle(fontSize: 12.5),
              decoration: _inputDeco('Payment Received Remarks'),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _paymentAmountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                    ],
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    decoration: _inputDeco('Payment Received Amount', prefixText: '₹ '),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 6,
                  child: TextFormField(
                    controller: _paymentRemarkCtrl,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Payment Received Remarks'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),

          // Deduction Adder Row
          if (_isMobile) ...[
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        _deductionTypeOptions.contains(_deductionType) ? _deductionType : null,
                    decoration: _inputDeco('Deduction Type'),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    items: _deductionTypeOptions
                        .map((o) => DropdownMenuItem(value: o, child: Text(o.isEmpty ? '-- Select --' : o)))
                        .toList(),
                    onChanged: (v) => setState(() => _deductionType = v ?? ''),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _deductionAmountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                    ],
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Deducted Amount', prefixText: '₹ '),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF414A51),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final amt = double.tryParse(_deductionAmountCtrl.text.trim()) ?? 0;
                if (_deductionType.isEmpty) {
                  _toast('Select a deduction type.', isError: true);
                  return;
                }
                setState(() {
                  _deductions.add(DeductionEntry(
                    deductionId: 'DED-${DateTime.now().millisecondsSinceEpoch % 100000}',
                    deductionType: _deductionType,
                    deductionAmount: amt,
                  ));
                  _deductionType = '';
                  _deductionAmountCtrl.clear();
                });
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Deduction Entry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        _deductionTypeOptions.contains(_deductionType) ? _deductionType : null,
                    decoration: _inputDeco('Deduction Type'),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    items: _deductionTypeOptions
                        .map((o) => DropdownMenuItem(value: o, child: Text(o.isEmpty ? '-- Select --' : o)))
                        .toList(),
                    onChanged: (v) => setState(() => _deductionType = v ?? ''),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _deductionAmountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                    ],
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Deducted Amount', prefixText: '₹ '),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF414A51),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    final amt = double.tryParse(_deductionAmountCtrl.text.trim()) ?? 0;
                    if (_deductionType.isEmpty) {
                      _toast('Select a deduction type.', isError: true);
                      return;
                    }
                    setState(() {
                      _deductions.add(DeductionEntry(
                        deductionId: 'DED-${DateTime.now().millisecondsSinceEpoch % 100000}',
                        deductionType: _deductionType,
                        deductionAmount: amt,
                      ));
                      _deductionType = '';
                      _deductionAmountCtrl.clear();
                    });
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Deduction', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),

          // Deductions Table
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tableWidth = math.max(constraints.maxWidth, 500.0);
                return ScrollConfiguration(
                  behavior:
                      ScrollConfiguration.of(context).copyWith(scrollbars: false),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      child: Table(
                      border: TableBorder.all(color: const Color(0xFFE2E8F0)),
                      columnWidths: const {
                        0: FlexColumnWidth(3),
                        1: FlexColumnWidth(4),
                        2: FlexColumnWidth(3),
                        3: FixedColumnWidth(36),
                      },
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(color: Color(0xFF414A51)),
                          children: const [
                            Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                child: Text('Deduction ID',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white))),
                            Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                child: Text('Deduction Type',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white))),
                            Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                child: Text('Amount (₹)',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white))),
                            Padding(padding: EdgeInsets.all(8), child: Text('')),
                          ],
                        ),
                        if (_deductions.isEmpty)
                          TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                child: Text('No deduction entries recorded.',
                                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
                              ),
                              const SizedBox(),
                              const SizedBox(),
                              const SizedBox(),
                            ],
                          )
                        else ...[
                          ..._deductions.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final d = entry.value;
                            return TableRow(
                              decoration: BoxDecoration(
                                color: idx.isEven ? Colors.white : const Color(0xFFF8FAFC),
                              ),
                              children: [
                                Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    child: Text(d.deductionId, style: const TextStyle(fontSize: 12))),
                                Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    child: Text(d.deductionType, style: const TextStyle(fontSize: 12))),
                                Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    child: Text('₹${d.deductionAmount.toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                                  onPressed: () => setState(() => _deductions.removeAt(idx)),
                                ),
                              ],
                            );
                          }),
                          TableRow(
                            decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                            children: [
                              const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  child: Text('Total Deductions',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
                              const SizedBox(),
                              Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  child: Text('₹${totalDeductions.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.redAccent))),
                              const SizedBox(),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Retention Card ───

  Widget _buildRetentionCard({
    required String title,
    required TextEditingController remarkCtrl,
    required TextEditingController amountCtrl,
    required DateTime? date,
    required VoidCallback onPickDate,
    required List<PlatformFile> files,
    required List<ProjectDocument> existingDocs,
    required void Function(ProjectDocument) onExistingRemoved,
    String docLabel = 'Retention Documents',
    Widget? extraChild,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF475569),
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (date != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    DateFormat('dd MMM yyyy').format(date),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF414A51),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isMobile) ...[
            TextFormField(
              controller: remarkCtrl,
              style: const TextStyle(fontSize: 12.5),
              decoration: _inputDeco('Remarks', hint: 'Notes...'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                    ],
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    decoration: _inputDeco('Amount', prefixText: '₹ '),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: InkWell(
                    onTap: onPickDate,
                    child: AbsorbPointer(
                      child: TextFormField(
                        readOnly: true,
                        style: const TextStyle(fontSize: 12.5),
                        decoration: _inputDeco(
                          'Receivable Date',
                          hint: 'dd-mm-yyyy',
                          suffix: const Icon(Icons.calendar_today_outlined, size: 15),
                        ),
                        controller: TextEditingController(
                          text: date != null ? DateFormat('dd-MM-yyyy').format(date) : '',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF414A51),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                ),
                onPressed: () => _pickFiles(files, existing: existingDocs),
                icon: const Icon(Icons.attach_file, size: 16),
                label: Text(
                  existingDocs.isEmpty && files.isEmpty ? 'Attach $docLabel' : '$docLabel (${existingDocs.length + files.length})',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    controller: remarkCtrl,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: _inputDeco('Remarks', hint: 'Notes...'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                    ],
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    decoration: _inputDeco('Amount', prefixText: '₹ '),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: InkWell(
                    onTap: onPickDate,
                    child: AbsorbPointer(
                      child: TextFormField(
                        readOnly: true,
                        style: const TextStyle(fontSize: 12.5),
                        decoration: _inputDeco(
                          'Receivable Date',
                          hint: 'dd-mm-yyyy',
                          suffix: const Icon(Icons.calendar_today_outlined, size: 15),
                        ),
                        controller: TextEditingController(
                          text: date != null ? DateFormat('dd-MM-yyyy').format(date) : '',
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF414A51),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  ),
                  onPressed: () => _pickFiles(files, existing: existingDocs),
                  icon: const Icon(Icons.attach_file, size: 16),
                  label: Text(
                    existingDocs.isEmpty && files.isEmpty ? 'File' : '${existingDocs.length + files.length}',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
          ?extraChild,
          if (existingDocs.isNotEmpty || files.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ...existingDocs.map((d) => _buildDocChip(
                      name: d.name,
                      isExisting: true,
                      onRemove: () => onExistingRemoved(d),
                      onView: () => _previewFile(
                        name: d.name,
                        url: d.downloadUrl,
                        size: d.size,
                        isLocal: false,
                      ),
                    )),
                ...files.map((f) => _buildDocChip(
                      name: f.name,
                      isExisting: false,
                      onRemove: () => setState(() => files.remove(f)),
                      onView: () => _previewFile(
                        name: f.name,
                        bytes: f.bytes,
                        size: f.size,
                        isLocal: true,
                      ),
                    )),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── Modern Floating Footer Action Card ───

  Widget _buildFooterActionCard() {
    final seq = _extractSerialFromCode(_loadedProject?.projectCode ?? '');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: _isMobile ? 14 : 20,
        vertical: _isMobile ? 12 : 16,
      ),
      child: _isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9CC70A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 2,
                  ),
                  onPressed: _isSubmitting ? null : _handleUpdate,
                  child: _isSubmitting
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                            SizedBox(width: 12),
                            Text('SAVING CHANGES...',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'UPDATE SITE PROJECT${seq.isNotEmpty ? ' #$seq' : ''}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          if (context.canPop()) {
                            context.pop(false);
                          } else {
                            context.go('/projects/assigned');
                          }
                        },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.close_rounded, size: 17),
                      SizedBox(width: 8),
                      Text('DISCARD / CANCEL',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300, width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          if (context.canPop()) {
                            context.pop(false);
                          } else {
                            context.go('/projects/assigned');
                          }
                        },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('DISCARD / CANCEL',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    ],
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9CC70A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 2,
                  ),
                  onPressed: _isSubmitting ? null : _handleUpdate,
                  child: _isSubmitting
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                            SizedBox(width: 12),
                            Text('SAVING CHANGES...',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                          ],
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 18),
                            const SizedBox(width: 10),
                            Text(
                              'UPDATE SITE PROJECT${seq.isNotEmpty ? ' #$seq' : ''}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  String _extractFromProjectCode(SiteProject p) {
    final parts = p.projectCode.split('-');
    if (parts.length > 2 && parts[2].contains('/')) return parts[2];
    if (parts.length > 3) return parts[3];
    return '—';
  }

  String _extractSerialFromCode(String code) {
    final parts = code.split('-');
    if (parts.length > 3 && int.tryParse(parts[3]) != null) return parts[3];
    if (parts.isNotEmpty) return parts.last;
    return '';
  }
}
