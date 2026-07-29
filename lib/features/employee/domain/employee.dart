import 'dart:convert';

class EducationItem {
  const EducationItem({
    required this.id,
    required this.degreeName,
    required this.instituteName,
    required this.result,
    required this.passingYear,
    this.certificateName = '',
  });

  final String id;
  final String degreeName;
  final String instituteName;
  final String result;
  final String passingYear;
  final String certificateName;

  Map<String, dynamic> toMap() => {
        'id': id,
        'degree_name': degreeName,
        'institute_name': instituteName,
        'result': result,
        'passing_year': passingYear,
        'certificate_name': certificateName,
      };

  factory EducationItem.fromMap(Map<String, dynamic> map) => EducationItem(
        id: map['id'] as String? ?? '',
        degreeName: map['degree_name'] as String? ?? '',
        instituteName: map['institute_name'] as String? ?? '',
        result: map['result'] as String? ?? '',
        passingYear: map['passing_year'] as String? ?? '',
        certificateName: map['certificate_name'] as String? ?? '',
      );
}

class ExperienceItem {
  const ExperienceItem({
    required this.id,
    required this.companyName,
    required this.position,
    required this.address,
    required this.workingDuration,
  });

  final String id;
  final String companyName;
  final String position;
  final String address;
  final String workingDuration;

  Map<String, dynamic> toMap() => {
        'id': id,
        'company_name': companyName,
        'position': position,
        'address': address,
        'working_duration': workingDuration,
      };

  factory ExperienceItem.fromMap(Map<String, dynamic> map) => ExperienceItem(
        id: map['id'] as String? ?? '',
        companyName: map['company_name'] as String? ?? '',
        position: map['position'] as String? ?? '',
        address: map['address'] as String? ?? '',
        workingDuration: map['working_duration'] as String? ?? '',
      );
}

class DocumentItem {
  const DocumentItem({
    required this.id,
    required this.documentType,
    required this.documentNumber,
    required this.fileName,
    required this.uploadedDate,
  });

  final String id;
  final String documentType;
  final String documentNumber;
  final String fileName;
  final String uploadedDate;

  Map<String, dynamic> toMap() => {
        'id': id,
        'document_type': documentType,
        'document_number': documentNumber,
        'file_name': fileName,
        'uploaded_date': uploadedDate,
      };

  factory DocumentItem.fromMap(Map<String, dynamic> map) => DocumentItem(
        id: map['id'] as String? ?? '',
        documentType: map['document_type'] as String? ?? '',
        documentNumber: map['document_number'] as String? ?? '',
        fileName: map['file_name'] as String? ?? '',
        uploadedDate: map['uploaded_date'] as String? ?? '',
      );
}

class Employee {
  const Employee({
    required this.id,
    required this.employeeId,
    required this.firstName,
    required this.lastName,
    required this.emailAddress,
    required this.phoneNumber,
    required this.gender,
    required this.dob,
    required this.organizationName,
    required this.department,
    required this.designation,
    required this.employmentType,
    required this.joiningDate,
    required this.status,
    this.bloodGroup = '',
    this.userType = 'EMPLOYEE',
    this.contractEndDate = '',
    this.profileImageUrl = '',
    this.street = '',
    this.city = '',
    this.state = '',
    this.postalCode = '',
    this.country = 'India',
    this.permanentAddress = '',
    this.permanentCity = '',
    this.permanentCountry = 'India',
    this.sameAsPermanent = false,
    this.presentAddress = '',
    this.presentCity = '',
    this.presentCountry = 'India',
    this.educationDegree = '',
    this.educationInstitution = '',
    this.educationYear = '',
    this.educationGrade = '',
    this.educationListJson = '',
    this.experienceCompany = '',
    this.experienceRole = '',
    this.experienceYears = '',
    this.experienceListJson = '',
    this.originalDob = '',
    this.personalMobile = '',
    this.passportNumber = '',
    this.drivingLicenseNumber = '',
    this.drivingLicenseBatch = '',
    this.healthIssues = '',
    this.emergencyName = '',
    this.emergencyMobile = '',
    this.referredByName = '',
    this.referredByMobile = '',
    this.fatherName = '',
    this.motherName = '',
    this.maritalStatus = 'Unmarried',
    this.spouseName = '',
    this.kids1Name = '',
    this.kids2Name = '',
    this.kids3Name = '',
    this.bankAccountHolder = '',
    this.bankName = '',
    this.bankAccountNumber = '',
    this.bankIfsc = '',
    this.bankBranch = '',
    this.bankAccountType = 'Savings',
    this.panNumber = '',
    this.aadhaarNumber = '',
    this.eduCertificatesUrl = '',
    this.bloodGroupReport = '',
    this.documentListJson = '',
    this.facebookUrl = '',
    this.twitterUrl = '',
    this.linkedinUrl = '',
    this.googleUrl = '',
    this.personalHistoryDetails = '',
    this.salaryType = 'Monthly',
    this.salaryBasic = 0.0,
    this.salaryHra = 0.0,
    this.salaryEducationAllowance = 0.0,
    this.salarySpecialAllowance = 0.0,
    this.salaryAllowances = 0.0,
    this.salaryTax = 0.0,
    this.salaryPf = 0.0,
    this.salaryTotalCtc = 0.0,
    this.insurancePolicyNo = '',
    this.insuranceProvider = '',
    this.insuranceCoverage = 0.0,
    this.pfNumber = '',
    this.pfUan = '',
    this.esiNumber = '',
    this.leaveDetails = '',
    this.leaveType = 'As Needed',
    this.leaveAllocationFrequency = 'Monthly',
    this.allowedLeaves = 1.0,
    this.effectiveDate = '',
    this.companyAssets = '',
    this.reportingManager = '',
    this.teamName = '',
    this.disciplinaryRecords = '',
    this.temporaryPassword = '',
    this.accessPermissions = const [],
  });

