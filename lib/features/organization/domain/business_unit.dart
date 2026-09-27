class BusinessUnit {
  const BusinessUnit({
    required this.id,
    this.organizationId = '',
    required this.organizationName,
    required this.unitName,
    this.description = '',
  });

  final int id;
  final String organizationId;
  final String organizationName;
  final String unitName;
  final String description;

  BusinessUnit copyWith({
    int? id,
    String? organizationId,
    String? organizationName,
    String? unitName,
    String? description,
  }) {
    return BusinessUnit(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      organizationName: organizationName ?? this.organizationName,
      unitName: unitName ?? this.unitName,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != 0) 'id': id,
      if (organizationId.isNotEmpty) 'organization_id': organizationId,
      'organization_name': organizationName,
      'unit_name': unitName,
      'description': description,
    };
  }

  factory BusinessUnit.fromMap(Map<String, dynamic> map) {
    return BusinessUnit(
      id: (map['id'] as num?)?.toInt() ?? 0,
      organizationId: map['organization_id']?.toString() ?? map['organizationId']?.toString() ?? map['org_id']?.toString() ?? '',
      organizationName: map['organization_name']?.toString() ?? map['organizationName']?.toString() ?? '',
      unitName: map['unit_name']?.toString() ?? map['unitName']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
    );
  }
}
