import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/location_data.dart';
import '../../../../core/widgets/app_searchable_dropdown.dart';
import '../../../../models/customer.dart';
import '../../../../providers/customer_providers.dart';
import '../../../employee/domain/employee.dart';
import '../../../employee/providers/employee_providers.dart';
import '../../domain/models/site_project.dart';
import '../../domain/services/project_code_generator.dart';
import '../../providers/project_providers.dart';
import '../dialogs/add_client_dialog.dart';

class NewProjectFormScreen extends ConsumerStatefulWidget {
  const NewProjectFormScreen({super.key});

  @override
  ConsumerState<NewProjectFormScreen> createState() =>
      _NewProjectFormScreenState();
}

class _NewProjectFormScreenState extends ConsumerState<NewProjectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // ── State variables ──
  bool _isSubmitting = false;

  // SECTION 1 — GENERAL CODE
  Employee? _selectedCreatorEmployee;
  Customer? _selectedClient;
  final _generalDetailsController = TextEditingController();
  final _placeController = TextEditingController();
  final _generalCodeController = TextEditingController();

  // SECTION 2 — PROJECT CODE
  String _subOrOwn = 'Own';
  String _selectedState = 'Tamil Nadu';
  String _selectedDistrict = 'Chennai';
  final _areaController = TextEditingController();
  final _projectCodeController = TextEditingController();

  // SECTION 3 — TENDER TYPE
  String _selectedTenderType = 'Open Tender';

  // SECTION 4 — TENDER SPEC / ENQUIRY SPEC
  final _tenderSpecRemarkController = TextEditingController();
  final List<PlatformFile> _tenderSpecFiles = [];

  // SECTION 5 — ASSIGNED TO (Multiple employees)
  final List<Employee> _selectedAssignedEmployees = [];
  bool _assignedInitialized = false;

  // SECTION 6 — OPENING DATE
  final _openingDateRemarkController = TextEditingController();
  DateTime? _openingDate;

  // SECTION 7 — CLOSING DATE
  final _closingDateRemarkController = TextEditingController();
  DateTime? _closingDate;

  // SECTION 8 — BQR
  final _bqrRemarkController = TextEditingController();
  final List<PlatformFile> _bqrFiles = [];

  // SECTION 9 — EMD / EMD EXEMPTION
  final _emdRemarkController = TextEditingController();
  final List<PlatformFile> _emdFiles = [];

  // List of districts dynamically computed from State
  List<String> _districtsList = [];

  @override
  void initState() {
    super.initState();
    _updateDistrictsForState(_selectedState);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _generalDetailsController.dispose();
    _placeController.dispose();
    _generalCodeController.dispose();
    _areaController.dispose();
    _projectCodeController.dispose();
    _tenderSpecRemarkController.dispose();
    _openingDateRemarkController.dispose();
    _closingDateRemarkController.dispose();
    _bqrRemarkController.dispose();
    _emdRemarkController.dispose();
    super.dispose();
  }

  void _updateDistrictsForState(String state) {
    if (state == 'Tamil Nadu') {
      _districtsList = [
        'Chennai',
        'Chengalpattu',
        'Coimbatore',
        'Cuddalore',
        'Dharmapuri',
        'Dindigul',
        'Erode',
        'Kallakurichi',
        'Kanchipuram',
        'Kanyakumari',
        'Karur',
        'Krishnagiri',
        'Madurai',
        'Mayiladuthurai',
        'Nagapattinam',
        'Namakkal',
        'Nilgiris',
        'Perambalur',
        'Pudukkottai',
        'Ramanathapuram',
        'Ranipet',
        'Salem',
        'Sivaganga',
        'Tenkasi',
        'Thanjavur',
        'Theni',
        'Thoothukudi',
        'Tiruchirappalli',
        'Tirunelveli',
        'Tirupathur',
        'Tiruppur',
        'Tiruvallur',
        'Tiruvannamalai',
        'Tiruvarur',
        'Vellore',
        'Viluppuram',
        'Virudhunagar',
      ];
    } else if (state == 'Karnataka') {
      _districtsList = [
        'Bengaluru Urban',
        'Bengaluru Rural',
        'Mysuru',
        'Dakshina Kannada',
        'Belagavi',
        'Dharwad',
        'Tumakuru',
        'Shivamogga',
        'Udupi',
        'Hassan',
        'Mandya',
      ];
    } else if (state == 'Maharashtra') {
      _districtsList = [
        'Mumbai City',
        'Mumbai Suburban',
        'Pune',
        'Thane',
        'Nagpur',
        'Nashik',
        'Palghar',
        'Chhatrapati Sambhajinagar',
      ];
    } else if (state == 'Delhi') {
      _districtsList = [
        'New Delhi',
        'Central Delhi',
        'North Delhi',
        'South Delhi',
        'West Delhi',
        'East Delhi',
      ];
    } else if (state == 'Andhra Pradesh') {
      _districtsList = [
        'Visakhapatnam',
        'NTR Vijayawada',
        'Guntur',
        'Tirupati',
        'Kurnool',
        'Nellore',
      ];
    } else if (state == 'Telangana') {
      _districtsList = [
        'Hyderabad',
        'Ranga Reddy',
        'Medchal-Malkajgiri',
        'Hanamkonda',
        'Warangal',
      ];
    } else {
      _districtsList = [
        'Central District',
        'North District',
        'South District',
        'East District',
        'West District',
      ];
    }

    if (!_districtsList.contains(_selectedDistrict)) {
      _selectedDistrict = _districtsList.first;
    }
  }

  void _generateGeneralCodeAction() {
    final clientName = _selectedClient?.displayName.isNotEmpty == true
        ? _selectedClient!.displayName
        : (_selectedClient?.companyName ?? 'GEN');
    final place = _placeController.text.trim();

    final code = ProjectCodeGenerator.generateGeneralCode(
      clientName: clientName,
      place: place,
      sequenceNumber: 1,
    );

    setState(() {
      _generalCodeController.text = code;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generated General Code: $code'),
        backgroundColor: const Color(0xFF414A51),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _generateProjectCodeAction() {
    final clientName = _selectedClient?.displayName.isNotEmpty == true
        ? _selectedClient!.displayName
        : (_selectedClient?.companyName ?? 'CLI');
    final area = _areaController.text.trim();

    final code = ProjectCodeGenerator.generateProjectCode(
      clientName: clientName,
      subOrOwn: _subOrOwn,
      state: _selectedState,
      district: _selectedDistrict,
      area: area,
      sequenceNumber: 1,
    );

    setState(() {
      _projectCodeController.text = code;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generated Project Code: $code'),
        backgroundColor: const Color(0xFF414A51),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickFiles(List<PlatformFile> targetList) async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        withData: true,
      );
      if (result == null) return;

      final remaining = 5 - targetList.length;
      if (remaining <= 0) {
        _showToast('You can upload a maximum of 5 files.');
        return;
      }

      final validFiles = <PlatformFile>[];
      for (final f in result.files) {
        if (f.size > 10 * 1024 * 1024) {
          _showToast('${f.name} exceeds 10MB limit.');
          continue;
        }
        validFiles.add(f);
      }

      setState(() {
        targetList.addAll(validFiles.take(remaining));
      });
    } catch (e) {
      _showToast('Could not pick files: $e');
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _pickDate({required bool isOpening}) async {
    final now = DateTime.now();
    final initial = isOpening
        ? (_openingDate ?? now)
        : (_closingDate ?? _openingDate ?? now);

    final first = isOpening ? DateTime(2020) : (_openingDate ?? DateTime(2020));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(2035),
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
      setState(() {
        if (isOpening) {
          _openingDate = picked;
          if (_closingDate != null && _closingDate!.isBefore(picked)) {
            _closingDate = null;
          }
        } else {
          _closingDate = picked;
        }
      });
    }
  }

  Future<void> _openAddClientDialog() async {
    final createdCustomer = await showDialog<Customer>(
      context: context,
      builder: (_) => const AddClientDialog(),
    );

    if (createdCustomer != null && mounted) {
      setState(() {
        _selectedClient = createdCustomer;
      });
    }
  }

  Future<void> _handleCreateSiteProject() async {
    // 1. Validation
    if (!(_formKey.currentState?.validate() ?? false)) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      _showToast('Please fill all mandatory fields marked with *');
      return;
    }

    if (_selectedClient == null) {
      _showToast('Please select a Client *');
      return;
    }

    if (_selectedCreatorEmployee == null) {
      _showToast('Please select Employee Name * in Section 1');
      return;
    }

    if (_selectedAssignedEmployees.isEmpty) {
      _showToast('Please assign at least one Employee * in Section 5');
      return;
    }

    // Auto-generate codes if user did not click CREATE CODE
    if (_generalCodeController.text.trim().isEmpty) {
      _generalCodeController.text = ProjectCodeGenerator.generateGeneralCode(
        clientName: _selectedClient!.displayName,
        place: _placeController.text.trim(),
      );
    }

    if (_projectCodeController.text.trim().isEmpty) {
      _projectCodeController.text = ProjectCodeGenerator.generateProjectCode(
        clientName: _selectedClient!.displayName,
        subOrOwn: _subOrOwn,
        state: _selectedState,
        district: _selectedDistrict,
        area: _areaController.text.trim(),
      );
    }

    // Validate closing date relative to opening date
    if (_openingDate != null && _closingDate != null) {
      if (_closingDate!.isBefore(_openingDate!)) {
        _showToast('Closing Date cannot be earlier than Opening Date.');
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final currentEmp = ref.read(currentEmployeeProvider);
      final clientName = _selectedClient!.displayName.isNotEmpty
          ? _selectedClient!.displayName
          : (_selectedClient!.companyName.isNotEmpty
              ? _selectedClient!.companyName
              : 'Unknown Client');

      final assignedNames =
          _selectedAssignedEmployees.map((e) => e.fullName).toList();
      final assignedIds =
          _selectedAssignedEmployees.map((e) => e.employeeId).toList();

      final project = SiteProject(
        employeeName: _selectedCreatorEmployee!.fullName,
        employeeId: _selectedCreatorEmployee!.employeeId,
        clientName: clientName,
        clientId: _selectedClient!.id,
        generalDetails: _generalDetailsController.text.trim(),
        place: _placeController.text.trim(),
        generalCode: _generalCodeController.text.trim(),
        subOrOwn: _subOrOwn,
        state: _selectedState,
        district: _selectedDistrict,
        area: _areaController.text.trim(),
        projectCode: _projectCodeController.text.trim(),
        tenderType: _selectedTenderType,
        tenderSpecRemark: _tenderSpecRemarkController.text.trim(),
        assignedToEmployeeNames: assignedNames,
        assignedToEmployeeIds: assignedIds,
        assignedToEmployeeName: assignedNames.join(', '),
        assignedToEmployeeId: assignedIds.join(', '),
        openingDate: _openingDate,
        openingDateRemark: _openingDateRemarkController.text.trim(),
        closingDate: _closingDate,
        closingDateRemark: _closingDateRemarkController.text.trim(),
        bqrRemark: _bqrRemarkController.text.trim(),
        emdRemark: _emdRemarkController.text.trim(),
        status: 'Active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: currentEmp?.fullName ?? currentEmp?.employeeId ?? 'Admin',
      );

      final filesByCategory = <String, List<PlatformFile>>{
        'tender_spec': _tenderSpecFiles,
        'bqr': _bqrFiles,
        'emd': _emdFiles,
      };

      await ref.read(projectRepositoryProvider).createProject(
            project,
            filesByCategory: filesByCategory,
          );

      ref.invalidate(projectsStreamProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Site Project "${project.projectCode}" created successfully!',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF414A51),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/module/project');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create site project: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(allEmployeesProvider);
    final allEmployees = employeesAsync.valueOrNull ?? [];
    final currentEmp = ref.watch(currentEmployeeProvider);

    // Auto-select creator employee if not yet selected
    if (_selectedCreatorEmployee == null && allEmployees.isNotEmpty) {
      if (currentEmp != null) {
        final match = allEmployees.firstWhere(
          (e) => e.id == currentEmp.id || e.employeeId == currentEmp.employeeId,
          orElse: () => allEmployees.first,
        );
        _selectedCreatorEmployee = match;
      } else {
        _selectedCreatorEmployee = allEmployees.first;
      }
    }

    if (!_assignedInitialized && allEmployees.isNotEmpty) {
      _assignedInitialized = true;
      if (_selectedCreatorEmployee != null) {
        _selectedAssignedEmployees.add(_selectedCreatorEmployee!);
      } else {
        _selectedAssignedEmployees.add(allEmployees.first);
      }
    }

    final customersAsync = ref.watch(activeCustomersProvider);
    final customers = customersAsync.valueOrNull ?? [];

    if (_selectedClient == null && customers.isNotEmpty) {
      _selectedClient = customers.first;
    }

    final tenderTypesAsync = ref.watch(tenderTypesProvider);
    final tenderTypes = tenderTypesAsync.valueOrNull ??
        [
          'Open Tender',
          'Limited Tender',
          'Single Tender / Direct',
          'E-Tender',
          'Item Rate Tender',
          'Percentage Rate Tender',
          'EPC Tender',
          'Turnkey Tender',
          'Quotation',
          'Other',
        ];

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF414A51)),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/module/project');
            }
          },
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF9C27B0).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.rocket_launch_rounded,
                size: 20,
                color: Color(0xFF9C27B0),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'NEW PROJECT',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF414A51),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE5E8E2), height: 1),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Scrollbar(
          controller: _scrollController,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 28,
              vertical: 20,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // SECTION 1 — GENERAL CODE
                    _buildSectionCard(
                      sectionNumber: 'SECTION 1',
                      sectionTitle: 'GENERAL CODE',
                      icon: Icons.qr_code_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isMobile) ...[
                            _buildEmployeeSelectField(
                              label: 'Employee Name *',
                              employees: allEmployees,
                              selected: _selectedCreatorEmployee,
                              onChanged: (emp) => setState(
                                  () => _selectedCreatorEmployee = emp),
                            ),
                            const SizedBox(height: 14),
                            _buildClientSelectField(customers),
                          ] else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildEmployeeSelectField(
                                    label: 'Employee Name *',
                                    employees: allEmployees,
                                    selected: _selectedCreatorEmployee,
                                    onChanged: (emp) => setState(
                                        () => _selectedCreatorEmployee = emp),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(child: _buildClientSelectField(customers)),
                              ],
                            ),
                          const SizedBox(height: 14),
                          if (isMobile) ...[
                            TextFormField(
                              controller: _generalDetailsController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Details',
                                hintText: 'Enter general project details...',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _placeController,
                              decoration: const InputDecoration(
                                labelText: 'Place',
                                hintText: 'e.g. Chennai, Bangalore',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ] else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _generalDetailsController,
                                    maxLines: 2,
                                    decoration: const InputDecoration(
                                      labelText: 'Details',
                                      hintText: 'Enter general project details...',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 1,
                                  child: TextFormField(
                                    controller: _placeController,
                                    decoration: const InputDecoration(
                                      labelText: 'Place',
                                      hintText: 'e.g. Chennai',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 16),
                          // General Code Action & Display
                          _buildCodeActionRow(
                            codeLabel: 'General Code',
                            controller: _generalCodeController,
                            buttonLabel: 'CREATE CODE',
                            onGenerate: _generateGeneralCodeAction,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // SECTION 2 — PROJECT CODE
                    _buildSectionCard(
                      sectionNumber: 'SECTION 2',
                      sectionTitle: 'PROJECT CODE',
                      icon: Icons.code_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isMobile) ...[
                            _buildClientDisplayOrSelect(customers),
                            const SizedBox(height: 14),
                            _buildSubOrOwnDropdown(),
                          ] else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildClientDisplayOrSelect(customers)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildSubOrOwnDropdown()),
                              ],
                            ),
                          const SizedBox(height: 14),
                          // Location Hierarchy: State -> District -> Area
                          if (isMobile) ...[
                            _buildStateDropdown(),
                            const SizedBox(height: 14),
                            _buildDistrictDropdown(),
                            const SizedBox(height: 14),
                            _buildAreaField(),
                          ] else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildStateDropdown()),
                                const SizedBox(width: 16),
                                Expanded(child: _buildDistrictDropdown()),
                                const SizedBox(width: 16),
                                Expanded(child: _buildAreaField()),
                              ],
                            ),
                          const SizedBox(height: 16),
                          // Project Code Action & Display
                          _buildCodeActionRow(
                            codeLabel: 'Project Code',
                            controller: _projectCodeController,
                            buttonLabel: 'CREATE CODE',
                            onGenerate: _generateProjectCodeAction,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // SECTION 3 — TENDER TYPE
                    _buildSectionCard(
                      sectionNumber: 'SECTION 3',
                      sectionTitle: 'TENDER TYPE',
                      icon: Icons.assignment_outlined,
                      child: AppSearchableDropdown<String>(
                        label: 'Tender Type',
                        value: tenderTypes.contains(_selectedTenderType)
                            ? _selectedTenderType
                            : (tenderTypes.isNotEmpty ? tenderTypes.first : 'Open Tender'),
                        items: tenderTypes,
                        searchHint: 'Search tender type...',
                        placeholder: 'Select Tender Type',
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedTenderType = val);
                        },
                      ),
                    ),
                    const SizedBox(height: 18),

                    // SECTION 4 — TENDER SPEC / ENQUIRY SPEC
                    _buildSectionCard(
                      sectionNumber: 'SECTION 4',
                      sectionTitle: 'TENDER SPEC / ENQUIRY SPEC',
                      icon: Icons.description_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _tenderSpecRemarkController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Remark Text',
                              hintText: 'Enter specification or enquiry remarks...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildFileUploadWidget(
                            label: 'Tender Spec Documents',
                            files: _tenderSpecFiles,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // SECTION 5 — ASSIGNED TO
                    _buildSectionCard(
                      sectionNumber: 'SECTION 5',
                      sectionTitle: 'ASSIGNED TO',
                      icon: Icons.person_pin_circle_outlined,
                      child: _buildMultipleEmployeeSelectField(allEmployees),
                    ),
                    const SizedBox(height: 18),

                    // SECTION 6 — OPENING DATE
                    _buildSectionCard(
                      sectionNumber: 'SECTION 6',
                      sectionTitle: 'OPENING DATE',
                      icon: Icons.calendar_today_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _openingDateRemarkController,
                            decoration: const InputDecoration(
                              labelText: 'Remark Text',
                              hintText: 'Opening date notes/remarks...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildDatePickerWidget(
                            label: 'Opening Date',
                            selectedDate: _openingDate,
                            onTap: () => _pickDate(isOpening: true),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // SECTION 7 — CLOSING DATE
                    _buildSectionCard(
                      sectionNumber: 'SECTION 7',
                      sectionTitle: 'CLOSING DATE',
                      icon: Icons.event_busy_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _closingDateRemarkController,
                            decoration: const InputDecoration(
                              labelText: 'Remark Text',
                              hintText: 'Closing date notes/remarks...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildDatePickerWidget(
                            label: 'Closing Date',
                            selectedDate: _closingDate,
                            onTap: () => _pickDate(isOpening: false),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // SECTION 8 — BQR
                    _buildSectionCard(
                      sectionNumber: 'SECTION 8',
                      sectionTitle: 'BQR',
                      icon: Icons.fact_check_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _bqrRemarkController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Remark Text',
                              hintText: 'BQR (Bidder Qualification Requirement) remarks...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildFileUploadWidget(
                            label: 'BQR Documents',
                            files: _bqrFiles,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // SECTION 9 — EMD / EMD EXEMPTION
                    _buildSectionCard(
                      sectionNumber: 'SECTION 9',
                      sectionTitle: 'EMD / EMD EXEMPTION',
                      icon: Icons.account_balance_wallet_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _emdRemarkController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Remark Text',
                              hintText: 'EMD amount, exemption details, bank guarantee...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildFileUploadWidget(
                            label: 'EMD Documents',
                            files: _emdFiles,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── FINAL ACTION: CREATE NEW SITE PROJECT ──
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF9CC70A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                        onPressed:
                            _isSubmitting ? null : _handleCreateSiteProject,
                        child: _isSubmitting
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 14),
                                  Text(
                                    'CREATING SITE PROJECT...',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_task_rounded, size: 20),
                                  SizedBox(width: 10),
                                  Text(
                                    'CREATE NEW SITE PROJECT',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helper Widgets ──

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

  Widget _buildMultipleEmployeeSelectField(List<Employee> allEmployees) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            RichText(
              text: const TextSpan(
                text: 'Employee Name',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
                children: [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (_selectedAssignedEmployees.isNotEmpty)
              Text(
                '${_selectedAssignedEmployees.length} employee(s) assigned',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9CC70A),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),

        // Interactive Selector Box
        InkWell(
          onTap: () => _openEmployeeMultiSelectDialog(allEmployees),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _selectedAssignedEmployees.isEmpty
                    ? Colors.red.shade300
                    : const Color(0xFFD0D5DD),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedAssignedEmployees.isEmpty
                        ? 'Select one or more employees...'
                        : _selectedAssignedEmployees
                            .map((e) => '${e.employeeId} - ${e.fullName}')
                            .join(', '),
                    style: TextStyle(
                      fontSize: 12,
                      color: _selectedAssignedEmployees.isEmpty
                          ? Colors.black38
                          : Colors.black87,
                      fontWeight: _selectedAssignedEmployees.isEmpty
                          ? FontWeight.normal
                          : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 14, color: Color(0xFF414A51)),
                      SizedBox(width: 2),
                      Text(
                        'Select',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF414A51),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
        ),

        // Selected Employee Chips
        if (_selectedAssignedEmployees.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedAssignedEmployees.map((emp) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF9CC70A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF9CC70A).withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_outline_rounded,
                        size: 14, color: Color(0xFF414A51)),
                    const SizedBox(width: 6),
                    Text(
                      '${emp.employeeId} - ${emp.fullName}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF414A51),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _selectedAssignedEmployees.remove(emp);
                        });
                      },
                      child: const Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: Color(0xFF414A51),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Future<void> _openEmployeeMultiSelectDialog(
      List<Employee> allEmployees) async {
    final tempSelected = List<Employee>.from(_selectedAssignedEmployees);
    final searchController = TextEditingController();
    String query = '';

    try {
      await showDialog(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return Dialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                insetPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: 520, maxHeight: 600),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                    color: const Color(0xFF9CC70A)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.people_alt_rounded,
                                    size: 20,
                                    color: Color(0xFF414A51),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Assign Employees',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF414A51),
                                      ),
                                    ),
                                    Text(
                                      '${tempSelected.length} employee(s) selected',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF9CC70A),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Search field
                        TextField(
                          controller: searchController,
                          autofocus: true,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText:
                                'Search by employee ID, name, or role...',
                            hintStyle: const TextStyle(
                                fontSize: 12.5, color: Colors.black38),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            prefixIcon: const Icon(Icons.search_rounded,
                                size: 18, color: Color(0xFF94A3B8)),
                            suffixIcon: query.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      searchController.clear();
                                      setDialogState(() => query = '');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: Color(0xFF9CC70A), width: 1.5),
                            ),
                          ),
                          onChanged: (val) {
                            setDialogState(
                                () => query = val.trim().toLowerCase());
                          },
                        ),
                        const SizedBox(height: 10),

                        // Select All / Deselect All Bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF414A51),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                              ),
                              icon: const Icon(Icons.select_all_rounded,
                                  size: 16),
                              label: const Text('Select All',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600)),
                              onPressed: () {
                                setDialogState(() {
                                  tempSelected.clear();
                                  tempSelected.addAll(allEmployees);
                                });
                              },
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                              ),
                              icon: const Icon(Icons.deselect_rounded,
                                  size: 16),
                              label: const Text('Clear All',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600)),
                              onPressed: () {
                                setDialogState(() {
                                  tempSelected.clear();
                                });
                              },
                            ),
                          ],
                        ),
                        const Divider(height: 1, color: Color(0xFFE5E8E2)),

                        // Employee List
                        Flexible(
                          child: Builder(
                            builder: (context) {
                              final filtered = allEmployees.where((emp) {
                                if (query.isEmpty) return true;
                                return emp.fullName
                                        .toLowerCase()
                                        .contains(query) ||
                                    emp.employeeId
                                        .toLowerCase()
                                        .contains(query) ||
                                    emp.designation
                                        .toLowerCase()
                                        .contains(query) ||
                                    emp.department
                                        .toLowerCase()
                                        .contains(query);
                              }).toList();

                              if (filtered.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.all(28),
                                  child: Center(
                                    child: Text(
                                      'No employees found',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF94A3B8)),
                                    ),
                                  ),
                                );
                              }

                              return ListView.separated(
                                shrinkWrap: true,
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) => const Divider(
                                    height: 1, color: Color(0xFFF1F5F9)),
                                itemBuilder: (context, index) {
                                  final emp = filtered[index];
                                  final isSelected = tempSelected.any((e) =>
                                      e.id == emp.id ||
                                      (e.employeeId.isNotEmpty &&
                                          e.employeeId == emp.employeeId));

                                  return CheckboxListTile(
                                    dense: true,
                                    activeColor: const Color(0xFF9CC70A),
                                    checkColor: Colors.white,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 2),
                                    title: Text(
                                      '${emp.employeeId} - ${emp.fullName}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: const Color(0xFF414A51),
                                      ),
                                    ),
                                    subtitle: emp.designation.isNotEmpty
                                        ? Text(
                                            emp.designation,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF94A3B8)),
                                          )
                                        : null,
                                    value: isSelected,
                                    onChanged: (checked) {
                                      setDialogState(() {
                                        if (checked == true) {
                                          if (!tempSelected
                                              .any((e) => e.id == emp.id)) {
                                            tempSelected.add(emp);
                                          }
                                        } else {
                                          tempSelected.removeWhere(
                                              (e) => e.id == emp.id);
                                        }
                                      });
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel',
                                  style: TextStyle(
                                      color: Color(0xFF414A51))),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF9CC70A),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                              ),
                              onPressed: () {
                                setState(() {
                                  _selectedAssignedEmployees.clear();
                                  _selectedAssignedEmployees
                                      .addAll(tempSelected);
                                });
                                Navigator.of(context).pop();
                              },
                              child: const Text('Apply Selection',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      searchController.dispose();
    }
  }

  Widget _buildEmployeeSelectField({
    required String label,
    required List<Employee> employees,
    required Employee? selected,
    required ValueChanged<Employee?> onChanged,
  }) {
    return AppSearchableDropdown<Employee>(
      label: label,
      value: employees.contains(selected) ? selected : null,
      items: employees,
      itemLabel: (emp) => '${emp.employeeId} - ${emp.fullName}',
      searchHint: 'Search employee by ID or name...',
      placeholder: 'Select Employee',
      isRequired: true,
      validator: (val) => val == null ? 'Employee is required' : null,
      onChanged: onChanged,
    );
  }

  Widget _buildClientSelectField(List<Customer> customers) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: AppSearchableDropdown<Customer>(
            label: 'Client *',
            value: customers.contains(_selectedClient) ? _selectedClient : null,
            items: customers,
            itemLabel: (c) {
              final label = c.displayName.isNotEmpty
                  ? c.displayName
                  : (c.companyName.isNotEmpty ? c.companyName : 'Customer #${c.id}');
              return label;
            },
            searchHint: 'Search client by name or company...',
            placeholder: 'Select Client',
            isRequired: true,
            validator: (val) => val == null ? 'Client is required' : null,
            onChanged: (c) => setState(() => _selectedClient = c),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(bottom: 1),
          child: Tooltip(
            message: 'Add New Client',
            child: InkWell(
              onTap: _openAddClientDialog,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 38,
                width: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF9CC70A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF9CC70A).withValues(alpha: 0.4),
                  ),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Color(0xFF414A51),
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClientDisplayOrSelect(List<Customer> customers) {
    final clientName = _selectedClient?.displayName.isNotEmpty == true
        ? _selectedClient!.displayName
        : (_selectedClient?.companyName.isNotEmpty == true
            ? _selectedClient!.companyName
            : 'No Client Selected');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Client',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD0D5DD), width: 0.8),
          ),
          child: Row(
            children: [
              const Icon(Icons.business_rounded, size: 16, color: Colors.black54),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  clientName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubOrOwnDropdown() {
    return AppSearchableDropdown<String>(
      label: 'Sub Or Own',
      value: _subOrOwn,
      items: const ['Own', 'Sub'],
      searchHint: 'Search Sub or Own...',
      placeholder: 'Select Sub or Own',
      onChanged: (val) {
        if (val != null) setState(() => _subOrOwn = val);
      },
    );
  }

  Widget _buildStateDropdown() {
    final states = LocationDataHelper.countryStatesMap['India'] ?? ['Tamil Nadu'];
    return AppSearchableDropdown<String>(
      label: 'State',
      value: states.contains(_selectedState) ? _selectedState : states.first,
      items: states,
      searchHint: 'Search state...',
      placeholder: 'Select State',
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _selectedState = val;
            _updateDistrictsForState(val);
          });
        }
      },
    );
  }

  Widget _buildDistrictDropdown() {
    return AppSearchableDropdown<String>(
      key: ValueKey('$_selectedState-$_selectedDistrict'),
      label: 'District',
      value: _districtsList.contains(_selectedDistrict)
          ? _selectedDistrict
          : (_districtsList.isNotEmpty ? _districtsList.first : null),
      items: _districtsList,
      searchHint: 'Search district...',
      placeholder: 'Select District',
      onChanged: (val) {
        if (val != null) setState(() => _selectedDistrict = val);
      },
    );
  }

  Widget _buildAreaField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Area',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 38,
          child: TextFormField(
            controller: _areaController,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            decoration: InputDecoration(
              hintText: 'e.g. Porur / Guindy',
              hintStyle: const TextStyle(fontSize: 11.5, color: Colors.black38),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD0D5DD), width: 0.8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD0D5DD), width: 0.8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeActionRow({
    required String codeLabel,
    required TextEditingController controller,
    required String buttonLabel,
    required VoidCallback onGenerate,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAF8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E8E2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  codeLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF718096),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  controller.text.isNotEmpty
                      ? controller.text
                      : 'Not Generated Yet',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: controller.text.isNotEmpty
                        ? const Color(0xFF414A51)
                        : const Color(0xFFA0AEC0),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF414A51),
              side: const BorderSide(color: Color(0xFF9CC70A), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: onGenerate,
            icon: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF9CC70A)),
            label: Text(
              buttonLabel,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickerWidget({
    required String label,
    required DateTime? selectedDate,
    required VoidCallback onTap,
  }) {
    final formatted = selectedDate != null
        ? DateFormat('dd-MM-yyyy').format(selectedDate)
        : 'Select Date';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
        ),
        child: Text(
          formatted,
          style: TextStyle(
            fontSize: 14,
            color: selectedDate != null
                ? AppColors.textPrimary
                : AppColors.textSecondary,
            fontWeight: selectedDate != null ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildFileUploadWidget({
    required String label,
    required List<PlatformFile> files,
  }) {
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
              ),
              onPressed: () => _pickFiles(files),
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text('Upload Documents'),
            ),
            const SizedBox(width: 12),
            Text(
              files.isEmpty
                  ? 'No documents attached'
                  : '${files.length} document(s) selected',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Supported: PDF, Word, Excel, PNG, JPG (Max 5 files, 10MB each)',
          style: TextStyle(fontSize: 11, color: Color(0xFF718096)),
        ),
        if (files.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final f in files)
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
                      size: 16, color: Color(0xFF414A51)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    '${(f.size / 1024).toStringAsFixed(0)} KB',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => files.remove(f)),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
