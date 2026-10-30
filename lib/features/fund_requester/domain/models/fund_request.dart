import 'fund_request_item.dart';

class FundRequest {
  final String id;
  final String requestNumber;
  final String employeeId;
  final String employeeName;
  final String employeeCustomId;
  final String department;
  final String message;
  final String projectCode;
  final String projectName;
  final double approvedAmount;
  final double requestAmount;
  final List<FundRequestItem> items;
  final List<String> billUrls;
  final String? audioNoteUrl;
  final int? audioDurationSeconds;
  final String status; // 'Pending', 'Approved', 'Rejected'
  final String? approvalRemarks;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  const FundRequest({
    required this.id,
    required this.requestNumber,
    required this.employeeId,
    required this.employeeName,
    this.employeeCustomId = '',
    this.department = '',
    required this.message,
    required this.projectCode,
    this.projectName = '',
    this.approvedAmount = 0.0,
    required this.requestAmount,
    this.items = const [],
    this.billUrls = const [],
    this.audioNoteUrl,
    this.audioDurationSeconds,
    this.status = 'Pending',
    this.approvalRemarks,
    this.approvedBy,
    this.approvedAt,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  FundRequest copyWith({
    String? id,
    String? requestNumber,
    String? employeeId,
    String? employeeName,
    String? employeeCustomId,
    String? department,
    String? message,
    String? projectCode,
    String? projectName,
    double? approvedAmount,
    double? requestAmount,
    List<FundRequestItem>? items,
    List<String>? billUrls,
    String? audioNoteUrl,
    int? audioDurationSeconds,
    String? status,
    String? approvalRemarks,
    String? approvedBy,
    DateTime? approvedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return FundRequest(
      id: id ?? this.id,
      requestNumber: requestNumber ?? this.requestNumber,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      employeeCustomId: employeeCustomId ?? this.employeeCustomId,
      department: department ?? this.department,
      message: message ?? this.message,
      projectCode: projectCode ?? this.projectCode,
      projectName: projectName ?? this.projectName,
      approvedAmount: approvedAmount ?? this.approvedAmount,
      requestAmount: requestAmount ?? this.requestAmount,
      items: items ?? this.items,
      billUrls: billUrls ?? this.billUrls,
      audioNoteUrl: audioNoteUrl ?? this.audioNoteUrl,
      audioDurationSeconds: audioDurationSeconds ?? this.audioDurationSeconds,
      status: status ?? this.status,
      approvalRemarks: approvalRemarks ?? this.approvalRemarks,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'requestNumber': requestNumber,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'employeeCustomId': employeeCustomId,
      'department': department,
      'message': message,
      'projectCode': projectCode,
      'projectName': projectName,
      'approvedAmount': approvedAmount,
      'requestAmount': requestAmount,
      'items': items.map((item) => item.toMap()).toList(),
      'billUrls': billUrls,
      'audioNoteUrl': audioNoteUrl,
      'audioDurationSeconds': audioDurationSeconds,
      'status': status,
      'approvalRemarks': approvalRemarks,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isDeleted': isDeleted,
    };
  }

  factory FundRequest.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawItems = map['items'] as List<dynamic>? ?? [];
    final itemsList = rawItems
        .map((item) => FundRequestItem.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();

    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val == null) return fallback;
      if (val is DateTime) return val;
      if (val is String) {
        return DateTime.tryParse(val) ?? fallback;
      }
      try {
        // Handle Firestore Timestamp
        final dynamic dynamicVal = val;
        return dynamicVal.toDate();
      } catch (_) {
        return fallback;
      }
    }

    final rawBills = map['billUrls'] as List<dynamic>? ?? [];

    return FundRequest(
      id: docId ?? (map['id'] ?? '').toString(),
      requestNumber: (map['requestNumber'] ?? map['request_number'] ?? '').toString(),
      employeeId: (map['employeeId'] ?? map['employee_id'] ?? '').toString(),
      employeeName: (map['employeeName'] ?? map['employee_name'] ?? '').toString(),
      employeeCustomId: (map['employeeCustomId'] ?? map['employee_custom_id'] ?? '').toString(),
      department: (map['department'] ?? '').toString(),
      message: (map['message'] ?? '').toString(),
      projectCode: (map['projectCode'] ?? map['project_code'] ?? '').toString(),
      projectName: (map['projectName'] ?? map['project_name'] ?? '').toString(),
      approvedAmount: (map['approvedAmount'] is num)
          ? (map['approvedAmount'] as num).toDouble()
          : (double.tryParse('${map['approvedAmount']}') ?? 0.0),
      requestAmount: (map['requestAmount'] is num)
          ? (map['requestAmount'] as num).toDouble()
          : (double.tryParse('${map['requestAmount']}') ?? 0.0),
      items: itemsList,
      billUrls: rawBills.map((e) => e.toString()).toList(),
      audioNoteUrl: map['audioNoteUrl']?.toString(),
      audioDurationSeconds: map['audioDurationSeconds'] as int?,
      status: (map['status'] ?? 'Pending').toString(),
      approvalRemarks: map['approvalRemarks']?.toString(),
      approvedBy: map['approvedBy']?.toString(),
      approvedAt: map['approvedAt'] != null ? parseDate(map['approvedAt'], DateTime.now()) : null,
      createdAt: parseDate(map['createdAt'] ?? map['created_at'], DateTime.now()),
      updatedAt: parseDate(map['updatedAt'] ?? map['updated_at'], DateTime.now()),
      isDeleted: map['isDeleted'] == true || map['is_deleted'] == true,
    );
  }
}

