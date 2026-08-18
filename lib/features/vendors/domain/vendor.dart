class VendorAddress {
  const VendorAddress({
    this.id,
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.city = '',
    this.state = '',
    this.country = 'India',
    this.pinCode = '',
  });

  final int? id;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String state;
  final String country;
  final String pinCode;

  VendorAddress copyWith({
    int? id,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? country,
    String? pinCode,
  }) {
    return VendorAddress(
      id: id ?? this.id,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      pinCode: pinCode ?? this.pinCode,
    );
  }
}

class VendorContactPerson {
  const VendorContactPerson({
    this.id,
    this.salutation = '',
    this.firstName = '',
    this.lastName = '',
    this.designation = '',
    this.department = '',
    this.email = '',
    this.phone = '',
    this.mobile = '',
    this.isPrimary = false,
  });

  final int? id;
  final String salutation;
  final String firstName;
  final String lastName;
  final String designation;
  final String department;
  final String email;
  final String phone;
  final String mobile;
  final bool isPrimary;

  String get fullName => '$firstName $lastName'.trim();

  VendorContactPerson copyWith({
    int? id,
    String? salutation,
    String? firstName,
    String? lastName,
    String? designation,
    String? department,
    String? email,
    String? phone,
    String? mobile,
    bool? isPrimary,
  }) {
    return VendorContactPerson(
      id: id ?? this.id,
      salutation: salutation ?? this.salutation,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      designation: designation ?? this.designation,
      department: department ?? this.department,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      mobile: mobile ?? this.mobile,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }
}

class VendorBankAccount {
  const VendorBankAccount({
    this.id,
    this.bankName = '',
    this.accountHolderName = '',
    this.accountNumber = '',
    this.ifscCode = '',
    this.branch = '',
    this.accountType = '',
  });

  final int? id;
  final String bankName;
  final String accountHolderName;
  final String accountNumber;
  final String ifscCode;
  final String branch;
  final String accountType;

  VendorBankAccount copyWith({
    int? id,
    String? bankName,
    String? accountHolderName,
    String? accountNumber,
    String? ifscCode,
    String? branch,
    String? accountType,
  }) {
    return VendorBankAccount(
      id: id ?? this.id,
      bankName: bankName ?? this.bankName,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      branch: branch ?? this.branch,
      accountType: accountType ?? this.accountType,
    );
  }
}

class Vendor {
  const Vendor({
    required this.id,
    required this.vendorCode,
    required this.displayName,
    this.companyName = '',
    this.salutation = '',
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.workPhone = '',
    this.mobile = '',
    this.gstTreatment = 'Registered Business - Regular',
    this.sourceOfSupply = '',
    this.pan = '',
    this.msmeRegistered = false,
    this.currency = 'INR - Indian Rupee',
    this.openingBalance = 0.0,
    this.paymentTerms = 'Due on Receipt',
    this.tds,
    this.status = 'Active',
    this.remarks = '',
    this.payables = 0.0,
    this.createdAt,
    this.updatedAt,
    this.primaryAddress,
    this.contactPersons = const [],
    this.bankAccounts = const [],
    this.documentPaths = const [],
  });

  final int id;
  final String vendorCode;
  final String displayName;
  final String companyName;
  final String salutation;
  final String firstName;
  final String lastName;
  final String email;
  final String workPhone;
  final String mobile;
  final String gstTreatment;
  final String sourceOfSupply;
  final String pan;
  final bool msmeRegistered;
  final String currency;
  final double openingBalance;
  final String paymentTerms;
  final String? tds;
  final String status; // Active, Inactive, Blocked
  final String remarks;
  final double payables;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final VendorAddress? primaryAddress;
  final List<VendorContactPerson> contactPersons;
  final List<VendorBankAccount> bankAccounts;
  final List<String> documentPaths;

  String get name => displayName.isNotEmpty ? displayName : companyName;

  Vendor copyWith({
    int? id,
    String? vendorCode,
    String? displayName,
    String? companyName,
    String? salutation,
    String? firstName,
    String? lastName,
    String? email,
    String? workPhone,
    String? mobile,
    String? gstTreatment,
    String? sourceOfSupply,
    String? pan,
    bool? msmeRegistered,
    String? currency,
    double? openingBalance,
    String? paymentTerms,
    String? tds,
    String? status,
    String? remarks,
    double? payables,
    DateTime? createdAt,
    DateTime? updatedAt,
    VendorAddress? primaryAddress,
    List<VendorContactPerson>? contactPersons,
    List<VendorBankAccount>? bankAccounts,
    List<String>? documentPaths,
  }) {
    return Vendor(
      id: id ?? this.id,
      vendorCode: vendorCode ?? this.vendorCode,
      displayName: displayName ?? this.displayName,
      companyName: companyName ?? this.companyName,
      salutation: salutation ?? this.salutation,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      workPhone: workPhone ?? this.workPhone,
      mobile: mobile ?? this.mobile,
      gstTreatment: gstTreatment ?? this.gstTreatment,
      sourceOfSupply: sourceOfSupply ?? this.sourceOfSupply,
      pan: pan ?? this.pan,
      msmeRegistered: msmeRegistered ?? this.msmeRegistered,
      currency: currency ?? this.currency,
      openingBalance: openingBalance ?? this.openingBalance,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      tds: tds ?? this.tds,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      payables: payables ?? this.payables,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      primaryAddress: primaryAddress ?? this.primaryAddress,
      contactPersons: contactPersons ?? this.contactPersons,
      bankAccounts: bankAccounts ?? this.bankAccounts,
      documentPaths: documentPaths ?? this.documentPaths,
    );
  }
}
