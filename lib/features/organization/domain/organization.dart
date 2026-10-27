class ContactNumber {
  const ContactNumber({required this.label, required this.number});

  final String label;
  final String number;

  ContactNumber copyWith({String? label, String? number}) {
    return ContactNumber(
      label: label ?? this.label,
      number: number ?? this.number,
    );
  }

  Map<String, dynamic> toMap() {
    return {'label': label, 'number': number};
  }

  factory ContactNumber.fromMap(Map<String, dynamic> map) {
    return ContactNumber(
      label: map['label']?.toString() ?? 'Mobile',
      number: map['number']?.toString() ?? '',
    );
  }
}

class DirectorDetail {
  const DirectorDetail({required this.name, required this.din});

  final String name;
  final String din;

  DirectorDetail copyWith({String? name, String? din}) {
    return DirectorDetail(name: name ?? this.name, din: din ?? this.din);
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'din': din};
  }

  factory DirectorDetail.fromMap(Map<String, dynamic> map) {
    return DirectorDetail(
      name: map['name']?.toString() ?? '',
      din: map['din']?.toString() ?? '',
    );
  }
}

class OrgDocument {
  const OrgDocument({
    required this.title,
    required this.fileName,
    required this.fileUrl,
    this.uploadedAt,
  });

  final String title;
  final String fileName;
  final String fileUrl;
  final String? uploadedAt;

  OrgDocument copyWith({
    String? title,
    String? fileName,
    String? fileUrl,
    String? uploadedAt,
  }) {
    return OrgDocument(
      title: title ?? this.title,
      fileName: fileName ?? this.fileName,
      fileUrl: fileUrl ?? this.fileUrl,
      uploadedAt: uploadedAt ?? this.uploadedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'file_name': fileName,
      'file_url': fileUrl,
      'fileName': fileName,
      'fileUrl': fileUrl,
      if (uploadedAt != null) 'uploaded_at': uploadedAt,
    };
  }

  factory OrgDocument.fromMap(Map<String, dynamic> map) {
    return OrgDocument(
      title: map['title']?.toString() ?? '',
      fileName:
          map['file_name']?.toString() ??
          map['fileName']?.toString() ??
          map['name']?.toString() ??
          '',
      fileUrl:
          map['file_url']?.toString() ??
          map['fileUrl']?.toString() ??
          map['url']?.toString() ??
          map['download_url']?.toString() ??
          map['downloadUrl']?.toString() ??
          '',
      uploadedAt:
          map['uploaded_at']?.toString() ?? map['uploadedAt']?.toString(),
    );
  }
}

class OrganizationBankDetail {
  const OrganizationBankDetail({
    this.id = '',
    required this.bankName,
    required this.accountNumber,
    required this.ifscCode,
    this.cifCode = '',
    this.branch = '',
    this.cancelledChequeDoc,
  });

  final String id;
  final String bankName;
  final String accountNumber;
  final String ifscCode;
  final String cifCode;
  final String branch;
  final OrgDocument? cancelledChequeDoc;

  OrganizationBankDetail copyWith({
    String? id,
    String? bankName,
    String? accountNumber,
    String? ifscCode,
    String? cifCode,
    String? branch,
    OrgDocument? cancelledChequeDoc,
  }) {
    return OrganizationBankDetail(
      id: id ?? this.id,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      cifCode: cifCode ?? this.cifCode,
      branch: branch ?? this.branch,
      cancelledChequeDoc: cancelledChequeDoc ?? this.cancelledChequeDoc,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'bank_name': bankName,
      'account_number': accountNumber,
      'ifsc_code': ifscCode,
      if (cifCode.isNotEmpty) 'cif_code': cifCode,
      if (branch.isNotEmpty) 'branch': branch,
      if (cancelledChequeDoc != null)
        'cancelled_cheque_doc': cancelledChequeDoc!.toMap(),
    };
  }

