// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../salary_settings/domain/salary_settings.dart';
import '../../salary_settings/providers/salary_settings_providers.dart';
import '../../attendance_settings/presentation/widgets/attendance_location_fields.dart';
import '../../organization/domain/business_unit.dart';
import '../../organization/domain/department.dart';
import '../../organization/domain/designation.dart';
import '../../organization/domain/location.dart';
import '../../organization/domain/organization.dart';
import '../../organization/providers/organization_providers.dart';
import '../../../../core/widgets/app_searchable_dropdown.dart';

class EmployeeRegistrationPage extends ConsumerStatefulWidget {
  const EmployeeRegistrationPage({
    required this.linkId,
    this.employee,
    this.acceptedEmpId,
    this.acceptedLinkId,
    super.key,
  });

  final String linkId;
  final Employee? employee;
  final int? acceptedEmpId;
  final String? acceptedLinkId;

  static List<Map<String, String>> get allWorldCountryCodes => _EmployeeRegistrationPageState.allWorldCountryCodes;

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
  String _bloodGroupDocFileName = 'No file chosen';
  String _gender = 'Male';
  String _userType = 'EMPLOYEE';
  String _status = 'ACTIVE';
  final _dobController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _phoneController = TextEditingController();
  String _phoneCountryCode = '+91';
  String _organizationName = '';
  String _businessUnit = '';
  String _workLocation = '';
  String _department = '';
  String _designation = '';
  final _joiningDateController = TextEditingController();
  final _contractEndDateController = TextEditingController();
  final _emailController = TextEditingController();
  final _pfNumberController = TextEditingController();
  final _esiNumberController = TextEditingController();
  final _reportingToController = TextEditingController();
  String _workScheduleType = 'Fixed Schedule';
  final _requiredWorkingHoursController = TextEditingController(text: '9 Hours');
  final _inTimeController = TextEditingController();
  final _outTimeController = TextEditingController();
  final _weeklyOffDayController = TextEditingController();
  final _reportingManagerTitleController = TextEditingController();
  final _adminNameController = TextEditingController(text: 'Saravanan G S');
  final _coordinatorNameController = TextEditingController(text: 'Admin Team');
  final _coordinatorPhoneController = TextEditingController(text: '8760098789');
  String _coordinatorPhoneCountryCode = '+91';
  String _leaveType = 'As Needed';
  String _leaveAllocationFrequency = 'Monthly';
  final _allowedLeavesController = TextEditingController(text: '1.0');
  final _monthlyPermissionLimitController = TextEditingController(text: '3.0');
  final _dailyPermissionLimitController = TextEditingController(text: '1.0');
  final _leaveEffectiveDateController = TextEditingController();

  final _siteLatitudeController = TextEditingController();
  final _siteLongitudeController = TextEditingController();
  final _siteRadiusController = TextEditingController(text: '15');
  bool _siteRequireGpsVerification = true;
  String _selectedFileName = 'No file chosen';
  String _profileImageDataUrl = '';
  Uint8List? _profileImageBytes;
  bool _isProfileImageRemoved = false;

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
  String _personalMobileCountryCode = '+91';
  final _panController = TextEditingController();
  final _passportController = TextEditingController();
  final _drivingLicenseController = TextEditingController();
  final _healthIssuesController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyMobileController = TextEditingController();
  String _emergencyMobileCountryCode = '+91';
  final _referredByNameController = TextEditingController();
  final _referredByMobileController = TextEditingController();
  String _referredByMobileCountryCode = '+91';
  final _fatherNameController = TextEditingController();
  final _motherNameController = TextEditingController();
  String _maritalStatus = 'Unmarried';
  final _spouseNameController = TextEditingController();
  final _kids1NameController = TextEditingController();
  final _kids2NameController = TextEditingController();
  final _kids3NameController = TextEditingController();
  bool _hasCriminalCases = false;
  final _criminalCaseDetailsController = TextEditingController();

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
  final _otherAllowanceController = TextEditingController();
  final _pfController = TextEditingController();
  final _esiController = TextEditingController();
  final _esiEmployerController = TextEditingController();
  final _professionalTaxController = TextEditingController();
  final _tdsController = TextEditingController();

  final _basicPercentController = TextEditingController();
  final _hraPercentController = TextEditingController();
  final _specialAllowancePercentController = TextEditingController();
  final _eduAllowancePercentController = TextEditingController();
  final _travelAllowancePercentController = TextEditingController();
  final _otherAllowancePercentController = TextEditingController();
  final _pfPercentController = TextEditingController();
  final _esiPercentController = TextEditingController();
  final _esiEmployerPercentController = TextEditingController();
  final _professionalTaxPercentController = TextEditingController();
  final _tdsPercentController = TextEditingController();

  bool _salaryPercentagesInitialized = false;

  void _initSalaryPercentagesFromDefaults(SalarySettings defaults) {
    if (_salaryPercentagesInitialized) return;
    _salaryPercentagesInitialized = true;
    _basicPercentController.text = defaults.basicPercentage.toStringAsFixed(1);
    _hraPercentController.text = defaults.hraPercentage.toStringAsFixed(1);
    _specialAllowancePercentController.text = defaults.specialAllowancePercentage.toStringAsFixed(1);
    _eduAllowancePercentController.text = defaults.educationAllowancePercentage.toStringAsFixed(1);
    _travelAllowancePercentController.text = defaults.travelAllowancePercentage.toStringAsFixed(1);
    _otherAllowancePercentController.text = defaults.otherAllowancePercentage.toStringAsFixed(1);
    _pfPercentController.text = defaults.pfPercentage.toStringAsFixed(1);
    _esiPercentController.text = defaults.esiPercentage.toStringAsFixed(1);
    _esiEmployerPercentController.text = defaults.esiEmployerPercentage.toStringAsFixed(1);
    _professionalTaxPercentController.text = defaults.professionalTaxPercentage.toStringAsFixed(1);
    _tdsPercentController.text = defaults.taxPercentage.toStringAsFixed(1);
  }

  void _recalculateSalaryAmountsFromPercentages() {
    final totalSalary = double.tryParse(_totalSalaryController.text.replaceAll(',', '').trim()) ?? 0.0;
    if (totalSalary <= 0) return;

    if ((double.tryParse(_basicPercentController.text.trim()) ?? 0.0) == 0.0) {
      _basicPercentController.text = '50.0';
    }
    if ((double.tryParse(_hraPercentController.text.trim()) ?? 0.0) == 0.0) {
      _hraPercentController.text = '20.0';
    }
    if ((double.tryParse(_specialAllowancePercentController.text.trim()) ?? 0.0) == 0.0 &&
        (double.tryParse(_eduAllowancePercentController.text.trim()) ?? 0.0) == 0.0 &&
        (double.tryParse(_travelAllowancePercentController.text.trim()) ?? 0.0) == 0.0 &&
        (double.tryParse(_otherAllowancePercentController.text.trim()) ?? 0.0) == 0.0) {
      _specialAllowancePercentController.text = '30.0';
    }
    if ((double.tryParse(_pfPercentController.text.trim()) ?? 0.0) == 0.0) {
      _pfPercentController.text = '12.0';
    }
    if (totalSalary <= 21000 && (double.tryParse(_esiPercentController.text.trim()) ?? 0.0) == 0.0) {
      _esiPercentController.text = '0.75';
    }

    void calcAmount(TextEditingController percentCtrl, TextEditingController amountCtrl, double basis) {
      final pct = double.tryParse(percentCtrl.text.trim()) ?? 0.0;
      final amount = (pct / 100) * basis;
      amountCtrl.text = amount == 0 ? '' : amount.toStringAsFixed(2);
    }

    calcAmount(_basicPercentController, _basicPayController, totalSalary);
    final basic = double.tryParse(_basicPayController.text.replaceAll(',', '').trim()) ?? 0.0;

    calcAmount(_hraPercentController, _hraController, totalSalary);
    calcAmount(_specialAllowancePercentController, _specialAllowanceController, totalSalary);
    calcAmount(_eduAllowancePercentController, _eduAllowanceController, totalSalary);
    calcAmount(_travelAllowancePercentController, _travelAllowanceController, totalSalary);
    calcAmount(_otherAllowancePercentController, _otherAllowanceController, totalSalary);
    calcAmount(_pfPercentController, _pfController, basic);

    if (totalSalary <= 21000 && totalSalary > 0) {
      calcAmount(_esiPercentController, _esiController, basic);
      calcAmount(_esiEmployerPercentController, _esiEmployerController, totalSalary);
    } else {
      _esiController.text = '';
      _esiEmployerController.text = '';
    }

    calcAmount(_professionalTaxPercentController, _professionalTaxController, totalSalary);
    calcAmount(_tdsPercentController, _tdsController, totalSalary);
  }

  void _onTotalSalaryChanged(String val) {
    setState(() {
      _recalculateSalaryAmountsFromPercentages();
    });
  }

  void _onPercentFieldEdited(TextEditingController percentCtrl, TextEditingController amountCtrl, double basis) {
    final pct = double.tryParse(percentCtrl.text.trim()) ?? 0.0;
    final amount = (pct / 100) * basis;
    setState(() {
      amountCtrl.text = amount == 0 ? '' : amount.toStringAsFixed(2);
    });
  }

