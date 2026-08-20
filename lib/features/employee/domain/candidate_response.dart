import 'dart:convert';

import 'employee.dart';

class CandidateResponse {
  const CandidateResponse({
    this.id = 0,
    required this.candidateId,
    required this.linkId,
    required this.employeeData,
    required this.submittedDate,
    this.status = 'Submitted',
  });

  final int id;
  final String candidateId;
  final String linkId;
  final Employee employeeData;
  final String submittedDate;
  final String status;

  Map<String, dynamic> toMap() {
    return {
      if (id != 0) 'id': id,
      'candidate_id': candidateId,
      'link_id': linkId,
      'submitted_date': submittedDate,
      'status': status,
      'employee_data_json': employeeData.toJson(),
      'full_name': employeeData.fullName,
      'email_address': employeeData.emailAddress,
      'phone_number': employeeData.phoneNumber,
    };
  }

  factory CandidateResponse.fromMap(Map<String, dynamic> map) {
    int parsedId = 0;
    if (map['id'] != null) {
      if (map['id'] is int) {
        parsedId = map['id'] as int;
      } else {
        parsedId = int.tryParse(map['id'].toString()) ?? 0;
      }
    }

    Employee empData;
    if (map['employee_data_json'] != null && map['employee_data_json'].toString().trim().isNotEmpty) {
      empData = Employee.fromJson(map['employee_data_json'].toString());
    } else {
      empData = Employee.fromMap(map);
    }

    final candidateId = map['candidate_id']?.toString() ?? empData.employeeId;

    return CandidateResponse(
      id: parsedId,
      candidateId: candidateId,
      linkId: map['link_id']?.toString() ?? '',
      employeeData: empData.copyWith(employeeId: candidateId),
      submittedDate: map['submitted_date']?.toString() ?? '',
      status: map['status']?.toString() ?? 'Submitted',
    );
  }

  CandidateResponse copyWith({
    int? id,
    String? candidateId,
    String? linkId,
    Employee? employeeData,
    String? submittedDate,
    String? status,
  }) {
    return CandidateResponse(
      id: id ?? this.id,
      candidateId: candidateId ?? this.candidateId,
      linkId: linkId ?? this.linkId,
      employeeData: employeeData ?? this.employeeData,
      submittedDate: submittedDate ?? this.submittedDate,
      status: status ?? this.status,
    );
  }
}