  factory OrganizationBankDetail.fromMap(Map<String, dynamic> map) {
    OrgDocument? chequeDoc;
    if (map['cancelled_cheque_doc'] is Map<String, dynamic>) {
      chequeDoc = OrgDocument.fromMap(
        map['cancelled_cheque_doc'] as Map<String, dynamic>,
      );
    } else if (map['cancelledChequeDoc'] is Map<String, dynamic>) {
      chequeDoc = OrgDocument.fromMap(
        map['cancelledChequeDoc'] as Map<String, dynamic>,
      );
    }

    return OrganizationBankDetail(
      id: map['id']?.toString() ?? '',
      bankName:
          map['bank_name']?.toString() ?? map['bankName']?.toString() ?? '',
      accountNumber:
          map['account_number']?.toString() ??
          map['accountNumber']?.toString() ??
          '',
      ifscCode:
          map['ifsc_code']?.toString() ?? map['ifscCode']?.toString() ?? '',
      cifCode: map['cif_code']?.toString() ?? map['cifCode']?.toString() ?? '',
      branch: map['branch']?.toString() ?? '',
      cancelledChequeDoc: chequeDoc,
    );
  }
}

class Organization {
  const Organization({
    required this.id,
    this.docId = '',
    required this.name,
    this.status = 'active',
    required this.businessType,
    required this.industryType,
    required this.businessUnits,
    required this.locations,
    required this.address,
    this.pincode = '',
    required this.phoneNumber,
    this.contactNumbers = const [],
    required this.emailAddress,
    required this.website,
    required this.taxId,
    this.gstNumber = '',
    this.cinNumber = '',
    this.panNumber = '',
    this.tanNumber = '',
    this.directors = const [],
    this.documents = const [],
    this.bankDetails = const [],
    this.employeePrefix = '',
  });

  final int id;
  final String docId;
  final String name;
  final String employeePrefix; // Dynamic Employee ID prefix e.g. "IGT", "ABC"
  final String status; // 'active', 'inactive'
  final String businessType;
  final String industryType;
  final String businessUnits;
  final String locations;
  final String address;
  final String pincode;
  final String phoneNumber;
  final List<ContactNumber> contactNumbers;
  final String emailAddress;
  final String website;
  final String taxId;
  final String gstNumber;
  final String cinNumber;
  final String panNumber;
  final String tanNumber;
  final List<DirectorDetail> directors;
  final List<OrgDocument> documents;
  final List<OrganizationBankDetail> bankDetails;

  bool get isActive => status.toLowerCase() != 'inactive';

  String get canonicalId =>
      docId.isNotEmpty ? docId : (id != 0 ? 'org_$id' : '');

  Organization copyWith({
    int? id,
    String? docId,
    String? name,
    String? status,
    String? businessType,
    String? industryType,
    String? businessUnits,
    String? locations,
    String? address,
    String? pincode,
    String? phoneNumber,
    List<ContactNumber>? contactNumbers,
    String? emailAddress,
    String? website,
    String? taxId,
    String? gstNumber,
    String? cinNumber,
    String? panNumber,
    String? tanNumber,
    List<DirectorDetail>? directors,
    List<OrgDocument>? documents,
    List<OrganizationBankDetail>? bankDetails,
    String? employeePrefix,
  }) {
    return Organization(
      id: id ?? this.id,
      docId: docId ?? this.docId,
      name: name ?? this.name,
      employeePrefix: employeePrefix ?? this.employeePrefix,
      status: status ?? this.status,
      businessType: businessType ?? this.businessType,
      industryType: industryType ?? this.industryType,
      businessUnits: businessUnits ?? this.businessUnits,
      locations: locations ?? this.locations,
      address: address ?? this.address,
      pincode: pincode ?? this.pincode,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      contactNumbers: contactNumbers ?? this.contactNumbers,
      emailAddress: emailAddress ?? this.emailAddress,
      website: website ?? this.website,
      taxId: taxId ?? this.taxId,
      gstNumber: gstNumber ?? this.gstNumber,
      cinNumber: cinNumber ?? this.cinNumber,
      panNumber: panNumber ?? this.panNumber,
      tanNumber: tanNumber ?? this.tanNumber,
      directors: directors ?? this.directors,
      documents: documents ?? this.documents,
      bankDetails: bankDetails ?? this.bankDetails,
    );
  }

