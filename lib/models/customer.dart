enum CustomerType { business, individual }

enum TaxPreference { taxable, taxExempt }

class CustomerAddress {
  const CustomerAddress({
    this.attention = '', this.country = 'India', this.address1 = '',
    this.address2 = '', this.city = '', this.state = '', this.pinCode = '',
    this.phone = '', this.fax = '',
  });

  final String attention, country, address1, address2, city, state, pinCode, phone, fax;

  Map<String, dynamic> toJson() => {
    'attention': attention, 'country': country, 'address1': address1,
    'address2': address2, 'city': city, 'state': state, 'pinCode': pinCode,
    'phone': phone, 'fax': fax,
  };

  factory CustomerAddress.fromJson(Map<String, dynamic> json) => CustomerAddress(
    attention: json['attention'] ?? '', country: json['country'] ?? 'India',
    address1: json['address1'] ?? '', address2: json['address2'] ?? '',
    city: json['city'] ?? '', state: json['state'] ?? '',
    pinCode: json['pinCode'] ?? '', phone: json['phone'] ?? '', fax: json['fax'] ?? '',
  );
}

class CustomerContact {
  const CustomerContact({this.salutation = 'Mr.', this.firstName = '', this.lastName = '', this.email = '', this.phone = ''});
  final String salutation, firstName, lastName, email, phone;
  Map<String, dynamic> toJson() => {'salutation': salutation, 'firstName': firstName, 'lastName': lastName, 'email': email, 'phone': phone};
  factory CustomerContact.fromJson(Map<String, dynamic> j) => CustomerContact(salutation: j['salutation'] ?? 'Mr.', firstName: j['firstName'] ?? '', lastName: j['lastName'] ?? '', email: j['email'] ?? '', phone: j['phone'] ?? '');
}

class Customer {
  const Customer({
    this.id, this.type = CustomerType.business, this.salutation = 'Mr.',
    this.firstName = '', this.lastName = '', required this.displayName,
    this.companyName = '', this.email = '', this.workPhone = '', this.mobile = '',
    this.language = 'English', required this.gstTreatment, required this.placeOfSupply,
    this.pan = '', this.gstin = '', this.taxPreference = TaxPreference.taxable,
    this.currency = 'INR', this.openingBalance = 0, this.paymentTerms = 'Due on Receipt',
    this.portalEnabled = false, this.billingAddress = const CustomerAddress(),
    this.shippingAddress = const CustomerAddress(), this.contacts = const [],
    this.customFields = const {}, this.reportingTags = const [], this.remarks = '',
    this.documentNames = const [], this.receivables = 0, this.unusedCredits = 0,
    this.isActive = true,
  });

  final int? id;
  final CustomerType type;
  final String salutation, firstName, lastName, displayName, companyName, email;
  final String workPhone, mobile, language, gstTreatment, placeOfSupply, pan, gstin;
  final TaxPreference taxPreference;
  final String currency, paymentTerms, remarks;
  final double openingBalance, receivables, unusedCredits;
  final bool portalEnabled, isActive;
  final CustomerAddress billingAddress, shippingAddress;
  final List<CustomerContact> contacts;
  final Map<String, String> customFields;
  final List<String> reportingTags, documentNames;

  String get fullName => [firstName, lastName].where((e) => e.isNotEmpty).join(' ');

