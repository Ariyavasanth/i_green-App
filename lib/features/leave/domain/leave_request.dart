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
    this.isOverride = false,
    this.overrideReason,
    this.approvedBy,
    this.requestedDays = 0.0,
    this.calculatedPaidDays = 0.0,
    this.calculatedLopDays = 0.0,
    this.paidDays = 0.0,
    this.lopDays = 0.0,
    this.approvalMode = 'calculated',
    this.leavePolicySnapshot = '',
    this.monthlyAllowanceSnapshot = 3.0,
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
  final bool isOverride;
  final String? overrideReason;
  final String? approvedBy;
  final double requestedDays;
  final double calculatedPaidDays;
  final double calculatedLopDays;
  final double paidDays;
  final double lopDays;
  final String approvalMode;
  final String leavePolicySnapshot;
  final double monthlyAllowanceSnapshot;

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
      'is_override': isOverride ? 1 : 0,
      'override_reason': overrideReason,
      'approved_by': approvedBy,
      'requested_days': requestedDays > 0 ? requestedDays : numDays,
      'calculated_paid_days': calculatedPaidDays,
      'calculated_lop_days': calculatedLopDays,
      'paid_days': paidDays,
      'lop_days': lopDays,
      'approval_mode': approvalMode,
      'leave_policy_snapshot': leavePolicySnapshot,
      'monthly_allowance_snapshot': monthlyAllowanceSnapshot,
    };
  }

  factory LeaveRequest.fromMap(Map<String, dynamic> map) {
    int parseInt(dynamic raw) {
      if (raw == null) return 0;
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) {
        final parsed = int.tryParse(raw);
        if (parsed != null) return parsed;
        final digits = raw.replaceAll(RegExp(r'\D'), '');
        if (digits.isNotEmpty) return int.tryParse(digits) ?? 0;
      }
      return 0;
    }

    String parseString(dynamic raw) {
      if (raw == null) return '';
      if (raw is String) return raw;
      if (raw.runtimeType.toString().contains('Timestamp')) {
        try {
          final dt = (raw as dynamic).toDate() as DateTime;
          return dt.toIso8601String();
        } catch (_) {}
      }
      if (raw is DateTime) return raw.toIso8601String();
      return raw.toString();
    }

    List<String> parseList(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
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

    final createdAtRaw = map['created_at'] ?? map['submitted_at'];

    return LeaveRequest(
      id: parseInt(map['id']),
      employeeId: parseInt(map['employee_id']),
      employeeName: parseString(map['employee_name']),
      employeeCustomId: parseString(map['employee_custom_id']),
      leaveType: parseString(map['leave_type']),
      fromDate: parseString(map['from_date']),
      toDate: parseString(map['to_date']),
      numDays: (map['num_days'] as num?)?.toDouble() ?? 0.0,
      reason: parseString(map['reason']),
      status: parseString(map['status']).isEmpty ? 'Pending' : parseString(map['status']),
      createdAt: parseString(createdAtRaw),
      approvedDates: parseList(map['approved_dates']),
      lopDates: parseList(map['lop_dates']),
      isEmergency: parseBool(map['is_emergency']),
      attachmentUrl: map['attachment_url'] != null ? parseString(map['attachment_url']) : null,
      rejectionReason: map['rejection_reason'] != null ? parseString(map['rejection_reason']) : null,
      isHalfDay: parseBool(map['is_half_day']),
      halfDayPeriod: map['half_day_period'] != null ? parseString(map['half_day_period']) : null,
      isOverride: parseBool(map['is_override']),
      overrideReason: map['override_reason'] != null ? parseString(map['override_reason']) : null,
      approvedBy: map['approved_by'] != null ? parseString(map['approved_by']) : null,
      requestedDays: (map['requested_days'] as num?)?.toDouble() ?? ((map['num_days'] as num?)?.toDouble() ?? 0.0),
      calculatedPaidDays: (map['calculated_paid_days'] as num?)?.toDouble() ?? 0.0,
      calculatedLopDays: (map['calculated_lop_days'] as num?)?.toDouble() ?? 0.0,
      paidDays: (map['paid_days'] as num?)?.toDouble() ?? 0.0,
      lopDays: (map['lop_days'] as num?)?.toDouble() ?? 0.0,
      approvalMode: parseString(map['approval_mode']).isEmpty ? 'calculated' : parseString(map['approval_mode']),
      leavePolicySnapshot: parseString(map['leave_policy_snapshot']),
      monthlyAllowanceSnapshot: (map['monthly_allowance_snapshot'] as num?)?.toDouble() ?? 3.0,
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
    bool? isOverride,
    String? overrideReason,
    String? approvedBy,
    double? requestedDays,
    double? calculatedPaidDays,
    double? calculatedLopDays,
    double? paidDays,
    double? lopDays,
    String? approvalMode,
    String? leavePolicySnapshot,
    double? monthlyAllowanceSnapshot,
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
      isOverride: isOverride ?? this.isOverride,
      overrideReason: overrideReason ?? this.overrideReason,
      approvedBy: approvedBy ?? this.approvedBy,
      requestedDays: requestedDays ?? this.requestedDays,
      calculatedPaidDays: calculatedPaidDays ?? this.calculatedPaidDays,
      calculatedLopDays: calculatedLopDays ?? this.calculatedLopDays,
      paidDays: paidDays ?? this.paidDays,
      lopDays: lopDays ?? this.lopDays,
      approvalMode: approvalMode ?? this.approvalMode,
      leavePolicySnapshot: leavePolicySnapshot ?? this.leavePolicySnapshot,
      monthlyAllowanceSnapshot: monthlyAllowanceSnapshot ?? this.monthlyAllowanceSnapshot,
    );
  }
}
