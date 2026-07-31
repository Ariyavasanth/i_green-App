class AssetAssignment {
  const AssetAssignment({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    this.employeeCode = '',
    required this.assetTypeId,
    required this.assetTypeName,
    required this.assignedDate,
    required this.description,
    this.status = 'Assigned',
    this.createdAt,
  });

  final int id;
  final int employeeId;
  final String employeeName;
  final String employeeCode;
  final int assetTypeId;
  final String assetTypeName;
  final String assignedDate;
  final String description; // Reason explaining the assignment
  final String status; // Assigned, Returned, Maintenance
  final String? createdAt;

  AssetAssignment copyWith({
    int? id,
    int? employeeId,
    String? employeeName,
    String? employeeCode,
    int? assetTypeId,
    String? assetTypeName,
    String? assignedDate,
    String? description,
    String? status,
    String? createdAt,
  }) {
    return AssetAssignment(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      employeeCode: employeeCode ?? this.employeeCode,
      assetTypeId: assetTypeId ?? this.assetTypeId,
      assetTypeName: assetTypeName ?? this.assetTypeName,
      assignedDate: assignedDate ?? this.assignedDate,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'employee_id': employeeId,
        'employee_name': employeeName,
        'employee_code': employeeCode,
        'asset_type_id': assetTypeId,
        'asset_type_name': assetTypeName,
        'assigned_date': assignedDate,
        'description': description,
        'status': status,
        'created_at': createdAt,
      };

  factory AssetAssignment.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawId = map['id'];
    int idVal = 0;
    if (rawId is int) {
      idVal = rawId;
    } else if (rawId is num) {
      idVal = rawId.toInt();
    } else if (docId != null) {
      idVal = docId.hashCode & 0x7FFFFFFF;
    }

    final rawEmpId = map['employee_id'];
    int empIdVal = 0;
    if (rawEmpId is int) {
      empIdVal = rawEmpId;
    } else if (rawEmpId is num) {
      empIdVal = rawEmpId.toInt();
    }

    final rawAssetTypeId = map['asset_type_id'];
    int assetTypeIdVal = 0;
    if (rawAssetTypeId is int) {
      assetTypeIdVal = rawAssetTypeId;
    } else if (rawAssetTypeId is num) {
      assetTypeIdVal = rawAssetTypeId.toInt();
    }

    return AssetAssignment(
      id: idVal,
      employeeId: empIdVal,
      employeeName: (map['employee_name'] as String?) ?? '',
      employeeCode: (map['employee_code'] as String?) ?? '',
      assetTypeId: assetTypeIdVal,
      assetTypeName: (map['asset_type_name'] as String?) ?? '',
      assignedDate: (map['assigned_date'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'Assigned',
      createdAt: map['created_at'] as String?,
    );
  }
}
