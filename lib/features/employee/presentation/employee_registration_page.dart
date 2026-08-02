// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../domain/employee.dart';
import '../domain/registration_link.dart';
import '../providers/employee_providers.dart';
import '../services/offer_letter_generator.dart';
import '../services/welcome_letter_generator.dart';

class EmployeeRegistrationPage extends ConsumerStatefulWidget {
  const EmployeeRegistrationPage({
    required this.linkId,
    this.employee,
    this.acceptedEmpId,
    super.key,
  });

  final String linkId;
  final Employee? employee;
  final int? acceptedEmpId;

  @override
  ConsumerState<EmployeeRegistrationPage> createState() =>
      _EmployeeRegistrationPageState();
}

class _EmployeeRegistrationPageState
    extends ConsumerState<EmployeeRegistrationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // Tab 1: Personal Info
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  String _bloodGroup = 'B+';
  String _gender = 'Male';
  String _userType = 'EMPLOYEE';
  String _status = 'ACTIVE';
  final _dobController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _phoneController = TextEditingController();
  String _department = 'Management';
  String _designation = 'Company Director';
  final _joiningDateController = TextEditingController();
  final _contractEndDateController = TextEditingController();
  final _emailController = TextEditingController();
  final _pfNumberController = TextEditingController();
  final _esiNumberController = TextEditingController();
  String _reportingTo = 'Saravanan G S';
  final _inTimeController = TextEditingController();
  final _outTimeController = TextEditingController();
  final _weeklyOffDayController = TextEditingController(text: 'Sunday');
  final _reportingManagerTitleController = TextEditingController(text: 'Managing Director');
  final _adminNameController = TextEditingController(text: 'Saravanan G S');
  final _coordinatorNameController = TextEditingController(text: 'Admin Team');
  final _coordinatorPhoneController = TextEditingController(text: '8760098789');
  String _leaveType = 'As Needed';
  String _leaveAllocationFrequency = 'Monthly';
  final _allowedLeavesController = TextEditingController(text: '1.0');
  final _leaveEffectiveDateController = TextEditingController();
  String _selectedFileName = 'No file chosen';
  String _profileImageDataUrl = '';
  Uint8List? _profileImageBytes;

  // Tab 2: Address
  final _permAddressController = TextEditingController();
  final _permCityController = TextEditingController();
  final _permCountryController = TextEditingController(text: 'India');
  bool _sameAsPermanent = false;
  final _presAddressController = TextEditingController();
  final _presCityController = TextEditingController();
  final _presCountryController = TextEditingController(text: 'India');

  // Tab 3: Education
  final _eduDegreeController = TextEditingController();
  final _eduInstController = TextEditingController();
  final _eduResultController = TextEditingController();
  final _eduYearController = TextEditingController();
  final _eduSearchController = TextEditingController();
  final List<EducationItem> _educationList = [];

  // Tab 4: Experience
  final _expCompanyController = TextEditingController();
  final _expPositionController = TextEditingController();
  final _expAddressController = TextEditingController();
  final _expDurationController = TextEditingController();
  final List<ExperienceItem> _experienceList = [];

  // Tab 5: History
  final _originalDobController = TextEditingController();
  final _personalMobileController = TextEditingController();
  final _panController = TextEditingController();
  final _passportController = TextEditingController();
  final _drivingLicenseController = TextEditingController();
  final _drivingLicenseBatchController = TextEditingController();
  final _healthIssuesController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyMobileController = TextEditingController();
  final _referredByNameController = TextEditingController();
  final _referredByMobileController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _motherNameController = TextEditingController();
  String _maritalStatus = 'Unmarried';
  final _spouseNameController = TextEditingController();
  final _kids1NameController = TextEditingController();
  final _kids2NameController = TextEditingController();
  final _kids3NameController = TextEditingController();

  // Tab 6: Bank Account
  final _bankHolderController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _bankAccNumController = TextEditingController();
  final _bankIfscController = TextEditingController();
  final _bankBranchController = TextEditingController();
  String _bankAccountType = 'Savings';

  // Tab 7: Document
  String _docType = 'Aadhaar Card';
  final _docNumberController = TextEditingController();
  String _docFileName = 'No file chosen';
  final List<DocumentItem> _documentList = [];

  // Tab 8: Social Media
  final _facebookController = TextEditingController();
  final _twitterController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _googleController = TextEditingController();

  // Tab 9: Salary & Offer Letter
  String _salaryType = 'Monthly';
  final _totalSalaryController = TextEditingController();
  final _basicPayController = TextEditingController();
  final _hraController = TextEditingController();
  final _eduAllowanceController = TextEditingController();
  final _specialAllowanceController = TextEditingController();
  final _travelAllowanceController = TextEditingController();
  final _taxController = TextEditingController();
  final _pfController = TextEditingController();
  final _professionalTaxController = TextEditingController();
  void _onTotalSalaryChanged(String val) {
    final cleanVal = val.replaceAll(',', '').trim();
    final total = double.tryParse(cleanVal);
    if (total != null && total >= 0) {
      final basic = total * 0.50;
      final hra = total * 0.25;
      final edu = total * 0.25;
      setState(() {
        _basicPayController.text = basic == 0 ? '' : basic.toStringAsFixed(2);
        _hraController.text = hra == 0 ? '' : hra.toStringAsFixed(2);
        _eduAllowanceController.text = edu == 0 ? '' : edu.toStringAsFixed(2);
      });
    }
  }

  // Tab 10: Credentials
  final _employeeCustomIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  // Tab 11: Access Permissions
  late Set<String> _selectedPermissions;

  void _generateSampleEmpId() {
    final stamp = DateTime.now().millisecondsSinceEpoch.toString();
    final suffix = stamp.length > 4 ? stamp.substring(stamp.length - 4) : stamp;
    setState(() {
      _employeeCustomIdController.text = 'EMP-$suffix';
    });
  }

  void _generateRandomPassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789@#';
    final rnd = List.generate(8, (i) => chars[(DateTime.now().microsecondsSinceEpoch + i * 17) % chars.length]).join();
    setState(() {
      _passwordController.text = rnd;
    });
  }

  bool get _isManagementAdd =>
      widget.linkId == 'new' ||
      widget.linkId == 'edit' ||
      widget.linkId.isEmpty ||
      widget.employee != null;

  bool get _isEditing => widget.employee != null || widget.linkId == 'edit';

  bool _isSubmitting = false;
  Employee? _submittedEmployee;
  Employee? _currentEmployee;
  String _registrationMode = 'manual';
  int? _selectedAcceptedEmpId;
  String? _selectedAcceptedLinkId;
  bool _draftLoaded = false;
  final Set<String> _savedTabs = {};

  void _populateFromEmployee(Employee emp) {
    setState(() {
      _currentEmployee = emp;
      _firstNameController.text = emp.firstName;
      _lastNameController.text = emp.lastName;
      if (emp.bloodGroup.isNotEmpty) _bloodGroup = emp.bloodGroup;
      if (emp.gender.isNotEmpty) _gender = emp.gender;
      if (emp.userType.isNotEmpty) _userType = emp.userType;
      if (emp.status.isNotEmpty) _status = emp.status;
      _dobController.text = emp.dob;
      _aadhaarController.text = emp.aadhaarNumber;
      _phoneController.text = emp.phoneNumber;
      if (emp.department.isNotEmpty) _department = emp.department;
      if (emp.designation.isNotEmpty) _designation = emp.designation;
      _joiningDateController.text = emp.joiningDate;
      _contractEndDateController.text = emp.contractEndDate;
      _emailController.text = emp.emailAddress;
      _pfNumberController.text = emp.pfNumber;
      _esiNumberController.text = emp.esiNumber;
      _inTimeController.text = emp.inTime;
      _outTimeController.text = emp.outTime;
      _weeklyOffDayController.text = emp.weeklyOffDay.isNotEmpty ? emp.weeklyOffDay : 'Sunday';
      _reportingManagerTitleController.text = emp.reportingManagerTitle.isNotEmpty ? emp.reportingManagerTitle : 'Managing Director';
      _adminNameController.text = emp.adminName.isNotEmpty ? emp.adminName : 'Saravanan G S';
      _coordinatorNameController.text = emp.coordinatorName.isNotEmpty ? emp.coordinatorName : 'Admin Team';
      _coordinatorPhoneController.text = emp.coordinatorPhone.isNotEmpty ? emp.coordinatorPhone : '8760098789';
      if (emp.reportingManager.isNotEmpty) _reportingTo = emp.reportingManager;
      if (emp.leaveType.isNotEmpty) _leaveType = emp.leaveType;
      _leaveAllocationFrequency = emp.leaveAllocationFrequency.isEmpty ? 'Monthly' : emp.leaveAllocationFrequency;
      _allowedLeavesController.text = emp.allowedLeaves.toString();
      _leaveEffectiveDateController.text = emp.effectiveDate;

      _permAddressController.text = emp.permanentAddress;
      _permCityController.text = emp.permanentCity;
      if (emp.permanentCountry.isNotEmpty) _permCountryController.text = emp.permanentCountry;
      _sameAsPermanent = emp.sameAsPermanent;
      _presAddressController.text = emp.presentAddress;
      _presCityController.text = emp.presentCity;
      if (emp.presentCountry.isNotEmpty) _presCountryController.text = emp.presentCountry;

      _originalDobController.text = emp.originalDob;
      _personalMobileController.text = emp.personalMobile;
      _panController.text = emp.panNumber;
      _passportController.text = emp.passportNumber;
      _drivingLicenseController.text = emp.drivingLicenseNumber;
      _drivingLicenseBatchController.text = emp.drivingLicenseBatch;
      _healthIssuesController.text = emp.healthIssues;
      _emergencyNameController.text = emp.emergencyName;
      _emergencyMobileController.text = emp.emergencyMobile;
      _referredByNameController.text = emp.referredByName;
      _referredByMobileController.text = emp.referredByMobile;
      _fatherNameController.text = emp.fatherName;
      _motherNameController.text = emp.motherName;
      if (emp.maritalStatus.isNotEmpty) _maritalStatus = emp.maritalStatus;
      _spouseNameController.text = emp.spouseName;
      _kids1NameController.text = emp.kids1Name;
      _kids2NameController.text = emp.kids2Name;
      _kids3NameController.text = emp.kids3Name;

      _bankHolderController.text = emp.bankAccountHolder;
      _bankNameController.text = emp.bankName;
      _bankAccNumController.text = emp.bankAccountNumber;
      _bankIfscController.text = emp.bankIfsc;
      _bankBranchController.text = emp.bankBranch;
      if (emp.bankAccountType.isNotEmpty) _bankAccountType = emp.bankAccountType;

      _facebookController.text = emp.facebookUrl;
      _twitterController.text = emp.twitterUrl;
      _linkedinController.text = emp.linkedinUrl;
      _googleController.text = emp.googleUrl;
      _profileImageDataUrl = emp.profileImageUrl;
      if (_profileImageDataUrl.isNotEmpty) {
        final commaIndex = _profileImageDataUrl.indexOf(',');
        if (commaIndex > 0) {
          try {
            _profileImageBytes = base64Decode(_profileImageDataUrl.substring(commaIndex + 1));
          } catch (_) {
            _profileImageBytes = null;
          }
        }
      }

      // Salary fields
      if (emp.salaryType.isNotEmpty) _salaryType = emp.salaryType;
      if (emp.salaryTotalCtc > 0) _totalSalaryController.text = emp.salaryTotalCtc.toStringAsFixed(2);
      if (emp.salaryBasic > 0) _basicPayController.text = emp.salaryBasic.toStringAsFixed(2);
      if (emp.salaryHra > 0) _hraController.text = emp.salaryHra.toStringAsFixed(2);
      if (emp.salaryEducationAllowance > 0) _eduAllowanceController.text = emp.salaryEducationAllowance.toStringAsFixed(2);
      if (emp.salarySpecialAllowance > 0) _specialAllowanceController.text = emp.salarySpecialAllowance.toStringAsFixed(2);
      if (emp.salaryTravelAllowance > 0) _travelAllowanceController.text = emp.salaryTravelAllowance.toStringAsFixed(2);
      if (emp.salaryTax > 0) _taxController.text = emp.salaryTax.toStringAsFixed(2);
      if (emp.salaryPf > 0) _pfController.text = emp.salaryPf.toStringAsFixed(2);
      if (emp.salaryProfessionalTax > 0) _professionalTaxController.text = emp.salaryProfessionalTax.toStringAsFixed(2);

      // Credentials fields
      if (emp.employeeId.isNotEmpty) _employeeCustomIdController.text = emp.employeeId;
      if (emp.temporaryPassword.isNotEmpty) _passwordController.text = emp.temporaryPassword;

      if (emp.educationListJson.isNotEmpty) {
        try {
          final List parsed = jsonDecode(emp.educationListJson);
          _educationList.clear();
          _educationList.addAll(parsed.map((e) => EducationItem.fromMap(Map<String, dynamic>.from(e))));
        } catch (_) {}
      }

      if (emp.experienceListJson.isNotEmpty) {
        try {
          final List parsed = jsonDecode(emp.experienceListJson);
          _experienceList.clear();
          _experienceList.addAll(parsed.map((e) => ExperienceItem.fromMap(Map<String, dynamic>.from(e))));
        } catch (_) {}
      }

      if (emp.documentListJson.isNotEmpty) {
        try {
          final List parsed = jsonDecode(emp.documentListJson);
          _documentList.clear();
          _documentList.addAll(parsed.map((e) => DocumentItem.fromMap(Map<String, dynamic>.from(e))));
        } catch (_) {}
      }

      if (emp.accessPermissions.isNotEmpty) {
        _selectedPermissions = Set<String>.from(emp.accessPermissions);
      }
    });
  }

  List<String> get _tabs => [
    'Personal Info',
    'Address',
    'Education',
    'Experience',
    'History',
    'Bank Account',
    'Document',
    'Social Media',
    if (_isManagementAdd) 'Job & Admin Details',
    if (_isManagementAdd) 'Salary & Offer Letter',
    if (_isManagementAdd) 'Welcome Letter',
    if (_isManagementAdd) 'Access Permissions',
    if (_isManagementAdd) 'Credentials',
  ];

  @override
  void initState() {
    super.initState();
    _selectedPermissions = widget.employee != null && widget.employee!.accessPermissions.isNotEmpty
        ? Set<String>.from(widget.employee!.accessPermissions)
        : (!_isManagementAdd ? <String>{} : Set<String>.from(Employee.allSidebarPermissions));
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    if (widget.employee != null) {
      _populateFromEmployee(widget.employee!);
    } else if (widget.acceptedEmpId != null) {
      _registrationMode = 'accepted_response';
      _selectedAcceptedEmpId = widget.acceptedEmpId;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final emps = await ref.read(employeesProvider.future);
        final matches = emps.where((e) => e.id == widget.acceptedEmpId).toList();
        if (matches.isNotEmpty && mounted) {
          final match = matches.first;
          _populateFromEmployee(match);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Auto-fetched details for ${match.fullName}. Configure credentials & permissions to complete registration.'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _aadhaarController.dispose();
    _phoneController.dispose();
    _joiningDateController.dispose();
    _contractEndDateController.dispose();
    _emailController.dispose();
    _pfNumberController.dispose();
    _esiNumberController.dispose();
    _inTimeController.dispose();
    _outTimeController.dispose();
    _weeklyOffDayController.dispose();
    _reportingManagerTitleController.dispose();
    _adminNameController.dispose();
    _coordinatorNameController.dispose();
    _coordinatorPhoneController.dispose();
    _permAddressController.dispose();
    _permCityController.dispose();
    _permCountryController.dispose();
    _presAddressController.dispose();
    _presCityController.dispose();
    _presCountryController.dispose();
    _eduDegreeController.dispose();
    _eduInstController.dispose();
    _eduResultController.dispose();
    _eduYearController.dispose();
    _eduSearchController.dispose();
    _expCompanyController.dispose();
    _expPositionController.dispose();
    _expAddressController.dispose();
    _expDurationController.dispose();
    _originalDobController.dispose();
    _personalMobileController.dispose();
    _panController.dispose();
    _passportController.dispose();
    _drivingLicenseController.dispose();
    _drivingLicenseBatchController.dispose();
    _healthIssuesController.dispose();
    _emergencyNameController.dispose();
    _emergencyMobileController.dispose();
    _referredByNameController.dispose();
    _referredByMobileController.dispose();
    _fatherNameController.dispose();
    _motherNameController.dispose();
    _spouseNameController.dispose();
    _kids1NameController.dispose();
    _kids2NameController.dispose();
    _kids3NameController.dispose();
    _bankHolderController.dispose();
    _bankNameController.dispose();
    _bankAccNumController.dispose();
    _bankIfscController.dispose();
    _bankBranchController.dispose();
    _docNumberController.dispose();
    _facebookController.dispose();
    _twitterController.dispose();
    _linkedinController.dispose();
    _googleController.dispose();
    _totalSalaryController.dispose();
    _basicPayController.dispose();
    _hraController.dispose();
    _eduAllowanceController.dispose();
    _specialAllowanceController.dispose();
    _travelAllowanceController.dispose();
    _taxController.dispose();
    _pfController.dispose();
    _professionalTaxController.dispose();
    _employeeCustomIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1950),
      lastDate: DateTime(2040),
    );
    if (picked != null) {
      final day = picked.day.toString().padLeft(2, '0');
      final month = picked.month.toString().padLeft(2, '0');
      final year = picked.year.toString();
      setState(() {
        controller.text = '$day-$month-$year';
      });
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      final file = result?.files.isNotEmpty == true ? result!.files.first : null;
      if (file == null) return;
      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('Unable to read the selected image.');
      }

      final ext = (file.extension ?? 'jpg').toLowerCase();
      final mimeType = switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        'bmp' => 'image/bmp',
        'jpg' || 'jpeg' => 'image/jpeg',
        _ => 'image/jpeg',
      };

      setState(() {
        _selectedFileName = file.name;
        _profileImageBytes = bytes;
        _profileImageDataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image selection failed: $e')),
      );
    }
  }

  Future<void> _submitForm(RegistrationLink? link, {bool isSubmit = true}) async {
    final isEditMode = _isEditing;

    if (isSubmit) {
      if (_firstNameController.text.trim().isEmpty) {
        _tabController.animateTo(0);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter First Name under Personal Info tab.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (!_formKey.currentState!.validate()) {
        _tabController.animateTo(0);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill mandatory fields marked with *'),
          ),
        );
        return;
      }
    } else {
      if (_firstNameController.text.trim().isEmpty) {
        _tabController.animateTo(0);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter at least First Name under Personal Info tab to save draft.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(employeeRepositoryProvider);
      final resolvedEmployeeId = _employeeCustomIdController.text.trim().isNotEmpty
          ? _employeeCustomIdController.text.trim()
          : (_currentEmployee?.employeeId.isNotEmpty == true
              ? _currentEmployee!.employeeId
              : (widget.employee?.employeeId.isNotEmpty == true
                  ? widget.employee!.employeeId
                  : 'pending_${DateTime.now().millisecondsSinceEpoch}'));

      String profileImageUrl = _currentEmployee?.profileImageUrl ?? widget.employee?.profileImageUrl ?? '';
      String profileImagePublicId = _currentEmployee?.profileImagePublicId ?? widget.employee?.profileImagePublicId ?? '';
      String profileImageFolder = _currentEmployee?.profileImageFolder ?? widget.employee?.profileImageFolder ?? '';

      if (_profileImageBytes != null) {
        final uploaded = await repo.uploadEmployeeProfileImage(
          employeeId: resolvedEmployeeId,
          role: _userType,
          imageBytes: _profileImageBytes!,
          fileName: _selectedFileName.isNotEmpty ? _selectedFileName : 'profile.jpg',
          mimeType: _selectedFileName.toLowerCase().endsWith('.png')
              ? 'image/png'
              : _selectedFileName.toLowerCase().endsWith('.webp')
                  ? 'image/webp'
                  : _selectedFileName.toLowerCase().endsWith('.gif')
                      ? 'image/gif'
                      : 'image/jpeg',
        );
        profileImageUrl = uploaded.url;
        profileImagePublicId = uploaded.publicId;
        profileImageFolder = uploaded.folder;
      }

      final employeeData = Employee(
        id: _currentEmployee?.id ?? 0,
        employeeId: resolvedEmployeeId,
        temporaryPassword: _passwordController.text.trim().isNotEmpty
            ? _passwordController.text.trim()
            : (_currentEmployee?.temporaryPassword ?? ''),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        emailAddress: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        gender: _gender,
        dob: _dobController.text.trim(),
        organizationName: (link?.organizationName ?? '').isEmpty
            ? 'iGreen Tech'
            : link!.organizationName,
        department: _department,
        designation: _designation,
        employmentType: 'Full-Time',
        joiningDate: _joiningDateController.text.trim(),
        status: isSubmit
            ? (_status.isEmpty || _status == 'PENDING' ? 'ACTIVE' : _status)
            : 'Draft',
        bloodGroup: _bloodGroup,
        userType: _userType,
        contractEndDate: _contractEndDateController.text.trim(),
        permanentAddress: _permAddressController.text.trim(),
        permanentCity: _permCityController.text.trim(),
        permanentCountry: _permCountryController.text.trim(),
        sameAsPermanent: _sameAsPermanent,
        presentAddress: _sameAsPermanent
            ? _permAddressController.text.trim()
            : _presAddressController.text.trim(),
        presentCity: _sameAsPermanent
            ? _permCityController.text.trim()
            : _presCityController.text.trim(),
        presentCountry: _sameAsPermanent
            ? _permCountryController.text.trim()
            : _presCountryController.text.trim(),
        educationListJson: jsonEncode(_educationList.map((e) => e.toMap()).toList()),
        experienceListJson: jsonEncode(_experienceList.map((e) => e.toMap()).toList()),
        originalDob: _originalDobController.text.trim(),
        personalMobile: _personalMobileController.text.trim(),
        passportNumber: _passportController.text.trim(),
        drivingLicenseNumber: _drivingLicenseController.text.trim(),
        drivingLicenseBatch: _drivingLicenseBatchController.text.trim(),
        healthIssues: _healthIssuesController.text.trim(),
        emergencyName: _emergencyNameController.text.trim(),
        emergencyMobile: _emergencyMobileController.text.trim(),
        referredByName: _referredByNameController.text.trim(),
        referredByMobile: _referredByMobileController.text.trim(),
        fatherName: _fatherNameController.text.trim(),
        motherName: _motherNameController.text.trim(),
        maritalStatus: _maritalStatus,
        spouseName: _spouseNameController.text.trim(),
        kids1Name: _kids1NameController.text.trim(),
        kids2Name: _kids2NameController.text.trim(),
        kids3Name: _kids3NameController.text.trim(),
        bankAccountHolder: _bankHolderController.text.trim(),
        bankName: _bankNameController.text.trim(),
        bankAccountNumber: _bankAccNumController.text.trim(),
        bankIfsc: _bankIfscController.text.trim(),
        bankBranch: _bankBranchController.text.trim(),
        bankAccountType: _bankAccountType,
        panNumber: _panController.text.trim(),
        aadhaarNumber: _aadhaarController.text.trim(),
        documentListJson: jsonEncode(_documentList.map((e) => e.toMap()).toList()),
        facebookUrl: _facebookController.text.trim(),
        twitterUrl: _twitterController.text.trim(),
        linkedinUrl: _linkedinController.text.trim(),
        googleUrl: _googleController.text.trim(),
        pfNumber: _pfNumberController.text.trim(),
        esiNumber: _esiNumberController.text.trim(),
        inTime: _inTimeController.text.trim(),
        outTime: _outTimeController.text.trim(),
        weeklyOffDay: _weeklyOffDayController.text.trim(),
        reportingManager: _reportingTo,
        reportingManagerTitle: _reportingManagerTitleController.text.trim(),
        adminName: _adminNameController.text.trim(),
        coordinatorName: _coordinatorNameController.text.trim(),
        coordinatorPhone: _coordinatorPhoneController.text.trim(),
        leaveType: _leaveType,
        leaveAllocationFrequency: _leaveAllocationFrequency,
        allowedLeaves: double.tryParse(_allowedLeavesController.text.trim()) ?? 1.0,
        effectiveDate: _leaveEffectiveDateController.text.trim(),
        salaryType: _salaryType,
        salaryTotalCtc: double.tryParse(_totalSalaryController.text.trim().replaceAll(',', '')) ?? 0.0,
        salaryBasic: double.tryParse(_basicPayController.text.trim().replaceAll(',', '')) ?? 0.0,
        salaryHra: double.tryParse(_hraController.text.trim().replaceAll(',', '')) ?? 0.0,
        salaryEducationAllowance: double.tryParse(_eduAllowanceController.text.trim().replaceAll(',', '')) ?? 0.0,
        salarySpecialAllowance: double.tryParse(_specialAllowanceController.text.trim().replaceAll(',', '')) ?? 0.0,
        salaryTravelAllowance: double.tryParse(_travelAllowanceController.text.trim().replaceAll(',', '')) ?? 0.0,
        salaryTax: double.tryParse(_taxController.text.trim().replaceAll(',', '')) ?? 0.0,
        salaryPf: double.tryParse(_pfController.text.trim().replaceAll(',', '')) ?? 0.0,
        salaryProfessionalTax: double.tryParse(_professionalTaxController.text.trim().replaceAll(',', '')) ?? 0.0,
        accessPermissions: _selectedPermissions.toList(),
        profileImageUrl: profileImageUrl,
        profileImagePublicId: profileImagePublicId,
        profileImageFolder: profileImageFolder,
      );

      Employee savedEmployee;

      if (isEditMode) {
        // Edit existing employee record
        final targetId = widget.employee?.id ?? _currentEmployee?.id ?? 0;
        final updated = employeeData.copyWith(id: targetId);
        await repo.updateEmployee(updated);
        savedEmployee = updated;
      } else if (_registrationMode == 'accepted_response' && _selectedAcceptedEmpId != null) {
        // Import an accepted candidate as a brand-new employee record.
        // The accepted ID is only for navigation context, not the target employee row.
        final imported = employeeData.copyWith(status: 'Active');
        if (_currentEmployee != null) {
          final updated = imported.copyWith(id: _currentEmployee!.id);
          await repo.updateEmployee(updated);
          savedEmployee = updated;
        } else {
          savedEmployee = await repo.addEmployee(imported);
        }
      } else if (widget.linkId == 'new' || widget.linkId.isEmpty) {
        // Manual Add mode
        if (_currentEmployee != null) {
          final updated = employeeData.copyWith(id: _currentEmployee!.id);
          await repo.updateEmployee(updated);
          savedEmployee = updated;
        } else {
          savedEmployee = await repo.addEmployee(employeeData);
        }
      } else {
        // Link-based registration (candidate mode)
        savedEmployee = await repo.submitEmployeeRegistration(
          linkId: widget.linkId,
          employeeData: employeeData,
          isSubmit: isSubmit,
        );
      }

      _currentEmployee = savedEmployee;
      ref.invalidate(employeesProvider);
      if (widget.linkId.isNotEmpty && widget.linkId != 'new' && widget.linkId != 'edit') {
        ref.invalidate(registrationLinksProvider);
        ref.invalidate(registrationLinkByIdProvider(widget.linkId));
      }

      final currentTab = _tabs[_tabController.index];
      setState(() {
        if (isSubmit) {
          _submittedEmployee = savedEmployee;
        }
        _savedTabs.add(currentTab);
        _isSubmitting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isSubmit
                ? (isEditMode ? 'Employee details updated successfully!' : 'Employee registered successfully!')
                : 'Draft progress saved successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Redirect if it's a final submission (not draft save) and we are in manager add/edit flow
        if (isSubmit && (widget.linkId == 'new' || widget.linkId.isEmpty || isEditMode || (_registrationMode == 'accepted_response' && _selectedAcceptedEmpId != null))) {
          if (GoRouter.of(context).canPop()) {
            GoRouter.of(context).pop();
          } else {
            GoRouter.of(context).go('/employee');
          }
        }
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final linkAsync = ref.watch(registrationLinkByIdProvider(widget.linkId));
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F6),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar with persistent submit action
            linkAsync.maybeWhen(
              data: (link) => _buildTopNavBar(link),
              orElse: () => _buildTopNavBar(null),
            ),
            // Scrollable Tab Bar
            _buildTabBar(),
            // Main Content Area
            Expanded(
              child: linkAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error loading link: $err')),
                data: (link) {
                  if (_isEditing) {
                    final editLink = link ??
                        const RegistrationLink(
                          id: 0,
                          linkId: 'edit',
                          generatedBy: '',
                          generatedDate: '',
                          expiryDate: '',
                          linkStatus: 'Pending',
                          organizationName: 'iGreen Tech',
                          department: 'Management',
                        );
                    return Form(
                      key: _formKey,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildPersonalInfoTab(editLink, isMobile),
                          _buildAddressTab(editLink, isMobile),
                          _buildEducationTab(editLink, isMobile),
                          _buildExperienceTab(editLink, isMobile),
                          _buildHistoryTab(editLink, isMobile),
                          _buildBankAccountTab(editLink, isMobile),
                          _buildDocumentTab(editLink, isMobile),
                          _buildSocialMediaTab(editLink, isMobile),
                          if (_isManagementAdd) _buildJobAdminDetailsTab(editLink, isMobile),
                          if (_isManagementAdd) _buildSalaryOfferLetterTab(editLink, isMobile),
                          if (_isManagementAdd) _buildWelcomeLetterTab(editLink, isMobile),
                          if (_isManagementAdd) _buildAccessPermissionsTab(editLink, isMobile),
                          if (_isManagementAdd) _buildCredentialsTab(editLink, isMobile),
                        ],
                      ),
                    );
                  }

                  if (link == null) {
                    return _buildStatusCard(
                      icon: Icons.error_outline,
                      color: Colors.red,
                      title: 'Invalid Registration Link',
                      message: 'This registration link does not exist in our system.',
                    );
                  }

                  if (link.linkStatus == 'Completed' || _submittedEmployee != null) {
                    final emp = _submittedEmployee;
                    return _buildStatusCard(
                      icon: Icons.check_circle_outline,
                      color: const Color(0xFF28A745),
                      title: 'Registration Completed Successfully!',
                      message:
                          'Thank you! Your employee registration has been submitted and your profile has been updated.\n\n'
                          '${emp != null ? "Generated Employee ID: ${emp.employeeId}\nTemporary Account Password: ${emp.temporaryPassword}" : "Status: Registration Link Completed"}',
                    );
                  }

                  if (link.linkStatus == 'Expired') {
                    return _buildStatusCard(
                      icon: Icons.timer_off_outlined,
                      color: Colors.orange,
                      title: 'Registration Link Expired',
                      message:
                          'This registration link has expired. Please contact HR for a new invite link.',
                    );
                  }

                  if (link.employeeId.isNotEmpty && !_draftLoaded) {
                    _draftLoaded = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      try {
                        final emps = await ref.read(employeesProvider.future);
                        final matches = emps.where((e) => e.employeeId == link.employeeId).toList();
                        if (matches.isNotEmpty && mounted) {
                          _populateFromEmployee(matches.first);
                        }
                      } catch (e) {
                        debugPrint('Error loading draft employee: $e');
                      }
                    });
                  }

                  return Form(
                    key: _formKey,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPersonalInfoTab(link, isMobile),
                        _buildAddressTab(link, isMobile),
                        _buildEducationTab(link, isMobile),
                        _buildExperienceTab(link, isMobile),
                        _buildHistoryTab(link, isMobile),
                        _buildBankAccountTab(link, isMobile),
                        _buildDocumentTab(link, isMobile),
                        _buildSocialMediaTab(link, isMobile),
                        if (_isManagementAdd) _buildJobAdminDetailsTab(link, isMobile),
                        if (_isManagementAdd) _buildSalaryOfferLetterTab(link, isMobile),
                        if (_isManagementAdd) _buildWelcomeLetterTab(link, isMobile),
                        if (_isManagementAdd) _buildAccessPermissionsTab(link, isMobile),
                        if (_isManagementAdd) _buildCredentialsTab(link, isMobile),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopNavBar(RegistrationLink? link) {
    final name = '${_firstNameController.text} ${_lastNameController.text}'.trim();
    final isEditMode = _isEditing;
    final titleText = name.isEmpty
        ? (isEditMode ? 'Edit Employee Details' : 'Employee Registration')
        : (isEditMode ? 'Edit: $name' : name);

    final submitBtn = ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.active,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: const Size(0, 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onPressed: _isSubmitting
          ? null
          : () => _submitForm(link ??
              const RegistrationLink(
                  id: 0,
                  linkId: 'edit',
                  generatedBy: '',
                  generatedDate: '',
                  expiryDate: '',
                  linkStatus: 'Pending',
                  organizationName: '',
                  department: '')),
      icon: _isSubmitting
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Icon(isEditMode ? Icons.save_outlined : Icons.check_circle_outline, size: 16),
      label: Text(
        _isSubmitting
            ? 'Saving...'
            : (isEditMode ? 'Save Changes' : 'Submit Registration'),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        if (isMobile) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(isEditMode ? Icons.edit : Icons.person, size: 20, color: AppColors.active),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        titleText,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.active,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isManagementAdd || isEditMode || (link != null && link.linkStatus != 'Completed' && _submittedEmployee == null)) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: submitBtn,
                  ),
                ],
              ],
            ),
          );
        }

        return Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isEditMode ? Icons.edit : Icons.person, size: 18, color: AppColors.active),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        titleText,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.active,
                        ),
                      ),
                    ),
                    if (_savedTabs.contains(_tabs[_tabController.index])) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFA5D6A7)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.check_circle, size: 12, color: Color(0xFF2E7D32)),
                            SizedBox(width: 4),
                            Text(
                              'Page Saved',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_isManagementAdd || isEditMode || (link != null && link.linkStatus != 'Completed' && _submittedEmployee == null))
                submitBtn,
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      alignment: Alignment.centerLeft,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: AppColors.active,
        indicatorWeight: 3,
        labelColor: AppColors.active,
        unselectedLabelColor: Colors.black87,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
        tabAlignment: TabAlignment.start,
        tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
      ),
    );
  }

  // TAB 1: PERSONAL INFO
  Widget _buildPersonalInfoTab(RegistrationLink link, bool isMobile) {
    final formGrid = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Registration Mode Selection (Radio buttons) & Accepted Response Dropdown
        if (_isManagementAdd) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE9ECEF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Registration Entry Mode:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                if (isMobile) ...[
                  InkWell(
                    onTap: () => setState(() {
                      _registrationMode = 'manual';
                      _selectedAcceptedEmpId = null;
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Radio<String>(
                            value: 'manual',
                            groupValue: _registrationMode,
                            activeColor: AppColors.active,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _registrationMode = val;
                                  _selectedAcceptedEmpId = null;
                                });
                              }
                            },
                          ),
                          const Expanded(
                            child: Text('Manual Entry', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _registrationMode = 'accepted_response'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Radio<String>(
                            value: 'accepted_response',
                            groupValue: _registrationMode,
                            activeColor: AppColors.active,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _registrationMode = val);
                              }
                            },
                          ),
                          const Expanded(
                            child: Text('Import Accepted Response', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Radio<String>(
                        value: 'manual',
                        groupValue: _registrationMode,
                        activeColor: AppColors.active,
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _registrationMode = val;
                              _selectedAcceptedEmpId = null;
                            });
                          }
                        },
                      ),
                      const Text('Manual Entry', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 24),
                      Radio<String>(
                        value: 'accepted_response',
                        groupValue: _registrationMode,
                        activeColor: AppColors.active,
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _registrationMode = val);
                          }
                        },
                      ),
                      const Flexible(
                        child: Text('Import Accepted Response', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ],
                if (_registrationMode == 'accepted_response') ...[
                  const SizedBox(height: 10),
                  Consumer(
                    builder: (context, ref, child) {
                      final linksAsync = ref.watch(registrationLinksProvider);
                      final employeesAsync = ref.watch(employeesProvider);
                      return linksAsync.when(
                        loading: () => const SizedBox(
                          height: 36,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        error: (err, _) => Text(
                          'Error loading responses: $err',
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                        data: (links) => employeesAsync.when(
                          loading: () => const SizedBox(
                            height: 36,
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          error: (err, _) => Text(
                            'Error loading employee data: $err',
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                          ),
                          data: (allEmps) {
                            final acceptedLinks = links
                                .where((link) => link.linkStatus.trim().toLowerCase() == 'accepted')
                                .toList();

                            if (acceptedLinks.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  'No accepted responses available yet. (Accept candidate responses in the Response UI first).',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              );
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Select Accepted Applicant / Member Name *',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                DropdownButtonFormField<String>(
                                  initialValue: acceptedLinks.any((e) => e.linkId == _selectedAcceptedLinkId)
                                      ? _selectedAcceptedLinkId
                                      : null,
                                  hint: const Text('Choose accepted member name...', style: TextStyle(fontSize: 12)),
                                  isDense: true,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(),
                                  ),
                                  items: acceptedLinks.map((link) {
                                    Employee? matchedEmployee;
                                    for (final emp in allEmps) {
                                      if (emp.employeeId == link.employeeId || emp.id.toString() == link.employeeId) {
                                        matchedEmployee = emp;
                                        break;
                                      }
                                    }

                                    final displayName = matchedEmployee?.fullName.isNotEmpty == true
                                        ? matchedEmployee!.fullName
                                        : (link.employeeName.isNotEmpty ? link.employeeName : link.linkId);
                                    final secondary = matchedEmployee?.emailAddress.isNotEmpty == true
                                        ? matchedEmployee!.emailAddress
                                        : (link.department.isNotEmpty ? link.department : link.organizationName);

                                    return DropdownMenuItem<String>(
                                      value: link.linkId,
                                      child: Text(
                                        '$displayName (${secondary.isEmpty ? '-' : secondary})',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (selectedLinkId) {
                                    if (selectedLinkId != null) {
                                      final selectedLink = acceptedLinks.firstWhere((e) => e.linkId == selectedLinkId);
                                      Employee? selectedEmployee;
                                      for (final emp in allEmps) {
                                        if (emp.employeeId == selectedLink.employeeId || emp.id.toString() == selectedLink.employeeId) {
                                          selectedEmployee = emp;
                                          break;
                                        }
                                      }

                                      setState(() {
                                        _selectedAcceptedEmpId = selectedEmployee?.id;
                                        _selectedAcceptedLinkId = selectedLinkId;
                                      });

                                      if (selectedEmployee != null) {
                                        _populateFromEmployee(selectedEmployee);
                                      } else {
                                        _firstNameController.text = selectedLink.employeeName;
                                        _status = 'ACTIVE';
                                      }

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Auto-fetched all details for ${selectedEmployee?.fullName.isNotEmpty == true ? selectedEmployee!.fullName : selectedLink.employeeName}',
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
        _buildRow2or3(
          isMobile: isMobile,
          children: [
            _buildTextField('First Name', _firstNameController, placeholder: 'First Name'),
            _buildTextField('Last Name', _lastNameController, placeholder: 'Last Name'),
            _buildDropdown(
              'Blood Group',
              _bloodGroup,
              ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'],
              (val) => setState(() => _bloodGroup = val!),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildRow2or3(
          isMobile: isMobile,
          children: [
            _buildDropdown(
              'Gender',
              _gender,
              ['Male', 'Female', 'Other'],
              (val) => setState(() => _gender = val!),
            ),
            _buildDateField('Date Of Birth', _dobController, placeholder: '13-05-1982'),
            _buildTextField('Aadhar Number', _aadhaarController, placeholder: '833750993144'),
          ],
        ),
        const SizedBox(height: 12),
        _buildRow2or3(
          isMobile: isMobile,
          children: [
            _buildTextField('Contact Number', _phoneController, placeholder: '8760098789'),
            _buildTextField('Email', _emailController, placeholder: 'Saravanan@igreentec.in'),
            _buildTextField('PF Number', _pfNumberController, placeholder: '100338738050'),
          ],
        ),
        const SizedBox(height: 12),
        _buildRow2or3(
          isMobile: isMobile,
          children: [
            _buildTextField('ESI Number', _esiNumberController, placeholder: 'ESI Number'),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
          ],
        ),
        const SizedBox(height: 20),
        // Image Picker Section
        Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.active,
              backgroundImage: _profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null,
              child: _profileImageBytes == null
                  ? Text(
                      _firstNameController.text.trim().isNotEmpty
                          ? _firstNameController.text.trim()[0].toUpperCase()
                          : 'E',
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Image', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: const BorderSide(color: Colors.grey),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                      ),
                      onPressed: _pickProfileImage,
                      child: const Text('Choose file', style: TextStyle(fontSize: 12, color: Colors.black)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedFileName,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Save / Cancel Buttons
        _buildSaveButtonsRow(link, 'Personal Info'),
      ],
    );

    final fullName = '${_firstNameController.text} ${_lastNameController.text}'.trim();
    final profileCard = Container(
      width: isMobile ? double.infinity : 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 45,
            backgroundColor: AppColors.active,
            child: Text(
              fullName.isNotEmpty ? fullName[0].toUpperCase() : 'E',
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            fullName.isEmpty ? 'Employee Name' : fullName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Email address', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(
                  _emailController.text.isEmpty ? '-' : _emailController.text,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87),
                ),
                const SizedBox(height: 14),
                const Text('Phone', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(
                  _phoneController.text.isEmpty ? '-' : _phoneController.text,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87),
                ),
                const SizedBox(height: 14),
                const Text('Social Profile', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildSocialButton('f'),
                    const SizedBox(width: 6),
                    _buildSocialButton('t'),
                    const SizedBox(width: 6),
                    _buildSocialButton('in'),
                    const SizedBox(width: 6),
                    _buildSocialButton('G'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: isMobile
          ? Column(
              children: [
                profileCard,
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.white,
                  child: formGrid,
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                profileCard,
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: formGrid,
                  ),
                ),
              ],
            ),
    );
  }

  // TAB: JOB & ADMIN DETAILS
  Widget _buildJobAdminDetailsTab(RegistrationLink link, bool isMobile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Job & Administrative Details',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildDropdown(
                  'User Type',
                  _userType,
                  ['SUPER_ADMIN', 'ADMIN', 'EMPLOYEE', 'HR', 'MANAGER'],
                  (val) => setState(() => _userType = val!),
                ),
                _buildDropdown(
                  'Status',
                  _status,
                  ['ACTIVE', 'INACTIVE'],
                  (val) => setState(() => _status = val!),
                ),
                _buildDropdown(
                  'Department',
                  _department,
                  {...Employee.departmentOptions, if (_department.isNotEmpty) _department}.toList(),
                  (val) => setState(() => _department = val!),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildDropdown(
                  'Designation',
                  _designation,
                  {...Employee.designationOptions, if (_designation.isNotEmpty) _designation}.toList(),
                  (val) => setState(() => _designation = val!),
                ),
                _buildDateField('Date Of Joining', _joiningDateController, placeholder: '29-04-2017'),
                _buildDateField('Contract End Date', _contractEndDateController, placeholder: 'dd-mm-yyyy'),
              ],
            ),
            const SizedBox(height: 12),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildDropdown(
                  'Reporting To',
                  _reportingTo,
                  ['Saravanan G S', 'John Doe', 'Jane Smith', 'None'],
                  (val) => setState(() => _reportingTo = val!),
                ),
                _buildTextField(
                  'Reporting Manager Title',
                  _reportingManagerTitleController,
                  placeholder: 'e.g. Managing Director',
                ),
                _buildTextField(
                  'Present Admin Name',
                  _adminNameController,
                  placeholder: 'e.g. Saravanan G S',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildTextField(
                  'Coordinator Name',
                  _coordinatorNameController,
                  placeholder: 'e.g. Admin Team',
                ),
                _buildTextField(
                  'Coordinator Contact Phone',
                  _coordinatorPhoneController,
                  placeholder: 'e.g. 8760098789',
                ),
                _buildTextField(
                  'Weekly Off Day',
                  _weeklyOffDayController,
                  placeholder: 'e.g. Sunday',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildTextField(
                  'In Time',
                  _inTimeController,
                  placeholder: 'e.g. 09:00 AM',
                ),
                _buildTextField(
                  'Out Time',
                  _outTimeController,
                  placeholder: 'e.g. 06:00 PM',
                ),
                _buildDropdown(
                  'Leave Type',
                  _leaveType,
                  ['As Needed', 'Once a Month', 'No Leave'],
                  (val) => setState(() => _leaveType = val!),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildDropdown(
                  'Leave Allocation Frequency',
                  _leaveAllocationFrequency,
                  ['Monthly', 'Quarterly', 'Yearly'],
                  (val) => setState(() => _leaveAllocationFrequency = val!),
                ),
                _buildTextField(
                  'Number of Allowed Leaves',
                  _allowedLeavesController,
                  placeholder: 'e.g. 1.0',
                ),
                _buildDateField(
                  'Effective Date',
                  _leaveEffectiveDateController,
                  placeholder: 'dd-mm-yyyy',
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSaveButtonsRow(link, 'Job & Admin Details'),
          ],
        ),
      ),
    );
  }

  // TAB 2: ADDRESS
  Widget _buildAddressTab(RegistrationLink link, bool isMobile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Permanent Contact Information',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 14),
            _buildTextField('Address', _permAddressController, placeholder: 'Address Details', maxLines: 2),
            const SizedBox(height: 12),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildTextField('City', _permCityController, placeholder: 'City'),
                _buildTextField('Country', _permCountryController, placeholder: 'Country'),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _sameAsPermanent,
                  onChanged: (val) {
                    setState(() {
                      _sameAsPermanent = val ?? false;
                      if (_sameAsPermanent) {
                        _presAddressController.text = _permAddressController.text;
                        _presCityController.text = _permCityController.text;
                        _presCountryController.text = _permCountryController.text;
                      }
                    });
                  },
                ),
                const Text('Same as Permanent Address', style: TextStyle(fontSize: 12, color: Colors.black87)),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Present Contact Information',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 14),
            _buildTextField('Address', _presAddressController, placeholder: 'Address Details', maxLines: 2),
            const SizedBox(height: 12),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildTextField('City', _presCityController, placeholder: 'City'),
                _buildTextField('Country', _presCountryController, placeholder: 'Country'),
              ],
            ),
            const SizedBox(height: 24),
            _buildSaveButtonsRow(link, 'Address'),
          ],
        ),
      ),
    );
  }

  // TAB 3: EDUCATION
  Widget _buildEducationTab(RegistrationLink link, bool isMobile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Export buttons & Search bar - responsive wrap to prevent overflow
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: ['Copy', 'CSV', 'Excel', 'PDF', 'Print'].map((label) {
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.active,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                      ),
                      onPressed: () {},
                      child: Text(label, style: const TextStyle(fontSize: 11)),
                    );
                  }).toList(),
                ),
                SizedBox(
                  width: isMobile ? 140 : 180,
                  child: TextField(
                    controller: _eduSearchController,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'Search...',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Education Table
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE4E7EC)),
                borderRadius: BorderRadius.circular(2),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: DataTable(
                        columnSpacing: 28,
                        headingRowHeight: 38,
                        dataRowMinHeight: 36,
                        dataRowMaxHeight: 48,
                        columns: const [
                          DataColumn(label: Text('ID ↕', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Certificate name ↕', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Institute ↕', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Result ↕', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('year ↕', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Action ↕', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        ],
                        rows: _educationList.isEmpty
                            ? [
                                const DataRow(cells: [
                                  DataCell(Text('No data available in table', style: TextStyle(fontSize: 12, color: Colors.black54))),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                ])
                              ]
                            : _educationList.map((item) {
                                return DataRow(cells: [
                                  DataCell(Text(item.id, style: const TextStyle(fontSize: 12))),
                                  DataCell(Text(item.degreeName, style: const TextStyle(fontSize: 12))),
                                  DataCell(Text(item.instituteName, style: const TextStyle(fontSize: 12))),
                                  DataCell(Text(item.result, style: const TextStyle(fontSize: 12))),
                                  DataCell(Text(item.passingYear, style: const TextStyle(fontSize: 12))),
                                  DataCell(IconButton(
                                    icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                                    onPressed: () {
                                      setState(() => _educationList.removeWhere((e) => e.id == item.id));
                                    },
                                  )),
                                ]);
                              }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(
                  'Showing ${_educationList.isEmpty ? 0 : 1} to ${_educationList.length} of ${_educationList.length} entries',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPaginationBtn('Previous', null),
                    const SizedBox(width: 6),
                    _buildPaginationBtn('Next', null),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Education Entry Form
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildTextField('Degree Name', _eduDegreeController, placeholder: 'Degree Name'),
                _buildTextField('Institute name', _eduInstController, placeholder: 'Institute name'),
              ],
            ),
            const SizedBox(height: 12),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildTextField('Result', _eduResultController, placeholder: 'Result'),
                _buildTextField('Passing Year', _eduYearController, placeholder: 'Passing Year'),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.active,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: () {
                if (_eduDegreeController.text.isNotEmpty || _eduInstController.text.isNotEmpty) {
                  setState(() {
                    _educationList.add(EducationItem(
                      id: (_educationList.length + 1).toString(),
                      degreeName: _eduDegreeController.text,
                      instituteName: _eduInstController.text,
                      result: _eduResultController.text,
                      passingYear: _eduYearController.text,
                    ));
                    _eduDegreeController.clear();
                    _eduInstController.clear();
                    _eduResultController.clear();
                    _eduYearController.clear();
                  });
                }
                _submitForm(link, isSubmit: false);
              },
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Save', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // TAB 4: EXPERIENCE
  Widget _buildExperienceTab(RegistrationLink link, bool isMobile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE4E7EC)),
                borderRadius: BorderRadius.circular(2),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: DataTable(
                        columnSpacing: 36,
                        headingRowHeight: 38,
                        dataRowMinHeight: 36,
                        dataRowMaxHeight: 48,
                        columns: const [
                          DataColumn(label: Text('ID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Company name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Position', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Work Duration', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Action', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        ],
                        rows: _experienceList.isEmpty
                            ? [
                                const DataRow(cells: [
                                  DataCell(Text('No data available in table', style: TextStyle(fontSize: 12, color: Colors.black54))),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                ])
                              ]
                            : _experienceList.map((item) {
                                return DataRow(cells: [
                                  DataCell(Text(item.id, style: const TextStyle(fontSize: 12))),
                                  DataCell(Text(item.companyName, style: const TextStyle(fontSize: 12))),
                                  DataCell(Text(item.position, style: const TextStyle(fontSize: 12))),
                                  DataCell(Text(item.workingDuration, style: const TextStyle(fontSize: 12))),
                                  DataCell(IconButton(
                                    icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                                    onPressed: () {
                                      setState(() => _experienceList.removeWhere((e) => e.id == item.id));
                                    },
                                  )),
                                ]);
                              }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(
                  'Showing ${_experienceList.isEmpty ? 0 : 1} to ${_experienceList.length} of ${_experienceList.length} entries',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPaginationBtn('Previous', null),
                    const SizedBox(width: 6),
                    _buildPaginationBtn('Next', null),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildTextField('Company Name', _expCompanyController, placeholder: 'Company Name'),
                _buildTextField('Position', _expPositionController, placeholder: 'Position'),
              ],
            ),
            const SizedBox(height: 12),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildTextField('Address', _expAddressController, placeholder: 'Duty'),
                _buildTextField('Working Duration', _expDurationController, placeholder: 'Working Duration'),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.active,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: () {
                if (_expCompanyController.text.isNotEmpty || _expPositionController.text.isNotEmpty) {
                  setState(() {
                    _experienceList.add(ExperienceItem(
                      id: (_experienceList.length + 1).toString(),
                      companyName: _expCompanyController.text,
                      position: _expPositionController.text,
                      address: _expAddressController.text,
                      workingDuration: _expDurationController.text,
                    ));
                    _expCompanyController.clear();
                    _expPositionController.clear();
                    _expAddressController.clear();
                    _expDurationController.clear();
                  });
                }
                _submitForm(link, isSubmit: false);
              },
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Save', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // TAB 5: HISTORY
  Widget _buildHistoryTab(RegistrationLink link, bool isMobile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildDateField('Original DOB', _originalDobController, placeholder: 'dd-mm-yyyy'),
                _buildTextField('Personal Mobile Number', _personalMobileController, placeholder: 'Personal Mobile Number'),
                _buildTextField('PAN No', _panController, placeholder: 'PAN'),
              ],
            ),
            const SizedBox(height: 12),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildTextField('Passport No', _passportController, placeholder: 'Passport Number'),
                _buildTextField('Driving License No.', _drivingLicenseController, placeholder: 'License Number'),
                _buildTextField('Driving License Batch Details', _drivingLicenseBatchController, placeholder: 'License Batch'),
              ],
            ),
            const SizedBox(height: 12),
            _buildTextField('Health Related Issues', _healthIssuesController, placeholder: 'Health Issues'),
            const SizedBox(height: 20),
            const Text('Emergency Contact :', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 10),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildTextField('Name', _emergencyNameController, placeholder: 'Emergency Name'),
                _buildTextField('Mobile Number', _emergencyMobileController, placeholder: 'Emergency Contact'),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Employee Referred By :', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 10),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildTextField('Name', _referredByNameController, placeholder: 'Referred By'),
                _buildTextField('Mobile Number', _referredByMobileController, placeholder: 'Referred Mobile'),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Family Details :', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 10),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildTextField('Father Name', _fatherNameController, placeholder: 'Father Name'),
                _buildTextField('Mother Name', _motherNameController, placeholder: 'Mother Name'),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Marital Status :', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Radio<String>(
                          value: 'Married',
                          groupValue: _maritalStatus,
                          onChanged: (val) => setState(() => _maritalStatus = val!),
                        ),
                        const Text('Married', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 8),
                        Radio<String>(
                          value: 'Unmarried',
                          groupValue: _maritalStatus,
                          onChanged: (val) => setState(() => _maritalStatus = val!),
                        ),
                        const Text('Unmarried', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildTextField('Spouse Name', _spouseNameController, placeholder: 'Spouse Name'),
                _buildTextField('Kids1 Name', _kids1NameController, placeholder: 'Kids Name'),
                _buildTextField('Kids2 Name', _kids2NameController, placeholder: 'Kids Name'),
              ],
            ),
            const SizedBox(height: 12),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildTextField('Kids3 Name', _kids3NameController, placeholder: 'Kids Name'),
                const SizedBox.shrink(),
                const SizedBox.shrink(),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.active,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: _isSubmitting ? null : () => _submitForm(link, isSubmit: false),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Save', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // TAB 6: BANK ACCOUNT
  Widget _buildBankAccountTab(RegistrationLink link, bool isMobile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bank Account Details',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 14),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildTextField('Account Holder Name', _bankHolderController, placeholder: 'Holder Name'),
                _buildTextField('Bank Name', _bankNameController, placeholder: 'Bank Name'),
              ],
            ),
            const SizedBox(height: 12),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildTextField('Account Number', _bankAccNumController, placeholder: 'Account Number'),
                _buildTextField('IFSC Code', _bankIfscController, placeholder: 'IFSC Code'),
              ],
            ),
            const SizedBox(height: 12),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildTextField('Branch Name', _bankBranchController, placeholder: 'Branch Name'),
                _buildDropdown(
                  'Account Type',
                  _bankAccountType,
                  ['Savings', 'Current', 'Salary'],
                  (val) => setState(() => _bankAccountType = val!),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.active,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: _isSubmitting ? null : () => _submitForm(link, isSubmit: false),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Save', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // TAB 7: DOCUMENT
  Widget _buildDocumentTab(RegistrationLink link, bool isMobile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Document Management & Attachments',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE4E7EC)),
                borderRadius: BorderRadius.circular(2),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: DataTable(
                        columnSpacing: 28,
                        headingRowHeight: 38,
                        dataRowMinHeight: 36,
                        dataRowMaxHeight: 48,
                        columns: const [
                          DataColumn(label: Text('ID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Document Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Document Number / File', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Action', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        ],
                        rows: _documentList.isEmpty
                            ? [
                                const DataRow(cells: [
                                  DataCell(Text('No documents uploaded yet', style: TextStyle(fontSize: 12, color: Colors.black54))),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                ])
                              ]
                            : _documentList.map((item) {
                                return DataRow(cells: [
                                  DataCell(Text(item.id, style: const TextStyle(fontSize: 12))),
                                  DataCell(Text(item.documentType, style: const TextStyle(fontSize: 12))),
                                  DataCell(Text('${item.documentNumber} (${item.fileName})', style: const TextStyle(fontSize: 12))),
                                  DataCell(IconButton(
                                    icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                                    onPressed: () {
                                      setState(() => _documentList.removeWhere((e) => e.id == item.id));
                                    },
                                  )),
                                ]);
                              }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(
                  'Showing ${_documentList.isEmpty ? 0 : 1} to ${_documentList.length} of ${_documentList.length} entries',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPaginationBtn('Previous', null),
                    const SizedBox(width: 6),
                    _buildPaginationBtn('Next', null),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildDropdown(
                  'Document Type',
                  _docType,
                  ['Aadhaar Card', 'PAN Card', 'Educational Certificate', 'Passport', 'Relieving Letter', 'Other'],
                  (val) => setState(() => _docType = val!),
                ),
                _buildTextField('Document Number / Reference', _docNumberController, placeholder: 'Document Number'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () {
                    setState(() {
                      _docFileName = '${_docType.replaceAll(' ', '_').toLowerCase()}_document.pdf';
                    });
                  },
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: const Text('Choose File', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 10),
                Text(_docFileName, style: const TextStyle(fontSize: 12, color: Colors.black87)),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.active,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: () {
                if (_docFileName != 'No file chosen' || _docNumberController.text.isNotEmpty) {
                  setState(() {
                    _documentList.add(DocumentItem(
                      id: (_documentList.length + 1).toString(),
                      documentType: _docType,
                      documentNumber: _docNumberController.text,
                      fileName: _docFileName,
                      uploadedDate: DateTime.now().toString().split(' ')[0],
                    ));
                    _docNumberController.clear();
                    _docFileName = 'No file chosen';
                  });
                }
                _submitForm(link, isSubmit: false);
              },
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Save', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // TAB 8: SOCIAL MEDIA
  Widget _buildSocialMediaTab(RegistrationLink link, bool isMobile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Social Media Links & Handles',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 14),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildTextField('Facebook URL', _facebookController, placeholder: 'https://facebook.com/username'),
                _buildTextField('Twitter / X Handle', _twitterController, placeholder: 'https://twitter.com/username'),
              ],
            ),
            const SizedBox(height: 12),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildTextField('LinkedIn Profile', _linkedinController, placeholder: 'https://linkedin.com/in/username'),
                _buildTextField('Google / Website URL', _googleController, placeholder: 'https://example.com'),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.active,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: _isSubmitting ? null : () => _submitForm(link, isSubmit: false),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Save', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationBtn(String label, VoidCallback? onPressed) {
    final isDisabled = onPressed == null;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        disabledForegroundColor: const Color(0xFF98A2B3),
        backgroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFF9FAFB),
        side: BorderSide(
          color: isDisabled ? const Color(0xFFEAECF0) : const Color(0xFFD0D5DD),
          width: 1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isDisabled ? const Color(0xFF98A2B3) : AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildRow2or3({
    required bool isMobile,
    required List<Widget> children,
  }) {
    if (isMobile) {
      return Column(
        children: children
            .where((w) => w is! SizedBox || (w.width != null || w.height != null))
            .map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: c,
                ))
            .toList(),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children.map((c) => Expanded(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: c,
      ))).toList(),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    String? placeholder,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(fontSize: 12, color: Colors.black38),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              borderSide: const BorderSide(color: AppColors.active, width: 1.2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(
    String label,
    TextEditingController controller, {
    String? placeholder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          readOnly: true,
          onTap: () => _selectDate(controller),
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          decoration: InputDecoration(
            hintText: placeholder ?? 'dd-mm-yyyy',
            hintStyle: const TextStyle(fontSize: 12, color: Colors.black38),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            suffixIcon: const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.black54),
            suffixIconConstraints: const BoxConstraints(minWidth: 28),
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
              borderSide: const BorderSide(color: AppColors.active, width: 1.2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
          initialValue: items.contains(value) ? value : items.first,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          icon: const Icon(Icons.keyboard_arrow_down, size: 16),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              borderSide: const BorderSide(color: AppColors.active, width: 1.2),
            ),
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item, style: const TextStyle(fontSize: 12)),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSocialButton(String label) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0xFFD0D5DD)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildSaveButtonsRow(RegistrationLink link, String tabName) {
    final isSaved = _savedTabs.contains(tabName);
    return Row(
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.active,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          onPressed: _isSubmitting ? null : () => _submitForm(link, isSubmit: false),
          icon: _isSubmitting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check, size: 16),
          label: const Text('Save', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.active,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          onPressed: () {},
          child: const Text('Cancel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ),
        if (isSaved) ...[
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFA5D6A7)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.check_circle, size: 16, color: Color(0xFF2E7D32)),
                SizedBox(width: 6),
                Text(
                  'This page is saved',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // TAB 9: SALARY & OFFER LETTER
  Widget _buildSalaryOfferLetterTab(RegistrationLink link, bool isMobile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFEAECF0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Basic Salary
            const Text(
              'Basic Slary',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475467),
              ),
            ),
            const SizedBox(height: 16),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildDropdown(
                  'Salary Type',
                  _salaryType,
                  ['Monthly', 'Yearly'],
                  (val) => setState(() => _salaryType = val ?? 'Monthly'),
                ),
                _buildTextField(
                  'Total Salary',
                  _totalSalaryController,
                  placeholder: '85000',
                  onChanged: _onTotalSalaryChanged,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Section 2: Addition
            const Text(
              'Addition',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475467),
              ),
            ),
            const SizedBox(height: 16),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildTextField('Basic', _basicPayController, placeholder: '42500.00'),
                _buildTextField('House Rent Allowance', _hraController, placeholder: '21250.00'),
              ],
            ),
            const SizedBox(height: 12),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildTextField('Special Allowance', _specialAllowanceController, placeholder: '21500.00'),
                _buildTextField('Education Allowance', _eduAllowanceController, placeholder: 'Education Allowance'),
                _buildTextField('Travel Allowance', _travelAllowanceController, placeholder: 'Travel Allowance'),
              ],
            ),
            const SizedBox(height: 24),

            // Section 3: Deduction
            const Text(
              'Deduction',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475467),
              ),
            ),
            const SizedBox(height: 16),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildTextField('Tax', _taxController, placeholder: 'tax...'),
                _buildTextField('Provident Fund', _pfController, placeholder: '1800'),
                _buildTextField('Professional Tax', _professionalTaxController, placeholder: '200'),
              ],
            ),
            const SizedBox(height: 28),

            // Section 4: Offer Letter Generation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFEAECF0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined, color: AppColors.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Offer Letter Generation',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Generate and download Microsoft Word (.docx) offer letter with candidate details, salary structure, and company terms & conditions.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00BFA5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    onPressed: () => OfferLetterGenerator.downloadOfferLetter(
                      context,
                      _buildCurrentEmployeeFromForm(link),
                    ),
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    label: const Text(
                      'Generate Offer Letter',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.active,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: _isSubmitting ? null : () => _submitForm(link, isSubmit: false),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Save', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // TAB: WELCOME LETTER
  Widget _buildWelcomeLetterTab(RegistrationLink link, bool isMobile) {
    final empName = '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'.trim();
    final data = WelcomeLetterData(
      employeeName: empName.isNotEmpty ? empName : 'Employee',
      reportingManagerName: _reportingTo.isNotEmpty && _reportingTo != 'None'
          ? _reportingTo
          : 'Saravanan G S',
      reportingManagerTitle: _reportingManagerTitleController.text.trim().isNotEmpty
          ? _reportingManagerTitleController.text.trim()
          : 'Managing Director',
      adminName: _adminNameController.text.trim().isNotEmpty
          ? _adminNameController.text.trim()
          : 'Saravanan G S',
      coordinatorName: _coordinatorNameController.text.trim().isNotEmpty
          ? _coordinatorNameController.text.trim()
          : 'Admin Team',
      coordinatorPhone: _coordinatorPhoneController.text.trim().isNotEmpty
          ? _coordinatorPhoneController.text.trim()
          : '8760098789',
      officeStartTime: _inTimeController.text.trim().isNotEmpty
          ? _inTimeController.text.trim()
          : '09:00 AM',
      officeEndTime: _outTimeController.text.trim().isNotEmpty
          ? _outTimeController.text.trim()
          : '06:00 PM',
      weeklyOffDay: _weeklyOffDayController.text.trim().isNotEmpty
          ? _weeklyOffDayController.text.trim()
          : 'Sunday',
    );

    final dateStr = DateFormat('MMMM dd, yyyy').format(DateTime.now());

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Action Bar / Header Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFEAECF0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.mark_email_read_outlined, color: AppColors.active, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Welcome Letter Preview',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Live preview generated from form & Job & Admin Details tab.',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.active,
                    side: const BorderSide(color: AppColors.active),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: () {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Welcome Letter preview updated with latest changes!'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh Preview', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.active,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: () => WelcomeLetterGenerator.downloadWelcomeLetter(context, data),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                  label: const Text('Generate PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Printed Letter Card Preview
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              padding: EdgeInsets.all(isMobile ? 20 : 44),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Company Header
                  Center(
                    child: Column(
                      children: const [
                        Text(
                          'IGREEN TECHNOLOGIES',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'OFFICIAL WELCOME LETTER',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                            color: AppColors.active,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: Color(0xFFE2E8F0), thickness: 1),
                  const SizedBox(height: 20),

                  // Date
                  Text(
                    'Date: $dateStr',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Paragraph 1: Dear {EmployeeName},
                  Text(
                    'Dear ${data.employeeName},',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Paragraph 2: Welcome to IGreen Technologies! ...
                  const Text(
                    'Welcome to IGreen Technologies! We are excited to have you on board and look forward to working with you.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Paragraph 3: We would like to give you ...
                  const Text(
                    'We would like to give you a brief overview of your key responsibilities.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Paragraph 4: You will be reporting directly to ...
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: Color(0xFF334155),
                      ),
                      children: [
                        const TextSpan(text: 'You will be reporting directly to '),
                        TextSpan(
                          text: '${data.reportingManagerName}, ${data.reportingManagerTitle}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        const TextSpan(text: ', who will guide you through your initial onboarding and assist you with any concerns regarding your responsibilities.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Paragraph 5: For knowledge transfer ...
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: Color(0xFF334155),
                      ),
                      children: [
                        const TextSpan(text: 'For knowledge transfer — including employee contact details and role-related information — please reach out to '),
                        TextSpan(
                          text: '${data.adminName} (present Admin)',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        const TextSpan(text: '. You may also coordinate with '),
                        TextSpan(
                          text: '${data.coordinatorName} (${data.coordinatorPhone})',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        const TextSpan(text: ' for any queries.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Paragraph 6: Office Timings ...
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: Color(0xFF334155),
                      ),
                      children: [
                        const TextSpan(text: 'Office Timings: '),
                        TextSpan(
                          text: '${data.officeStartTime} to ${data.officeEndTime} (${data.weeklyOffDay} Holiday)',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Paragraph 7: Once again, welcome aboard!
                  const Text(
                    'Once again, welcome aboard!',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Sign-off
                  const Text(
                    'Sincerely,',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'IGreen Technologies Team',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Employee _buildCurrentEmployeeFromForm(RegistrationLink link) {
    return Employee(
      id: 0,
      employeeId: _employeeCustomIdController.text.trim(),
      temporaryPassword: _passwordController.text.trim(),
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      emailAddress: _emailController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      gender: _gender,
      dob: _dobController.text.trim(),
      organizationName: link.organizationName.isEmpty
          ? 'iGreen Tech'
          : link.organizationName,
      department: _department,
      designation: _designation,
      employmentType: 'Full-Time',
      joiningDate: _joiningDateController.text.trim(),
      status: _status,
      bloodGroup: _bloodGroup,
      userType: _userType,
      contractEndDate: _contractEndDateController.text.trim(),
      permanentAddress: _permAddressController.text.trim(),
      permanentCity: _permCityController.text.trim(),
      permanentCountry: _permCountryController.text.trim(),
      sameAsPermanent: _sameAsPermanent,
      presentAddress: _sameAsPermanent
          ? _permAddressController.text.trim()
          : _presAddressController.text.trim(),
      presentCity: _sameAsPermanent
          ? _permCityController.text.trim()
          : _presCityController.text.trim(),
      presentCountry: _sameAsPermanent
          ? _permCountryController.text.trim()
          : _presCountryController.text.trim(),
      educationListJson: jsonEncode(_educationList.map((e) => e.toMap()).toList()),
      experienceListJson: jsonEncode(_experienceList.map((e) => e.toMap()).toList()),
      originalDob: _originalDobController.text.trim(),
      personalMobile: _personalMobileController.text.trim(),
      passportNumber: _passportController.text.trim(),
      drivingLicenseNumber: _drivingLicenseController.text.trim(),
      drivingLicenseBatch: _drivingLicenseBatchController.text.trim(),
      healthIssues: _healthIssuesController.text.trim(),
      emergencyName: _emergencyNameController.text.trim(),
      emergencyMobile: _emergencyMobileController.text.trim(),
      referredByName: _referredByNameController.text.trim(),
      referredByMobile: _referredByMobileController.text.trim(),
      fatherName: _fatherNameController.text.trim(),
      motherName: _motherNameController.text.trim(),
      maritalStatus: _maritalStatus,
      spouseName: _spouseNameController.text.trim(),
      kids1Name: _kids1NameController.text.trim(),
      kids2Name: _kids2NameController.text.trim(),
      kids3Name: _kids3NameController.text.trim(),
      bankAccountHolder: _bankHolderController.text.trim(),
      bankName: _bankNameController.text.trim(),
      bankAccountNumber: _bankAccNumController.text.trim(),
      bankIfsc: _bankIfscController.text.trim(),
      bankBranch: _bankBranchController.text.trim(),
      bankAccountType: _bankAccountType,
      panNumber: _panController.text.trim(),
      aadhaarNumber: _aadhaarController.text.trim(),
      documentListJson: jsonEncode(_documentList.map((e) => e.toMap()).toList()),
      facebookUrl: _facebookController.text.trim(),
      twitterUrl: _twitterController.text.trim(),
      linkedinUrl: _linkedinController.text.trim(),
      googleUrl: _googleController.text.trim(),
      pfNumber: _pfNumberController.text.trim(),
      esiNumber: _esiNumberController.text.trim(),
      reportingManager: _reportingTo,
      reportingManagerTitle: _reportingManagerTitleController.text.trim(),
      adminName: _adminNameController.text.trim(),
      coordinatorName: _coordinatorNameController.text.trim(),
      coordinatorPhone: _coordinatorPhoneController.text.trim(),
      weeklyOffDay: _weeklyOffDayController.text.trim(),
      salaryType: _salaryType,
      salaryTotalCtc: double.tryParse(_totalSalaryController.text.trim().replaceAll(',', '')) ?? 0.0,
      salaryBasic: double.tryParse(_basicPayController.text.trim().replaceAll(',', '')) ?? 0.0,
      salaryHra: double.tryParse(_hraController.text.trim().replaceAll(',', '')) ?? 0.0,
      salaryEducationAllowance: double.tryParse(_eduAllowanceController.text.trim().replaceAll(',', '')) ?? 0.0,
      salarySpecialAllowance: double.tryParse(_specialAllowanceController.text.trim().replaceAll(',', '')) ?? 0.0,
      salaryTravelAllowance: double.tryParse(_travelAllowanceController.text.trim().replaceAll(',', '')) ?? 0.0,
      salaryTax: double.tryParse(_taxController.text.trim().replaceAll(',', '')) ?? 0.0,
      salaryPf: double.tryParse(_pfController.text.trim().replaceAll(',', '')) ?? 0.0,
      salaryProfessionalTax: double.tryParse(_professionalTaxController.text.trim().replaceAll(',', '')) ?? 0.0,
    );
  }

  // TAB 10: CREDENTIALS
  Widget _buildCredentialsTab(RegistrationLink? link, bool isMobile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFEAECF0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Account Credentials',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475467),
              ),
            ),
            const SizedBox(height: 16),
            if (_isManagementAdd) ...[
              _buildRow2or3(
                isMobile: isMobile,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Employee ID / Username',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          InkWell(
                            onTap: _generateSampleEmpId,
                            child: const Text(
                              'Auto Generate ID',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.active),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _employeeCustomIdController,
                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                        decoration: const InputDecoration(
                          hintText: 'e.g. EMP-0002 (Leave blank for auto-id)',
                          hintStyle: TextStyle(fontSize: 12, color: Colors.black38),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFD0D5DD), width: 0.8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFD0D5DD), width: 0.8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: AppColors.active, width: 1.2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  _buildDropdown(
                    'User Role / Type',
                    _userType,
                    ['SUPER_ADMIN', 'ADMIN', 'EMPLOYEE', 'HR', 'MANAGER'],
                    (val) => setState(() => _userType = val ?? 'EMPLOYEE'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isManagementAdd ? 'Temporary Password' : 'Login Password *',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        if (_isManagementAdd)
                          InkWell(
                            onTap: _generateRandomPassword,
                            child: const Text(
                              'Generate Password',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.active),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: _isManagementAdd ? 'Enter password or generate' : 'Enter your secure login password',
                        hintStyle: const TextStyle(fontSize: 12, color: Colors.black38),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                        ),
                        border: const OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFD0D5DD), width: 0.8),
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFD0D5DD), width: 0.8),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.active, width: 1.2),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isManagementAdd)
                  _buildDropdown(
                    'Account Status',
                    _status,
                    ['ACTIVE', 'INACTIVE', 'SUSPENDED'],
                    (val) => setState(() => _status = val ?? 'ACTIVE'),
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
            if (_isManagementAdd) ...[
              const SizedBox(height: 28),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.active,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: _isSubmitting ? null : () => _submitForm(link, isSubmit: false),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Save Credentials', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAccessPermissionsTab(RegistrationLink? link, bool isMobile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE4E7EC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.security, size: 22, color: AppColors.active),
                      SizedBox(width: 10),
                      Text(
                        'Access Permissions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475467),
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      setState(() {
                        if (_selectedPermissions.length ==
                            Employee.allSidebarPermissions.length) {
                          _selectedPermissions.clear();
                        } else {
                          _selectedPermissions =
                              Set<String>.from(Employee.allSidebarPermissions);
                        }
                      });
                    },
                    icon: Icon(
                      _selectedPermissions.length ==
                              Employee.allSidebarPermissions.length
                          ? Icons.deselect
                          : Icons.select_all,
                      size: 16,
                      color: AppColors.active,
                    ),
                    label: Text(
                      _selectedPermissions.length ==
                              Employee.allSidebarPermissions.length
                          ? 'Deselect All'
                          : 'Select All',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.active,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Select which sidebar menu options this employee is allowed to view and access upon login:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  border: Border.all(color: const Color(0xFFEAECF0)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: Employee.sidebarPermissionsByCategory.entries.map((entry) {
                    final categoryName = entry.key;
                    final categoryPermissions = entry.value;
                    final isFirst = entry.key == Employee.sidebarPermissionsByCategory.keys.first;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            top: isFirst ? 0.0 : 16.0,
                            bottom: 8.0,
                          ),
                          child: Text(
                            categoryName,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF667085),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          children: categoryPermissions.map((permission) {
                            final isSelected = _selectedPermissions.contains(permission);
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedPermissions.remove(permission);
                                  } else {
                                    _selectedPermissions.add(permission);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                width: isMobile ? double.infinity : 270,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.active.withValues(alpha: 0.05)
                                      : Colors.white,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.active.withValues(alpha: 0.4)
                                        : const Color(0xFFD0D5DD),
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: Checkbox(
                                        value: isSelected,
                                        activeColor: AppColors.active,
                                        onChanged: (val) {
                                          setState(() {
                                            if (val == true) {
                                              _selectedPermissions.add(permission);
                                            } else {
                                              _selectedPermissions.remove(permission);
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        permission,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: isSelected
                                              ? Colors.black87
                                              : Colors.black54,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.active,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                onPressed: _isSubmitting ? null : () => _submitForm(link, isSubmit: false),
                icon: const Icon(Icons.check, size: 16),
                label: const Text(
                  'Save Permissions',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: color),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
