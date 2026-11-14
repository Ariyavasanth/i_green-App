class DailyProgressEntry {
  final String id;
  final String projectCode;
  final DateTime date;
  final double quantityDone;
  final double totalQuantity;
  final String unit; // e.g. "metres", "units", "tons"
  final String remarks;
  final String approvalStatus; // 'approved' | 'pending_approval' | 'rejected'
  final String? approvedBy;
  final DateTime? approvedAt;
  final String createdBy;
  final DateTime createdAt;

  const DailyProgressEntry({
    required this.id,
    required this.projectCode,
    required this.date,
    required this.quantityDone,
    required this.totalQuantity,
    this.unit = 'metres',
    this.remarks = '',
    this.approvalStatus = 'approved',
    this.approvedBy,
    this.approvedAt,
    required this.createdBy,
    required this.createdAt,
  });

  double get percentageComplete {
    if (totalQuantity <= 0) return 0.0;
    final pct = (quantityDone / totalQuantity) * 100;
    return pct > 100 ? 100.0 : pct;
  }

  static bool isBackdatedBeyondLimit(DateTime entryDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDay = DateTime(entryDate.year, entryDate.month, entryDate.day);
    final diff = today.difference(entryDay).inDays;
    return diff > 2;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'project_code': projectCode,
        'date': date.toIso8601String(),
        'quantity_done': quantityDone,
        'total_quantity': totalQuantity,
        'unit': unit,
        'remarks': remarks,
        'approval_status': approvalStatus,
        'approved_by': approvedBy,
        'approved_at': approvedAt?.toIso8601String(),
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
      };

  factory DailyProgressEntry.fromJson(Map<String, dynamic> json, [String? docId]) =>
      DailyProgressEntry(
        id: docId ?? json['id'] as String? ?? '',
        projectCode: json['project_code'] as String? ?? '',
        date: json['date'] != null
            ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
            : DateTime.now(),
        quantityDone: (json['quantity_done'] as num?)?.toDouble() ?? 0.0,
        totalQuantity: (json['total_quantity'] as num?)?.toDouble() ?? 0.0,
        unit: json['unit'] as String? ?? 'metres',
        remarks: json['remarks'] as String? ?? '',
        approvalStatus: json['approval_status'] as String? ?? 'approved',
        approvedBy: json['approved_by'] as String?,
        approvedAt: json['approved_at'] != null
            ? DateTime.tryParse(json['approved_at'].toString())
            : null,
        createdBy: json['created_by'] as String? ?? '',
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
}

