class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.businessType,
    required this.industryType,
    required this.businessUnits,
    required this.locations,
    required this.address,
    required this.phoneNumber,
    required this.emailAddress,
    required this.website,
    required this.taxId,
  });

  final int id;
  final String name;
  final String businessType;
  final String industryType;
  final String businessUnits;
  final String locations;
  final String address;
  final String phoneNumber;
  final String emailAddress;
  final String website;
  final String taxId;

  Organization copyWith({
    int? id,
    String? name,
    String? businessType,
    String? industryType,
    String? businessUnits,
    String? locations,
    String? address,
    String? phoneNumber,
    String? emailAddress,
    String? website,
    String? taxId,
  }) {
    return Organization(
      id: id ?? this.id,
      name: name ?? this.name,
      businessType: businessType ?? this.businessType,
      industryType: industryType ?? this.industryType,
      businessUnits: businessUnits ?? this.businessUnits,
      locations: locations ?? this.locations,
      address: address ?? this.address,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      emailAddress: emailAddress ?? this.emailAddress,
      website: website ?? this.website,
      taxId: taxId ?? this.taxId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != 0) 'id': id,
      'name': name,
      'business_type': businessType,
      'industry_type': industryType,
      'business_units': businessUnits,
      'locations': locations,
      'address': address,
      'phone_number': phoneNumber,
      'email_address': emailAddress,
      'website': website,
      'tax_id': taxId,
    };
  }

  factory Organization.fromMap(Map<String, dynamic> map) {
    return Organization(
      id: (map['id'] as num?)?.toInt() ?? 0,
      name: map['name']?.toString() ?? '',
      businessType: map['business_type']?.toString() ?? '',
      industryType: map['industry_type']?.toString() ?? '',
      businessUnits: map['business_units']?.toString() ?? '',
      locations: map['locations']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      phoneNumber: map['phone_number']?.toString() ?? '',
      emailAddress: map['email_address']?.toString() ?? '',
      website: map['website']?.toString() ?? '',
      taxId: map['tax_id']?.toString() ?? '',
    );
  }
}