  Customer copyWith({
    int? id,
    CustomerType? type,
    String? salutation,
    String? firstName,
    String? lastName,
    String? displayName,
    String? companyName,
    String? email,
    String? workPhone,
    String? mobile,
    String? language,
    String? gstTreatment,
    String? placeOfSupply,
    String? pan,
    String? gstin,
    TaxPreference? taxPreference,
    String? currency,
    double? openingBalance,
    String? paymentTerms,
    bool? portalEnabled,
    CustomerAddress? billingAddress,
    CustomerAddress? shippingAddress,
    List<CustomerContact>? contacts,
    Map<String, String>? customFields,
    List<String>? reportingTags,
    String? remarks,
    List<String>? documentNames,
    double? receivables,
    double? unusedCredits,
    bool? isActive,
  }) {
    return Customer(
      id: id ?? this.id,
      type: type ?? this.type,
      salutation: salutation ?? this.salutation,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      displayName: displayName ?? this.displayName,
      companyName: companyName ?? this.companyName,
      email: email ?? this.email,
      workPhone: workPhone ?? this.workPhone,
      mobile: mobile ?? this.mobile,
      language: language ?? this.language,
      gstTreatment: gstTreatment ?? this.gstTreatment,
      placeOfSupply: placeOfSupply ?? this.placeOfSupply,
      pan: pan ?? this.pan,
      gstin: gstin ?? this.gstin,
      taxPreference: taxPreference ?? this.taxPreference,
      currency: currency ?? this.currency,
      openingBalance: openingBalance ?? this.openingBalance,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      portalEnabled: portalEnabled ?? this.portalEnabled,
      billingAddress: billingAddress ?? this.billingAddress,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      contacts: contacts ?? this.contacts,
      customFields: customFields ?? this.customFields,
      reportingTags: reportingTags ?? this.reportingTags,
      remarks: remarks ?? this.remarks,
      documentNames: documentNames ?? this.documentNames,
      receivables: receivables ?? this.receivables,
      unusedCredits: unusedCredits ?? this.unusedCredits,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'salutation': salutation,
    'firstName': firstName,
    'lastName': lastName,
    'displayName': displayName,
    'companyName': companyName,
    'email': email,
    'workPhone': workPhone,
    'mobile': mobile,
    'language': language,
    'gstTreatment': gstTreatment,
    'placeOfSupply': placeOfSupply,
    'pan': pan,
    'gstin': gstin,
    'taxPreference': taxPreference.name,
    'currency': currency,
    'openingBalance': openingBalance,
    'paymentTerms': paymentTerms,
    'portalEnabled': portalEnabled,
    'billingAddress': billingAddress.toJson(),
    'shippingAddress': shippingAddress.toJson(),
    'contacts': contacts.map((c) => c.toJson()).toList(),
    'customFields': customFields,
    'reportingTags': reportingTags,
    'remarks': remarks,
    'documentNames': documentNames,
    'receivables': receivables,
    'unusedCredits': unusedCredits,
    'isActive': isActive,
  };

  factory Customer.fromJson(Map<String, dynamic> json, {int? id}) {
    return Customer(
      id: id ?? (json['id'] is num ? (json['id'] as num).toInt() : int.tryParse(json['id']?.toString() ?? '')),
      type: json['type'] == 'individual' ? CustomerType.individual : CustomerType.business,
      salutation: json['salutation'] ?? 'Mr.',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      displayName: json['displayName'] ?? json['name'] ?? '',
      companyName: json['companyName'] ?? json['company_name'] ?? '',
      email: json['email'] ?? '',
      workPhone: json['workPhone'] ?? json['phone'] ?? '',
      mobile: json['mobile'] ?? '',
      language: json['language'] ?? 'English',
      gstTreatment: json['gstTreatment'] ?? 'Registered Business - Regular',
      placeOfSupply: json['placeOfSupply'] ?? 'Tamil Nadu',
      pan: json['pan'] ?? '',
      gstin: json['gstin'] ?? '',
      taxPreference: json['taxPreference'] == 'taxExempt' ? TaxPreference.taxExempt : TaxPreference.taxable,
      currency: json['currency'] ?? 'INR',
      openingBalance: (json['openingBalance'] is num) ? (json['openingBalance'] as num).toDouble() : 0.0,
      paymentTerms: json['paymentTerms'] ?? 'Due on Receipt',
      portalEnabled: json['portalEnabled'] == true,
      billingAddress: json['billingAddress'] is Map ? CustomerAddress.fromJson(Map<String, dynamic>.from(json['billingAddress'])) : const CustomerAddress(),
      shippingAddress: json['shippingAddress'] is Map ? CustomerAddress.fromJson(Map<String, dynamic>.from(json['shippingAddress'])) : const CustomerAddress(),
      contacts: json['contacts'] is List ? (json['contacts'] as List).map((c) => CustomerContact.fromJson(Map<String, dynamic>.from(c))).toList() : const [],
      customFields: json['customFields'] is Map ? Map<String, String>.from(json['customFields']) : const {},
      reportingTags: json['reportingTags'] is List ? List<String>.from(json['reportingTags']) : const [],
      remarks: json['remarks'] ?? '',
      documentNames: json['documentNames'] is List ? List<String>.from(json['documentNames']) : const [],
      receivables: (json['receivables'] is num) ? (json['receivables'] as num).toDouble() : 0.0,
      unusedCredits: (json['unusedCredits'] is num) ? (json['unusedCredits'] as num).toDouble() : 0.0,
      isActive: json['isActive'] ?? true,
    );
  }
}
