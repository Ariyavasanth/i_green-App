class AssetReturnRequest {
  const AssetReturnRequest({
    required this.id,
    required this.assetAssignmentId,
    required this.assetName,
    required this.assetTypeName,
    required this.serialNumber,
    required this.employeeId,
    required this.employeeName,
    required this.employeeCode,
    required this.requestDate,
    required this.reason,
    this.status = 'Pending',
    this.createdAt,
    this.respondedAt,
  });

  final int id;
  final int assetAssignmentId;
  final String assetName;
  final String assetTypeName;
  final String serialNumber;
  final int employeeId;
  final String employeeName;
  final String employeeCode;
  final String requestDate;
  final String reason;
  final String status; // Pending, Approved, Rejected
  final String? createdAt;
  final String? respondedAt;

  AssetReturnRequest copyWith({
    int? id,
    String? status,
    String? createdAt,
    String? respondedAt,
  }) =>
      AssetReturnRequest(
        id: id ?? this.id,
        assetAssignmentId: assetAssignmentId,
        assetName: assetName,
        assetTypeName: assetTypeName,
        serialNumber: serialNumber,
        employeeId: employeeId,
        employeeName: employeeName,
        employeeCode: employeeCode,
        requestDate: requestDate,
        reason: reason,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        respondedAt: respondedAt ?? this.respondedAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'asset_assignment_id': assetAssignmentId,
        'asset_name': assetName,
        'asset_type_name': assetTypeName,
        'serial_number': serialNumber,
        'employee_id': employeeId,
        'employee_name': employeeName,
        'employee_code': employeeCode,
        'request_date': requestDate,
        'reason': reason,
        'status': status,
        'created_at': createdAt,
        'responded_at': respondedAt,
      };

  factory AssetReturnRequest.fromMap(Map<String, dynamic> map, [String? docId]) {
    int asInt(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
    return AssetReturnRequest(
      id: asInt(map['id']) != 0 ? asInt(map['id']) : (docId?.hashCode ?? 0) & 0x7fffffff,
      assetAssignmentId: asInt(map['asset_assignment_id']),
      assetName: map['asset_name'] as String? ?? '',
      assetTypeName: map['asset_type_name'] as String? ?? '',
      serialNumber: map['serial_number'] as String? ?? '',
      employeeId: asInt(map['employee_id']),
      employeeName: map['employee_name'] as String? ?? '',
      employeeCode: map['employee_code'] as String? ?? '',
      requestDate: map['request_date'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
      status: map['status'] as String? ?? 'Pending',
      createdAt: map['created_at'] as String?,
      respondedAt: map['responded_at'] as String?,
    );
  }
}