  void _onAmountFieldEdited(TextEditingController amountCtrl, TextEditingController percentCtrl, double basis) {
    final amount = double.tryParse(amountCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    final pct = basis > 0 ? (amount / basis) * 100 : 0.0;
    setState(() {
      percentCtrl.text = pct == 0 ? '0.0' : pct.toStringAsFixed(1);
    });
  }

  double _getAdditionsTotal() {
    final basic = double.tryParse(_basicPayController.text.replaceAll(',', '').trim()) ?? 0.0;
    final hra = double.tryParse(_hraController.text.replaceAll(',', '').trim()) ?? 0.0;
    final special = double.tryParse(_specialAllowanceController.text.replaceAll(',', '').trim()) ?? 0.0;
    final edu = double.tryParse(_eduAllowanceController.text.replaceAll(',', '').trim()) ?? 0.0;
    final travel = double.tryParse(_travelAllowanceController.text.replaceAll(',', '').trim()) ?? 0.0;
    final other = double.tryParse(_otherAllowanceController.text.replaceAll(',', '').trim()) ?? 0.0;
    return basic + hra + special + edu + travel + other;
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

  bool get _isCandidateLink =>
      widget.linkId.isNotEmpty &&
      widget.linkId != 'new' &&
      widget.linkId != 'edit' &&
      widget.acceptedLinkId == null &&
      widget.acceptedEmpId == null;

  bool get _isManagementAdd =>
      !_isCandidateLink &&
      (widget.linkId == 'new' ||
       widget.linkId == 'edit' ||
       widget.linkId.isEmpty ||
       widget.employee != null ||
       widget.acceptedLinkId != null ||
       widget.acceptedEmpId != null ||
       _registrationMode == 'accepted_response');

  void _updateTabControllerIfNeeded() {
    if (_tabController.length != _tabs.length) {
      final oldIndex = _tabController.index;
      final newIndex = oldIndex.clamp(0, _tabs.length - 1);
      _tabController.dispose();
      _tabController = TabController(
        length: _tabs.length,
        initialIndex: newIndex,
        vsync: this,
      );
      _tabController.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  bool get _isEditing => widget.employee != null || widget.linkId == 'edit';

  bool _isSubmitting = false;
  bool _isDraftSaving = false;
  Employee? _submittedEmployee;
  Employee? _currentEmployee;
  String _registrationMode = 'manual';
  // ignore: unused_field
  int? _selectedAcceptedEmpId;
  String? _selectedAcceptedLinkId;
  bool _draftLoaded = false;
  bool _hasSubmittedAtLeastOnce = false;
  final Set<String> _savedTabs = {};
  bool _isPopulating = false;
  final Map<TextEditingController, String> _savedControllerTexts = {};

  List<String> _validatePersonalInfoTab() {
    final errors = <String>[];
    final hasPhoto = _profileImageBytes != null ||
        (_profileImageDataUrl.isNotEmpty && !_isProfileImageRemoved);
    if (!hasPhoto) {
      errors.add('Candidate Photo is mandatory');
    }
    final firstName = _firstNameController.text.trim();
    if (firstName.isEmpty) {
      errors.add('First Name is required');
    } else if (RegExp(r'[0-9]').hasMatch(firstName)) {
      errors.add('First Name cannot contain numbers');
    } else if (RegExp(r"[^a-zA-Z\s.\-']").hasMatch(firstName)) {
      errors.add('First Name cannot contain special characters');
    }

    final lastName = _lastNameController.text.trim();
    if (lastName.isEmpty) {
      errors.add('Last Name is required');
    } else if (RegExp(r'[0-9]').hasMatch(lastName)) {
      errors.add('Last Name cannot contain numbers');
    } else if (RegExp(r"[^a-zA-Z\s.\-']").hasMatch(lastName)) {
      errors.add('Last Name cannot contain special characters');
    }

    if (_gender.trim().isEmpty) {
      errors.add('Gender is required');
    }
    if (_dobController.text.trim().isEmpty) {
      errors.add('Official Date of Birth is required');
    }
    final aadhaar = _aadhaarController.text.trim();
    if (aadhaar.isEmpty) {
      errors.add('Aadhaar Number is required');
    } else if (aadhaar.length != 12 || !RegExp(r'^\d{12}$').hasMatch(aadhaar)) {
      errors.add('Aadhaar Number must be exactly 12 digits');
    }

    final phone = _phoneController.text.trim();
    final phoneDetails = getCountryPhoneDetails(_phoneCountryCode);
    final expectedPhoneDigits = phoneDetails['digits'] as int? ?? 10;
    if (phone.isEmpty) {
      errors.add('Primary Mobile Number is required');
    } else if (!RegExp(r'^\d+$').hasMatch(phone)) {
      errors.add('Primary Mobile Number must contain only digits (0-9)');
    } else if (phone.length != expectedPhoneDigits) {
      errors.add('Primary Mobile Number must be exactly $expectedPhoneDigits digits for $_phoneCountryCode');
    }

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      errors.add('Email Address is required');
    } else if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email)) {
      errors.add('Invalid Email Address format (e.g. user@domain.com)');
    }

    final pfText = _pfNumberController.text.trim().toUpperCase();
    if (pfText.isNotEmpty) {
      if (pfText.length != 12 && pfText.length != 22) {
        errors.add('PF Number / UAN must be 12 digits or 22 characters');
      }
    }

    final esiText = _esiNumberController.text.trim();
    if (esiText.isNotEmpty) {
      if (esiText.length != 17 || !RegExp(r'^\d{17}$').hasMatch(esiText)) {
        errors.add('ESI Number must be exactly 17 digits');
      }
    }
    return errors;
  }

  List<String> _validateAddressTab() {
    final errors = <String>[];
    if (_permAddressController.text.trim().isEmpty) {
      errors.add('Permanent Address is required');
    }
    final permCity = _permCityController.text.trim();
    if (permCity.isEmpty) {
      errors.add('Permanent City is required');
    } else if (RegExp(r'[0-9]').hasMatch(permCity)) {
      errors.add('Permanent City name cannot contain numbers');
    }
    if (_permCountryController.text.trim().isEmpty) {
      errors.add('Permanent Country is required');
    }
    if (!_sameAsPermanent) {
      if (_presAddressController.text.trim().isEmpty) {
        errors.add('Present Address is required');
      }
      final presCity = _presCityController.text.trim();
      if (presCity.isEmpty) {
        errors.add('Present City is required');
      } else if (RegExp(r'[0-9]').hasMatch(presCity)) {
        errors.add('Present City name cannot contain numbers');
      }
      if (_presCountryController.text.trim().isEmpty) {
        errors.add('Present Country is required');
      }
    }
    return errors;
  }

  List<String> _validateEducationTab() {
    final errors = <String>[];
    bool hasEduInList = _educationList.any((e) => e.degreeName.trim().isNotEmpty && e.instituteName.trim().isNotEmpty);
    bool hasEduInControllers = _eduDegreeController.text.trim().isNotEmpty && _eduInstController.text.trim().isNotEmpty;

    if (!hasEduInList && !hasEduInControllers) {
      errors.add('Highest Degree / Course Name and Institute Name are required');
    }

    bool hasCertDoc = _documentList.any((doc) =>
        doc.documentType.toLowerCase().contains('degree') ||
        doc.documentType.toLowerCase().contains('education') ||
        doc.documentType.toLowerCase().contains('mark') ||
        doc.documentType.toLowerCase().contains('certificate')) ||
        _educationList.any((e) => e.certificateName.isNotEmpty && e.certificateName != 'No file chosen');
    if (!hasCertDoc && !hasEduInList) {
      errors.add('Highest Degree Certificate file upload is required');
    }
    return errors;
  }

  List<String> _validateExperienceTab() {
    final errors = <String>[];
    for (int i = 0; i < _experienceList.length; i++) {
      final exp = _experienceList[i];
      if (exp.companyName.trim().isEmpty) {
        errors.add('Experience #${i + 1}: Previous Company Name is required');
      }
      if (exp.position.trim().isEmpty) {
        errors.add('Experience #${i + 1}: Designation is required');
      }
    }
    return errors;
  }

  List<String> _validateHistoryTab() {
    final errors = <String>[];
    final pan = _panController.text.trim().toUpperCase();
    if (pan.isEmpty) {
      errors.add('PAN Number is required');
    } else if (pan.length != 10 || !RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$').hasMatch(pan)) {
      errors.add('PAN Number must be valid 10 characters (e.g. ABCDE1234F)');
    }

    final personalMobile = _personalMobileController.text.trim();
    if (personalMobile.isNotEmpty) {
      final phoneDetails = getCountryPhoneDetails(_personalMobileCountryCode);
      final expectedDigits = phoneDetails['digits'] as int? ?? 10;
      if (!RegExp(r'^\d+$').hasMatch(personalMobile)) {
        errors.add('Personal Mobile Number must contain only digits (0-9)');
      } else if (personalMobile.length != expectedDigits) {
        errors.add('Personal Mobile Number must be exactly $expectedDigits digits for $_personalMobileCountryCode');
      }
    }

    final passport = _passportController.text.trim().toUpperCase();
    if (passport.isNotEmpty) {
      if (passport.length < 8 || passport.length > 9 || !RegExp(r'^[A-Z0-9]{8,9}$').hasMatch(passport)) {
        errors.add('Passport Number must be 8 or 9 alphanumeric characters');
      }
    }

    final dl = _drivingLicenseController.text.trim().toUpperCase();
    if (dl.isNotEmpty) {
      if (dl.length < 10 || dl.length > 16 || !RegExp(r'^[A-Z0-9 \-]{10,16}$').hasMatch(dl)) {
        errors.add('Driving License must be 10 to 16 alphanumeric characters');
      }
    }

    final emergencyName = _emergencyNameController.text.trim();
    if (emergencyName.isEmpty) {
      errors.add('Emergency Contact Person Name is required');
    } else if (RegExp(r'[0-9]').hasMatch(emergencyName)) {
      errors.add('Emergency Contact Person Name cannot contain numbers');
    }

    final emergencyMobile = _emergencyMobileController.text.trim();
    final emergencyPhoneDetails = getCountryPhoneDetails(_emergencyMobileCountryCode);
    final expectedEmergencyDigits = emergencyPhoneDetails['digits'] as int? ?? 10;
    if (emergencyMobile.isEmpty) {
      errors.add('Emergency Contact Mobile Number is required');
    } else if (!RegExp(r'^\d+$').hasMatch(emergencyMobile)) {
      errors.add('Emergency Contact Mobile Number must contain only digits (0-9)');
    } else if (emergencyMobile.length != expectedEmergencyDigits) {
      errors.add('Emergency Contact Mobile Number must be exactly $expectedEmergencyDigits digits for $_emergencyMobileCountryCode');
    }

    final refMobile = _referredByMobileController.text.trim();
    if (refMobile.isNotEmpty) {
      final refPhoneDetails = getCountryPhoneDetails(_referredByMobileCountryCode);
      final expectedRefDigits = refPhoneDetails['digits'] as int? ?? 10;
      if (!RegExp(r'^\d+$').hasMatch(refMobile)) {
        errors.add('Referred By Mobile Number must contain only digits (0-9)');
      } else if (refMobile.length != expectedRefDigits) {
        errors.add('Referred By Mobile Number must be exactly $expectedRefDigits digits for $_referredByMobileCountryCode');
      }
    }

    final fatherName = _fatherNameController.text.trim();
    if (fatherName.isNotEmpty && RegExp(r'[0-9]').hasMatch(fatherName)) {
      errors.add("Father's Name cannot contain numbers");
    }

    final motherName = _motherNameController.text.trim();
    if (motherName.isNotEmpty && RegExp(r'[0-9]').hasMatch(motherName)) {
      errors.add("Mother's Name cannot contain numbers");
    }

    final spouseName = _spouseNameController.text.trim();
    if (spouseName.isNotEmpty && RegExp(r'[0-9]').hasMatch(spouseName)) {
      errors.add("Spouse's Name cannot contain numbers");
    }

    if (_hasCriminalCases && _criminalCaseDetailsController.text.trim().isEmpty) {
      errors.add('Criminal Case Details are required when declaration is Yes');
    }
    return errors;
  }

  List<String> _validateBankAccountTab() {
    final errors = <String>[];
    final bankHolder = _bankHolderController.text.trim();
    if (bankHolder.isEmpty) {
      errors.add('Account Holder Name is required');
    } else if (RegExp(r'[0-9]').hasMatch(bankHolder)) {
      errors.add('Account Holder Name cannot contain numbers');
    }

    if (_bankNameController.text.trim().isEmpty) {
      errors.add('Bank Name is required');
    }

    final bankAccNum = _bankAccNumController.text.trim();
    if (bankAccNum.isEmpty) {
      errors.add('Account Number is required');
    } else if (!RegExp(r'^\d+$').hasMatch(bankAccNum)) {
      errors.add('Account Number must contain only digits (0-9)');
    } else if (bankAccNum.length < 9 || bankAccNum.length > 18) {
      errors.add('Account Number must be between 9 and 18 digits');
    }

    final ifsc = _bankIfscController.text.trim().toUpperCase();
    if (ifsc.isEmpty) {
      errors.add('IFSC Code is required');
    } else if (ifsc.length != 11 || !RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(ifsc)) {
      errors.add('IFSC Code must be valid 11 characters (e.g. SBIN0001234)');
    }

    if (_bankAccountType.trim().isEmpty) {
      errors.add('Account Type is required');
    }
    return errors;
  }

  List<String> _validateDocumentTab() {
    final errors = <String>[];
    bool hasAadhaarDoc = _documentList.any((d) =>
        d.documentType.toLowerCase().contains('aadhaar') ||
        d.documentType.toLowerCase().contains('government id') ||
        d.documentType.toLowerCase().contains('gov') ||
        d.documentType.toLowerCase().contains('aadhar')) ||
        _aadhaarController.text.trim().isNotEmpty;

    if (!hasAadhaarDoc) {
      errors.add('Aadhaar Card / Government ID copy upload is required');
    }
    return errors;
  }

  List<String> _validateSocialMediaTab() {
    return [];
  }

  List<String> _validateJobAdminDetailsTab() {
    final errors = <String>[];
    if (_isManagementAdd) {
      if (_organizationName.trim().isEmpty) {
        errors.add('Organization is required');
      }
      if (_department.trim().isEmpty) {
        errors.add('Department is required');
      }
      if (_designation.trim().isEmpty) {
        errors.add('Designation is required');
      }
      if (_joiningDateController.text.trim().isEmpty) {
        errors.add('Date of Joining is required');
      }
      final coordPhone = _coordinatorPhoneController.text.trim();
      if (coordPhone.isNotEmpty) {
        final coordPhoneDetails = getCountryPhoneDetails(_coordinatorPhoneCountryCode);
        final expectedDigits = coordPhoneDetails['digits'] as int? ?? 10;
        if (!RegExp(r'^\d+$').hasMatch(coordPhone)) {
          errors.add('Coordinator Phone must contain only digits');
        } else if (coordPhone.length != expectedDigits) {
          errors.add('Coordinator Phone must be exactly $expectedDigits digits');
        }
      }
    }
    return errors;
  }

  List<String> _validateSalaryOfferLetterTab() {
    final errors = <String>[];
    if (_isManagementAdd) {
      final total = double.tryParse(_totalSalaryController.text.replaceAll(',', '').trim()) ?? 0.0;
      if (total > 0) {
        final additionsTotal = _getAdditionsTotal();
        final excess = additionsTotal - total;
        if (excess > 0.01) {
          errors.add('Total additions (\u20B9${additionsTotal.toStringAsFixed(2)}) exceed Total Salary CTC (\u20B9${total.toStringAsFixed(2)})');
        }
      }
    }
    return errors;
  }

  List<String> _validateCredentialsTab() {
    final errors = <String>[];
    if (_isManagementAdd && !_isEditing && widget.acceptedEmpId == null) {
      if (_passwordController.text.trim().isEmpty) {
        errors.add('Temporary Password is required for employee account creation');
      }
    }
    return errors;
  }

  List<String> _validateTabByName(String tabName) {
    switch (tabName) {
      case 'Personal Info':
        return _validatePersonalInfoTab();
      case 'Address':
        return _validateAddressTab();
      case 'Education':
        return _validateEducationTab();
      case 'Experience':
        return _validateExperienceTab();
      case 'History':
        return _validateHistoryTab();
      case 'Bank Account':
        return _validateBankAccountTab();
      case 'Document':
        return _validateDocumentTab();
      case 'Social Media':
        return _validateSocialMediaTab();
      case 'Job & Admin Details':
        return _validateJobAdminDetailsTab();
      case 'Salary & Offer Letter':
        return _validateSalaryOfferLetterTab();
      case 'Credentials':
        return _validateCredentialsTab();
      default:
        return [];
    }
  }

  Map<String, List<String>> _getAllCandidateFormErrors() {
    final result = <String, List<String>>{};
    final candidateTabs = [
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
      if (_isManagementAdd) 'Credentials',
    ];
    for (final tab in candidateTabs) {
      final errs = _validateTabByName(tab);
      if (errs.isNotEmpty) {
        result[tab] = errs;
      }
    }
    return result;
  }

  void _showSubmissionErrorSummaryDialog(Map<String, List<String>> errorsByTab) {
    showDialog(
      context: context,
      builder: (context) {
        final isMobile = MediaQuery.of(context).size.width < 600;
        final totalErrors = errorsByTab.values.fold(0, (prev, element) => prev + element.length);

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Container(
            width: isMobile ? double.infinity : 600,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF3F2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFD92D20), size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Action Required: Complete Registration Details',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF101828),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$totalErrors required item${totalErrors > 1 ? "s" : ""} across ${errorsByTab.length} tab${errorsByTab.length > 1 ? "s" : ""} must be completed before submission.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF667085),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: errorsByTab.entries.map((entry) {
                        final tabName = entry.key;
                        final errorList = entry.value;
                        final tabIndex = _tabs.indexOf(tabName);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF5F5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFDA29B)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.tab, size: 16, color: Color(0xFFD92D20)),
                                      const SizedBox(width: 6),
                                      Text(
                                        tabName,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFB42318),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (tabIndex >= 0)
                                    InkWell(
                                      onTap: () {
                                        Navigator.of(context).pop();
                                        _tabController.animateTo(tabIndex);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.active,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Go to Tab',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ...errorList.map((err) => Padding(
                                padding: const EdgeInsets.only(left: 4, top: 3),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• ', style: TextStyle(color: Color(0xFFD92D20), fontWeight: FontWeight.bold)),
                                    Expanded(
                                      child: Text(
                                        err,
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF475467)),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        side: const BorderSide(color: Color(0xFFD0D5DD)),
                      ),
                      child: const Text('Review and Correct', style: TextStyle(color: Color(0xFF344054), fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _snapshotSavedTexts() {
    final controllers = [
      _firstNameController, _lastNameController, _dobController, _aadhaarController,
      _phoneController, _emailController, _pfNumberController, _esiNumberController,
      _permAddressController, _permCityController, _permCountryController,
      _presAddressController, _presCityController, _presCountryController,
      _originalDobController, _personalMobileController, _panController, _passportController,
      _drivingLicenseController, _healthIssuesController, _emergencyNameController,
      _emergencyMobileController, _referredByNameController, _referredByMobileController,
      _fatherNameController, _motherNameController, _spouseNameController,
      _kids1NameController, _kids2NameController, _kids3NameController,
      _criminalCaseDetailsController,
      _bankHolderController, _bankNameController, _bankAccNumController,
      _bankIfscController, _bankBranchController,
      _facebookController, _twitterController, _linkedinController, _googleController,
      _joiningDateController, _contractEndDateController, _reportingToController,
      _reportingManagerTitleController, _adminNameController, _coordinatorNameController,
      _coordinatorPhoneController, _weeklyOffDayController, _inTimeController,
      _outTimeController, _allowedLeavesController,
      _monthlyPermissionLimitController, _dailyPermissionLimitController,
      _totalSalaryController, _basicPayController, _hraController, _specialAllowanceController,
      _eduAllowanceController, _travelAllowanceController, _otherAllowanceController,
      _pfController, _esiController, _professionalTaxController, _tdsController,
      _employeeCustomIdController, _passwordController,
    ];
    for (final c in controllers) {
      _savedControllerTexts[c] = c.text;
    }
  }

  void _markTabUnsaved(String tab) {
    if (_isPopulating) return;
    if (_savedTabs.contains(tab)) {
      setState(() {
        _savedTabs.remove(tab);
      });
    }
  }

  void _attachControllerListeners() {
    _snapshotSavedTexts();
    void addListenerTo(TextEditingController controller, String tabName) {
      _savedControllerTexts[controller] = controller.text;
      controller.addListener(() {
        if (!_isPopulating && _savedTabs.contains(tabName)) {
          final lastSavedText = _savedControllerTexts[controller] ?? '';
          if (controller.text != lastSavedText) {
            _markTabUnsaved(tabName);
          }
        }
      });
    }

    // Personal Info Tab
    addListenerTo(_firstNameController, 'Personal Info');
    addListenerTo(_lastNameController, 'Personal Info');
    addListenerTo(_dobController, 'Personal Info');
    addListenerTo(_aadhaarController, 'Personal Info');
    addListenerTo(_phoneController, 'Personal Info');
    addListenerTo(_emailController, 'Personal Info');
    addListenerTo(_pfNumberController, 'Personal Info');
    addListenerTo(_esiNumberController, 'Personal Info');

    // Address Tab
    addListenerTo(_permAddressController, 'Address');
    addListenerTo(_permCityController, 'Address');
    addListenerTo(_permCountryController, 'Address');
    addListenerTo(_presAddressController, 'Address');
    addListenerTo(_presCityController, 'Address');
    addListenerTo(_presCountryController, 'Address');

    // History Tab
    addListenerTo(_originalDobController, 'History');
    addListenerTo(_personalMobileController, 'History');
    addListenerTo(_panController, 'History');
    addListenerTo(_passportController, 'History');
    addListenerTo(_drivingLicenseController, 'History');
    addListenerTo(_healthIssuesController, 'History');
    addListenerTo(_emergencyNameController, 'History');
    addListenerTo(_emergencyMobileController, 'History');
    addListenerTo(_referredByNameController, 'History');
    addListenerTo(_referredByMobileController, 'History');
    addListenerTo(_fatherNameController, 'History');
    addListenerTo(_motherNameController, 'History');
    addListenerTo(_spouseNameController, 'History');
    addListenerTo(_kids1NameController, 'History');
    addListenerTo(_kids2NameController, 'History');
    addListenerTo(_kids3NameController, 'History');
    addListenerTo(_criminalCaseDetailsController, 'History');

    // Bank Account Tab
    addListenerTo(_bankHolderController, 'Bank Account');
    addListenerTo(_bankNameController, 'Bank Account');
    addListenerTo(_bankAccNumController, 'Bank Account');
    addListenerTo(_bankIfscController, 'Bank Account');
    addListenerTo(_bankBranchController, 'Bank Account');

    // Social Media Tab
    addListenerTo(_facebookController, 'Social Media');
    addListenerTo(_twitterController, 'Social Media');
    addListenerTo(_linkedinController, 'Social Media');
    addListenerTo(_googleController, 'Social Media');

    // Job & Admin Details Tab
    addListenerTo(_joiningDateController, 'Job & Admin Details');
    addListenerTo(_contractEndDateController, 'Job & Admin Details');
    addListenerTo(_reportingToController, 'Job & Admin Details');
    addListenerTo(_reportingManagerTitleController, 'Job & Admin Details');
    addListenerTo(_adminNameController, 'Job & Admin Details');
    addListenerTo(_coordinatorNameController, 'Job & Admin Details');
    addListenerTo(_coordinatorPhoneController, 'Job & Admin Details');
    addListenerTo(_weeklyOffDayController, 'Job & Admin Details');
    addListenerTo(_inTimeController, 'Job & Admin Details');
    addListenerTo(_outTimeController, 'Job & Admin Details');
    addListenerTo(_requiredWorkingHoursController, 'Job & Admin Details');
    addListenerTo(_allowedLeavesController, 'Job & Admin Details');
    addListenerTo(_monthlyPermissionLimitController, 'Job & Admin Details');
    addListenerTo(_dailyPermissionLimitController, 'Job & Admin Details');

    // Salary Details Tab
    addListenerTo(_totalSalaryController, 'Salary & Offer Letter');
    addListenerTo(_basicPayController, 'Salary & Offer Letter');
    addListenerTo(_hraController, 'Salary & Offer Letter');
    addListenerTo(_specialAllowanceController, 'Salary & Offer Letter');
    addListenerTo(_eduAllowanceController, 'Salary & Offer Letter');
    addListenerTo(_travelAllowanceController, 'Salary & Offer Letter');
    addListenerTo(_otherAllowanceController, 'Salary & Offer Letter');
    addListenerTo(_pfController, 'Salary & Offer Letter');
    addListenerTo(_esiController, 'Salary & Offer Letter');
    addListenerTo(_professionalTaxController, 'Salary & Offer Letter');
    addListenerTo(_tdsController, 'Salary & Offer Letter');

    // Credentials Tab
    addListenerTo(_employeeCustomIdController, 'Credentials');
    addListenerTo(_passwordController, 'Credentials');
  }

  (String, String) _parsePhoneAndCountryCode(String fullPhone) {
    final trimmed = fullPhone.trim();
    if (trimmed.isEmpty) return ('+91', '');
    
    // Sort codes by length descending so longer codes match first
    final sortedCodes = allWorldCountryCodes.map((e) => e['code']!).toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final code in sortedCodes) {
      if (trimmed.startsWith(code)) {
        return (code, trimmed.substring(code.length).trim());
      }
    }
    if (trimmed.startsWith('+')) {
      final spaceIdx = trimmed.indexOf(' ');
      if (spaceIdx > 0) {
        return (trimmed.substring(0, spaceIdx), trimmed.substring(spaceIdx + 1).trim());
      }
    }
    return ('+91', trimmed);
  }

  String _formatPhoneWithCountryCode(String countryCode, String phoneDigits) {
    final digits = phoneDigits.trim();
    if (digits.isEmpty) return '';
    if (digits.startsWith('+')) return digits;
    return '$countryCode $digits';
  }

  Employee? _findMatchingEmployee(RegistrationLink link, List<Employee> employees) {
    if (link.employeeId.isNotEmpty) {
      for (final emp in employees) {
        if (emp.employeeId == link.employeeId || emp.id.toString() == link.employeeId) {
          return emp;
        }
      }
    }
    if (link.linkId.isNotEmpty) {
      for (final emp in employees) {
        if (emp.employeeId == link.linkId || emp.id.toString() == link.linkId) {
          return emp;
        }
      }
    }
    if (link.employeeName.trim().isNotEmpty) {
      final targetName = link.employeeName.trim().toLowerCase();
      for (final emp in employees) {
        final empFullName = emp.fullName.trim().toLowerCase();
        final empFirstName = emp.firstName.trim().toLowerCase();
        if (empFullName == targetName || empFirstName == targetName) {
          return emp;
        }
      }
    }
    if (link.employeeName.trim().isNotEmpty) {
      final targetName = link.employeeName.trim().toLowerCase();
      for (final emp in employees) {
        final empFullName = emp.fullName.trim().toLowerCase();
        if (empFullName.isNotEmpty && (empFullName.contains(targetName) || targetName.contains(empFullName))) {
          return emp;
        }
      }
    }
    return null;
  }

  void _populateFromEmployee(Employee emp) {
    _isPopulating = true;
    setState(() {
      _currentEmployee = emp;
      _firstNameController.text = emp.firstName;
      _lastNameController.text = emp.lastName;
      if (emp.bloodGroup.isNotEmpty) _bloodGroup = emp.bloodGroup;
      if (emp.bloodGroupReport.isNotEmpty) _bloodGroupDocFileName = emp.bloodGroupReport;
      if (emp.gender.isNotEmpty) _gender = emp.gender;
      if (emp.userType.isNotEmpty) _userType = emp.userType;
      if (emp.status.isNotEmpty) _status = emp.status;
      _dobController.text = emp.dob;
      _aadhaarController.text = emp.aadhaarNumber;
      final (phoneCc, phoneNum) = _parsePhoneAndCountryCode(emp.phoneNumber);
      _phoneCountryCode = phoneCc;
      _phoneController.text = phoneNum;
      if (emp.organizationName.isNotEmpty) _organizationName = emp.organizationName;
      if (emp.businessUnit.isNotEmpty) _businessUnit = emp.businessUnit;
      if (emp.workLocation.isNotEmpty) _workLocation = emp.workLocation;
      if (emp.department.isNotEmpty) _department = emp.department;
      if (emp.designation.isNotEmpty) _designation = emp.designation;
      _joiningDateController.text = emp.joiningDate;
      _contractEndDateController.text = emp.contractEndDate;
      _emailController.text = emp.emailAddress;
      _pfNumberController.text = emp.pfNumber;
      _esiNumberController.text = emp.esiNumber;
      _inTimeController.text = emp.inTime;
      _outTimeController.text = emp.outTime;
      _weeklyOffDayController.text = emp.weeklyOffDay;
      if (emp.isDynamicEmployee || (emp.inTime.isEmpty && emp.outTime.isEmpty && !emp.isStaticEmployee)) {
        _workScheduleType = 'Flexible Schedule';
      } else {
        _workScheduleType = 'Fixed Schedule';
      }
      _requiredWorkingHoursController.text = '${emp.requiredWorkingHours > 0 ? emp.requiredWorkingHours.toStringAsFixed(0) : "9"} Hours';
      _reportingManagerTitleController.text = emp.reportingManagerTitle.isNotEmpty ? emp.reportingManagerTitle : 'Managing Director';
      _adminNameController.text = emp.adminName.isNotEmpty ? emp.adminName : 'Saravanan G S';
      _coordinatorNameController.text = emp.coordinatorName.isNotEmpty ? emp.coordinatorName : 'Admin Team';
      final (coordCc, coordNum) = _parsePhoneAndCountryCode(emp.coordinatorPhone.isNotEmpty ? emp.coordinatorPhone : '8760098789');
      _coordinatorPhoneCountryCode = coordCc;
      _coordinatorPhoneController.text = coordNum;
      if (emp.reportingManager.isNotEmpty) _reportingToController.text = emp.reportingManager;
      if (emp.leaveType.isNotEmpty) {
        _leaveType = emp.leaveType == 'Once a Month' ? 'Manual Allocation' : emp.leaveType;
      }
      _leaveAllocationFrequency = emp.leaveAllocationFrequency.isEmpty ? 'Monthly' : emp.leaveAllocationFrequency;
      _allowedLeavesController.text = emp.allowedLeaves.toString();
      _monthlyPermissionLimitController.text = emp.monthlyPermissionLimitHours > 0 ? emp.monthlyPermissionLimitHours.toString() : '3.0';
      _dailyPermissionLimitController.text = emp.dailyPermissionLimitHours > 0 ? emp.dailyPermissionLimitHours.toString() : '1.0';
      _leaveEffectiveDateController.text = emp.effectiveDate;

      _siteLatitudeController.text = emp.siteLatitude != 0 ? emp.siteLatitude.toStringAsFixed(6) : '';
      _siteLongitudeController.text = emp.siteLongitude != 0 ? emp.siteLongitude.toStringAsFixed(6) : '';
      _siteRadiusController.text = emp.siteAllowedRadiusMeters.toString();
      _siteRequireGpsVerification = emp.siteRequireGpsVerification;

      _permAddressController.text = emp.permanentAddress;
      _permCityController.text = emp.permanentCity;
      if (emp.permanentCountry.isNotEmpty) _permCountryController.text = emp.permanentCountry;
      _sameAsPermanent = emp.sameAsPermanent;
      _presAddressController.text = emp.presentAddress;
      _presCityController.text = emp.presentCity;
      if (emp.presentCountry.isNotEmpty) _presCountryController.text = emp.presentCountry;

      _originalDobController.text = emp.originalDob;
      final (personalCc, personalNum) = _parsePhoneAndCountryCode(emp.personalMobile);
      _personalMobileCountryCode = personalCc;
      _personalMobileController.text = personalNum;
      _panController.text = emp.panNumber;
      _passportController.text = emp.passportNumber;
      _drivingLicenseController.text = emp.drivingLicenseNumber;
      _healthIssuesController.text = emp.healthIssues;
      _emergencyNameController.text = emp.emergencyName;
      final (emergencyCc, emergencyNum) = _parsePhoneAndCountryCode(emp.emergencyMobile);
      _emergencyMobileCountryCode = emergencyCc;
      _emergencyMobileController.text = emergencyNum;
      _referredByNameController.text = emp.referredByName;
      final (refCc, refNum) = _parsePhoneAndCountryCode(emp.referredByMobile);
      _referredByMobileCountryCode = refCc;
      _referredByMobileController.text = refNum;
      _fatherNameController.text = emp.fatherName;
      _motherNameController.text = emp.motherName;
      if (emp.maritalStatus.isNotEmpty) _maritalStatus = emp.maritalStatus;
      _spouseNameController.text = emp.spouseName;
      _kids1NameController.text = emp.kids1Name;
      _kids2NameController.text = emp.kids2Name;
      _kids3NameController.text = emp.kids3Name;
      _hasCriminalCases = emp.hasCriminalCases;
      _criminalCaseDetailsController.text = emp.criminalCaseDetails;

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
        _selectedFileName = emp.profileImagePublicId.isNotEmpty
            ? '${emp.profileImagePublicId}.jpg'
            : 'profile_image.jpg';
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

      final total = emp.salaryTotalCtc;
      final basic = emp.salaryBasic > 0 ? emp.salaryBasic : (total > 0 ? total * 0.5 : 0.0);
      final hra = emp.salaryHra > 0 ? emp.salaryHra : (total > 0 ? total * 0.2 : 0.0);
      final special = emp.salarySpecialAllowance > 0 ? emp.salarySpecialAllowance : (total > 0 ? total * 0.3 : 0.0);
      final edu = emp.salaryEducationAllowance;
      final travel = emp.salaryTravelAllowance;
      final other = emp.salaryOtherAllowance;
      final pf = emp.salaryPf > 0 ? emp.salaryPf : (basic > 0 ? basic * 0.12 : 0.0);
      final esi = emp.salaryEsi > 0 ? emp.salaryEsi : (total <= 21000 && basic > 0 ? basic * 0.0075 : 0.0);
      final esiEmployer = emp.salaryEsiEmployer > 0 ? emp.salaryEsiEmployer : (total <= 21000 && total > 0 ? total * 0.0325 : 0.0);
      final pt = emp.salaryProfessionalTax;
      final tds = emp.salaryTax;

      if (basic > 0) _basicPayController.text = basic.toStringAsFixed(2);
      if (hra > 0) _hraController.text = hra.toStringAsFixed(2);
      if (special > 0) _specialAllowanceController.text = special.toStringAsFixed(2);
      if (edu > 0) _eduAllowanceController.text = edu.toStringAsFixed(2);
      if (travel > 0) _travelAllowanceController.text = travel.toStringAsFixed(2);
      if (other > 0) _otherAllowanceController.text = other.toStringAsFixed(2);
      if (pf > 0) _pfController.text = pf.toStringAsFixed(2);
      if (esi > 0) _esiController.text = esi.toStringAsFixed(2);
      if (esiEmployer > 0) _esiEmployerController.text = esiEmployer.toStringAsFixed(2);
      if (pt > 0) _professionalTaxController.text = pt.toStringAsFixed(2);
      if (tds > 0) _tdsController.text = tds.toStringAsFixed(2);

      if (total > 0) {
        _basicPercentController.text = ((basic / total) * 100).toStringAsFixed(1);
        _hraPercentController.text = ((hra / total) * 100).toStringAsFixed(1);
        _specialAllowancePercentController.text = ((special / total) * 100).toStringAsFixed(1);
        _eduAllowancePercentController.text = ((edu / total) * 100).toStringAsFixed(1);
        _travelAllowancePercentController.text = ((travel / total) * 100).toStringAsFixed(1);
        _otherAllowancePercentController.text = ((other / total) * 100).toStringAsFixed(1);
        if (total <= 21000) {
          _esiPercentController.text = basic > 0 ? ((esi / basic) * 100).toStringAsFixed(1) : '0.0';
          _esiEmployerPercentController.text = ((esiEmployer / total) * 100).toStringAsFixed(1);
        } else {
          _esiController.text = '';
          _esiEmployerController.text = '';
        }
        _professionalTaxPercentController.text = ((pt / total) * 100).toStringAsFixed(1);
        _tdsPercentController.text = ((tds / total) * 100).toStringAsFixed(1);
      }
      if (basic > 0) {
        _pfPercentController.text = ((pf / basic) * 100).toStringAsFixed(1);
      }
      _salaryPercentagesInitialized = true;

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

      _updateSavedTabsFromData();
    });
  }

  void _updateSavedTabsFromData() {
    _isPopulating = true;
    // If loading an existing saved employee, mark all populated tabs as saved in draft history
    if (_firstNameController.text.isNotEmpty || _phoneController.text.isNotEmpty || _emailController.text.isNotEmpty) _savedTabs.add('Personal Info');
    if (_permAddressController.text.isNotEmpty || _presAddressController.text.isNotEmpty || _permCityController.text.isNotEmpty) _savedTabs.add('Address');
    if (_educationList.isNotEmpty || _eduDegreeController.text.isNotEmpty) _savedTabs.add('Education');
    if (_experienceList.isNotEmpty || _expCompanyController.text.isNotEmpty) _savedTabs.add('Experience');
    if (_fatherNameController.text.isNotEmpty || _motherNameController.text.isNotEmpty || _panController.text.isNotEmpty || _personalMobileController.text.isNotEmpty) _savedTabs.add('History');
    if (_bankAccNumController.text.isNotEmpty || _bankNameController.text.isNotEmpty || _bankIfscController.text.isNotEmpty) _savedTabs.add('Bank Account');
    if (_documentList.isNotEmpty || _docNumberController.text.isNotEmpty) _savedTabs.add('Document');
    if (_facebookController.text.isNotEmpty || _twitterController.text.isNotEmpty || _linkedinController.text.isNotEmpty || _googleController.text.isNotEmpty) _savedTabs.add('Social Media');
    if (_joiningDateController.text.isNotEmpty) _savedTabs.add('Job & Admin Details');
    if (_totalSalaryController.text.isNotEmpty || _basicPayController.text.isNotEmpty) _savedTabs.add('Salary & Offer Letter');
  }

  bool _isTabSaved(String tab) {
    return _savedTabs.contains(tab);
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
    _attachControllerListeners();
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
    } else if (widget.acceptedLinkId != null && widget.acceptedLinkId!.isNotEmpty) {
      _registrationMode = 'accepted_response';
      _selectedAcceptedLinkId = widget.acceptedLinkId;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        ref.invalidate(allEmployeesProvider);
        ref.invalidate(registrationLinksProvider);
        ref.invalidate(candidateResponsesProvider);
        final repo = ref.read(employeeRepositoryProvider);

        final candidateResponse = await repo.getCandidateResponseByLinkId(widget.acceptedLinkId!) ??
            await repo.getCandidateResponseByCandidateId(widget.acceptedLinkId!);

        if (candidateResponse != null && mounted) {
          _populateFromEmployee(candidateResponse.employeeData);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Auto-fetched candidate details for ${candidateResponse.employeeData.fullName}. Complete details to finalize registration.'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          final links = await ref.read(registrationLinksProvider.future);
          final allEmps = await ref.read(allEmployeesProvider.future);
          final matchingLinks = links.where((l) => l.linkId == widget.acceptedLinkId).toList();
          if (matchingLinks.isNotEmpty && mounted) {
            final link = matchingLinks.first;
            final matchedEmployee = _findMatchingEmployee(link, allEmps);
            if (matchedEmployee != null) {
              _selectedAcceptedEmpId = matchedEmployee.id;
              _populateFromEmployee(matchedEmployee);
            } else if (link.employeeName.isNotEmpty) {
              final nameParts = link.employeeName.trim().split(RegExp(r'\s+'));
              if (nameParts.length > 1) {
                _firstNameController.text = nameParts.first;
                _lastNameController.text = nameParts.sublist(1).join(' ');
              } else {
                _firstNameController.text = link.employeeName;
              }
              _status = 'ACTIVE';
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Auto-fetched candidate details for ${matchedEmployee?.fullName.isNotEmpty == true ? matchedEmployee!.fullName : (link.employeeName.isNotEmpty ? link.employeeName : link.linkId)}. Complete details to finalize registration.'),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      });
    } else if (widget.acceptedEmpId != null) {
      _registrationMode = 'accepted_response';
      _selectedAcceptedEmpId = widget.acceptedEmpId;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        ref.invalidate(allEmployeesProvider);
        final emps = await ref.read(allEmployeesProvider.future);
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
    } else if (widget.linkId.isNotEmpty && widget.linkId != 'new' && widget.linkId != 'edit') {
      _registrationMode = 'candidate';
      _selectedAcceptedLinkId = null;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        ref.invalidate(allEmployeesProvider);
        ref.invalidate(registrationLinksProvider);
        ref.invalidate(candidateResponsesProvider);
        final repo = ref.read(employeeRepositoryProvider);

        final candidateResponse = await repo.getCandidateResponseByLinkId(widget.linkId) ??
            await repo.getCandidateResponseByCandidateId(widget.linkId);

        if (candidateResponse != null && mounted) {
          _populateFromEmployee(candidateResponse.employeeData);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Auto-fetched candidate details for ${candidateResponse.employeeData.fullName}. Complete details to finalize registration.'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          final links = await ref.read(registrationLinksProvider.future);
          final allEmps = await ref.read(allEmployeesProvider.future);
          final matchingLinks = links.where((l) => l.linkId == widget.linkId).toList();
          if (matchingLinks.isNotEmpty && mounted) {
            final link = matchingLinks.first;
            final matchedEmployee = _findMatchingEmployee(link, allEmps);
            if (matchedEmployee != null) {
              _selectedAcceptedEmpId = matchedEmployee.id;
              _populateFromEmployee(matchedEmployee);
            } else if (link.employeeName.isNotEmpty) {
              if (_firstNameController.text.isEmpty) {
                final nameParts = link.employeeName.trim().split(RegExp(r'\s+'));
                if (nameParts.length > 1) {
                  _firstNameController.text = nameParts.first;
                  _lastNameController.text = nameParts.sublist(1).join(' ');
                } else {
                  _firstNameController.text = link.employeeName;
                }
              }
              _status = 'ACTIVE';
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Auto-fetched candidate details for ${matchedEmployee?.fullName.isNotEmpty == true ? matchedEmployee!.fullName : (link.employeeName.isNotEmpty ? link.employeeName : link.linkId)}. Complete details to finalize registration.'),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
              ),
            );
          }
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
    _reportingToController.dispose();
    _inTimeController.dispose();
    _outTimeController.dispose();
    _weeklyOffDayController.dispose();
    _requiredWorkingHoursController.dispose();
    _monthlyPermissionLimitController.dispose();
    _dailyPermissionLimitController.dispose();
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
    _criminalCaseDetailsController.dispose();
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
    _otherAllowanceController.dispose();
    _pfController.dispose();
    _esiController.dispose();
    _esiEmployerController.dispose();
    _professionalTaxController.dispose();
    _tdsController.dispose();
    _basicPercentController.dispose();
    _hraPercentController.dispose();
    _specialAllowancePercentController.dispose();
    _eduAllowancePercentController.dispose();
    _travelAllowancePercentController.dispose();
    _otherAllowancePercentController.dispose();
    _pfPercentController.dispose();
    _esiPercentController.dispose();
    _esiEmployerPercentController.dispose();
    _professionalTaxPercentController.dispose();
    _tdsPercentController.dispose();
    _employeeCustomIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(TextEditingController controller, {String? tabName}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final formatted = '${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}';
      controller.text = formatted;
      if (tabName != null) {
        _markTabUnsaved(tabName);
      }
    }
  }



  void _removeProfileImage() {
    setState(() {
      _profileImageBytes = null;
      _profileImageDataUrl = '';
      _selectedFileName = 'No file chosen';
      _isProfileImageRemoved = true;
    });
  }

  Future<void> _pickBloodGroupDocFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );
      final file = result?.files.isNotEmpty == true ? result!.files.first : null;
      if (file == null) return;
      setState(() {
        _bloodGroupDocFileName = file.name;
      });
      _markTabUnsaved('Personal Info');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to select file: $e')),
        );
      }
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
        _isProfileImageRemoved = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image selection failed: $e')),
      );
    }
  }

  Future<void> _submitForm(RegistrationLink? link, {bool isSubmit = true}) async {
    final isEditMode = widget.employee != null || widget.linkId == 'edit' || (_currentEmployee != null && _currentEmployee!.employeeId.startsWith('EMP-'));

    if (isSubmit) {
      setState(() {
        _hasSubmittedAtLeastOnce = true;
      });

      final candidateErrors = _getAllCandidateFormErrors();
      if (candidateErrors.isNotEmpty) {
        _showSubmissionErrorSummaryDialog(candidateErrors);
        return;
      }

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

      if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
        _tabController.animateTo(0);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill mandatory fields marked with * and correct invalid format errors.'),
            backgroundColor: Colors.orange,
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



    if (isSubmit) {
      setState(() => _isSubmitting = true);
    } else {
      setState(() => _isDraftSaving = true);
    }

    try {
      final repo = ref.read(employeeRepositoryProvider);
      final resolvedEmployeeId = _employeeCustomIdController.text.trim().isNotEmpty
          ? _employeeCustomIdController.text.trim()
          : ((isSubmit && (_currentEmployee?.employeeId.startsWith('EMP-') == true))
              ? _currentEmployee!.employeeId
              : ((isSubmit && (widget.employee?.employeeId.startsWith('EMP-') == true))
                  ? widget.employee!.employeeId
                  : (isSubmit ? '' : 'pending_${DateTime.now().millisecondsSinceEpoch}')));

      String profileImageUrl = _isProfileImageRemoved
          ? ''
          : (_profileImageDataUrl.isNotEmpty
              ? _profileImageDataUrl
              : (_currentEmployee?.profileImageUrl ?? widget.employee?.profileImageUrl ?? ''));
      String profileImagePublicId = _isProfileImageRemoved
          ? ''
          : (_currentEmployee?.profileImagePublicId ?? widget.employee?.profileImagePublicId ?? '');
      String profileImageFolder = _isProfileImageRemoved
          ? ''
          : (_currentEmployee?.profileImageFolder ?? widget.employee?.profileImageFolder ?? '');

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
        phoneNumber: _formatPhoneWithCountryCode(_phoneCountryCode, _phoneController.text),
        gender: _gender,
        dob: _dobController.text.trim(),
        organizationName: _organizationName.trim().isNotEmpty
            ? _organizationName.trim()
            : ((link?.organizationName ?? '').isNotEmpty
                ? link!.organizationName
                : 'iGreen Tech'),
        businessUnit: _businessUnit.trim(),
        workLocation: _workLocation.trim(),
        department: _department.trim(),
        designation: _designation.trim(),
        employmentType: 'Full-Time',
        joiningDate: _joiningDateController.text.trim(),
        status: (isSubmit || isEditMode || resolvedEmployeeId.startsWith('EMP-'))
            ? (_status.isEmpty || _status == 'PENDING' || _status.toLowerCase() == 'draft' ? 'ACTIVE' : _status)
            : (_status.isNotEmpty && _status.toLowerCase() != 'draft' ? _status : 'Draft'),
        bloodGroup: _bloodGroup,
        bloodGroupReport: _bloodGroupDocFileName,
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
        personalMobile: _formatPhoneWithCountryCode(_personalMobileCountryCode, _personalMobileController.text),
        passportNumber: _passportController.text.trim(),
        drivingLicenseNumber: _drivingLicenseController.text.trim(),
        drivingLicenseBatch: '',
        healthIssues: _healthIssuesController.text.trim(),
        emergencyName: _emergencyNameController.text.trim(),
        emergencyMobile: _formatPhoneWithCountryCode(_emergencyMobileCountryCode, _emergencyMobileController.text),
        referredByName: _referredByNameController.text.trim(),
        referredByMobile: _formatPhoneWithCountryCode(_referredByMobileCountryCode, _referredByMobileController.text),
        fatherName: _fatherNameController.text.trim(),
        motherName: _motherNameController.text.trim(),
        maritalStatus: _maritalStatus,
        spouseName: _spouseNameController.text.trim(),
        kids1Name: _kids1NameController.text.trim(),
        kids2Name: _kids2NameController.text.trim(),
        kids3Name: _kids3NameController.text.trim(),
        hasCriminalCases: _hasCriminalCases,
        criminalCaseDetails: _hasCriminalCases ? _criminalCaseDetailsController.text.trim() : '',
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
        inTime: _workScheduleType == 'Fixed Schedule' ? _inTimeController.text.trim() : '',
        outTime: _workScheduleType == 'Fixed Schedule' ? _outTimeController.text.trim() : '',
        requiredWorkingHours: double.tryParse(_requiredWorkingHoursController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 9.0,
        weeklyOffDay: _weeklyOffDayController.text.trim(),
        reportingManager: _reportingToController.text.trim(),
        reportingManagerTitle: _reportingManagerTitleController.text.trim(),
        adminName: _adminNameController.text.trim(),
        coordinatorName: _coordinatorNameController.text.trim(),
        coordinatorPhone: _formatPhoneWithCountryCode(_coordinatorPhoneCountryCode, _coordinatorPhoneController.text),
        leaveType: _leaveType == 'Manual Allocation' ? 'Monthly Allocation' : _leaveType,
        leaveAllocationFrequency: 'Monthly',
        allowedLeaves: (_leaveType == 'Monthly Allocation' || _leaveType == 'Manual Allocation') ? (double.tryParse(_allowedLeavesController.text.trim()) ?? 3.0) : 0.0,
        monthlyLeaveAllowance: (_leaveType == 'Monthly Allocation' || _leaveType == 'Manual Allocation') ? (double.tryParse(_allowedLeavesController.text.trim()) ?? 3.0) : 3.0,
        monthlyPermissionLimitHours: double.tryParse(_monthlyPermissionLimitController.text.trim()) ?? 3.0,
        dailyPermissionLimitHours: double.tryParse(_dailyPermissionLimitController.text.trim()) ?? 1.0,
        effectiveDate: _leaveEffectiveDateController.text.trim(),
        salaryType: _salaryType,
        salaryTotalCtc: double.tryParse(_totalSalaryController.text.trim().replaceAll(',', '')) ?? 0.0,
        salaryBasic: double.tryParse(_basicPayController.text.trim().replaceAll(',', '')) ?? 0.0,
        salaryHra: double.tryParse(_hraController.text.trim().replaceAll(',', '')) ?? 0.0,
        salaryEducationAllowance: double.tryParse(_eduAllowanceController.text.trim().replaceAll(',', '')) ?? 0.0,
        salarySpecialAllowance: double.tryParse(_specialAllowanceController.text.trim().replaceAll(',', '')) ?? 0.0,
        salaryTravelAllowance: double.tryParse(_travelAllowanceController.text.trim().replaceAll(',', '')) ?? 0.0,
        salaryOtherAllowance: double.tryParse(_otherAllowanceController.text.trim().replaceAll(',', '')) ?? 0.0,
        salaryTax: double.tryParse(_tdsController.text.trim().replaceAll(',', '')) ?? 0.0,
        salaryPf: double.tryParse(_pfController.text.trim().replaceAll(',', '')) ?? 0.0,
        salaryEsi: double.tryParse(_esiController.text.trim().replaceAll(',', '')) ?? 0.0,
        salaryEsiEmployer: double.tryParse(_esiEmployerController.text.trim().replaceAll(',', '')) ?? 0.0,
        salaryProfessionalTax: double.tryParse(_professionalTaxController.text.trim().replaceAll(',', '')) ?? 0.0,
        accessPermissions: _selectedPermissions.toList(),
        isStaticEmployee: _workScheduleType == 'Fixed Schedule',
        isDynamicEmployee: _workScheduleType == 'Flexible Schedule',
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
      } else if (_registrationMode == 'accepted_response' || widget.acceptedLinkId != null || widget.acceptedEmpId != null) {

        if (!isSubmit) {
          // Draft save: preserve candidate record
          final targetId = _currentEmployee?.id ?? widget.acceptedEmpId ?? 0;
          final updated = employeeData.copyWith(
            id: targetId,
            employeeId: (_currentEmployee?.employeeId.isNotEmpty == true)
                ? _currentEmployee!.employeeId
                : 'CAN-draft',
            status: 'Draft',
          );
          if (targetId != 0) {
            await repo.updateEmployee(updated);
            savedEmployee = updated;
          } else {
            savedEmployee = await repo.addEmployee(updated);
          }
        } else {
          // Admin conversion mode: Convert Candidate to full Employee with EMP- ID and set status to Registered
          final linkIdToConvert = _selectedAcceptedLinkId ?? widget.acceptedLinkId ?? widget.linkId;
          savedEmployee = await repo.convertCandidateToEmployee(
            linkId: linkIdToConvert,
            employeeData: employeeData,
          );
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
        // Candidate Link submission
        if (isSubmit) {
          savedEmployee = await repo.submitCandidateRegistration(
            linkId: widget.linkId,
            candidateData: employeeData,
          );
        } else {
          savedEmployee = await repo.submitEmployeeRegistration(
            linkId: widget.linkId,
            employeeData: employeeData,
            isSubmit: false,
          );
        }
      }

      _currentEmployee = savedEmployee;
      if (savedEmployee.profileImageUrl.isNotEmpty) {
        _profileImageDataUrl = savedEmployee.profileImageUrl;
      }
      _isProfileImageRemoved = false;
      ref.invalidate(employeesProvider);
      ref.invalidate(allEmployeesProvider);
      ref.invalidate(activeResponsesProvider);
      ref.invalidate(registrationLinksProvider);
      ref.invalidate(candidateResponsesProvider);

      if (_selectedAcceptedLinkId != null && _selectedAcceptedLinkId!.isNotEmpty) {
        ref.invalidate(registrationLinkByIdProvider(_selectedAcceptedLinkId!));
      }
      if (widget.linkId.isNotEmpty && widget.linkId != 'new' && widget.linkId != 'edit') {
        ref.invalidate(registrationLinkByIdProvider(widget.linkId));
      }

      final currentTab = _tabs[_tabController.index];
      setState(() {
        if (isSubmit) {
          _submittedEmployee = savedEmployee;
        }
        _savedTabs.add(currentTab);
        _isSubmitting = false;
        _isDraftSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(isSubmit
                    ? (isEditMode ? 'Employee details updated successfully!' : 'Employee registered successfully!')
                    : '$currentTab page saved successfully!'),
              ],
            ),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );

        // Redirect to /employee-management only for management/admin additions, edits, or candidate conversions
        if (isSubmit && (_isManagementAdd || _selectedAcceptedLinkId != null || widget.acceptedLinkId != null)) {
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) {
              GoRouter.of(context).go('/employee-management');
            }
          });
        }
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _isDraftSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _updateTabControllerIfNeeded();
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

                  if (link.linkStatus == 'Submitted' || link.linkStatus == 'Converted' || link.linkStatus == 'Completed' || link.linkStatus == 'Used' || _submittedEmployee != null) {
                    final emp = _submittedEmployee;
                    return _buildStatusCard(
                      icon: Icons.check_circle_outline,
                      color: const Color(0xFF28A745),
                      title: _submittedEmployee != null
                          ? 'Registration Submitted Successfully!'
                          : 'Registration Link Already Used',
                      message: _submittedEmployee != null
                          ? 'Thank you! Your employee registration has been submitted successfully.\n\n${emp != null && emp.employeeId.isNotEmpty ? "Candidate ID: ${emp.employeeId}" : "Status: Registration Submitted"}'
                          : 'This registration link has already been used and is no longer available.',
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

                  if (!_draftLoaded && (link.employeeId.isNotEmpty || link.linkId.isNotEmpty)) {
                    _draftLoaded = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      try {
                        final repo = ref.read(employeeRepositoryProvider);
                        final candidateResponse = await repo.getCandidateResponseByLinkId(link.linkId) ??
                            (link.employeeId.isNotEmpty ? await repo.getCandidateResponseByCandidateId(link.employeeId) : null);
                        if (candidateResponse != null && mounted) {
                          _populateFromEmployee(candidateResponse.employeeData);
                        } else {
                          final emps = await ref.read(allEmployeesProvider.future);
                          final matchedEmployee = _findMatchingEmployee(link, emps);
                          if (matchedEmployee != null && mounted) {
                            _selectedAcceptedEmpId = matchedEmployee.id;
                            _populateFromEmployee(matchedEmployee);
                          } else if (link.employeeName.isNotEmpty && mounted) {
                            setState(() {
                              if (_firstNameController.text.isEmpty) {
                                final nameParts = link.employeeName.trim().split(RegExp(r'\s+'));
                                if (nameParts.length > 1) {
                                  _firstNameController.text = nameParts.first;
                                  _lastNameController.text = nameParts.sublist(1).join(' ');
                                } else {
                                  _firstNameController.text = link.employeeName;
                                }
                              }
                            });
                          }
                        }
                      } catch (_) {}
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
      onPressed: (_isSubmitting || _isDraftSaving)
          ? null
          : () => _showRegistrationPreviewDialog(link ??
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
                if (_isManagementAdd || isEditMode || (link != null && link.linkStatus != 'Submitted' && link.linkStatus != 'Converted' && _submittedEmployee == null)) ...[
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
              if (_isManagementAdd || isEditMode || (link != null && link.linkStatus != 'Submitted' && link.linkStatus != 'Converted' && _submittedEmployee == null))
                submitBtn,
            ],
          ),
        );
      },
    );
  }

