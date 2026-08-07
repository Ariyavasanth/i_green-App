class IncentiveRequest {
  final int? id;
  final String requestId;
  final int? employeeId;
  final String employeeName;
  final String designation;
  final String site;
  final String productName;
  final double meters;
  final double rate;
  final double amount;
  final double? verifiedMeters;
  final double? approvedAmount;
  final String status; // 'Pending', 'Approved', 'Rejected', 'Cancelled'
  final String? remarks;
  final String createdAt;

  IncentiveRequest({
    this.id,
    required this.requestId,
    this.employeeId,
    required this.employeeName,
    required this.designation,
    required this.site,
    required this.productName,
    required this.meters,
    required this.rate,
    required this.amount,
    this.verifiedMeters,
    this.approvedAmount,
    this.status = 'Pending',
    this.remarks,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'request_id': requestId,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'designation': designation,
      'site': site,
      'product_name': productName,
      'meters': meters,
      'rate': rate,
      'amount': amount,
      'verified_meters': verifiedMeters,
      'approved_amount': approvedAmount,
      'status': status,
      'remarks': remarks,
      'created_at': createdAt,
    };
  }

  factory IncentiveRequest.fromMap(Map<String, dynamic> map) {
    return IncentiveRequest(
      id: map['id'] as int?,
      requestId: map['request_id'] as String? ?? '',
      employeeId: map['employee_id'] as int?,
      employeeName: map['employee_name'] as String? ?? '',
      designation: map['designation'] as String? ?? 'Operator',
      site: map['site'] as String? ?? '',
      productName: map['product_name'] as String? ?? '',
      meters: (map['meters'] as num?)?.toDouble() ?? 0.0,
      rate: (map['rate'] as num?)?.toDouble() ?? 0.0,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      verifiedMeters: (map['verified_meters'] as num?)?.toDouble(),
      approvedAmount: (map['approved_amount'] as num?)?.toDouble(),
      status: map['status'] as String? ?? 'Pending',
      remarks: map['remarks'] as String?,
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  IncentiveRequest copyWith({
    int? id,
    String? requestId,
    int? employeeId,
    String? employeeName,
    String? designation,
    String? site,
    String? productName,
    double? meters,
    double? rate,
    double? amount,
    double? verifiedMeters,
    double? approvedAmount,
    String? status,
    String? remarks,
    String? createdAt,
  }) {
    return IncentiveRequest(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      designation: designation ?? this.designation,
      site: site ?? this.site,
      productName: productName ?? this.productName,
      meters: meters ?? this.meters,
      rate: rate ?? this.rate,
      amount: amount ?? this.amount,
      verifiedMeters: verifiedMeters ?? this.verifiedMeters,
      approvedAmount: approvedAmount ?? this.approvedAmount,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