  static const List<String> allSidebarPermissions = [
    'Home',
    'Organization Management',
    'Organization Structure',
    'Responses',
    'Employee Management',
    'Leave',
    'Leave Management',
    'Loan',
    'Pay Slip',
    'Items',
    'Inventory Adjustments',
    'Customers',
    'Quotes',
    'Sales Orders',
    'Invoices',
    'Delivery Challans',
    'Payments Received',
    'Credit Notes',
    'e-Way Bills',
    'Vendors',
    'Expenses',
    'Purchase Orders',
    'Bills',
  ];

  static const Map<String, List<String>> sidebarPermissionsByCategory = {
    'OVERVIEW': [
      'Home',
    ],
    'ORGANIZATION': [
      'Organization Management',
      'Organization Structure',
    ],
    'EMPLOYEE': [
      'Responses',
      'Employee Management',
      'Leave',
      'Leave Management',
      'Loan',
      'Pay Slip',
    ],
    'STOCK': [
      'Items',
      'Inventory Adjustments',
    ],
    'SALES': [
      'Customers',
      'Quotes',
      'Sales Orders',
      'Invoices',
      'Delivery Challans',
      'Payments Received',
      'Credit Notes',
      'e-Way Bills',
    ],
    'PURCHASE': [
      'Vendors',
      'Expenses',
      'Purchase Orders',
      'Bills',
    ],
  };

  static const List<String> departmentOptions = [
    'Administration',
    'Human Resources',
    'Information Technology',
    'Admin Support',
    'Management',
    'Finance',
    'Project',
    'Execution',
    'Business Development',
    'Production Unit',
    'Production Support',
    'Labour',
    'Others',
  ];

  static const List<String> designationOptions = [
    'Coordinator',
    'Finance Head',
    'Sr. Accountant',
    'Admin Assistant',
    'Office Assistant',
    'Sales Executive',
    'Company Director',
    'Manager',
    'Site Coordinator',
    'Sr. Site Coordinator',
    'Rig Operator',
    'Bore Path Specialist',
    'Site Coordinator - Trainee',
    'Tracker',
    'Sr. Project Coordinator',
    'Business Development Executive',
    'Driver',
    'Accounts Assistant',
    'Assistant Manager',
    'Lathe Operator',
    'Welder',
    'Milling and Lathe Operator',
    'Technical Head',
    'Operator',
    'Sr. Labourer',
    'Trainee',
    'Cook',
    'Executive',
    'Helper',
    'Consultant',
    'Project Lead',
    'Back Office - Executive',
    'Associate',
    'VMC Programmer',
    'Store In-Charge',
    'Relationship Manager',
    'CNC Programmer',
    'CNC Operator',
    'VMC Operator',
    'Fitter',
    'Grinder',
    'Rigger',
    'Purchase Executive',
    'Milling Operator',
    'Factory Coordinator',
    'CAD Designer',
    'Project Assistant',
    'Sr. Admin Executive',
    'Junior Accountant',
    'Supervisor',
    'Factory Manager',
  ];

