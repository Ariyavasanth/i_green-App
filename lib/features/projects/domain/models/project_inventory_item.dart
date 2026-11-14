class ProjectInventoryItem {
  final String id;
  final String projectCode;
  final String supervisorId;
  final String supervisorName;
  final String itemId;
  final String itemName;
  final String unit;
  final double issuedQty;
  final double usedQty;
  final double returnedQty;
  final DateTime updatedAt;

  const ProjectInventoryItem({
    required this.id,
    required this.projectCode,
    required this.supervisorId,
    required this.supervisorName,
    required this.itemId,
    required this.itemName,
    this.unit = 'units',
    this.issuedQty = 0.0,
    this.usedQty = 0.0,
    this.returnedQty = 0.0,
    required this.updatedAt,
  });

  double get balanceQty => issuedQty - (usedQty + returnedQty);

  bool get isSettled => balanceQty <= 0.0001;

  Map<String, dynamic> toJson() => {
        'id': id,
        'project_code': projectCode,
        'supervisor_id': supervisorId,
        'supervisor_name': supervisorName,
        'item_id': itemId,
        'item_name': itemName,
        'unit': unit,
        'issued_qty': issuedQty,
        'used_qty': usedQty,
        'returned_qty': returnedQty,
        'balance_qty': balanceQty,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory ProjectInventoryItem.fromJson(Map<String, dynamic> json, [String? docId]) =>
      ProjectInventoryItem(
        id: docId ?? json['id'] as String? ?? '',
        projectCode: json['project_code'] as String? ?? '',
        supervisorId: json['supervisor_id'] as String? ?? '',
        supervisorName: json['supervisor_name'] as String? ?? '',
        itemId: json['item_id'] as String? ?? '',
        itemName: json['item_name'] as String? ?? '',
        unit: json['unit'] as String? ?? 'units',
        issuedQty: (json['issued_qty'] as num?)?.toDouble() ?? 0.0,
        usedQty: (json['used_qty'] as num?)?.toDouble() ?? 0.0,
        returnedQty: (json['returned_qty'] as num?)?.toDouble() ?? 0.0,
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
}

