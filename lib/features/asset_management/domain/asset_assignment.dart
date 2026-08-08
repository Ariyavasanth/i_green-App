class AssetAssignment {
  const AssetAssignment({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    this.employeeCode = '',
    required this.assetTypeId,
    required this.assetTypeName,
    this.assetName = '',
    this.serialNumber = '',
    required this.assignedDate,
    required this.description,
    this.status = 'Assigned',
    this.maintenanceAddress,
    this.maintenanceContact,
    this.maintenanceGivenDate,
    this.maintenanceReturnDate,
    this.transferredFrom,
    this.transferDate,
    this.createdAt,
  });

  final int id;
  final int employeeId;
  final String employeeName;
  final String employeeCode;
  final int assetTypeId;
  final String assetTypeName;
  final String assetName;
  final String serialNumber;
  final String assignedDate;
  final String description; // Reason explaining the assignment
  final String status; // Assigned, Returned, Maintenance
  final String? maintenanceAddress;
  final String? maintenanceContact;
  final String? maintenanceGivenDate;
  final String? maintenanceReturnDate;
  final String? transferredFrom;
  final String? transferDate;
  final String? createdAt;

  AssetAssignment copyWith({
    int? id,
    int? employeeId,
    String? employeeName,
    String? employeeCode,
    int? assetTypeId,
    String? assetTypeName,
    String? assetName,
    String? serialNumber,
    String? assignedDate,
    String? description,
    String? status,
    String? maintenanceAddress,
    String? maintenanceContact,
    String? maintenanceGivenDate,
    String? maintenanceReturnDate,
    String? transferredFrom,
    String? transferDate,
    String? createdAt,
  }) {
    return AssetAssignment(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      employeeCode: employeeCode ?? this.employeeCode,
      assetTypeId: assetTypeId ?? this.assetTypeId,
      assetTypeName: assetTypeName ?? this.assetTypeName,
      assetName: assetName ?? this.assetName,
      serialNumber: serialNumber ?? this.serialNumber,
      assignedDate: assignedDate ?? this.assignedDate,
      description: description ?? this.description,
      status: status ?? this.status,
      maintenanceAddress: maintenanceAddress ?? this.maintenanceAddress,
      maintenanceContact: maintenanceContact ?? this.maintenanceContact,
      maintenanceGivenDate: maintenanceGivenDate ?? this.maintenanceGivenDate,
      maintenanceReturnDate: maintenanceReturnDate ?? this.maintenanceReturnDate,
      transferredFrom: transferredFrom ?? this.transferredFrom,
      transferDate: transferDate ?? this.transferDate,
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
        'asset_name': assetName,
        'serial_number': serialNumber,
        'assigned_date': assignedDate,
        'description': description,
        'status': status,
        'maintenance_address': maintenanceAddress,
        'maintenance_contact': maintenanceContact,
        'maintenance_given_date': maintenanceGivenDate,
        'maintenance_return_date': maintenanceReturnDate,
        'transferred_from': transferredFrom,
        'transfer_date': transferDate,
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
      assetName: (map['asset_name'] as String?) ?? '',
      serialNumber: (map['serial_number'] as String?) ?? '',
      assignedDate: (map['assigned_date'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'Assigned',
      maintenanceAddress: map['maintenance_address'] as String?,
      maintenanceContact: map['maintenance_contact'] as String?,
      maintenanceGivenDate: map['maintenance_given_date'] as String?,
      maintenanceReturnDate: map['maintenance_return_date'] as String?,
      transferredFrom: map['transferred_from'] as String?,
      transferDate: map['transfer_date'] as String?,
      createdAt: map['created_at'] as String?,
    );
  }
}
