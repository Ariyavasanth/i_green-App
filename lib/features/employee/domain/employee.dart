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
    this.street = '',
    this.city = '',
    this.state = '',
    this.postalCode = '',
    this.country = 'India',
    this.educationDegree = '',
    this.educationInstitution = '',
    this.educationYear = '',
    this.educationGrade = '',
    this.experienceCompany = '',
    this.experienceRole = '',
    this.experienceYears = '',
    this.bankAccountHolder = '',
    this.bankName = '',
    this.bankAccountNumber = '',
    this.bankIfsc = '',
    this.bankBranch = '',
    this.panNumber = '',
    this.aadhaarNumber = '',
    this.eduCertificatesUrl = '',
    this.bloodGroupReport = '',
    this.personalHistoryDetails = '',
    this.salaryBasic = 0.0,
    this.salaryHra = 0.0,
    this.salaryAllowances = 0.0,
    this.salaryTotalCtc = 0.0,
    this.insurancePolicyNo = '',
    this.insuranceProvider = '',
    this.insuranceCoverage = 0.0,
    this.pfNumber = '',
    this.pfUan = '',
    this.esiNumber = '',
    this.leaveDetails = '',
    this.companyAssets = '',
    this.reportingManager = '',
    this.teamName = '',
    this.disciplinaryRecords = '',
    this.temporaryPassword = '',
  });

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

  final String street;
  final String city;
  final String state;
  final String postalCode;
  final String country;

  final String educationDegree;
  final String educationInstitution;
  final String educationYear;
  final String educationGrade;

  final String experienceCompany;
  final String experienceRole;
  final String experienceYears;

  final String bankAccountHolder;
  final String bankName;
  final String bankAccountNumber;
  final String bankIfsc;
  final String bankBranch;

  final String panNumber;
  final String aadhaarNumber;
  final String eduCertificatesUrl;
  final String bloodGroupReport;

  final String personalHistoryDetails;

  final double salaryBasic;
  final double salaryHra;
  final double salaryAllowances;
  final double salaryTotalCtc;

  final String insurancePolicyNo;
  final String insuranceProvider;
  final double insuranceCoverage;

  final String pfNumber;
  final String pfUan;
  final String esiNumber;

  final String leaveDetails;
  final String companyAssets;

  final String reportingManager;
  final String teamName;

  final String disciplinaryRecords;
  final String temporaryPassword;

  String get fullName => '$firstName $lastName'.trim();

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
      'street': street,
      'city': city,
      'state': state,
      'postal_code': postalCode,
      'country': country,
      'education_degree': educationDegree,
      'education_institution': educationInstitution,
      'education_year': educationYear,
      'education_grade': educationGrade,
      'experience_company': experienceCompany,
      'experience_role': experienceRole,
      'experience_years': experienceYears,
      'bank_account_holder': bankAccountHolder,
      'bank_name': bankName,
      'bank_account_number': bankAccountNumber,
      'bank_ifsc': bankIfsc,
      'bank_branch': bankBranch,
      'pan_number': panNumber,
      'aadhaar_number': aadhaarNumber,
      'edu_certificates_url': eduCertificatesUrl,
      'blood_group_report': bloodGroupReport,
      'personal_history_details': personalHistoryDetails,
      'salary_basic': salaryBasic,
      'salary_hra': salaryHra,
      'salary_allowances': salaryAllowances,
      'salary_total_ctc': salaryTotalCtc,
      'insurance_policy_no': insurancePolicyNo,
      'insurance_provider': insuranceProvider,
      'insurance_coverage': insuranceCoverage,
      'pf_number': pfNumber,
      'pf_uan': pfUan,
      'esi_number': esiNumber,
      'leave_details': leaveDetails,
      'company_assets': companyAssets,
      'reporting_manager': reportingManager,
      'team_name': teamName,
      'disciplinary_records': disciplinaryRecords,
      'temporary_password': temporaryPassword,
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
      street: map['street'] as String? ?? '',
      city: map['city'] as String? ?? '',
      state: map['state'] as String? ?? '',
      postalCode: map['postal_code'] as String? ?? '',
      country: map['country'] as String? ?? 'India',
      educationDegree: map['education_degree'] as String? ?? '',
      educationInstitution: map['education_institution'] as String? ?? '',
      educationYear: map['education_year'] as String? ?? '',
      educationGrade: map['education_grade'] as String? ?? '',
      experienceCompany: map['experience_company'] as String? ?? '',
      experienceRole: map['experience_role'] as String? ?? '',
      experienceYears: map['experience_years'] as String? ?? '',
      bankAccountHolder: map['bank_account_holder'] as String? ?? '',
      bankName: map['bank_name'] as String? ?? '',
      bankAccountNumber: map['bank_account_number'] as String? ?? '',
      bankIfsc: map['bank_ifsc'] as String? ?? '',
      bankBranch: map['bank_branch'] as String? ?? '',
      panNumber: map['pan_number'] as String? ?? '',
      aadhaarNumber: map['aadhaar_number'] as String? ?? '',
      eduCertificatesUrl: map['edu_certificates_url'] as String? ?? '',
      bloodGroupReport: map['blood_group_report'] as String? ?? '',
      personalHistoryDetails: map['personal_history_details'] as String? ?? '',
      salaryBasic: (map['salary_basic'] as num?)?.toDouble() ?? 0.0,
      salaryHra: (map['salary_hra'] as num?)?.toDouble() ?? 0.0,
      salaryAllowances: (map['salary_allowances'] as num?)?.toDouble() ?? 0.0,
      salaryTotalCtc: (map['salary_total_ctc'] as num?)?.toDouble() ?? 0.0,
      insurancePolicyNo: map['insurance_policy_no'] as String? ?? '',
      insuranceProvider: map['insurance_provider'] as String? ?? '',
      insuranceCoverage: (map['insurance_coverage'] as num?)?.toDouble() ?? 0.0,
      pfNumber: map['pf_number'] as String? ?? '',
      pfUan: map['pf_uan'] as String? ?? '',
      esiNumber: map['esi_number'] as String? ?? '',
      leaveDetails: map['leave_details'] as String? ?? '',
      companyAssets: map['company_assets'] as String? ?? '',
      reportingManager: map['reporting_manager'] as String? ?? '',
      teamName: map['team_name'] as String? ?? '',
      disciplinaryRecords: map['disciplinary_records'] as String? ?? '',
      temporaryPassword: map['temporary_password'] as String? ?? '',
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
    String? street,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    String? educationDegree,
    String? educationInstitution,
    String? educationYear,
    String? educationGrade,
    String? experienceCompany,
    String? experienceRole,
    String? experienceYears,
    String? bankAccountHolder,
    String? bankName,
    String? bankAccountNumber,
    String? bankIfsc,
    String? bankBranch,
    String? panNumber,
    String? aadhaarNumber,
    String? eduCertificatesUrl,
    String? bloodGroupReport,
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
    String? companyAssets,
    String? reportingManager,
    String? teamName,
    String? disciplinaryRecords,
    String? temporaryPassword,
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
      street: street ?? this.street,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      educationDegree: educationDegree ?? this.educationDegree,
      educationInstitution: educationInstitution ?? this.educationInstitution,
      educationYear: educationYear ?? this.educationYear,
      educationGrade: educationGrade ?? this.educationGrade,
      experienceCompany: experienceCompany ?? this.experienceCompany,
      experienceRole: experienceRole ?? this.experienceRole,
      experienceYears: experienceYears ?? this.experienceYears,
      bankAccountHolder: bankAccountHolder ?? this.bankAccountHolder,
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankIfsc: bankIfsc ?? this.bankIfsc,
      bankBranch: bankBranch ?? this.bankBranch,
      panNumber: panNumber ?? this.panNumber,
      aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
      eduCertificatesUrl: eduCertificatesUrl ?? this.eduCertificatesUrl,
      bloodGroupReport: bloodGroupReport ?? this.bloodGroupReport,
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
      companyAssets: companyAssets ?? this.companyAssets,
      reportingManager: reportingManager ?? this.reportingManager,
      teamName: teamName ?? this.teamName,
      disciplinaryRecords: disciplinaryRecords ?? this.disciplinaryRecords,
      temporaryPassword: temporaryPassword ?? this.temporaryPassword,
    );
  }
}
