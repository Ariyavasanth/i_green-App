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
  final String status; // Pending, Approved, Denied
  final String createdAt;
  final List<String> approvedDates;
  final List<String> lopDates;

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
    };
  }

  factory LeaveRequest.fromMap(Map<String, dynamic> map) {
    List<String> parseJsonList(String? jsonStr) {
      if (jsonStr == null || jsonStr.isEmpty) return [];
      try {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
      return [];
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
      approvedDates: parseJsonList(map['approved_dates'] as String?),
      lopDates: parseJsonList(map['lop_dates'] as String?),
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
    );
  }
}