  static const List<String> leaveTypeOptions = [
    'As Needed',
    'Once a Month',
    'No Leave',
  ];

  final int id;
  final String employeeId;
  final String firstName;
  final String lastName;
  final String emailAddress;
  final String phoneNumber;
  final String gender;
  final String dob;
  final String organizationName;
  final String department;
  final String designation;
  final String employmentType;
  final String joiningDate;
  final String status;

  final String bloodGroup;
  final String userType;
  final String contractEndDate;
  final String profileImageUrl;

  final String street;
  final String city;
  final String state;
  final String postalCode;
  final String country;

  final String permanentAddress;
  final String permanentCity;
  final String permanentCountry;
  final bool sameAsPermanent;
  final String presentAddress;
  final String presentCity;
  final String presentCountry;

  final String educationDegree;
  final String educationInstitution;
  final String educationYear;
  final String educationGrade;
  final String educationListJson;

  final String experienceCompany;
  final String experienceRole;
  final String experienceYears;
  final String experienceListJson;

  final String originalDob;
  final String personalMobile;
  final String passportNumber;
  final String drivingLicenseNumber;
  final String drivingLicenseBatch;
  final String healthIssues;
  final String emergencyName;
  final String emergencyMobile;
  final String referredByName;
  final String referredByMobile;
  final String fatherName;
  final String motherName;
  final String maritalStatus;
  final String spouseName;
  final String kids1Name;
  final String kids2Name;
  final String kids3Name;

  final String bankAccountHolder;
  final String bankName;
  final String bankAccountNumber;
  final String bankIfsc;
  final String bankBranch;
  final String bankAccountType;

  final String panNumber;
  final String aadhaarNumber;
  final String eduCertificatesUrl;
  final String bloodGroupReport;
  final String documentListJson;

  final String facebookUrl;
  final String twitterUrl;
  final String linkedinUrl;
  final String googleUrl;

  final String personalHistoryDetails;

  final String salaryType;
  final double salaryBasic;
  final double salaryHra;
  final double salaryEducationAllowance;
  final double salarySpecialAllowance;
  final double salaryAllowances;
  final double salaryTax;
  final double salaryPf;
  final double salaryTotalCtc;

  final String insurancePolicyNo;
  final String insuranceProvider;
  final double insuranceCoverage;

  final String pfNumber;
  final String pfUan;
  final String esiNumber;

  final String leaveDetails;
  final String leaveType;
  final String leaveAllocationFrequency;
  final double allowedLeaves;
  final String effectiveDate;
  final String companyAssets;

  final String reportingManager;
  final String teamName;

  final String disciplinaryRecords;
  final String temporaryPassword;
  final List<String> accessPermissions;

  String get fullName => '$firstName $lastName'.trim();

