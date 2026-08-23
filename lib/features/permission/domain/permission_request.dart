import 'permission_enums.dart';

class PermissionRequest {
  final int? id;
  final int employeeId;
  final String employeeName;
  final String employeeCode;
  final String department;
  final DateTime date;
  final String fromTime; // 'HH:mm' or 'hh:mm a'
  final String toTime;   // 'HH:mm' or 'hh:mm a'
  final int durationMinutes;
  final PermissionType permissionType;
  final String reason;
  final PermissionStatus status;
  final bool isEmergency;
  final String? emergencyReason;
  final String? attachmentUrl;
  final DateTime submittedAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? adminComment;
  final PayrollTreatment payrollTreatment;
  final int paidDurationMinutes;
  final int lopDurationMinutes;

  const PermissionRequest({
    this.id,
    required this.employeeId,
    required this.employeeName,
    required this.employeeCode,
    required this.department,
    required this.date,
    required this.fromTime,
    required this.toTime,
    required this.durationMinutes,
    required this.permissionType,
    required this.reason,
    required this.status,
    this.isEmergency = false,
    this.emergencyReason,
    this.attachmentUrl,
    required this.submittedAt,
    this.reviewedBy,
    this.reviewedAt,
    this.adminComment,
    this.payrollTreatment = PayrollTreatment.unspecified,
    this.paidDurationMinutes = 0,
    this.lopDurationMinutes = 0,
  });

  PermissionRequest copyWith({
    int? id,
    int? employeeId,
    String? employeeName,
    String? employeeCode,
    String? department,
    DateTime? date,
    String? fromTime,
    String? toTime,
    int? durationMinutes,
    PermissionType? permissionType,
    String? reason,
    PermissionStatus? status,
    bool? isEmergency,
    String? emergencyReason,
    String? attachmentUrl,
    DateTime? submittedAt,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? adminComment,
    PayrollTreatment? payrollTreatment,
    int? paidDurationMinutes,
    int? lopDurationMinutes,
  }) {
    return PermissionRequest(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      employeeCode: employeeCode ?? this.employeeCode,
      department: department ?? this.department,
      date: date ?? this.date,
      fromTime: fromTime ?? this.fromTime,
      toTime: toTime ?? this.toTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      permissionType: permissionType ?? this.permissionType,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      isEmergency: isEmergency ?? this.isEmergency,
      emergencyReason: emergencyReason ?? this.emergencyReason,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      submittedAt: submittedAt ?? this.submittedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      adminComment: adminComment ?? this.adminComment,
      payrollTreatment: payrollTreatment ?? this.payrollTreatment,
      paidDurationMinutes: paidDurationMinutes ?? this.paidDurationMinutes,
      lopDurationMinutes: lopDurationMinutes ?? this.lopDurationMinutes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'employee_code': employeeCode,
      'department': department,
      'date': date.toIso8601String().split('T').first,
      'from_time': fromTime,
      'to_time': toTime,
      'duration_minutes': durationMinutes,
      'permission_type': permissionType.name,
      'reason': reason,
      'status': status.name,
      'is_emergency': isEmergency ? 1 : 0,
      'emergency_reason': emergencyReason,
      'attachment_url': attachmentUrl,
      'submitted_at': submittedAt.toIso8601String(),
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'admin_comment': adminComment,
      'payroll_treatment': payrollTreatment.name,
      'paid_duration_minutes': paidDurationMinutes,
      'lop_duration_minutes': lopDurationMinutes,
    };
  }

  static int _parseEmployeeId(dynamic val) {
    if (val is int) return val;
    if (val != null) {
      final str = val.toString().trim();
      final parsed = int.tryParse(str);
      if (parsed != null) return parsed;
      final digits = str.replaceAll(RegExp(r'\D'), '');
      if (digits.isNotEmpty) {
        return int.tryParse(digits) ?? 0;
      }
    }
    return 0;
  }

  static DateTime _parseDate(dynamic val) {
    if (val == null) return DateTime.now();
    if (val is DateTime) return DateTime(val.year, val.month, val.day);
    final str = val.toString().trim();
    if (str.isEmpty) return DateTime.now();
    final parsedIso = DateTime.tryParse(str);
    if (parsedIso != null) {
      return DateTime(parsedIso.year, parsedIso.month, parsedIso.day);
    }
    try {
      final parts = str.split('-');
      if (parts.length == 3) {
        if (parts[0].length == 4) {
          return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        } else {
          return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      }
    } catch (_) {}
    return DateTime.now();
  }

  factory PermissionRequest.fromMap(Map<String, dynamic> map) {
    return PermissionRequest(
      id: map['id'] as int?,
      employeeId: _parseEmployeeId(map['employee_id']),
      employeeName: map['employee_name'] as String? ?? '',
      employeeCode: map['employee_code'] as String? ?? '',
      department: map['department'] as String? ?? '',
      date: _parseDate(map['date']),
      fromTime: map['from_time'] as String? ?? '',
      toTime: map['to_time'] as String? ?? '',
      durationMinutes: map['duration_minutes'] as int? ?? 0,
      permissionType: PermissionType.fromString(map['permission_type']?.toString() ?? ''),
      reason: map['reason'] as String? ?? '',
      status: PermissionStatus.fromString(map['status']?.toString() ?? 'pending'),
      isEmergency: (map['is_emergency'] ?? 0) == 1,
      emergencyReason: map['emergency_reason'] as String?,
      attachmentUrl: map['attachment_url'] as String?,
      submittedAt: DateTime.tryParse(map['submitted_at']?.toString() ?? '') ?? DateTime.now(),
      reviewedBy: map['reviewed_by'] as String?,
      reviewedAt: map['reviewed_at'] != null ? DateTime.tryParse(map['reviewed_at'].toString()) : null,
      adminComment: map['admin_comment'] as String?,
      payrollTreatment: PayrollTreatment.fromString(map['payroll_treatment']?.toString() ?? ''),
      paidDurationMinutes: map['paid_duration_minutes'] as int? ?? 0,
      lopDurationMinutes: map['lop_duration_minutes'] as int? ?? 0,
    );
  }
}
