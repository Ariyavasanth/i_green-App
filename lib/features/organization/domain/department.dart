class Department {
  const Department({
    required this.id,
    this.organizationName = '',
    this.businessUnitName = '',
    required this.departmentName,
    required this.departmentHead,
    required this.reportingHierarchy,
    required this.workLocation,
  });

  final int id;
  final String organizationName;
  final String businessUnitName;
  final String departmentName;
  final String departmentHead;
  final String reportingHierarchy;
  final String workLocation;

  Department copyWith({
    int? id,
    String? organizationName,
    String? businessUnitName,
    String? departmentName,
    String? departmentHead,
    String? reportingHierarchy,
    String? workLocation,
  }) {
    return Department(
      id: id ?? this.id,
      organizationName: organizationName ?? this.organizationName,
      businessUnitName: businessUnitName ?? this.businessUnitName,
      departmentName: departmentName ?? this.departmentName,
      departmentHead: departmentHead ?? this.departmentHead,
      reportingHierarchy: reportingHierarchy ?? this.reportingHierarchy,
      workLocation: workLocation ?? this.workLocation,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != 0) 'id': id,
      'organization_name': organizationName,
      'business_unit_name': businessUnitName,
      'department_name': departmentName,
      'department_head': departmentHead,
      'reporting_hierarchy': reportingHierarchy,
      'work_location': workLocation,
    };
  }

  factory Department.fromMap(Map<String, dynamic> map) {
    return Department(
      id: (map['id'] as num?)?.toInt() ?? 0,
      organizationName: map['organization_name']?.toString() ?? '',
      businessUnitName: map['business_unit_name']?.toString() ?? '',
      departmentName: map['department_name']?.toString() ?? '',
      departmentHead: map['department_head']?.toString() ?? '',
      reportingHierarchy: map['reporting_hierarchy']?.toString() ?? '',
      workLocation: map['work_location']?.toString() ?? '',
    );
  }
}
