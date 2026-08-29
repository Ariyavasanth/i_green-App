class Location {
  const Location({
    required this.id,
    required this.organizationName,
    required this.businessUnitName,
    required this.locationName,
    this.address = '',
  });

  final int id;
  final String organizationName;
  final String businessUnitName;
  final String locationName;
  final String address;

  Location copyWith({
    int? id,
    String? organizationName,
    String? businessUnitName,
    String? locationName,
    String? address,
  }) {
    return Location(
      id: id ?? this.id,
      organizationName: organizationName ?? this.organizationName,
      businessUnitName: businessUnitName ?? this.businessUnitName,
      locationName: locationName ?? this.locationName,
      address: address ?? this.address,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != 0) 'id': id,
      'organization_name': organizationName,
      'business_unit_name': businessUnitName,
      'location_name': locationName,
      'address': address,
    };
  }

  factory Location.fromMap(Map<String, dynamic> map) {
    return Location(
      id: (map['id'] as num?)?.toInt() ?? 0,
      organizationName: map['organization_name']?.toString() ?? '',
      businessUnitName: map['business_unit_name']?.toString() ?? '',
      locationName: map['location_name']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
    );
  }
}
