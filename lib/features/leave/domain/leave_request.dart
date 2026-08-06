import 'dart:convert';

class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.employeeCustomId,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.numDays,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.approvedDates = const [],
    this.lopDates = const [],
    this.isEmergency = false,
    this.attachmentUrl,
    this.rejectionReason,
    this.isHalfDay = false,
    this.halfDayPeriod,
  });

  final int id;
  final int employeeId;
  final String employeeName;
  final String employeeCustomId;
  final String leaveType;
  final String fromDate;
  final String toDate;
  final double numDays;
  final String reason;
  final String status; // Pending, Approved, Denied, Cancelled
  final String createdAt;
  final List<String> approvedDates;
  final List<String> lopDates;
  final bool isEmergency;
  final String? attachmentUrl;
  final String? rejectionReason;
  final bool isHalfDay;
  final String? halfDayPeriod;

  Map<String, dynamic> toMap() {
    return {
      if (id != 0) 'id': id,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'employee_custom_id': employeeCustomId,
      'leave_type': leaveType,
      'from_date': fromDate,
      'to_date': toDate,
      'num_days': numDays,
      'reason': reason,
      'status': status,
      'created_at': createdAt,
      'approved_dates': jsonEncode(approvedDates),
      'lop_dates': jsonEncode(lopDates),
      'is_emergency': isEmergency ? 1 : 0,
      'attachment_url': attachmentUrl,
      'rejection_reason': rejectionReason,
      'is_half_day': isHalfDay ? 1 : 0,
      'half_day_period': halfDayPeriod,
    };
  }

  factory LeaveRequest.fromMap(Map<String, dynamic> map) {
    List<String> parseList(dynamic raw) {
      if (raw == null) return [];
      // Firestore native array of strings
      if (raw is List) return raw.map((e) => e.toString()).toList();
      // SQLite JSON-encoded string
      if (raw is String && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) return decoded.map((e) => e.toString()).toList();
        } catch (_) {}
      }
      return [];
    }

    bool parseBool(dynamic raw) {
      if (raw == null) return false;
      if (raw is int) return raw != 0;
      if (raw is bool) return raw;
      if (raw is String) return raw == '1' || raw.toLowerCase() == 'true';
      return false;
    }

    return LeaveRequest(
      id: map['id'] as int? ?? 0,
      employeeId: map['employee_id'] as int? ?? 0,
      employeeName: map['employee_name'] as String? ?? '',
      employeeCustomId: map['employee_custom_id'] as String? ?? '',
      leaveType: map['leave_type'] as String? ?? '',
      fromDate: map['from_date'] as String? ?? '',
      toDate: map['to_date'] as String? ?? '',
      numDays: (map['num_days'] as num?)?.toDouble() ?? 0.0,
      reason: map['reason'] as String? ?? '',
      status: map['status'] as String? ?? 'Pending',
      createdAt: map['created_at'] as String? ?? '',
      approvedDates: parseList(map['approved_dates']),
      lopDates: parseList(map['lop_dates']),
      isEmergency: parseBool(map['is_emergency']),
      attachmentUrl: map['attachment_url'] as String?,
      rejectionReason: map['rejection_reason'] as String?,
      isHalfDay: parseBool(map['is_half_day']),
      halfDayPeriod: map['half_day_period'] as String?,
    );
  }

  LeaveRequest copyWith({
    int? id,
    int? employeeId,
    String? employeeName,
    String? employeeCustomId,
    String? leaveType,
    String? fromDate,
    String? toDate,
    double? numDays,
    String? reason,
    String? status,
    String? createdAt,
    List<String>? approvedDates,
    List<String>? lopDates,
    bool? isEmergency,
    String? attachmentUrl,
    String? rejectionReason,
    bool? isHalfDay,
    String? halfDayPeriod,
  }) {
    return LeaveRequest(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      employeeCustomId: employeeCustomId ?? this.employeeCustomId,
      leaveType: leaveType ?? this.leaveType,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      numDays: numDays ?? this.numDays,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      approvedDates: approvedDates ?? this.approvedDates,
      lopDates: lopDates ?? this.lopDates,
      isEmergency: isEmergency ?? this.isEmergency,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      isHalfDay: isHalfDay ?? this.isHalfDay,
      halfDayPeriod: halfDayPeriod ?? this.halfDayPeriod,
    );
  }
}