  Map<String, dynamic> toMap() {
    final effectiveTaxId = gstNumber.isNotEmpty ? gstNumber : taxId;
    final effectivePhone = phoneNumber.isNotEmpty
        ? phoneNumber
        : (contactNumbers.isNotEmpty
              ? contactNumbers.map((c) => '${c.label}: ${c.number}').join(', ')
              : '');

    return {
      if (id != 0) 'id': id,
      if (canonicalId.isNotEmpty) 'doc_id': canonicalId,
      'name': name,
      'status': status.isNotEmpty ? status : 'active',
      'business_type': businessType,
      'industry_type': industryType,
      'business_units': businessUnits,
      'locations': locations,
      'address': address,
      'pincode': pincode,
      'phone_number': effectivePhone,
      'contact_numbers': contactNumbers.map((c) => c.toMap()).toList(),
      'email_address': emailAddress,
      'website': website,
      'tax_id': effectiveTaxId,
      'gst_number': effectiveTaxId,
      'cin_number': cinNumber,
      'pan_number': panNumber,
      'tan_number': tanNumber,
      'directors': directors.map((d) => d.toMap()).toList(),
      'documents': documents.map((doc) => doc.toMap()).toList(),
      'bank_details': bankDetails.map((b) => b.toMap()).toList(),
      'employee_prefix': employeePrefix.trim().toUpperCase(),
    };
  }

  factory Organization.fromMap(Map<String, dynamic> map, [String? documentId]) {
    // Parse contact numbers
    List<ContactNumber> contacts = [];
    if (map['contact_numbers'] is List) {
      contacts = (map['contact_numbers'] as List)
          .whereType<Map<String, dynamic>>()
          .map((m) => ContactNumber.fromMap(m))
          .toList();
    } else if (map['phone_number'] != null &&
        map['phone_number'].toString().isNotEmpty) {
      final rawPhone = map['phone_number'].toString();
      contacts = [ContactNumber(label: 'Primary', number: rawPhone)];
    }

    // Parse directors
    List<DirectorDetail> directorsList = [];
    if (map['directors'] is List) {
      directorsList = (map['directors'] as List)
          .whereType<Map<String, dynamic>>()
          .map((m) => DirectorDetail.fromMap(m))
          .toList();
    }

    // Parse documents
    List<OrgDocument> docsList = [];
    if (map['documents'] is List) {
      docsList = (map['documents'] as List)
          .whereType<Map<String, dynamic>>()
          .map((m) => OrgDocument.fromMap(m))
          .toList();
    }

    // Parse bank details safely (supports legacy documents without bank_details)
    List<OrganizationBankDetail> banksList = [];
    if (map['bank_details'] is List) {
      banksList = (map['bank_details'] as List)
          .whereType<Map<String, dynamic>>()
          .map((m) => OrganizationBankDetail.fromMap(m))
          .toList();
    } else if (map['bankDetails'] is List) {
      banksList = (map['bankDetails'] as List)
          .whereType<Map<String, dynamic>>()
          .map((m) => OrganizationBankDetail.fromMap(m))
          .toList();
    }

    final gst =
        map['gst_number']?.toString() ?? map['tax_id']?.toString() ?? '';
    final parsedId = (map['id'] as num?)?.toInt() ?? 0;
    final resolvedDocId =
        documentId ??
        map['doc_id']?.toString() ??
        (parsedId != 0 ? 'org_$parsedId' : '');

    return Organization(
      id: parsedId,
      docId: resolvedDocId,
      name: map['name']?.toString() ?? '',
      status: map['status']?.toString() ?? 'active',
      businessType: map['business_type']?.toString() ?? '',
      industryType: map['industry_type']?.toString() ?? '',
      businessUnits: map['business_units']?.toString() ?? '',
      locations: map['locations']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      pincode: map['pincode']?.toString() ?? '',
      phoneNumber:
          map['phone_number']?.toString() ??
          (contacts.isNotEmpty ? contacts.first.number : ''),
      contactNumbers: contacts,
      emailAddress: map['email_address']?.toString() ?? '',
      website: map['website']?.toString() ?? '',
      taxId: gst,
      gstNumber: gst,
      cinNumber: map['cin_number']?.toString() ?? '',
      panNumber: map['pan_number']?.toString() ?? '',
      tanNumber: map['tan_number']?.toString() ?? '',
      directors: directorsList,
      documents: docsList,
      bankDetails: banksList,
      employeePrefix: (map['employee_prefix'] ?? map['employeePrefix'] ?? '').toString().trim().toUpperCase(),
    );
  }
}
