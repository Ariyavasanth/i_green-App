enum HierarchyLevel {
  head('Head'),
  manager('Manager'),
  lead('Lead'),
  senior('Senior'),
  supervisor('Supervisor'),
  employee('Employee'),
  trainee('Trainee');

  const HierarchyLevel(this.label);
  final String label;

  static HierarchyLevel fromString(String val) {
    return HierarchyLevel.values.firstWhere(
      (e) =>
          e.label.toLowerCase() == val.trim().toLowerCase() ||
          e.name.toLowerCase() == val.trim().toLowerCase(),
      orElse: () => HierarchyLevel.employee,
    );
  }
}

class Designation {
  const Designation({
    required this.id,
    this.organizationId = '',
    this.organizationName = '',
    required this.departmentName,
    required this.designationName,
    this.hierarchyLevel = HierarchyLevel.employee,
    this.description = '',
    this.bandId = '',
    this.bandCode = '',
    this.bandLevel = 0,
  });

  final int id;
  final String organizationId;
  final String organizationName;
  final String departmentName;
  final String designationName;
  final HierarchyLevel hierarchyLevel;
  final String description;
  final String bandId;
  final String bandCode;
  final int bandLevel;

  Designation copyWith({
    int? id,
    String? organizationId,
    String? organizationName,
    String? departmentName,
    String? designationName,
    HierarchyLevel? hierarchyLevel,
    String? description,
    String? bandId,
    String? bandCode,
    int? bandLevel,
  }) {
    return Designation(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      organizationName: organizationName ?? this.organizationName,
      departmentName: departmentName ?? this.departmentName,
      designationName: designationName ?? this.designationName,
      hierarchyLevel: hierarchyLevel ?? this.hierarchyLevel,
      description: description ?? this.description,
      bandId: bandId ?? this.bandId,
      bandCode: bandCode ?? this.bandCode,
      bandLevel: bandLevel ?? this.bandLevel,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != 0) 'id': id,
      if (organizationId.isNotEmpty) 'organization_id': organizationId,
      'organization_name': organizationName,
      'department_name': departmentName,
      'designation_name': designationName,
      'hierarchy_level': hierarchyLevel.label,
      'description': description,
      if (bandId.isNotEmpty) 'band_id': bandId,
      if (bandCode.isNotEmpty) 'band_code': bandCode,
      if (bandLevel > 0) 'band_level': bandLevel,
    };
  }

  factory Designation.fromMap(Map<String, dynamic> map) {
    return Designation(
      id: (map['id'] as num?)?.toInt() ?? 0,
      organizationId:
          map['organization_id']?.toString() ??
          map['organizationId']?.toString() ??
          map['org_id']?.toString() ??
          '',
      organizationName:
          map['organization_name']?.toString() ??
          map['organizationName']?.toString() ??
          '',
      departmentName:
          map['department_name']?.toString() ??
          map['departmentName']?.toString() ??
          '',
      designationName:
          map['designation_name']?.toString() ??
          map['designationName']?.toString() ??
          '',
      hierarchyLevel: HierarchyLevel.fromString(
        map['hierarchy_level']?.toString() ?? 'Employee',
      ),
      description: map['description']?.toString() ?? '',
      bandId: map['band_id']?.toString() ?? map['bandId']?.toString() ?? '',
      bandCode:
          map['band_code']?.toString() ?? map['bandCode']?.toString() ?? '',
      bandLevel:
          (map['band_level'] as num?)?.toInt() ??
          (map['bandLevel'] as num?)?.toInt() ??
          0,
    );
  }
}
