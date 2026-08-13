class AssetTransferRequest {
  const AssetTransferRequest({
    required this.id,
    required this.assetAssignmentId,
    required this.assetName,
    required this.assetTypeName,
    required this.serialNumber,
    required this.fromEmployeeId,
    required this.fromEmployeeName,
    required this.fromEmployeeCode,
    required this.toEmployeeId,
    required this.toEmployeeName,
    required this.toEmployeeCode,
    required this.transferDate,
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
  final int fromEmployeeId;
  final String fromEmployeeName;
  final String fromEmployeeCode;
  final int toEmployeeId;
  final String toEmployeeName;
  final String toEmployeeCode;
  final String transferDate;
  final String reason;
  final String status;
  final String? createdAt;
  final String? respondedAt;

  AssetTransferRequest copyWith({int? id, String? status, String? createdAt, String? respondedAt}) =>
      AssetTransferRequest(
        id: id ?? this.id,
        assetAssignmentId: assetAssignmentId,
        assetName: assetName,
        assetTypeName: assetTypeName,
        serialNumber: serialNumber,
        fromEmployeeId: fromEmployeeId,
        fromEmployeeName: fromEmployeeName,
        fromEmployeeCode: fromEmployeeCode,
        toEmployeeId: toEmployeeId,
        toEmployeeName: toEmployeeName,
        toEmployeeCode: toEmployeeCode,
        transferDate: transferDate,
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
        'from_employee_id': fromEmployeeId,
        'from_employee_name': fromEmployeeName,
        'from_employee_code': fromEmployeeCode,
        'to_employee_id': toEmployeeId,
        'to_employee_name': toEmployeeName,
        'to_employee_code': toEmployeeCode,
        'transfer_date': transferDate,
        'reason': reason,
        'status': status,
        'created_at': createdAt,
        'responded_at': respondedAt,
      };

  factory AssetTransferRequest.fromMap(Map<String, dynamic> map, [String? docId]) {
    int asInt(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
    return AssetTransferRequest(
      id: asInt(map['id']) != 0 ? asInt(map['id']) : (docId?.hashCode ?? 0) & 0x7fffffff,
      assetAssignmentId: asInt(map['asset_assignment_id']),
      assetName: map['asset_name'] as String? ?? '',
      assetTypeName: map['asset_type_name'] as String? ?? '',
      serialNumber: map['serial_number'] as String? ?? '',
      fromEmployeeId: asInt(map['from_employee_id']),
      fromEmployeeName: map['from_employee_name'] as String? ?? '',
      fromEmployeeCode: map['from_employee_code'] as String? ?? '',
      toEmployeeId: asInt(map['to_employee_id']),
      toEmployeeName: map['to_employee_name'] as String? ?? '',
      toEmployeeCode: map['to_employee_code'] as String? ?? '',
      transferDate: map['transfer_date'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
      status: map['status'] as String? ?? 'Pending',
      createdAt: map['created_at'] as String?,
      respondedAt: map['responded_at'] as String?,
    );
  }
}