  List<EducationItem> get educationItems {
    if (educationListJson.isEmpty) return [];
    try {
      final decoded = jsonDecode(educationListJson) as List;
      return decoded.map((e) => EducationItem.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  List<ExperienceItem> get experienceItems {
    if (experienceListJson.isEmpty) return [];
    try {
      final decoded = jsonDecode(experienceListJson) as List;
      return decoded.map((e) => ExperienceItem.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  List<DocumentItem> get documentItems {
    if (documentListJson.isEmpty) return [];
    try {
      final decoded = jsonDecode(documentListJson) as List;
      return decoded.map((e) => DocumentItem.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != 0) 'id': id,
      'employee_id': employeeId,
      'first_name': firstName,
      'last_name': lastName,
      'email_address': emailAddress,
      'phone_number': phoneNumber,
      'gender': gender,
      'dob': dob,
      'organization_name': organizationName,
      'department': department,
      'designation': designation,
      'employment_type': employmentType,
      'joining_date': joiningDate,
      'status': status,
      'blood_group': bloodGroup,
      'user_type': userType,
      'contract_end_date': contractEndDate,
      'profile_image_url': profileImageUrl,
      'street': street,
      'city': city,
      'state': state,
      'postal_code': postalCode,
      'country': country,
      'permanent_address': permanentAddress,
      'permanent_city': permanentCity,
      'permanent_country': permanentCountry,
      'same_as_permanent': sameAsPermanent ? 1 : 0,
      'present_address': presentAddress,
      'present_city': presentCity,
      'present_country': presentCountry,
      'education_degree': educationDegree,
      'education_institution': educationInstitution,
      'education_year': educationYear,
      'education_grade': educationGrade,
      'education_list_json': educationListJson,
      'experience_company': experienceCompany,
      'experience_role': experienceRole,
      'experience_years': experienceYears,
      'experience_list_json': experienceListJson,
      'original_dob': originalDob,
      'personal_mobile': personalMobile,
      'passport_number': passportNumber,
      'driving_license_number': drivingLicenseNumber,
      'driving_license_batch': drivingLicenseBatch,
      'health_issues': healthIssues,
      'emergency_name': emergencyName,
      'emergency_mobile': emergencyMobile,
      'referred_by_name': referredByName,
      'referred_by_mobile': referredByMobile,
      'father_name': fatherName,
      'mother_name': motherName,
      'marital_status': maritalStatus,
      'spouse_name': spouseName,
      'kids1_name': kids1Name,
      'kids2_name': kids2Name,
      'kids3_name': kids3Name,
      'bank_account_holder': bankAccountHolder,
      'bank_name': bankName,
      'bank_account_number': bankAccountNumber,
      'bank_ifsc': bankIfsc,
      'bank_branch': bankBranch,
      'bank_account_type': bankAccountType,
      'pan_number': panNumber,
      'aadhaar_number': aadhaarNumber,
      'edu_certificates_url': eduCertificatesUrl,
      'blood_group_report': bloodGroupReport,
      'document_list_json': documentListJson,
      'facebook_url': facebookUrl,
      'twitter_url': twitterUrl,
      'linkedin_url': linkedinUrl,
      'google_url': googleUrl,
      'personal_history_details': personalHistoryDetails,
      'salary_type': salaryType,
      'salary_basic': salaryBasic,
      'salary_hra': salaryHra,
      'salary_education_allowance': salaryEducationAllowance,
      'salary_special_allowance': salarySpecialAllowance,
      'salary_allowances': salaryAllowances,
      'salary_tax': salaryTax,
      'salary_pf': salaryPf,
      'salary_total_ctc': salaryTotalCtc,
      'insurance_policy_no': insurancePolicyNo,
      'insurance_provider': insuranceProvider,
      'insurance_coverage': insuranceCoverage,
      'pf_number': pfNumber,
      'pf_uan': pfUan,
      'esi_number': esiNumber,
      'leave_details': leaveDetails,
      'leave_type': leaveType,
      'leave_allocation_frequency': leaveAllocationFrequency,
      'allowed_leaves': allowedLeaves,
      'effective_date': effectiveDate,
      'company_assets': companyAssets,
      'reporting_manager': reportingManager,
      'team_name': teamName,
      'disciplinary_records': disciplinaryRecords,
      'temporary_password': temporaryPassword,
      'access_permissions': jsonEncode(accessPermissions),
    };
  }

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'] as int? ?? 0,
      employeeId: map['employee_id'] as String? ?? '',
      firstName: map['first_name'] as String? ?? '',
      lastName: map['last_name'] as String? ?? '',
      emailAddress: map['email_address'] as String? ?? '',
      phoneNumber: map['phone_number'] as String? ?? '',
      gender: map['gender'] as String? ?? '',
      dob: map['dob'] as String? ?? '',
      organizationName: map['organization_name'] as String? ?? '',
      department: map['department'] as String? ?? '',
      designation: map['designation'] as String? ?? '',
      employmentType: map['employment_type'] as String? ?? 'Full-Time',
      joiningDate: map['joining_date'] as String? ?? '',
      status: map['status'] as String? ?? 'Active',
      bloodGroup: map['blood_group'] as String? ?? '',
      userType: map['user_type'] as String? ?? 'EMPLOYEE',
      contractEndDate: map['contract_end_date'] as String? ?? '',
      profileImageUrl: map['profile_image_url'] as String? ?? '',
      street: map['street'] as String? ?? '',
      city: map['city'] as String? ?? '',
      state: map['state'] as String? ?? '',
      postalCode: map['postal_code'] as String? ?? '',
      country: map['country'] as String? ?? 'India',
      permanentAddress: map['permanent_address'] as String? ?? '',
      permanentCity: map['permanent_city'] as String? ?? '',
      permanentCountry: map['permanent_country'] as String? ?? 'India',
      sameAsPermanent: (map['same_as_permanent'] as int? ?? 0) == 1,
      presentAddress: map['present_address'] as String? ?? '',
      presentCity: map['present_city'] as String? ?? '',
      presentCountry: map['present_country'] as String? ?? 'India',
      educationDegree: map['education_degree'] as String? ?? '',
      educationInstitution: map['education_institution'] as String? ?? '',
      educationYear: map['education_year'] as String? ?? '',
      educationGrade: map['education_grade'] as String? ?? '',
      educationListJson: map['education_list_json'] as String? ?? '',
      experienceCompany: map['experience_company'] as String? ?? '',
      experienceRole: map['experience_role'] as String? ?? '',
      experienceYears: map['experience_years'] as String? ?? '',
      experienceListJson: map['experience_list_json'] as String? ?? '',
      originalDob: map['original_dob'] as String? ?? '',
      personalMobile: map['personal_mobile'] as String? ?? '',
      passportNumber: map['passport_number'] as String? ?? '',
      drivingLicenseNumber: map['driving_license_number'] as String? ?? '',
      drivingLicenseBatch: map['driving_license_batch'] as String? ?? '',
      healthIssues: map['health_issues'] as String? ?? '',
      emergencyName: map['emergency_name'] as String? ?? '',
      emergencyMobile: map['emergency_mobile'] as String? ?? '',
      referredByName: map['referred_by_name'] as String? ?? '',
      referredByMobile: map['referred_by_mobile'] as String? ?? '',
      fatherName: map['father_name'] as String? ?? '',
      motherName: map['mother_name'] as String? ?? '',
      maritalStatus: map['marital_status'] as String? ?? 'Unmarried',
      spouseName: map['spouse_name'] as String? ?? '',
      kids1Name: map['kids1_name'] as String? ?? '',
      kids2Name: map['kids2_name'] as String? ?? '',
      kids3Name: map['kids3_name'] as String? ?? '',
      bankAccountHolder: map['bank_account_holder'] as String? ?? '',
      bankName: map['bank_name'] as String? ?? '',
      bankAccountNumber: map['bank_account_number'] as String? ?? '',
      bankIfsc: map['bank_ifsc'] as String? ?? '',
      bankBranch: map['bank_branch'] as String? ?? '',
      bankAccountType: map['bank_account_type'] as String? ?? 'Savings',
      panNumber: map['pan_number'] as String? ?? '',
      aadhaarNumber: map['aadhaar_number'] as String? ?? '',
      eduCertificatesUrl: map['edu_certificates_url'] as String? ?? '',
      bloodGroupReport: map['blood_group_report'] as String? ?? '',
      documentListJson: map['document_list_json'] as String? ?? '',
      facebookUrl: map['facebook_url'] as String? ?? '',
      twitterUrl: map['twitter_url'] as String? ?? '',
      linkedinUrl: map['linkedin_url'] as String? ?? '',
      googleUrl: map['google_url'] as String? ?? '',
      personalHistoryDetails: map['personal_history_details'] as String? ?? '',
      salaryType: map['salary_type'] as String? ?? 'Monthly',
      salaryBasic: (map['salary_basic'] as num?)?.toDouble() ?? 0.0,
      salaryHra: (map['salary_hra'] as num?)?.toDouble() ?? 0.0,
      salaryEducationAllowance: (map['salary_education_allowance'] as num?)?.toDouble() ?? 0.0,
      salarySpecialAllowance: (map['salary_special_allowance'] as num?)?.toDouble() ?? 0.0,
      salaryAllowances: (map['salary_allowances'] as num?)?.toDouble() ?? 0.0,
      salaryTax: (map['salary_tax'] as num?)?.toDouble() ?? 0.0,
      salaryPf: (map['salary_pf'] as num?)?.toDouble() ?? 0.0,
      salaryTotalCtc: (map['salary_total_ctc'] as num?)?.toDouble() ?? 0.0,
      insurancePolicyNo: map['insurance_policy_no'] as String? ?? '',
      insuranceProvider: map['insurance_provider'] as String? ?? '',
      insuranceCoverage: (map['insurance_coverage'] as num?)?.toDouble() ?? 0.0,
      pfNumber: map['pf_number'] as String? ?? '',
      pfUan: map['pf_uan'] as String? ?? '',
      esiNumber: map['esi_number'] as String? ?? '',
      leaveDetails: map['leave_details'] as String? ?? '',
      leaveType: map['leave_type'] as String? ?? 'As Needed',
      leaveAllocationFrequency: map['leave_allocation_frequency'] as String? ?? 'Monthly',
      allowedLeaves: (map['allowed_leaves'] as num?)?.toDouble() ?? 1.0,
      effectiveDate: map['effective_date'] as String? ?? '',
      companyAssets: map['company_assets'] as String? ?? '',
      reportingManager: map['reporting_manager'] as String? ?? '',
      teamName: map['team_name'] as String? ?? '',
      disciplinaryRecords: map['disciplinary_records'] as String? ?? '',
      temporaryPassword: map['temporary_password'] as String? ?? '',
      accessPermissions: map['access_permissions'] != null && (map['access_permissions'] as String).isNotEmpty
          ? () {
              try {
                final decoded = jsonDecode(map['access_permissions'] as String);
                if (decoded is List) {
                  return decoded.map((e) => e.toString()).toList();
                }
              } catch (_) {}
              return <String>[];
            }()
          : <String>[],
    );
  }

  Employee copyWith({
    int? id,
    String? employeeId,
    String? firstName,
    String? lastName,
    String? emailAddress,
    String? phoneNumber,
    String? gender,
    String? dob,
    String? organizationName,
    String? department,
    String? designation,
    String? employmentType,
    String? joiningDate,
    String? status,
    String? bloodGroup,
    String? userType,
    String? contractEndDate,
    String? profileImageUrl,
    String? street,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    String? permanentAddress,
    String? permanentCity,
    String? permanentCountry,
    bool? sameAsPermanent,
    String? presentAddress,
    String? presentCity,
    String? presentCountry,
    String? educationDegree,
    String? educationInstitution,
    String? educationYear,
    String? educationGrade,
    String? educationListJson,
    String? experienceCompany,
    String? experienceRole,
    String? experienceYears,
    String? experienceListJson,
    String? originalDob,
    String? personalMobile,
    String? passportNumber,
    String? drivingLicenseNumber,
    String? drivingLicenseBatch,
    String? healthIssues,
    String? emergencyName,
    String? emergencyMobile,
    String? referredByName,
    String? referredByMobile,
    String? fatherName,
    String? motherName,
    String? maritalStatus,
    String? spouseName,
    String? kids1Name,
    String? kids2Name,
    String? kids3Name,
    String? bankAccountHolder,
    String? bankName,
    String? bankAccountNumber,
    String? bankIfsc,
    String? bankBranch,
    String? bankAccountType,
    String? panNumber,
    String? aadhaarNumber,
    String? eduCertificatesUrl,
    String? bloodGroupReport,
    String? documentListJson,
    String? facebookUrl,
    String? twitterUrl,
    String? linkedinUrl,
    String? googleUrl,
    String? personalHistoryDetails,
    double? salaryBasic,
    double? salaryHra,
    double? salaryAllowances,
    double? salaryTotalCtc,
    String? insurancePolicyNo,
    String? insuranceProvider,
    double? insuranceCoverage,
    String? pfNumber,
    String? pfUan,
    String? esiNumber,
    String? leaveDetails,
    String? leaveType,
    String? leaveAllocationFrequency,
    double? allowedLeaves,
    String? effectiveDate,
    String? companyAssets,
    String? reportingManager,
    String? teamName,
    String? disciplinaryRecords,
    String? temporaryPassword,
    List<String>? accessPermissions,
  }) {
    return Employee(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      emailAddress: emailAddress ?? this.emailAddress,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      gender: gender ?? this.gender,
      dob: dob ?? this.dob,
      organizationName: organizationName ?? this.organizationName,
      department: department ?? this.department,
      designation: designation ?? this.designation,
      employmentType: employmentType ?? this.employmentType,
      joiningDate: joiningDate ?? this.joiningDate,
      status: status ?? this.status,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      userType: userType ?? this.userType,
      contractEndDate: contractEndDate ?? this.contractEndDate,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      street: street ?? this.street,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      permanentAddress: permanentAddress ?? this.permanentAddress,
      permanentCity: permanentCity ?? this.permanentCity,
      permanentCountry: permanentCountry ?? this.permanentCountry,
      sameAsPermanent: sameAsPermanent ?? this.sameAsPermanent,
      presentAddress: presentAddress ?? this.presentAddress,
      presentCity: presentCity ?? this.presentCity,
      presentCountry: presentCountry ?? this.presentCountry,
      educationDegree: educationDegree ?? this.educationDegree,
      educationInstitution: educationInstitution ?? this.educationInstitution,
      educationYear: educationYear ?? this.educationYear,
      educationGrade: educationGrade ?? this.educationGrade,
      educationListJson: educationListJson ?? this.educationListJson,
      experienceCompany: experienceCompany ?? this.experienceCompany,
      experienceRole: experienceRole ?? this.experienceRole,
      experienceYears: experienceYears ?? this.experienceYears,
      experienceListJson: experienceListJson ?? this.experienceListJson,
      originalDob: originalDob ?? this.originalDob,
      personalMobile: personalMobile ?? this.personalMobile,
      passportNumber: passportNumber ?? this.passportNumber,
      drivingLicenseNumber: drivingLicenseNumber ?? this.drivingLicenseNumber,
      drivingLicenseBatch: drivingLicenseBatch ?? this.drivingLicenseBatch,
      healthIssues: healthIssues ?? this.healthIssues,
      emergencyName: emergencyName ?? this.emergencyName,
      emergencyMobile: emergencyMobile ?? this.emergencyMobile,
      referredByName: referredByName ?? this.referredByName,
      referredByMobile: referredByMobile ?? this.referredByMobile,
      fatherName: fatherName ?? this.fatherName,
      motherName: motherName ?? this.motherName,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      spouseName: spouseName ?? this.spouseName,
      kids1Name: kids1Name ?? this.kids1Name,
      kids2Name: kids2Name ?? this.kids2Name,
      kids3Name: kids3Name ?? this.kids3Name,
      bankAccountHolder: bankAccountHolder ?? this.bankAccountHolder,
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankIfsc: bankIfsc ?? this.bankIfsc,
      bankBranch: bankBranch ?? this.bankBranch,
      bankAccountType: bankAccountType ?? this.bankAccountType,
      panNumber: panNumber ?? this.panNumber,
      aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
      eduCertificatesUrl: eduCertificatesUrl ?? this.eduCertificatesUrl,
      bloodGroupReport: bloodGroupReport ?? this.bloodGroupReport,
      documentListJson: documentListJson ?? this.documentListJson,
      facebookUrl: facebookUrl ?? this.facebookUrl,
      twitterUrl: twitterUrl ?? this.twitterUrl,
      linkedinUrl: linkedinUrl ?? this.linkedinUrl,
      googleUrl: googleUrl ?? this.googleUrl,
      personalHistoryDetails: personalHistoryDetails ?? this.personalHistoryDetails,
      salaryBasic: salaryBasic ?? this.salaryBasic,
      salaryHra: salaryHra ?? this.salaryHra,
      salaryAllowances: salaryAllowances ?? this.salaryAllowances,
      salaryTotalCtc: salaryTotalCtc ?? this.salaryTotalCtc,
      insurancePolicyNo: insurancePolicyNo ?? this.insurancePolicyNo,
      insuranceProvider: insuranceProvider ?? this.insuranceProvider,
      insuranceCoverage: insuranceCoverage ?? this.insuranceCoverage,
      pfNumber: pfNumber ?? this.pfNumber,
      pfUan: pfUan ?? this.pfUan,
      esiNumber: esiNumber ?? this.esiNumber,
      leaveDetails: leaveDetails ?? this.leaveDetails,
      leaveType: leaveType ?? this.leaveType,
      leaveAllocationFrequency: leaveAllocationFrequency ?? this.leaveAllocationFrequency,
      allowedLeaves: allowedLeaves ?? this.allowedLeaves,
      effectiveDate: effectiveDate ?? this.effectiveDate,
      companyAssets: companyAssets ?? this.companyAssets,
      reportingManager: reportingManager ?? this.reportingManager,
      teamName: teamName ?? this.teamName,
      disciplinaryRecords: disciplinaryRecords ?? this.disciplinaryRecords,
      temporaryPassword: temporaryPassword ?? this.temporaryPassword,
      accessPermissions: accessPermissions ?? this.accessPermissions,
    );
  }
}
