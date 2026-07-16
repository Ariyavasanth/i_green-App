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
}