  bool _isTabHasData(String tab) {
    switch (tab) {
      case 'Personal Info':
        return _firstNameController.text.trim().isNotEmpty || _lastNameController.text.trim().isNotEmpty;
      case 'Address':
        return _permAddressController.text.trim().isNotEmpty;
      case 'Education':
        return _educationList.isNotEmpty || _eduDegreeController.text.trim().isNotEmpty;
      case 'Experience':
        return _experienceList.isNotEmpty || _expCompanyController.text.trim().isNotEmpty;
      case 'History':
        return _fatherNameController.text.trim().isNotEmpty || _panController.text.trim().isNotEmpty;
      case 'Bank Account':
        return _bankHolderController.text.trim().isNotEmpty || _bankAccNumController.text.trim().isNotEmpty;
      case 'Document':
        return _documentList.isNotEmpty;
      case 'Social Media':
        return _facebookController.text.trim().isNotEmpty ||
            _twitterController.text.trim().isNotEmpty ||
            _linkedinController.text.trim().isNotEmpty ||
            _googleController.text.trim().isNotEmpty;
      default:
        return false;
    }
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
        tabs: _tabs.map((tab) {
          final isCandidateTab = [
            'Personal Info', 'Address', 'Education', 'Experience',
            'History', 'Bank Account', 'Document', 'Social Media'
          ].contains(tab);
          final tabErrors = isCandidateTab ? _validateTabByName(tab) : <String>[];
          final isSaved = _isTabSaved(tab);
          final hasData = _isTabHasData(tab);
          final showGreenCheck = isCandidateTab && tabErrors.isEmpty && (isSaved || (_hasSubmittedAtLeastOnce && hasData));
          final showRedAlert = isCandidateTab && tabErrors.isNotEmpty && (_hasSubmittedAtLeastOnce || isSaved);

          return Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tab),
                if (showGreenCheck) ...[
                  const SizedBox(width: 5),
                  const Icon(Icons.check_circle, size: 14, color: Color(0xFF2E7D32)),
                ] else if (showRedAlert) ...[
                  const SizedBox(width: 5),
                  const Icon(Icons.error_outline, size: 14, color: Color(0xFFD32F2F)),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // TAB 1: PERSONAL INFO
  Widget _buildPersonalInfoTab(RegistrationLink link, bool isMobile) {
    ImageProvider? profileImageProvider;
    if (_profileImageBytes != null) {
      profileImageProvider = MemoryImage(_profileImageBytes!);
    } else if (_profileImageDataUrl.isNotEmpty) {
      if (_profileImageDataUrl.startsWith('data:image')) {
        final commaIndex = _profileImageDataUrl.indexOf(',');
        if (commaIndex > 0) {
          try {
            final decoded = base64Decode(_profileImageDataUrl.substring(commaIndex + 1));
            profileImageProvider = MemoryImage(decoded);
          } catch (_) {}
        }
      } else if (_profileImageDataUrl.startsWith('http://') || _profileImageDataUrl.startsWith('https://')) {
        profileImageProvider = NetworkImage(_profileImageDataUrl);
      }
    }
    final bool hasProfileImage = profileImageProvider != null;

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
                      final employeesAsync = ref.watch(allEmployeesProvider);
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
                                    final matchedEmployee = _findMatchingEmployee(link, allEmps);

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
                                      final selectedEmployee = _findMatchingEmployee(selectedLink, allEmps);

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
            _buildTextField('First Name *', _firstNameController, placeholder: 'First Name', isName: true),
            _buildTextField('Last Name *', _lastNameController, placeholder: 'Last Name', isName: true),
          ],
        ),
        const SizedBox(height: 12),
        _buildRow2or3(
          isMobile: isMobile,
          children: [
            _buildDropdown(
              'Blood Group',
              _bloodGroup,
              ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-', 'A1+', 'A1-', 'A2+', 'A2-', 'A1B+', 'A1B-', 'A2B+', 'A2B-', 'Bombay Blood Group (hh)', "Other / Don't Know"],
              (val) { if (val != null) { setState(() => _bloodGroup = val); _markTabUnsaved('Personal Info'); } },
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Blood Group Certificate / Test Report Document',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 5),
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD0D5DD), width: 0.8),
                  ),
                  child: Row(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF2F4F7),
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                            side: const BorderSide(color: Color(0xFFD0D5DD)),
                          ),
                        ),
                        onPressed: _pickBloodGroupDocFile,
                        child: const Text('Choose file', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _bloodGroupDocFileName,
                          style: TextStyle(
                            fontSize: 11,
                            color: _bloodGroupDocFileName == 'No file chosen' ? Colors.black54 : AppColors.active,
                            fontWeight: _bloodGroupDocFileName == 'No file chosen' ? FontWeight.normal : FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_bloodGroupDocFileName != 'No file chosen')
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _bloodGroupDocFileName = 'No file chosen';
                            });
                            _markTabUnsaved('Personal Info');
                          },
                          child: const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.close, size: 16, color: Colors.grey),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            _buildDropdown(
              'Gender *',
              _gender,
              ['Male', 'Female', 'Other'],
              (val) { if (val != null) { setState(() => _gender = val); _markTabUnsaved('Personal Info'); } },
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildRow2or3(
          isMobile: isMobile,
          children: [
            _buildDateField('Date Of Birth (Official) *', _dobController, placeholder: '13-05-1982'),
            _buildTextField('Aadhaar Number *', _aadhaarController, placeholder: '833750993144', isAadhaar: true, maxLength: 12),
            _buildTextField(
              'Primary Mobile Number *',
              _phoneController,
              placeholder: '8760098789',
              isPhone: true,
              countryCode: _phoneCountryCode,
              onCountryCodeChanged: (val) { setState(() => _phoneCountryCode = val); _markTabUnsaved('Personal Info'); },
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildRow2or3(
          isMobile: isMobile,
          children: [
            _buildTextField('Email Address *', _emailController, placeholder: 'Saravanan@igreentec.in', isEmail: true),
            _buildTextField('PF Number', _pfNumberController, placeholder: '100338738050 or 22 chars', isPf: true, maxLength: 22),
            _buildTextField('ESI Number', _esiNumberController, placeholder: 'ESI Number', isEsi: true, maxLength: 17),
          ],
        ),
        const SizedBox(height: 20),
        // Image Picker Section
        Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.active,
              backgroundImage: profileImageProvider,
              child: profileImageProvider == null
                  ? Text(
                      _firstNameController.text.trim().isNotEmpty
                          ? _firstNameController.text.trim()[0].toUpperCase()
                          : 'E',
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabelWithRequiredStar('Candidate Photo *'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (hasProfileImage)
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            side: const BorderSide(color: Colors.grey),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                          ),
                          onPressed: _removeProfileImage,
                          child: const Text('Delete file', style: TextStyle(fontSize: 12, color: Colors.black)),
                        )
                      else
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
                      Expanded(
                        child: Text(
                          _selectedFileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
            backgroundImage: profileImageProvider,
            child: profileImageProvider == null
                ? Text(
                    fullName.isNotEmpty ? fullName[0].toUpperCase() : 'E',
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                  )
                : null,
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
                  _phoneController.text.isEmpty
                      ? '-'
                      : _formatPhoneWithCountryCode(_phoneCountryCode, _phoneController.text),
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
            () {
              final orgsAsync = ref.watch(organizationsProvider);
              final orgList = orgsAsync.valueOrNull ?? [];
              final orgNames = orgList.map((e) => e.name).toList();
              if (_organizationName.isNotEmpty && !orgNames.contains(_organizationName)) {
                orgNames.insert(0, _organizationName);
              }
              if (_organizationName.isEmpty && orgNames.isNotEmpty) {
                _organizationName = orgNames.first;
              }

              final buAsync = ref.watch(businessUnitsProvider(_organizationName.isEmpty ? null : _organizationName));
              final buList = buAsync.valueOrNull ?? [];
              final buNames = buList.map((e) => e.unitName).toList();
              if (_businessUnit.isNotEmpty && !buNames.contains(_businessUnit)) {
                buNames.insert(0, _businessUnit);
              }

              final locAsync = ref.watch(locationsProvider(LocationFilter(
                organizationName: _organizationName.isEmpty ? null : _organizationName,
                businessUnitName: _businessUnit.isEmpty ? null : _businessUnit,
              )));
              final locList = locAsync.valueOrNull ?? [];
              final locNames = locList.map((e) => e.locationName).toList();
              if (_workLocation.isNotEmpty && !locNames.contains(_workLocation)) {
                locNames.insert(0, _workLocation);
              }

              final deptsAsync = ref.watch(filteredDepartmentsProvider(DepartmentFilter(
                organizationName: _organizationName.isEmpty ? null : _organizationName,
                businessUnitName: _businessUnit.isEmpty ? null : _businessUnit,
                workLocation: _workLocation.isEmpty ? null : _workLocation,
              )));
              final deptList = deptsAsync.valueOrNull ?? [];
              final deptNames = deptList.map((e) => e.departmentName).toList();
              if (deptNames.isEmpty) {
                deptNames.addAll(Employee.departmentOptions);
              }
              if (_department.isNotEmpty && !deptNames.contains(_department)) {
                deptNames.insert(0, _department);
              }
              if (_department.isEmpty && deptNames.isNotEmpty) {
                _department = deptNames.first;
              }

              final desigAsync = ref.watch(designationsProvider(_department.isEmpty ? null : _department));
              final desigList = desigAsync.valueOrNull ?? [];
              final desigNames = desigList.map((e) => e.designationName).where((s) => s.isNotEmpty).toSet().toList();
              if (_designation.isNotEmpty && !desigNames.contains(_designation)) {
                desigNames.insert(0, _designation);
              }
              if (_designation.isEmpty && desigNames.isNotEmpty) {
                _designation = desigNames.first;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRow2or3(
                    isMobile: isMobile,
                    children: [
                      _buildDropdown(
                        'Organization *',
                        _organizationName,
                        orgNames,
                        (val) {
                          if (val != null && val != _organizationName) {
                            setState(() {
                              _organizationName = val;
                              _businessUnit = '';
                              _workLocation = '';
                              _department = '';
                              _designation = '';
                            });
                            _markTabUnsaved('Job & Admin Details');
                          }
                        },
                        placeholder: 'Select Organization',
                      ),
                      _buildDropdown(
                        'Business Unit / Division',
                        _businessUnit,
                        buNames,
                        (val) {
                          if (val != null && val != _businessUnit) {
                            setState(() {
                              _businessUnit = val;
                              _workLocation = '';
                              _department = '';
                              _designation = '';
                            });
                            _markTabUnsaved('Job & Admin Details');
                          }
                        },
                        placeholder: 'Select Business Unit',
                      ),
                      _buildDropdown(
                        'Work Location',
                        _workLocation,
                        locNames,
                        (val) {
                          if (val != null && val != _workLocation) {
                            setState(() {
                              _workLocation = val;
                              _department = '';
                              _designation = '';
                            });
                            _markTabUnsaved('Job & Admin Details');
                          }
                        },
                        placeholder: 'Select Work Location',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildRow2or3(
                    isMobile: isMobile,
                    children: [
                      _buildDropdown(
                        'Department *',
                        _department,
                        deptNames,
                        (val) {
                          if (val != null && val != _department) {
                            setState(() {
                              _department = val;
                              _designation = '';
                              final match = deptList.where((d) => d.departmentName.trim().toLowerCase() == val.trim().toLowerCase()).firstOrNull;
                              if (match != null && match.departmentHead.trim().isNotEmpty) {
                                _reportingToController.text = match.departmentHead.trim();
                                _reportingManagerTitleController.text = '${match.departmentName} Head';
                              }
                            });
                            _markTabUnsaved('Job & Admin Details');
                          }
                        },
                        placeholder: 'Select Department',
                      ),
                      _buildDropdown(
                        'Designation *',
                        _designation,
                        desigNames,
                        (val) {
                          if (val != null && val != _designation) {
                            setState(() => _designation = val);
                            _markTabUnsaved('Job & Admin Details');
                          }
                        },
                        placeholder: 'Select Designation',
                      ),
                      _buildDateField('Date Of Joining', _joiningDateController, placeholder: '29-04-2017'),
                    ],
                  ),
                ],
              );
            }(),
            const SizedBox(height: 12),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildDateField('Contract End Date', _contractEndDateController, placeholder: 'dd-mm-yyyy'),
                _buildTextField(
                  'Reporting To',
                  _reportingToController,
                  placeholder: 'e.g. Saravanan G S',
                  isName: true,
                ),
                _buildTextField(
                  'Reporting Manager Title',
                  _reportingManagerTitleController,
                  placeholder: 'e.g. Managing Director',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildTextField(
                  'Present Admin Name',
                  _adminNameController,
                  placeholder: 'e.g. Saravanan G S',
                  isName: true,
                ),
                _buildTextField(
                  'Coordinator Name',
                  _coordinatorNameController,
                  placeholder: 'e.g. Admin Team',
                ),
                _buildTextField(
                  'Coordinator Contact Phone',
                  _coordinatorPhoneController,
                  placeholder: 'e.g. 8760098789',
                  isPhone: true,
                  countryCode: _coordinatorPhoneCountryCode,
                  onCountryCodeChanged: (val) { setState(() => _coordinatorPhoneCountryCode = val); _markTabUnsaved('Job & Admin Details'); },
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildDropdown(
                  'Work Schedule Type',
                  _workScheduleType,
                  ['Fixed Schedule', 'Flexible Schedule'],
                  (val) {
                    if (val != null) {
                      setState(() => _workScheduleType = val);
                      _markTabUnsaved('Job & Admin Details');
                    }
                  },
                ),
                _buildTextField(
                  'Weekly Off Day',
                  _weeklyOffDayController,
                  placeholder: 'e.g. Sunday',
                ),
                if (_workScheduleType == 'Fixed Schedule')
                  _buildTextField(
                    'In Time',
                    _inTimeController,
                    placeholder: 'e.g. 09:00 AM',
                  )
                else
                  _buildTextField(
                    'Required Working Hours',
                    _requiredWorkingHoursController,
                    placeholder: 'e.g. 9 Hours',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                if (_workScheduleType == 'Fixed Schedule')
                  _buildTextField(
                    'Out Time',
                    _outTimeController,
                    placeholder: 'e.g. 06:00 PM',
                  ),
                _buildDropdown(
                  'Leave Type',
                  _leaveType,
                  ['As Needed', 'Manual Allocation', 'No Leave'],
                  (val) { if (val != null) { setState(() => _leaveType = val); _markTabUnsaved('Job & Admin Details'); } },
                ),
                if (_leaveType == 'Manual Allocation') ...[
                  _buildDropdown(
                    'Leave Allocation Frequency',
                    _leaveAllocationFrequency,
                    ['Monthly', 'Quarterly', 'Yearly'],
                    (val) { if (val != null) { setState(() => _leaveAllocationFrequency = val); _markTabUnsaved('Job & Admin Details'); } },
                  ),
                  _buildTextField(
                    'Number of Allowed Leaves',
                    _allowedLeavesController,
                    placeholder: 'e.g. 1.0',
                    isNumber: true,
                    allowDecimal: true,
                  ),
                ],
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
            _buildTextField('Address *', _permAddressController, placeholder: 'Address Details', maxLines: 2),
            const SizedBox(height: 12),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildTextField('City *', _permCityController, placeholder: 'City', isName: true),
                _buildTextField('Country *', _permCountryController, placeholder: 'Country', isName: true),
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
            _buildTextField(_sameAsPermanent ? 'Address' : 'Address *', _presAddressController, placeholder: 'Address Details', maxLines: 2),
            const SizedBox(height: 12),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildTextField(_sameAsPermanent ? 'City' : 'City *', _presCityController, placeholder: 'City', isName: true),
                _buildTextField(_sameAsPermanent ? 'Country' : 'Country *', _presCountryController, placeholder: 'Country', isName: true),
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
                _buildTextField('Highest Degree / Course Name *', _eduDegreeController, placeholder: 'Degree Name'),
                _buildTextField('Institute / University Name *', _eduInstController, placeholder: 'Institute name'),
              ],
            ),
            const SizedBox(height: 12),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildTextField('Percentage / CGPA *', _eduResultController, placeholder: 'Result (e.g. 85% / Pass)'),
                _buildTextField('Passing Year *', _eduYearController, placeholder: 'Year (e.g. 2024)', isNumber: true, maxLength: 4),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.active,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Education entry added to list.'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill degree name or institute first.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Education', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
            _buildSaveButtonsRow(
              link,
              'Education',
              onCustomSave: () {
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
              },
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
            Row(
              children: const [
                Text(
                  'Work Experience History',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                SizedBox(width: 8),
                Text(
                  '(Optional for Freshers)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ],
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
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.active,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Experience entry added to list.'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill company name or position first.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Experience', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
            _buildSaveButtonsRow(
              link,
              'Experience',
              onCustomSave: () {
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
              },
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
                _buildTextField(
                  'Personal Mobile Number',
                  _personalMobileController,
                  placeholder: 'Personal Mobile Number',
                  isPhone: true,
                  countryCode: _personalMobileCountryCode,
                  onCountryCodeChanged: (val) { setState(() => _personalMobileCountryCode = val); _markTabUnsaved('History'); },
                ),
                _buildTextField('PAN Number *', _panController, placeholder: 'PAN (e.g. ABCDE1234F)', isPan: true),
              ],
            ),
            const SizedBox(height: 12),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildTextField('Passport No', _passportController, placeholder: 'Passport Number', isPassport: true),
                _buildTextField('Driving License No.', _drivingLicenseController, placeholder: 'License Number', isDrivingLicense: true),
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
                _buildTextField('Emergency Contact Name *', _emergencyNameController, placeholder: 'Emergency Name', isName: true),
                _buildTextField(
                  'Emergency Mobile Number *',
                  _emergencyMobileController,
                  placeholder: 'Emergency Contact',
                  isPhone: true,
                  countryCode: _emergencyMobileCountryCode,
                  onCountryCodeChanged: (val) { setState(() => _emergencyMobileCountryCode = val); _markTabUnsaved('History'); },
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Employee Referred By :', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 10),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildTextField('Name', _referredByNameController, placeholder: 'Referred By', isName: true),
                _buildTextField(
                  'Mobile Number',
                  _referredByMobileController,
                  placeholder: 'Referred Mobile',
                  isPhone: true,
                  countryCode: _referredByMobileCountryCode,
                  onCountryCodeChanged: (val) { setState(() => _referredByMobileCountryCode = val); _markTabUnsaved('History'); },
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Family Details :', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 10),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildTextField('Father Name', _fatherNameController, placeholder: 'Father Name', isName: true),
                _buildTextField('Mother Name', _motherNameController, placeholder: 'Mother Name', isName: true),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Marital Status', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Radio<String>(
                          value: 'Married',
                          groupValue: _maritalStatus,
                          onChanged: (val) { if (val != null) { setState(() => _maritalStatus = val); _markTabUnsaved('History'); } },
                        ),
                        const Text('Married', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 8),
                        Radio<String>(
                          value: 'Unmarried',
                          groupValue: _maritalStatus,
                          onChanged: (val) { if (val != null) { setState(() => _maritalStatus = val); _markTabUnsaved('History'); } },
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
                _buildTextField('Spouse Name', _spouseNameController, placeholder: 'Spouse Name', isName: true),
                _buildTextField('Kids1 Name', _kids1NameController, placeholder: 'Kids Name', isName: true),
                _buildTextField('Kids2 Name', _kids2NameController, placeholder: 'Kids Name', isName: true),
              ],
            ),
            const SizedBox(height: 12),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildTextField('Kids3 Name', _kids3NameController, placeholder: 'Kids Name', isName: true),
                const SizedBox.shrink(),
                const SizedBox.shrink(),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Criminal Background Check :', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: _hasCriminalCases,
                  activeColor: AppColors.active,
                  onChanged: (val) {
                    setState(() => _hasCriminalCases = val ?? false);
                    _markTabUnsaved('History');
                  },
                ),
                const Expanded(
                  child: Text(
                    'Does the employee have any criminal cases or legal charges?',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87),
                  ),
                ),
              ],
            ),
            if (_hasCriminalCases) ...[
              const SizedBox(height: 10),
              _buildTextField(
                'Criminal Case Details / Description *',
                _criminalCaseDetailsController,
                placeholder: 'Enter details regarding the criminal case(s)...',
                maxLines: 3,
              ),
            ],
            const SizedBox(height: 24),
            _buildSaveButtonsRow(link, 'History'),
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
                _buildTextField('Account Holder Name *', _bankHolderController, placeholder: 'Holder Name', isName: true),
                _buildTextField('Bank Name *', _bankNameController, placeholder: 'Bank Name', isName: true),
              ],
            ),
            const SizedBox(height: 12),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildTextField('Account Number *', _bankAccNumController, placeholder: 'Account Number', isNumber: true, maxLength: 18),
                _buildTextField('IFSC Code *', _bankIfscController, placeholder: 'IFSC Code (e.g. SBIN0001234)', isIfsc: true),
              ],
            ),
            const SizedBox(height: 12),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildTextField('Branch Name', _bankBranchController, placeholder: 'Branch Name', isName: true),
                _buildDropdown(
                  'Account Type *',
                  _bankAccountType,
                  ['Savings', 'Current', 'Salary'],
                  (val) { if (val != null) { setState(() => _bankAccountType = val); _markTabUnsaved('Bank Account'); } },
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSaveButtonsRow(link, 'Bank Account'),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDocumentFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );
      final file = result?.files.isNotEmpty == true ? result!.files.first : null;
      if (file == null) return;
      setState(() {
        _docFileName = file.name;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to select file: $e')),
        );
      }
    }
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
            const SizedBox(height: 4),
            RichText(
              text: const TextSpan(
                text: 'Mandatory Upload Copy: ',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                children: [
                  TextSpan(text: 'Aadhaar Card / Gov ID', style: TextStyle(color: Colors.black87)),
                  TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
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
                  'Document Type *',
                  _docType,
                  ['Aadhaar Card', 'PAN Card', 'Educational Certificate', 'Passport', 'Relieving Letter', 'Blood Group Certificate', 'Test Report', 'Other'],
                  (val) { if (val != null) { setState(() => _docType = val); _markTabUnsaved('Document'); } },
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
                  onPressed: _pickDocumentFile,
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: const Text('Choose File', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _docFileName,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.active,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Document added to list.'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select a file or enter document number first.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Document', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildSaveButtonsRow(
              link,
              'Document',
              onCustomSave: () {
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
              },
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
            Row(
              children: const [
                Text(
                  'Social Media Links & Handles',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                SizedBox(width: 8),
                Text(
                  '(All Optional)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ],
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
            _buildSaveButtonsRow(link, 'Social Media'),
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

  static Map<String, dynamic> getCountryPhoneDetails(String code) {
    switch (code) {
      case '+91':
        return {'digits': 10, 'placeholder': '9876543210', 'compact': '+91 🇮🇳'};
      case '+1':
        return {'digits': 10, 'placeholder': '2025550143', 'compact': '+1 🇺🇸'};
      case '+44':
        return {'digits': 10, 'placeholder': '7911123456', 'compact': '+44 🇬🇧'};
      case '+971':
        return {'digits': 9, 'placeholder': '501234567', 'compact': '+971 🇦🇪'};
      case '+966':
        return {'digits': 9, 'placeholder': '512345678', 'compact': '+966 🇸🇦'};
      case '+65':
        return {'digits': 8, 'placeholder': '81234567', 'compact': '+65 🇸🇬'};
      case '+61':
        return {'digits': 9, 'placeholder': '412345678', 'compact': '+61 🇦🇺'};
      case '+60':
        return {'digits': 10, 'placeholder': '1234567890', 'compact': '+60 🇲🇾'};
      case '+49':
        return {'digits': 11, 'placeholder': '15123456789', 'compact': '+49 🇩🇪'};
      case '+33':
        return {'digits': 9, 'placeholder': '612345678', 'compact': '+33 🇫🇷'};
      case '+81':
        return {'digits': 10, 'placeholder': '9012345678', 'compact': '+81 🇯🇵'};
      case '+86':
        return {'digits': 11, 'placeholder': '13800138000', 'compact': '+86 🇨🇳'};
      case '+880':
        return {'digits': 10, 'placeholder': '1712345678', 'compact': '+880 🇧🇩'};
      case '+94':
        return {'digits': 9, 'placeholder': '712345678', 'compact': '+94 🇱🇰'};
      case '+92':
        return {'digits': 10, 'placeholder': '3001234567', 'compact': '+92 🇵🇰'};
      case '+977':
        return {'digits': 10, 'placeholder': '9812345678', 'compact': '+977 🇳🇵'};
      case '+62':
        return {'digits': 11, 'placeholder': '81234567890', 'compact': '+62 🇮🇩'};
      case '+63':
        return {'digits': 10, 'placeholder': '9171234567', 'compact': '+63 🇵🇭'};
      case '+84':
        return {'digits': 9, 'placeholder': '912345678', 'compact': '+84 🇻🇳'};
      case '+66':
        return {'digits': 9, 'placeholder': '812345678', 'compact': '+66 🇹🇭'};
      case '+27':
        return {'digits': 9, 'placeholder': '821234567', 'compact': '+27 🇿🇦'};
      case '+20':
        return {'digits': 10, 'placeholder': '1012345678', 'compact': '+20 🇪🇬'};
      case '+234':
        return {'digits': 10, 'placeholder': '8012345678', 'compact': '+234 🇳🇬'};
      default:
        final match = allWorldCountryCodes.firstWhere(
          (c) => c['code'] == code,
          orElse: () => {'code': code, 'label': '$code 🌐'},
        );
        final label = match['label'] ?? '';
        final parts = label.split(' ');
        final flag = parts.length > 1 ? parts[1] : '';
        return {
          'digits': 10,
          'placeholder': '9876543210',
          'compact': '$code $flag'.trim(),
        };
    }
  }

  static const List<Map<String, String>> allWorldCountryCodes = [
    {'code': '+91', 'label': '+91 🇮🇳 (India)'},
    {'code': '+1', 'label': '+1 🇺🇸 (USA / Canada)'},
    {'code': '+44', 'label': '+44 🇬🇧 (UK)'},
    {'code': '+971', 'label': '+971 🇦🇪 (UAE)'},
    {'code': '+966', 'label': '+966 🇸🇦 (Saudi Arabia)'},
    {'code': '+65', 'label': '+65 🇸🇬 (Singapore)'},
    {'code': '+61', 'label': '+61 🇦🇺 (Australia)'},
    {'code': '+60', 'label': '+60 🇲🇾 (Malaysia)'},
    {'code': '+49', 'label': '+49 🇩🇪 (Germany)'},
    {'code': '+33', 'label': '+33 🇫🇷 (France)'},
    {'code': '+81', 'label': '+81 🇯🇵 (Japan)'},
    {'code': '+86', 'label': '+86 🇨🇳 (China)'},
    {'code': '+93', 'label': '+93 🇦🇫 (Afghanistan)'},
    {'code': '+355', 'label': '+355 🇦🇱 (Albania)'},
    {'code': '+213', 'label': '+213 🇩🇿 (Algeria)'},
    {'code': '+1684', 'label': '+1684 🇦🇸 (American Samoa)'},
    {'code': '+376', 'label': '+376 🇦🇩 (Andorra)'},
    {'code': '+244', 'label': '+244 🇦🇴 (Angola)'},
    {'code': '+1264', 'label': '+1264 🇦🇮 (Anguilla)'},
    {'code': '+1268', 'label': '+1268 🇦🇬 (Antigua & Barbuda)'},
    {'code': '+54', 'label': '+54 🇦🇷 (Argentina)'},
    {'code': '+374', 'label': '+374 🇦🇲 (Armenia)'},
    {'code': '+297', 'label': '+297 🇦🇼 (Aruba)'},
    {'code': '+43', 'label': '+43 🇦🇹 (Austria)'},
    {'code': '+994', 'label': '+994 🇦🇿 (Azerbaijan)'},
    {'code': '+1242', 'label': '+1242 🇧🇸 (Bahamas)'},
    {'code': '+973', 'label': '+973 🇧🇭 (Bahrain)'},
    {'code': '+880', 'label': '+880 🇧🇩 (Bangladesh)'},
    {'code': '+1246', 'label': '+1246 🇧🇧 (Barbados)'},
    {'code': '+375', 'label': '+375 🇧🇾 (Belarus)'},
    {'code': '+32', 'label': '+32 🇧🇪 (Belgium)'},
    {'code': '+501', 'label': '+501 🇧🇿 (Belize)'},
    {'code': '+229', 'label': '+229 🇧🇯 (Benin)'},
    {'code': '+1441', 'label': '+1441 🇧🇲 (Bermuda)'},
    {'code': '+975', 'label': '+975 🇧🇹 (Bhutan)'},
    {'code': '+591', 'label': '+591 🇧🇴 (Bolivia)'},
    {'code': '+387', 'label': '+387 🇧🇦 (Bosnia & Herzegovina)'},
    {'code': '+267', 'label': '+267 🇧🇼 (Botswana)'},
    {'code': '+55', 'label': '+55 🇧🇷 (Brazil)'},
    {'code': '+246', 'label': '+246 🇮🇴 (British Indian Ocean Territory)'},
    {'code': '+1284', 'label': '+1284 🇻🇬 (British Virgin Islands)'},
    {'code': '+673', 'label': '+673 🇧🇳 (Brunei)'},
    {'code': '+359', 'label': '+359 🇧🇬 (Bulgaria)'},
    {'code': '+226', 'label': '+226 🇧🇫 (Burkina Faso)'},
    {'code': '+257', 'label': '+257 🇧🇮 (Burundi)'},
    {'code': '+855', 'label': '+855 🇰🇭 (Cambodia)'},
    {'code': '+237', 'label': '+237 🇨🇲 (Cameroon)'},
    {'code': '+238', 'label': '+238 🇨🇻 (Cape Verde)'},
    {'code': '+1345', 'label': '+1345 🇰🇾 (Cayman Islands)'},
    {'code': '+236', 'label': '+236 🇨🇫 (Central African Republic)'},
    {'code': '+235', 'label': '+235 🇹🇩 (Chad)'},
    {'code': '+56', 'label': '+56 🇨🇱 (Chile)'},
    {'code': '+57', 'label': '+57 🇨🇴 (Colombia)'},
    {'code': '+269', 'label': '+269 🇰🇲 (Comoros)'},
    {'code': '+242', 'label': '+242 🇨🇬 (Congo - Brazzaville)'},
    {'code': '+243', 'label': '+243 🇨🇩 (Congo - Kinshasa)'},
    {'code': '+682', 'label': '+682 🇨🇰 (Cook Islands)'},
    {'code': '+506', 'label': '+506 🇨🇷 (Costa Rica)'},
    {'code': '+385', 'label': '+385 🇭🇷 (Croatia)'},
    {'code': '+53', 'label': '+53 🇨🇺 (Cuba)'},
    {'code': '+599', 'label': '+599 🇨🇼 (Curaçao)'},
    {'code': '+357', 'label': '+357 🇨🇾 (Cyprus)'},
    {'code': '+420', 'label': '+420 🇨🇿 (Czech Republic)'},
    {'code': '+45', 'label': '+45 🇩🇰 (Denmark)'},
    {'code': '+253', 'label': '+253 🇩🇯 (Djibouti)'},
    {'code': '+1767', 'label': '+1767 🇩🇲 (Dominica)'},
    {'code': '+1809', 'label': '+1809 🇩🇴 (Dominican Republic)'},
    {'code': '+593', 'label': '+593 🇪🇨 (Ecuador)'},
    {'code': '+20', 'label': '+20 🇪🇬 (Egypt)'},
    {'code': '+503', 'label': '+503 🇸🇻 (El Salvador)'},
    {'code': '+240', 'label': '+240 🇬🇶 (Equatorial Guinea)'},
    {'code': '+291', 'label': '+291 🇪🇷 (Eritrea)'},
    {'code': '+372', 'label': '+372 🇪🇪 (Estonia)'},
    {'code': '+251', 'label': '+251 🇪🇹 (Ethiopia)'},
    {'code': '+500', 'label': '+500 🇫🇰 (Falkland Islands)'},
    {'code': '+298', 'label': '+298 🇫🇴 (Faroe Islands)'},
    {'code': '+679', 'label': '+679 🇫🇯 (Fiji)'},
    {'code': '+358', 'label': '+358 🇫🇮 (Finland)'},
    {'code': '+594', 'label': '+594 🇬🇫 (French Guiana)'},
    {'code': '+689', 'label': '+689 🇵🇫 (French Polynesia)'},
    {'code': '+241', 'label': '+241 🇬🇦 (Gabon)'},
    {'code': '+220', 'label': '+220 🇬🇲 (Gambia)'},
    {'code': '+995', 'label': '+995 🇬🇪 (Georgia)'},
    {'code': '+233', 'label': '+233 🇬🇭 (Ghana)'},
    {'code': '+350', 'label': '+350 🇬🇮 (Gibraltar)'},
    {'code': '+30', 'label': '+30 🇬🇷 (Greece)'},
    {'code': '+299', 'label': '+299 🇬🇱 (Greenland)'},
    {'code': '+1473', 'label': '+1473 🇬🇩 (Grenada)'},
    {'code': '+590', 'label': '+590 🇬🇵 (Guadeloupe)'},
    {'code': '+1671', 'label': '+1671 🇬🇺 (Guam)'},
    {'code': '+502', 'label': '+502 🇬🇹 (Guatemala)'},
    {'code': '+224', 'label': '+224 🇬🇳 (Guinea)'},
    {'code': '+245', 'label': '+245 🇬🇼 (Guinea-Bissau)'},
    {'code': '+592', 'label': '+592 🇬🇾 (Guyana)'},
    {'code': '+509', 'label': '+509 🇭🇹 (Haiti)'},
    {'code': '+504', 'label': '+504 🇭🇳 (Honduras)'},
    {'code': '+852', 'label': '+852 🇭🇰 (Hong Kong)'},
    {'code': '+36', 'label': '+36 🇭🇺 (Hungary)'},
    {'code': '+354', 'label': '+354 🇮🇸 (Iceland)'},
    {'code': '+62', 'label': '+62 🇮🇩 (Indonesia)'},
    {'code': '+98', 'label': '+98 🇮🇷 (Iran)'},
    {'code': '+964', 'label': '+964 🇮🇶 (Iraq)'},
    {'code': '+353', 'label': '+353 🇮🇪 (Ireland)'},
    {'code': '+441624', 'label': '+441624 🇮🇲 (Isle of Man)'},
    {'code': '+972', 'label': '+972 🇮🇱 (Israel)'},
    {'code': '+39', 'label': '+39 🇮🇹 (Italy)'},
    {'code': '+225', 'label': '+225 🇨🇮 (Ivory Coast)'},
    {'code': '+1876', 'label': '+1876 🇯🇲 (Jamaica)'},
    {'code': '+962', 'label': '+962 🇯🇴 (Jordan)'},
    {'code': '+7', 'label': '+7 🇰🇿 (Kazakhstan / Russia)'},
    {'code': '+254', 'label': '+254 🇰🇪 (Kenya)'},
    {'code': '+686', 'label': '+686 🇰🇮 (Kiribati)'},
    {'code': '+383', 'label': '+383 🇽🇰 (Kosovo)'},
    {'code': '+965', 'label': '+965 🇰🇼 (Kuwait)'},
    {'code': '+996', 'label': '+996 🇰🇬 (Kyrgyzstan)'},
    {'code': '+856', 'label': '+856 🇱🇦 (Laos)'},
    {'code': '+371', 'label': '+371 🇱🇻 (Latvia)'},
    {'code': '+961', 'label': '+961 🇱🇧 (Lebanon)'},
    {'code': '+266', 'label': '+266 🇱🇸 (Lesotho)'},
    {'code': '+231', 'label': '+231 🇱🇷 (Liberia)'},
    {'code': '+218', 'label': '+218 🇱🇾 (Libya)'},
    {'code': '+423', 'label': '+423 🇱🇮 (Liechtenstein)'},
    {'code': '+370', 'label': '+370 🇱🇹 (Lithuania)'},
    {'code': '+352', 'label': '+352 🇱🇺 (Luxembourg)'},
    {'code': '+853', 'label': '+853 🇲🇴 (Macau)'},
    {'code': '+389', 'label': '+389 🇲🇰 (North Macedonia)'},
    {'code': '+261', 'label': '+261 🇲🇬 (Madagascar)'},
    {'code': '+265', 'label': '+265 🇲🇼 (Malawi)'},
    {'code': '+960', 'label': '+960 🇲🇻 (Maldives)'},
    {'code': '+223', 'label': '+223 🇲🇱 (Mali)'},
    {'code': '+356', 'label': '+356 🇲🇹 (Malta)'},
    {'code': '+692', 'label': '+692 🇲🇭 (Marshall Islands)'},
    {'code': '+596', 'label': '+596 🇲🇶 (Martinique)'},
    {'code': '+222', 'label': '+222 🇲🇷 (Mauritania)'},
    {'code': '+230', 'label': '+230 🇲🇺 (Mauritius)'},
    {'code': '+262', 'label': '+262 🇾🇹 (Mayotte / Réunion)'},
    {'code': '+52', 'label': '+52 🇲🇽 (Mexico)'},
    {'code': '+691', 'label': '+691 🇫🇲 (Micronesia)'},
    {'code': '+373', 'label': '+373 🇲🇩 (Moldova)'},
    {'code': '+377', 'label': '+377 🇲🇨 (Monaco)'},
    {'code': '+976', 'label': '+976 🇲🇳 (Mongolia)'},
    {'code': '+382', 'label': '+382 🇲🇪 (Montenegro)'},
    {'code': '+1664', 'label': '+1664 🇲🇸 (Montserrat)'},
    {'code': '+212', 'label': '+212 🇲🇦 (Morocco)'},
    {'code': '+258', 'label': '+258 🇲🇿 (Mozambique)'},
    {'code': '+95', 'label': '+95 🇲🇲 (Myanmar)'},
    {'code': '+264', 'label': '+264 🇳🇦 (Namibia)'},
    {'code': '+674', 'label': '+674 🇳🇷 (Nauru)'},
    {'code': '+977', 'label': '+977 🇳🇵 (Nepal)'},
    {'code': '+31', 'label': '+31 🇳🇱 (Netherlands)'},
    {'code': '+687', 'label': '+687 🇳🇨 (New Caledonia)'},
    {'code': '+64', 'label': '+64 🇳🇿 (New Zealand)'},
    {'code': '+505', 'label': '+505 🇳🇮 (Nicaragua)'},
    {'code': '+227', 'label': '+227 🇳🇪 (Niger)'},
    {'code': '+234', 'label': '+234 🇳🇬 (Nigeria)'},
    {'code': '+683', 'label': '+683 🇳🇺 (Niue)'},
    {'code': '+850', 'label': '+850 🇰🇵 (North Korea)'},
    {'code': '+1670', 'label': '+1670 🇲🇵 (Northern Mariana Islands)'},
    {'code': '+47', 'label': '+47 🇳🇴 (Norway)'},
    {'code': '+968', 'label': '+968 🇴🇲 (Oman)'},
    {'code': '+92', 'label': '+92 🇵🇰 (Pakistan)'},
    {'code': '+680', 'label': '+680 🇵🇼 (Palau)'},
    {'code': '+970', 'label': '+970 🇵🇸 (Palestine)'},
    {'code': '+507', 'label': '+507 🇵🇦 (Panama)'},
    {'code': '+675', 'label': '+675 🇵🇬 (Papua New Guinea)'},
    {'code': '+595', 'label': '+595 🇵🇾 (Paraguay)'},
    {'code': '+51', 'label': '+51 🇵🇪 (Peru)'},
    {'code': '+63', 'label': '+63 🇵🇭 (Philippines)'},
    {'code': '+48', 'label': '+48 🇵🇱 (Poland)'},
    {'code': '+351', 'label': '+351 🇵🇹 (Portugal)'},
    {'code': '+1787', 'label': '+1787 🇵🇷 (Puerto Rico)'},
    {'code': '+974', 'label': '+974 🇶🇦 (Qatar)'},
    {'code': '+40', 'label': '+40 🇷🇴 (Romania)'},
    {'code': '+250', 'label': '+250 🇷🇼 (Rwanda)'},
    {'code': '+290', 'label': '+290 🇸🇭 (St. Helena)'},
    {'code': '+1869', 'label': '+1869 🇰🇳 (St. Kitts & Nevis)'},
    {'code': '+1758', 'label': '+1758 🇱🇨 (St. Lucia)'},
    {'code': '+508', 'label': '+508 🇵🇲 (St. Pierre & Miquelon)'},
    {'code': '+1784', 'label': '+1784 🇻🇨 (St. Vincent & Grenadines)'},
    {'code': '+685', 'label': '+685 🇼🇸 (Samoa)'},
    {'code': '+378', 'label': '+378 🇸🇲 (San Marino)'},
    {'code': '+239', 'label': '+239 🇸🇹 (Sao Tome & Principe)'},
    {'code': '+221', 'label': '+221 🇸🇳 (Senegal)'},
    {'code': '+381', 'label': '+381 🇷🇸 (Serbia)'},
    {'code': '+248', 'label': '+248 🇸🇨 (Seychelles)'},
    {'code': '+232', 'label': '+232 🇸🇱 (Sierra Leone)'},
    {'code': '+1721', 'label': '+1721 🇸🇽 (Sint Maarten)'},
    {'code': '+421', 'label': '+421 🇸🇰 (Slovakia)'},
    {'code': '+386', 'label': '+386 🇸🇮 (Slovenia)'},
    {'code': '+677', 'label': '+677 🇸🇧 (Solomon Islands)'},
    {'code': '+252', 'label': '+252 🇸🇴 (Somalia)'},
    {'code': '+27', 'label': '+27 🇿🇦 (South Africa)'},
    {'code': '+82', 'label': '+82 🇰🇷 (South Korea)'},
    {'code': '+211', 'label': '+211 🇸🇸 (South Sudan)'},
    {'code': '+34', 'label': '+34 🇪🇸 (Spain)'},
    {'code': '+94', 'label': '+94 🇱🇰 (Sri Lanka)'},
    {'code': '+249', 'label': '+249 🇸🇩 (Sudan)'},
    {'code': '+597', 'label': '+597 🇸🇷 (Suriname)'},
    {'code': '+268', 'label': '+268 🇸🇿 (Eswatini)'},
    {'code': '+46', 'label': '+46 🇸🇪 (Sweden)'},
    {'code': '+41', 'label': '+41 🇨🇭 (Switzerland)'},
    {'code': '+963', 'label': '+963 🇸🇾 (Syria)'},
    {'code': '+886', 'label': '+886 🇹🇼 (Taiwan)'},
    {'code': '+992', 'label': '+992 🇹🇯 (Tajikistan)'},
    {'code': '+255', 'label': '+255 🇹🇿 (Tanzania)'},
    {'code': '+66', 'label': '+66 🇹🇭 (Thailand)'},
    {'code': '+670', 'label': '+670 🇹🇱 (Timor-Leste)'},
    {'code': '+228', 'label': '+228 🇹🇬 (Togo)'},
    {'code': '+690', 'label': '+690 🇹🇰 (Tokelau)'},
    {'code': '+676', 'label': '+676 🇹🇴 (Tonga)'},
    {'code': '+1868', 'label': '+1868 🇹🇹 (Trinidad & Tobago)'},
    {'code': '+216', 'label': '+216 🇹🇳 (Tunisia)'},
    {'code': '+90', 'label': '+90 🇹🇷 (Turkey)'},
    {'code': '+993', 'label': '+993 🇹🇲 (Turkmenistan)'},
    {'code': '+1649', 'label': '+1649 🇹🇨 (Turks & Caicos Islands)'},
    {'code': '+688', 'label': '+688 🇹🇻 (Tuvalu)'},
    {'code': '+1340', 'label': '+1340 🇻🇮 (U.S. Virgin Islands)'},
    {'code': '+256', 'label': '+256 🇺🇬 (Uganda)'},
    {'code': '+380', 'label': '+380 🇺🇦 (Ukraine)'},
    {'code': '+598', 'label': '+598 🇺🇾 (Uruguay)'},
    {'code': '+998', 'label': '+998 🇺🇿 (Uzbekistan)'},
    {'code': '+678', 'label': '+678 🇻🇺 (Vanuatu)'},
    {'code': '+379', 'label': '+379 🇻🇦 (Vatican City)'},
    {'code': '+58', 'label': '+58 🇻🇪 (Venezuela)'},
    {'code': '+84', 'label': '+84 🇻🇳 (Vietnam)'},
    {'code': '+681', 'label': '+681 🇼🇫 (Wallis & Futuna)'},
    {'code': '+967', 'label': '+967 🇾🇪 (Yemen)'},
    {'code': '+260', 'label': '+260 🇿🇲 (Zambia)'},
    {'code': '+263', 'label': '+263 🇿🇼 (Zimbabwe)'},
  ];

  Widget _buildCountryCodeDropdown({
    required String selectedCode,
    required ValueChanged<String> onChanged,
  }) {
    final effectiveCode = allWorldCountryCodes.any((c) => c['code'] == selectedCode) ? selectedCode : '+91';
    final details = getCountryPhoneDetails(effectiveCode);

    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          barrierColor: Colors.black26,
          builder: (ctx) {
            String q = '';
            return StatefulBuilder(
              builder: (context, setModalState) {
                final filtered = allWorldCountryCodes.where((item) {
                  if (q.trim().isEmpty) return true;
                  final query = q.trim().toLowerCase();
                  return item['label']!.toLowerCase().contains(query) ||
                      item['code']!.toLowerCase().contains(query);
                }).toList();

                return Dialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: Colors.white,
                  insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Container(
                    width: 380,
                    constraints: const BoxConstraints(maxHeight: 440),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Select Country Code',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            InkWell(
                              onTap: () => Navigator.pop(context),
                              borderRadius: BorderRadius.circular(16),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          autofocus: true,
                          style: const TextStyle(fontSize: 12.5, color: Colors.black87),
                          decoration: InputDecoration(
                            hintText: 'Search country or code...',
                            hintStyle: const TextStyle(fontSize: 12, color: Colors.black38),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                            prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(8)),
                              borderSide: BorderSide(color: AppColors.primary, width: 1.2),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                          ),
                          onChanged: (val) => setModalState(() => q = val),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: filtered.isEmpty
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text(
                                      'No country found',
                                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                    ),
                                  ),
                                )
                              : Scrollbar(
                                  thumbVisibility: true,
                                  child: ListView.builder(
                                    itemCount: filtered.length,
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    itemBuilder: (context, index) {
                                      final item = filtered[index];
                                      final code = item['code']!;
                                      final isSelected = code == effectiveCode;

                                      return InkWell(
                                        onTap: () {
                                          onChanged(code);
                                          Navigator.pop(ctx);
                                        },
                                        borderRadius: BorderRadius.circular(6),
                                        hoverColor: const Color(0xFFF1F5F9),
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(vertical: 2),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? AppColors.primary.withOpacity(0.08)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item['label']!,
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                                    color: isSelected ? AppColors.primary : const Color(0xFF334155),
                                                  ),
                                                ),
                                              ),
                                              if (isSelected)
                                                const Icon(
                                                  Icons.check_rounded,
                                                  size: 16,
                                                  color: AppColors.primary,
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.only(left: 10, right: 6),
        decoration: const BoxDecoration(
          border: Border(
            right: BorderSide(color: Color(0xFFD0D5DD), width: 0.8),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              details['compact'] as String,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.black54),
          ],
        ),
      ),
    );
  }

  Widget _buildLabelWithRequiredStar(String label) {
    if (!label.contains('*')) {
      return Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
      );
    }
    final parts = label.split('*');
    final cleanLabel = parts[0].trim();
    final suffix = parts.length > 1 ? parts.sublist(1).join('*').trim() : '';

    return RichText(
      text: TextSpan(
        text: cleanLabel,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
        children: [
          const TextSpan(
            text: ' *',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
          ),
          if (suffix.isNotEmpty)
            TextSpan(
              text: ' $suffix',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    String? placeholder,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
    bool isNumber = false,
    bool isPhone = false,
    bool isPan = false,
    bool isIfsc = false,
    bool isPassport = false,
    bool isDrivingLicense = false,
    bool isName = false,
    bool isAlphanumeric = false,
    bool isUppercase = false,
    bool isEmail = false,
    bool isPf = false,
    bool isAadhaar = false,
    bool isEsi = false,
    int? maxLength,
    String countryCode = '+91',
    ValueChanged<String>? onCountryCodeChanged,
    bool allowDecimal = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    FormFieldValidator<String>? validator,
  }) {
    final phoneDetails = isPhone ? getCountryPhoneDetails(countryCode) : null;
    final maxPhoneDigits = phoneDetails != null ? (phoneDetails['digits'] as int) : 10;
    final dynamicPlaceholder = isPhone
        ? (placeholder ?? phoneDetails!['placeholder'] as String)
        : placeholder;

    final TextCapitalization textCapitalization = (isPan || isIfsc || isPassport || isDrivingLicense || isPf || isUppercase)
        ? TextCapitalization.characters
        : (isName ? TextCapitalization.words : TextCapitalization.none);

    final effectiveKeyboardType = keyboardType ?? (
      isPhone
        ? TextInputType.phone
        : (isNumber
          ? TextInputType.numberWithOptions(decimal: allowDecimal)
          : (isPan || isIfsc || isPassport || isDrivingLicense || isPf || isAlphanumeric
            ? TextInputType.visiblePassword
            : (isEmail ? TextInputType.emailAddress : TextInputType.text)))
    );

    final effectiveInputFormatters = inputFormatters ?? (
      isPan ? [
        LengthLimitingTextInputFormatter(10),
        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
        _UpperCaseTextFormatter(),
      ] : isAadhaar ? [
        LengthLimitingTextInputFormatter(12),
        FilteringTextInputFormatter.digitsOnly,
      ] : isEsi ? [
        LengthLimitingTextInputFormatter(17),
        FilteringTextInputFormatter.digitsOnly,
      ] : isPf ? [
        LengthLimitingTextInputFormatter(22),
        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
        _UpperCaseTextFormatter(),
      ] : isIfsc ? [
        LengthLimitingTextInputFormatter(11),
        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
        _UpperCaseTextFormatter(),
      ] : isPassport ? [
        LengthLimitingTextInputFormatter(9),
        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
        _UpperCaseTextFormatter(),
      ] : isDrivingLicense ? [
        LengthLimitingTextInputFormatter(16),
        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 \-]')),
        _UpperCaseTextFormatter(),
      ] : isAlphanumeric ? [
        if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
        if (isUppercase) _UpperCaseTextFormatter(),
      ] : isName ? [
        if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
        FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s.\-']")),
      ] : (isNumber || isPhone) ? [
        if (allowDecimal)
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
        else
          FilteringTextInputFormatter.digitsOnly,
        if (isPhone)
          LengthLimitingTextInputFormatter(maxPhoneDigits)
        else if (maxLength != null)
          LengthLimitingTextInputFormatter(maxLength),
      ] : [
        if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
        if (isUppercase) _UpperCaseTextFormatter(),
      ]
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLabelWithRequiredStar(label),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          textCapitalization: textCapitalization,
          onChanged: (val) {
            String sanitized = val;
            if (isPan || isIfsc || isPassport || isDrivingLicense || isUppercase) {
              sanitized = sanitized.toUpperCase();
            }
            if (isPan || isIfsc || isPassport) {
              sanitized = sanitized.replaceAll(RegExp(r'[^A-Z0-9]'), '');
            } else if (isDrivingLicense) {
              sanitized = sanitized.replaceAll(RegExp(r'[^A-Z0-9 \-]'), '');
            } else if (isAlphanumeric) {
              sanitized = sanitized.replaceAll(RegExp(r'[^A-Z0-9a-z]'), '');
            } else if (isName) {
              sanitized = sanitized.replaceAll(RegExp(r"[^a-zA-Z\s.\-']"), '');
            } else if (isNumber || isPhone) {
              final pattern = allowDecimal ? RegExp(r'[^0-9.]') : RegExp(r'[^0-9]');
              sanitized = sanitized.replaceAll(pattern, '');
            }

            if (sanitized != val) {
              controller.value = controller.value.copyWith(
                text: sanitized,
                selection: TextSelection.collapsed(offset: sanitized.length),
              );
            }
            if (onChanged != null) onChanged(sanitized);
          },
          keyboardType: effectiveKeyboardType,
          inputFormatters: effectiveInputFormatters,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) {
            final trimmed = (value ?? '').trim();
            if (trimmed.isEmpty && label.contains('*') && _hasSubmittedAtLeastOnce) {
              final cleanLabel = label.replaceAll('*', '').trim();
              return '$cleanLabel is required.';
            }
            if (trimmed.isNotEmpty) {
              if (isPan) {
                if (trimmed.length != 10) {
                  return 'PAN Number must be exactly 10 characters.';
                }
              } else if (isIfsc) {
                if (trimmed.length != 11) {
                  return 'IFSC Code must be exactly 11 characters.';
                }
              } else if (isPassport) {
                if (trimmed.length < 8 || trimmed.length > 9) {
                  return 'Passport Number must be 8 or 9 characters.';
                }
              } else if (isDrivingLicense) {
                if (trimmed.length < 10 || trimmed.length > 16) {
                  return 'Driving License must be 10 to 16 characters.';
                }
              } else if (isAadhaar) {
                if (trimmed.length != 12) {
                  return 'Aadhaar Number must be exactly 12 digits.';
                }
              } else if (isEsi) {
                if (trimmed.length != 17) {
                  return 'ESI Number must be exactly 17 digits.';
                }
              } else if (isPf) {
                if (trimmed.length != 12 && trimmed.length != 22) {
                  return 'PF Number / UAN must be 12 digits or 22 characters.';
                }
              } else if (isName) {
                if (RegExp(r'[0-9]').hasMatch(trimmed)) {
                  return 'Numbers are not allowed in name fields.';
                }
                if (RegExp(r"[^a-zA-Z\s.\-']").hasMatch(trimmed)) {
                  return 'Special symbols are not allowed in name fields.';
                }
              } else if (isEmail) {
                final emailRegExp = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                if (!emailRegExp.hasMatch(trimmed)) {
                  return 'Please enter a valid email address (e.g. user@gmail.com).';
                }
              } else if (isNumber || isPhone) {
                if (RegExp(r'[a-zA-Z]').hasMatch(trimmed)) {
                  return 'Alphabets are not allowed. Please enter numbers only.';
                }
                final pattern = allowDecimal ? RegExp(r'^\d*\.?\d*$') : RegExp(r'^\d+$');
                if (!pattern.hasMatch(trimmed)) {
                  return 'Only numeric characters (0-9) are allowed.';
                }
                if (isPhone && trimmed.length != maxPhoneDigits) {
                  return 'Please enter exactly $maxPhoneDigits digits for $countryCode.';
                }
              }
            }
            if (validator != null) {
              return validator(value);
            }
            return null;
          },
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          decoration: InputDecoration(
            hintText: dynamicPlaceholder,
            hintStyle: const TextStyle(fontSize: 12, color: Colors.black38),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            prefixIcon: isPhone && onCountryCodeChanged != null
                ? _buildCountryCodeDropdown(
                    selectedCode: countryCode,
                    onChanged: onCountryCodeChanged,
                  )
                : null,
            prefixIconConstraints: isPhone
                ? const BoxConstraints(minWidth: 0, minHeight: 0)
                : null,
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red, width: 1.0),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red, width: 1.2),
            ),
            errorStyle: const TextStyle(fontSize: 11, color: Colors.red),
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
        _buildLabelWithRequiredStar(label),
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
    ValueChanged<String?> onChanged, {
    String? placeholder,
  }) {
    final effectiveItems = <String>{...items, if (value.isNotEmpty) value}.toList();
    final effectiveValue = effectiveItems.contains(value) && value.isNotEmpty
        ? value
        : (effectiveItems.isNotEmpty && placeholder == null ? effectiveItems.first : (value.isNotEmpty ? value : null));

    return AppSearchableDropdown<String>(
      label: label,
      value: effectiveValue,
      items: effectiveItems,
      placeholder: placeholder,
      searchHint: 'Search ${label.replaceAll('*', '').trim()}...',
      onChanged: onChanged,
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

  void _showRegistrationPreviewDialog(RegistrationLink? link) {
    final candidateErrors = _getAllCandidateFormErrors();
    if (candidateErrors.isNotEmpty) {
      setState(() {
        _hasSubmittedAtLeastOnce = true;
      });
      _showSubmissionErrorSummaryDialog(candidateErrors);
      return;
    }

    if (_totalSalaryController.text.trim().isNotEmpty) {
      _recalculateSalaryAmountsFromPercentages();
    }
    final name = '${_firstNameController.text} ${_lastNameController.text}'.trim();
    final isMobile = MediaQuery.of(context).size.width < 600;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: isMobile
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 20)
              : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Container(
            width: isMobile ? double.infinity : MediaQuery.of(context).size.width * 0.85,
            constraints: BoxConstraints(
              maxWidth: 900,
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            padding: EdgeInsets.all(isMobile ? 14 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.active.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.assignment_turned_in, color: AppColors.active, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Registration Details Preview',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Review all details for ${name.isEmpty ? "Candidate" : name} before final submission.',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 20),
                // Body content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Candidate Profile Photo header if present
                        if (_profileImageBytes != null || _profileImageDataUrl.isNotEmpty) ...[
                          Center(
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 36,
                                  backgroundColor: Colors.grey.shade200,
                                  backgroundImage: _profileImageBytes != null
                                      ? MemoryImage(_profileImageBytes!)
                                      : (_profileImageDataUrl.startsWith('http') ? NetworkImage(_profileImageDataUrl) as ImageProvider : null),
                                  child: (_profileImageBytes == null && !_profileImageDataUrl.startsWith('http'))
                                      ? const Icon(Icons.person, size: 36, color: Colors.grey)
                                      : null,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  name.isEmpty ? 'Candidate Photo' : name,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                        ],

                        // Section 1: Personal Info
                        _buildPreviewSectionHeader('Personal Information', Icons.person_outline),
                        _buildPreviewGrid([
                          _buildPreviewField('First Name', _firstNameController.text),
                          _buildPreviewField('Last Name', _lastNameController.text),
                          _buildPreviewField('Blood Group', _bloodGroup),
                          _buildPreviewField('Blood Group Report Doc', _bloodGroupDocFileName),
                          _buildPreviewField('Gender', _gender),
                          _buildPreviewField('Date of Birth', _dobController.text),
                          _buildPreviewField('Aadhaar Number', _aadhaarController.text),
                          _buildPreviewField('Contact Phone', _formatPhoneWithCountryCode(_phoneCountryCode, _phoneController.text)),
                          _buildPreviewField('Email Address', _emailController.text),
                          _buildPreviewField('PF Number', _pfNumberController.text),
                          _buildPreviewField('ESI Number', _esiNumberController.text),
                        ]),
                        const SizedBox(height: 20),

                        // Section 2: Address
                        _buildPreviewSectionHeader('Address Information', Icons.location_on_outlined),
                        _buildPreviewGrid([
                          _buildPreviewField('Permanent Address', _permAddressController.text),
                          _buildPreviewField('Permanent City', _permCityController.text),
                          _buildPreviewField('Permanent Country', _permCountryController.text),
                          _buildPreviewField('Present Address', _sameAsPermanent ? '${_permAddressController.text} (Same as permanent)' : _presAddressController.text),
                          _buildPreviewField('Present City', _sameAsPermanent ? _permCityController.text : _presCityController.text),
                          _buildPreviewField('Present Country', _sameAsPermanent ? _permCountryController.text : _presCountryController.text),
                        ]),
                        const SizedBox(height: 20),

                        // Section 3: Education
                        _buildPreviewSectionHeader('Education Details', Icons.school_outlined),
                        if (_educationList.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text('No education entries added.', style: TextStyle(fontSize: 12, color: Colors.black54, fontStyle: FontStyle.italic)),
                          )
                        else
                          ..._educationList.map((edu) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('• ${edu.degreeName} from ${edu.instituteName} (${edu.passingYear}) - ${edu.result}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                          )),
                        const SizedBox(height: 20),

                        // Section 4: Experience
                        _buildPreviewSectionHeader('Work Experience', Icons.work_outline),
                        if (_experienceList.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text('No experience entries added.', style: TextStyle(fontSize: 12, color: Colors.black54, fontStyle: FontStyle.italic)),
                          )
                        else
                          ..._experienceList.map((exp) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('• ${exp.position} at ${exp.companyName} (${exp.workingDuration})', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                          )),
                        const SizedBox(height: 20),

                        // Section 5: Personal & Family History
                        _buildPreviewSectionHeader('Personal & Family History', Icons.history_edu_outlined),
                        _buildPreviewGrid([
                          _buildPreviewField('Original DOB', _originalDobController.text),
                          _buildPreviewField('Personal Mobile', _formatPhoneWithCountryCode(_personalMobileCountryCode, _personalMobileController.text)),
                          _buildPreviewField('PAN Number', _panController.text),
                          _buildPreviewField('Passport Number', _passportController.text),
                          _buildPreviewField('Driving License', _drivingLicenseController.text),
                          _buildPreviewField('Health Issues', _healthIssuesController.text),
                          _buildPreviewField('Emergency Contact Name', _emergencyNameController.text),
                          _buildPreviewField('Emergency Contact Phone', _formatPhoneWithCountryCode(_emergencyMobileCountryCode, _emergencyMobileController.text)),
                          _buildPreviewField('Referred By Name', _referredByNameController.text),
                          _buildPreviewField('Referred By Phone', _formatPhoneWithCountryCode(_referredByMobileCountryCode, _referredByMobileController.text)),
                          _buildPreviewField('Father Name', _fatherNameController.text),
                          _buildPreviewField('Mother Name', _motherNameController.text),
                          _buildPreviewField('Marital Status', _maritalStatus),
                          _buildPreviewField('Spouse Name', _spouseNameController.text),
                          _buildPreviewField('Kids Details', [_kids1NameController.text, _kids2NameController.text, _kids3NameController.text].where((k) => k.isNotEmpty).join(', ')),
                          _buildPreviewField('Has Criminal Record', _hasCriminalCases ? 'Yes' : 'No'),
                          if (_hasCriminalCases)
                            _buildPreviewField('Criminal Case Details', _criminalCaseDetailsController.text),
                        ]),
                        const SizedBox(height: 20),

                        // Section 6: Bank Account Details
                        _buildPreviewSectionHeader('Bank Account Details', Icons.account_balance_outlined),
                        _buildPreviewGrid([
                          _buildPreviewField('Account Holder', _bankHolderController.text),
                          _buildPreviewField('Bank Name', _bankNameController.text),
                          _buildPreviewField('Account Number', _bankAccNumController.text),
                          _buildPreviewField('IFSC Code', _bankIfscController.text),
                          _buildPreviewField('Branch', _bankBranchController.text),
                          _buildPreviewField('Account Type', _bankAccountType),
                        ]),
                        const SizedBox(height: 20),

                        // Section 7: Documents
                        _buildPreviewSectionHeader('Documents', Icons.folder_open_outlined),
                        if (_documentList.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text('No document entries attached.', style: TextStyle(fontSize: 12, color: Colors.black54, fontStyle: FontStyle.italic)),
                          )
                        else
                          ..._documentList.map((doc) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('• ${doc.documentType}: ${doc.documentNumber} (${doc.fileName})', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                          )),
                        const SizedBox(height: 20),

                        // Section 8: Social Profiles
                        _buildPreviewSectionHeader('Social Profiles', Icons.share_outlined),
                        _buildPreviewGrid([
                          _buildPreviewField('Facebook', _facebookController.text),
                          _buildPreviewField('Twitter', _twitterController.text),
                          _buildPreviewField('LinkedIn', _linkedinController.text),
                          _buildPreviewField('Google', _googleController.text),
                        ]),
                        const SizedBox(height: 20),

                        // Section 9: Job & Admin Details
                        if (_isManagementAdd || _isEditing || _department.isNotEmpty || _joiningDateController.text.isNotEmpty || link != null) ...[
                          _buildPreviewSectionHeader('Job & Administrative Details', Icons.badge_outlined),
                          _buildPreviewGrid([
                            if (_organizationName.isNotEmpty) _buildPreviewField('Organization', _organizationName),
                            if (_businessUnit.isNotEmpty) _buildPreviewField('Business Unit / Division', _businessUnit),
                            if (_workLocation.isNotEmpty) _buildPreviewField('Work Location', _workLocation),
                            _buildPreviewField('Department', _department),
                            _buildPreviewField('Designation', _designation),
                            _buildPreviewField('User Role / Type', _userType),
                            _buildPreviewField('Account Status', _status),
                            _buildPreviewField('Date of Joining', _joiningDateController.text),
                            _buildPreviewField('Contract End Date', _contractEndDateController.text),
                            _buildPreviewField('Reporting Manager', _reportingToController.text),
                            _buildPreviewField('Reporting Manager Title', _reportingManagerTitleController.text),
                            _buildPreviewField('Admin Name', _adminNameController.text),
                            _buildPreviewField('Coordinator Name', _coordinatorNameController.text),
                            _buildPreviewField('Coordinator Contact', _formatPhoneWithCountryCode(_coordinatorPhoneCountryCode, _coordinatorPhoneController.text)),
                            _buildPreviewField('Work Schedule Type', _workScheduleType),
                            _buildPreviewField('Weekly Off Day', _weeklyOffDayController.text),
                            if (_workScheduleType == 'Fixed Schedule')
                              _buildPreviewField('Work Hours', '${_inTimeController.text} - ${_outTimeController.text}')
                            else
                              _buildPreviewField('Required Working Hours', _requiredWorkingHoursController.text),
                            if (_siteLatitudeController.text.isNotEmpty || _siteLongitudeController.text.isNotEmpty)
                              _buildPreviewField('Site Geo-Fence Location', '${_siteLatitudeController.text}, ${_siteLongitudeController.text}'),
                            if (_siteRadiusController.text.isNotEmpty)
                              _buildPreviewField('Allowed Site Radius', '${_siteRadiusController.text} meters'),
                            _buildPreviewField('GPS Verification Required', _siteRequireGpsVerification ? 'Yes' : 'No'),
                            _buildPreviewField('Leave Type', _leaveType),
                            if (_leaveType == 'Manual Allocation') ...[
                              _buildPreviewField('Allocation Frequency', _leaveAllocationFrequency),
                              _buildPreviewField('Allowed Leaves', _allowedLeavesController.text),
                              _buildPreviewField('Leave Effective Date', _leaveEffectiveDateController.text),
                            ],

                          ]),
                          const SizedBox(height: 20),

                          // Section 10: Salary Details
                          _buildPreviewSectionHeader('Salary Details', Icons.payments_outlined),
                          _buildPreviewGrid([
                            _buildPreviewField('Salary Type', _salaryType),
                            _buildPreviewField('Total CTC (Monthly)', _totalSalaryController.text),
                            _buildPreviewField('Basic Pay', _basicPayController.text),
                            _buildPreviewField('HRA', _hraController.text),
                            _buildPreviewField('Special Allowance', _specialAllowanceController.text),
                            _buildPreviewField('Education Allowance', _eduAllowanceController.text),
                            _buildPreviewField('Travel Allowance', _travelAllowanceController.text),
                            _buildPreviewField('Other Allowance', _otherAllowanceController.text),
                            _buildPreviewField('PF Deduction', _pfController.text),
                            _buildPreviewField('ESI Deduction (Employee)', _esiController.text),
                            _buildPreviewField('ESI Contribution (Employer)', _esiEmployerController.text),
                            _buildPreviewField('Professional Tax', _professionalTaxController.text),
                            _buildPreviewField('TDS', _tdsController.text),
                          ]),
                          const SizedBox(height: 20),

                          // Section 11: Credentials & Permissions
                          _buildPreviewSectionHeader('Credentials & Permissions', Icons.security_outlined),
                          _buildPreviewGrid([
                            _buildPreviewField('Employee Custom ID', _employeeCustomIdController.text),
                            _buildPreviewField('Temporary Password', _passwordController.text.isNotEmpty ? '••••••••' : '-'),
                            _buildPreviewField('User Role', _userType),
                            _buildPreviewField('Account Status', _status),
                            _buildPreviewField('Access Permissions', _selectedPermissions.isEmpty ? '-' : _selectedPermissions.join(', ')),
                          ]),
                        ],
                      ],
                    ),
                  ),
                ),
                const Divider(height: 20),
                // Footer Action Buttons
                if (isMobile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.active,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _submitForm(link, isSubmit: true);
                        },
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: Text(
                          _isEditing ? 'Confirm & Save Changes' : 'Confirm & Submit Registration',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Colors.grey),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.edit, size: 16, color: Colors.black87),
                        label: const Text('Go Back & Edit', style: TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          side: const BorderSide(color: Colors.grey),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.edit, size: 16, color: Colors.black87),
                        label: const Text('Go Back & Edit', style: TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.active,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _submitForm(link, isSubmit: true);
                        },
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: Text(
                          _isEditing ? 'Confirm & Save Changes' : 'Confirm & Submit Registration',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreviewSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.active),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.active),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewGrid(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 500;
        return Wrap(
          spacing: 16,
          runSpacing: 10,
          children: children.map((child) => SizedBox(
            width: isSmall ? constraints.maxWidth : (constraints.maxWidth - 16) / 2 - 1,
            child: child,
          )).toList(),
        );
      },
    );
  }

  Widget _buildPreviewField(String label, String value) {
    final displayValue = value.trim().isEmpty ? '-' : value.trim();
    final isEmpty = value.trim().isEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(
            displayValue,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isEmpty ? Colors.grey : Colors.black87,
              fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButtonsRow(
    RegistrationLink link,
    String tabName, {
    VoidCallback? onCustomSave,
    String saveLabel = 'Save',
  }) {
    final isSaved = _savedTabs.contains(tabName);
    final isLastTab = _tabController.index == _tabs.length - 1;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.active,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: (_isSubmitting || _isDraftSaving)
                  ? null
                  : () {
                      if (onCustomSave != null) {
                        onCustomSave();
                      }
                      _submitForm(link, isSubmit: false);
                    },
              icon: _isDraftSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check, size: 16),
              label: Text(_isDraftSaving ? 'Saving...' : saveLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.active,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: () {
                if (GoRouter.of(context).canPop()) {
                  GoRouter.of(context).pop();
                } else {
                  GoRouter.of(context).go('/employee-management');
                }
              },
              child: const Text('Cancel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        if (isSaved) ...[
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
          if (!isLastTab)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: () {
                final currentIndex = _tabController.index;
                if (currentIndex < _tabs.length - 1) {
                  _tabController.animateTo(currentIndex + 1);
                }
              },
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Next Tab →', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
        ],
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 32),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFE9ECEF)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline, size: 14, color: AppColors.active),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    isLastTab
                        ? 'Press Save to save progress, then click Submit Registration when done.'
                        : (isSaved ? 'Page saved! Click Next Tab to proceed.' : 'Press Save to save progress and unlock Next button.'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSalaryComponentRow({
    required String label,
    required String basis,
    required TextEditingController amountController,
    required TextEditingController percentController,
    required String placeholder,
    required double basisValue,
    required bool isMobile,
    bool showPercentageField = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                basis,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (value) {
                  if (value != null && value.isNotEmpty && RegExp(r'[a-zA-Z]').hasMatch(value)) {
                    return 'Alphabets are not allowed. Please enter numbers only.';
                  }
                  return null;
                },
                style: const TextStyle(fontSize: 12, color: Colors.black87),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: placeholder,
                  hintStyle: const TextStyle(
                      fontSize: 12, color: Color(0xFF98A2B3)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: Color(0xFFD0D5DD), width: 0.8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: Color(0xFFD0D5DD), width: 0.8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.active, width: 1.2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.red, width: 1.0),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.red, width: 1.2),
                  ),
                  errorStyle: const TextStyle(fontSize: 10, color: Colors.red),
                ),
                onChanged: (_) => _onAmountFieldEdited(
                    amountController, percentController, basisValue),
              ),
            ),
            if (showPercentageField) ...[
              const SizedBox(width: 6),
              SizedBox(
                width: isMobile ? 74 : 88,
                child: TextFormField(
                controller: percentController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (value) {
                  if (value != null && value.isNotEmpty && RegExp(r'[a-zA-Z]').hasMatch(value)) {
                    return 'Alphabets not allowed.';
                  }
                  return null;
                },
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.active,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  suffixText: '%',
                  suffixStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: Color(0xFFD0D5DD), width: 0.8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: Color(0xFFD0D5DD), width: 0.8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.active, width: 1.2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.red, width: 1.0),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.red, width: 1.2),
                  ),
                  errorStyle: const TextStyle(fontSize: 9, color: Colors.red),
                ),
                onChanged: (_) => _onPercentFieldEdited(
                    percentController, amountController, basisValue),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // TAB 9: SALARY & OFFER LETTER
  Widget _buildSalaryOfferLetterTab(RegistrationLink link, bool isMobile) {
    final defaultSalarySettings =
        ref.watch(salarySettingsNotifierProvider).valueOrNull ??
            const SalarySettings();
    _initSalaryPercentagesFromDefaults(defaultSalarySettings);

    final totalSalary = double.tryParse(
            _totalSalaryController.text.replaceAll(',', '').trim()) ??
        0.0;
    final basicPay = double.tryParse(
            _basicPayController.text.replaceAll(',', '').trim()) ??
        (totalSalary * 0.50);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Container(
        padding: EdgeInsets.all(isMobile ? 14 : 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFEAECF0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Basic Salary & Total CTC
            const Text(
              'Basic Salary & Total CTC',
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
                  isNumber: true,
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
                _buildSalaryComponentRow(
                  label: 'Basic Pay',
                  basis: '% of Total',
                  amountController: _basicPayController,
                  percentController: _basicPercentController,
                  placeholder: '42500.00',
                  basisValue: totalSalary,
                  isMobile: isMobile,
                ),
                _buildSalaryComponentRow(
                  label: 'House Rent Allowance',
                  basis: '% of Total',
                  amountController: _hraController,
                  percentController: _hraPercentController,
                  placeholder: '21250.00',
                  basisValue: totalSalary,
                  isMobile: isMobile,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRow2or3(
              isMobile: isMobile,
              children: [
                _buildSalaryComponentRow(
                  label: 'Special Allowance',
                  basis: '% of Total',
                  amountController: _specialAllowanceController,
                  percentController: _specialAllowancePercentController,
                  placeholder: '21500.00',
                  basisValue: totalSalary,
                  isMobile: isMobile,
                ),
                _buildSalaryComponentRow(
                  label: 'Education Allowance',
                  basis: '% of Total',
                  amountController: _eduAllowanceController,
                  percentController: _eduAllowancePercentController,
                  placeholder: '0.00',
                  basisValue: totalSalary,
                  isMobile: isMobile,
                  showPercentageField: false,
                ),
                _buildSalaryComponentRow(
                  label: 'Travel Allowance',
                  basis: '% of Total',
                  amountController: _travelAllowanceController,
                  percentController: _travelAllowancePercentController,
                  placeholder: '0.00',
                  basisValue: totalSalary,
                  isMobile: isMobile,
                  showPercentageField: false,
                ),
                _buildSalaryComponentRow(
                  label: 'Other Allowance',
                  basis: '% of Total',
                  amountController: _otherAllowanceController,
                  percentController: _otherAllowancePercentController,
                  placeholder: '0.00',
                  basisValue: totalSalary,
                  isMobile: isMobile,
                  showPercentageField: false,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Excess validation warning
            Builder(
              builder: (context) {
                final total = double.tryParse(
                        _totalSalaryController.text.replaceAll(',', '').trim()) ??
                    0.0;
                if (total <= 0) return const SizedBox(height: 12);
                final additionsTotal = _getAdditionsTotal();
                final excess = additionsTotal - total;
                if (excess > 0.01) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3F2),
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: const Color(0xFFFDA29B)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Color(0xFFD92D20), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Total additions (\u20B9${additionsTotal.toStringAsFixed(2)}) exceed Total Salary (\u20B9${total.toStringAsFixed(2)}) by \u20B9${excess.toStringAsFixed(2)}. Please adjust the values.',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFD92D20),
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if ((additionsTotal - total).abs() < 0.01 &&
                    additionsTotal > 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF3),
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: const Color(0xFF6CE9A6)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline,
                              color: Color(0xFF039855), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Salary breakup is balanced. Total additions = \u20B9${additionsTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF039855),
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox(height: 12);
              },
            ),
            const SizedBox(height: 12),

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
                _buildSalaryComponentRow(
                  label: 'Provident Fund (PF)',
                  basis: '% of Basic',
                  amountController: _pfController,
                  percentController: _pfPercentController,
                  placeholder: '1800.00',
                  basisValue: basicPay,
                  isMobile: isMobile,
                  showPercentageField: false,
                ),
                if (totalSalary > 0 && totalSalary <= 21000) ...[
                  _buildSalaryComponentRow(
                    label: 'Employee State Insurance (ESI)',
                    basis: '% of Basic',
                    amountController: _esiController,
                    percentController: _esiPercentController,
                    placeholder: '0.00',
                    basisValue: basicPay,
                    isMobile: isMobile,
                  ),
                  _buildSalaryComponentRow(
                    label: 'ESI Employer (Company)',
                    basis: 'From Company',
                    amountController: _esiEmployerController,
                    percentController: _esiEmployerPercentController,
                    placeholder: '0.00',
                    basisValue: totalSalary,
                    isMobile: isMobile,
                  ),
                ],
                _buildSalaryComponentRow(
                  label: 'Professional Tax',
                  basis: '% of Total',
                  amountController: _professionalTaxController,
                  percentController: _professionalTaxPercentController,
                  placeholder: '200.00',
                  basisValue: totalSalary,
                  isMobile: isMobile,
                ),
                _buildSalaryComponentRow(
                  label: 'TDS',
                  basis: '% of Total',
                  amountController: _tdsController,
                  percentController: _tdsPercentController,
                  placeholder: '0.00',
                  basisValue: totalSalary,
                  isMobile: isMobile,
                  showPercentageField: false,
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Section 4: Offer Letter Generation
            Container(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFEAECF0)),
              ),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.description_outlined, color: AppColors.primary, size: 28),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
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
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
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
                        ),
                      ],
                    )
                  : Row(
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
                        const SizedBox(width: 16),
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
            const SizedBox(height: 28),
            _buildSaveButtonsRow(link, 'Salary & Compensation'),
          ],
        ),
      ),
    );
  }

  // TAB: WELCOME LETTER
  Widget _buildWelcomeLetterTab(RegistrationLink link, bool isMobile) {
    final empName = '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'.trim();
    final selectedOrg = _organizationName.trim().isNotEmpty
        ? _organizationName.trim()
        : (link.organizationName.isNotEmpty ? link.organizationName : 'IGreen Technologies');

    final data = WelcomeLetterData(
      organizationName: selectedOrg,
      employeeName: empName.isNotEmpty ? empName : 'Employee',
      reportingManagerName: _reportingToController.text.trim().isNotEmpty && _reportingToController.text.trim() != 'None'
          ? _reportingToController.text.trim()
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
      weeklyOffDay: _weeklyOffDayController.text.trim(),
    );

    final dateStr = DateFormat('MMMM dd, yyyy').format(DateTime.now());

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFEAECF0)),
            ),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.active,
                                side: const BorderSide(color: AppColors.active),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.active,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                              onPressed: () => WelcomeLetterGenerator.downloadWelcomeLetter(context, data),
                              icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                              label: const Text('Generate PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      const Icon(Icons.mark_email_read_outlined, color: AppColors.active, size: 28),
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
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              padding: EdgeInsets.all(isMobile ? 14 : 44),
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
                      children: [
                        Text(
                          selectedOrg.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isMobile ? 18 : 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'OFFICIAL WELCOME LETTER',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isMobile ? 10 : 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                            color: AppColors.active,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isMobile ? 16 : 24),
                  const Divider(color: Color(0xFFE2E8F0), thickness: 1),
                  SizedBox(height: isMobile ? 14 : 20),

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

                  // Paragraph 2: Welcome to Organization Name! ...
                  Text(
                    'Welcome to $selectedOrg! We are excited to have you on board and look forward to working with you.',
                    style: const TextStyle(
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
                          text: data.weeklyOffDay.trim().isNotEmpty
                              ? '${data.officeStartTime} to ${data.officeEndTime} (${data.weeklyOffDay.trim()} Holiday)'
                              : '${data.officeStartTime} to ${data.officeEndTime}',
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
                  Text(
                    '$selectedOrg Team',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildSaveButtonsRow(link, 'Welcome Letter'),
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
      phoneNumber: _formatPhoneWithCountryCode(_phoneCountryCode, _phoneController.text),
      gender: _gender,
      dob: _dobController.text.trim(),
      organizationName: _organizationName.trim().isNotEmpty
          ? _organizationName.trim()
          : (link.organizationName.isNotEmpty ? link.organizationName : 'IGreentec Engg. India Pvt. Ltd.'),
      workLocation: _workLocation.trim().isNotEmpty ? _workLocation.trim() : 'Chennai Office',
      businessUnit: _businessUnit.trim(),
      department: _department,
      designation: _designation,
      employmentType: 'Full-Time',
      joiningDate: _joiningDateController.text.trim(),
      status: _status,
      bloodGroup: _bloodGroup,
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
      personalMobile: _formatPhoneWithCountryCode(_personalMobileCountryCode, _personalMobileController.text),
      passportNumber: _passportController.text.trim(),
      drivingLicenseNumber: _drivingLicenseController.text.trim(),
      drivingLicenseBatch: '',
      healthIssues: _healthIssuesController.text.trim(),
      emergencyName: _emergencyNameController.text.trim(),
      emergencyMobile: _formatPhoneWithCountryCode(_emergencyMobileCountryCode, _emergencyMobileController.text),
      referredByName: _referredByNameController.text.trim(),
      referredByMobile: _formatPhoneWithCountryCode(_referredByMobileCountryCode, _referredByMobileController.text),
      fatherName: _fatherNameController.text.trim(),
      motherName: _motherNameController.text.trim(),
      maritalStatus: _maritalStatus,
      spouseName: _spouseNameController.text.trim(),
      kids1Name: _kids1NameController.text.trim(),
      kids2Name: _kids2NameController.text.trim(),
      kids3Name: _kids3NameController.text.trim(),
      hasCriminalCases: _hasCriminalCases,
      criminalCaseDetails: _hasCriminalCases ? _criminalCaseDetailsController.text.trim() : '',
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
      reportingManager: _reportingToController.text.trim(),
      reportingManagerTitle: _reportingManagerTitleController.text.trim(),
      adminName: _adminNameController.text.trim(),
      coordinatorName: _coordinatorNameController.text.trim(),
      coordinatorPhone: _formatPhoneWithCountryCode(_coordinatorPhoneCountryCode, _coordinatorPhoneController.text),
      inTime: _workScheduleType == 'Fixed Schedule' ? _inTimeController.text.trim() : '',
      outTime: _workScheduleType == 'Fixed Schedule' ? _outTimeController.text.trim() : '',
      requiredWorkingHours: double.tryParse(_requiredWorkingHoursController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 9.0,
      weeklyOffDay: _weeklyOffDayController.text.trim(),
      salaryType: _salaryType,
      salaryTotalCtc: double.tryParse(_totalSalaryController.text.trim().replaceAll(',', '')) ?? 0.0,
      salaryBasic: double.tryParse(_basicPayController.text.trim().replaceAll(',', '')) ?? 0.0,
      salaryHra: double.tryParse(_hraController.text.trim().replaceAll(',', '')) ?? 0.0,
      salaryEducationAllowance: double.tryParse(_eduAllowanceController.text.trim().replaceAll(',', '')) ?? 0.0,
      salarySpecialAllowance: double.tryParse(_specialAllowanceController.text.trim().replaceAll(',', '')) ?? 0.0,
      salaryTravelAllowance: double.tryParse(_travelAllowanceController.text.trim().replaceAll(',', '')) ?? 0.0,
      salaryTax: double.tryParse(_tdsController.text.trim().replaceAll(',', '')) ?? 0.0,
      salaryPf: double.tryParse(_pfController.text.trim().replaceAll(',', '')) ?? 0.0,
      salaryEsi: double.tryParse(_esiController.text.trim().replaceAll(',', '')) ?? 0.0,
      salaryEsiEmployer: double.tryParse(_esiEmployerController.text.trim().replaceAll(',', '')) ?? 0.0,
      salaryProfessionalTax: double.tryParse(_professionalTaxController.text.trim().replaceAll(',', '')) ?? 0.0,
      isStaticEmployee: _workScheduleType == 'Fixed Schedule',
      isDynamicEmployee: _workScheduleType == 'Flexible Schedule',
      siteLatitude: (_selectedPermissions.contains('Site Visit Attendance') || _selectedPermissions.contains('Site Visit Attendance Management')) ? (AttendanceLocationFields.parseCoordinate(_siteLatitudeController.text) ?? 0.0) : 0.0,
      siteLongitude: (_selectedPermissions.contains('Site Visit Attendance') || _selectedPermissions.contains('Site Visit Attendance Management')) ? (AttendanceLocationFields.parseCoordinate(_siteLongitudeController.text) ?? 0.0) : 0.0,
      siteAllowedRadiusMeters: (_selectedPermissions.contains('Site Visit Attendance') || _selectedPermissions.contains('Site Visit Attendance Management')) ? (int.tryParse(_siteRadiusController.text.trim()) ?? 15) : 15,
      siteRequireGpsVerification: (_selectedPermissions.contains('Site Visit Attendance') || _selectedPermissions.contains('Site Visit Attendance Management')) ? _siteRequireGpsVerification : true,
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
              _buildSaveButtonsRow(link ?? const RegistrationLink(id: 0, linkId: '', generatedBy: '', generatedDate: '', expiryDate: '', linkStatus: '', organizationName: '', department: ''), 'Credentials', saveLabel: 'Save Credentials'),
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
              _buildSaveButtonsRow(link ?? const RegistrationLink(id: 0, linkId: '', generatedBy: '', generatedDate: '', expiryDate: '', linkStatus: '', organizationName: '', department: ''), 'Access Permissions', saveLabel: 'Save Permissions'),
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

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

