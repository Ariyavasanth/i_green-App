import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceCorrectionRequest {
  const AttendanceCorrectionRequest({
    required this.id,
    required this.employeeId,
    required this.employeeCode,
    required this.employeeName,
    this.department = '',
    required this.date,
    required this.accidentalCheckOutTime,
    required this.activityType,
    required this.startTime,
    required this.description,
    this.status = 'pending', // 'pending', 'approved', 'rejected'
    this.resumedCheckInTime,
    this.finalCheckOutTime,
    this.adminComment,
    this.reviewedBy,
    this.reviewedAt,
    required this.submittedAt,
  });

  final String id;
  final int employeeId;
  final String employeeCode;
  final String employeeName;
  final String department;
  final String date; // YYYY-MM-DD
  final String accidentalCheckOutTime; // e.g. "12:00:00 PM"
  final String activityType; // "Lunch Break", "Tea Break", "Meeting", "Accidental Check-Out"
  final String startTime; // Only start time specified by employee
  final String description;
  final String status;
  final String? resumedCheckInTime; // Set by admin upon approval
  final String? finalCheckOutTime; // Set by admin if approving a past day
  final String? adminComment;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime submittedAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'employee_code': employeeCode,
      'employee_name': employeeName,
      'department': department,
      'date': date,
      'accidental_checkout_time': accidentalCheckOutTime,
      'activity_type': activityType,
      'start_time': startTime,
      'description': description,
      'status': status,
      'resumed_check_in_time': resumedCheckInTime,
      'final_checkout_time': finalCheckOutTime,
      'admin_comment': adminComment,
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'submitted_at': Timestamp.fromDate(submittedAt),
    };
  }

  factory AttendanceCorrectionRequest.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return AttendanceCorrectionRequest(
      id: docId,
      employeeId: map['employee_id'] is int
          ? map['employee_id'] as int
          : int.tryParse(map['employee_id']?.toString() ?? '0') ?? 0,
      employeeCode: (map['employee_code'] ?? '').toString(),
      employeeName: (map['employee_name'] ?? '').toString(),
      department: (map['department'] ?? '').toString(),
      date: (map['date'] ?? '').toString(),
      accidentalCheckOutTime: (map['accidental_checkout_time'] ?? '').toString(),
      activityType: (map['activity_type'] ?? 'Lunch Break').toString(),
      startTime: (map['start_time'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      status: (map['status'] ?? 'pending').toString(),
      resumedCheckInTime: map['resumed_check_in_time']?.toString(),
      finalCheckOutTime: map['final_checkout_time']?.toString(),
      adminComment: map['admin_comment']?.toString(),
      reviewedBy: map['reviewed_by']?.toString(),
      reviewedAt: map['reviewed_at'] != null ? parseDateTime(map['reviewed_at']) : null,
      submittedAt: parseDateTime(map['submitted_at']),
    );
  }
}

