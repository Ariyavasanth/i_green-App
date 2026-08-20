class RegistrationLink {
  const RegistrationLink({
    required this.id,
    required this.linkId,
    required this.generatedBy,
    required this.generatedDate,
    required this.expiryDate,
    required this.linkStatus, // 'Pending', 'Completed', 'Expired'
    this.employeeName = '',
    this.employeeId = '',
    this.organizationName = '',
    this.department = '',
    this.submittedDate = '',
    this.submittedBy = '',
  });

  final int id;
  final String linkId;
  final String generatedBy;
  final String generatedDate;
  final String expiryDate;
  final String linkStatus;
  final String employeeName;
  final String employeeId;
  final String organizationName;
  final String department;
  final String submittedDate;
  final String submittedBy;

  String get fullUrl {
    try {
      final uri = Uri.base;
      if (uri.scheme == 'http' || uri.scheme == 'https') {
        final origin = uri.origin;
        if (!origin.contains('localhost') &&
            !origin.contains('127.0.0.1')) {
          return '$origin/#/employee/register/$linkId';
        }
      }
    } catch (_) {}
    return 'https://app.igreentech.in/#/employee/register/$linkId';
  }

  String buildFullUrl({String? customBaseUrl}) {
    if (customBaseUrl != null && customBaseUrl.trim().isNotEmpty) {
      final base = customBaseUrl.trim().replaceAll(RegExp(r'/$'), '');
      return '$base/#/employee/register/$linkId';
    }
    return fullUrl;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != 0) 'id': id,
      'link_id': linkId,
      'generated_by': generatedBy,
      'generated_date': generatedDate,
      'expiry_date': expiryDate,
      'link_status': linkStatus,
      'employee_name': employeeName,
      'employee_id': employeeId,
      'organization_name': organizationName,
      'department': department,
      'submitted_date': submittedDate,
      'submitted_by': submittedBy,
    };
  }

  factory RegistrationLink.fromMap(Map<String, dynamic> map) {
    int parsedId = 0;
    if (map['id'] != null) {
      if (map['id'] is int) {
        parsedId = map['id'] as int;
      } else {
        parsedId = int.tryParse(map['id'].toString()) ?? 0;
      }
    }

    return RegistrationLink(
      id: parsedId,
      linkId: map['link_id']?.toString() ?? '',
      generatedBy: map['generated_by']?.toString() ?? '',
      generatedDate: map['generated_date']?.toString() ?? '',
      expiryDate: map['expiry_date']?.toString() ?? '',
      linkStatus: map['link_status']?.toString() ?? 'Pending',
      employeeName: map['employee_name']?.toString() ?? '',
      employeeId: map['employee_id']?.toString() ?? '',
      organizationName: map['organization_name']?.toString() ?? '',
      department: map['department']?.toString() ?? '',
      submittedDate: map['submitted_date']?.toString() ?? '',
      submittedBy: map['submitted_by']?.toString() ?? '',
    );
  }

  RegistrationLink copyWith({
    int? id,
    String? linkId,
    String? generatedBy,
    String? generatedDate,
    String? expiryDate,
    String? linkStatus,
    String? employeeName,
    String? employeeId,
    String? organizationName,
    String? department,
    String? submittedDate,
    String? submittedBy,
  }) {
    return RegistrationLink(
      id: id ?? this.id,
      linkId: linkId ?? this.linkId,
      generatedBy: generatedBy ?? this.generatedBy,
      generatedDate: generatedDate ?? this.generatedDate,
      expiryDate: expiryDate ?? this.expiryDate,
      linkStatus: linkStatus ?? this.linkStatus,
      employeeName: employeeName ?? this.employeeName,
      employeeId: employeeId ?? this.employeeId,
      organizationName: organizationName ?? this.organizationName,
      department: department ?? this.department,
      submittedDate: submittedDate ?? this.submittedDate,
      submittedBy: submittedBy ?? this.submittedBy,
    );
  }
}

enum RegistrationStatus {
  pending,
  submitted,
  accepted,
  rejected,
  registered,
}

extension RegistrationStatusX on RegistrationStatus {
  String get value => switch (this) {
        RegistrationStatus.pending => 'Pending',
        RegistrationStatus.submitted => 'Submitted',
        RegistrationStatus.accepted => 'Accepted',
        RegistrationStatus.rejected => 'Rejected',
        RegistrationStatus.registered => 'Registered',
      };

  static RegistrationStatus fromString(String status) {
    return switch (status.trim().toLowerCase()) {
      'submitted' => RegistrationStatus.submitted,
      'accepted' => RegistrationStatus.accepted,
      'rejected' => RegistrationStatus.rejected,
      'registered' || 'converted' => RegistrationStatus.registered,
      _ => RegistrationStatus.pending,
    };
  }
}

