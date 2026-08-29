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
      (e) => e.label.toLowerCase() == val.trim().toLowerCase() || e.name.toLowerCase() == val.trim().toLowerCase(),
      orElse: () => HierarchyLevel.employee,
    );
  }
}

class Designation {
  const Designation({
    required this.id,
    required this.departmentName,
    required this.designationName,
    required this.hierarchyLevel,
    this.description = '',
  });

  final int id;
  final String departmentName;
  final String designationName;
  final HierarchyLevel hierarchyLevel;
  final String description;

  Designation copyWith({
    int? id,
    String? departmentName,
    String? designationName,
    HierarchyLevel? hierarchyLevel,
    String? description,
  }) {
    return Designation(
      id: id ?? this.id,
      departmentName: departmentName ?? this.departmentName,
      designationName: designationName ?? this.designationName,
      hierarchyLevel: hierarchyLevel ?? this.hierarchyLevel,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != 0) 'id': id,
      'department_name': departmentName,
      'designation_name': designationName,
      'hierarchy_level': hierarchyLevel.label,
      'description': description,
    };
  }

  factory Designation.fromMap(Map<String, dynamic> map) {
    return Designation(
      id: (map['id'] as num?)?.toInt() ?? 0,
      departmentName: map['department_name']?.toString() ?? '',
      designationName: map['designation_name']?.toString() ?? '',
      hierarchyLevel: HierarchyLevel.fromString(map['hierarchy_level']?.toString() ?? 'Employee'),
      description: map['description']?.toString() ?? '',
    );
  }
}
