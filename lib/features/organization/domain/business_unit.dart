class BusinessUnit {
  const BusinessUnit({
    required this.id,
    required this.organizationName,
    required this.unitName,
    this.description = '',
  });

  final int id;
  final String organizationName;
  final String unitName;
  final String description;

  BusinessUnit copyWith({
    int? id,
    String? organizationName,
    String? unitName,
    String? description,
  }) {
    return BusinessUnit(
      id: id ?? this.id,
      organizationName: organizationName ?? this.organizationName,
      unitName: unitName ?? this.unitName,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != 0) 'id': id,
      'organization_name': organizationName,
      'unit_name': unitName,
      'description': description,
    };
  }

  factory BusinessUnit.fromMap(Map<String, dynamic> map) {
    return BusinessUnit(
      id: (map['id'] as num?)?.toInt() ?? 0,
      organizationName: map['organization_name']?.toString() ?? '',
      unitName: map['unit_name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
    );
  }
}
