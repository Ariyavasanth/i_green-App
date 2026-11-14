import 'project_document.dart';

class ProjectPermission {
  final String id;
  final String projectCode;
  final String authority; // 'Corporation' | 'Highways' | 'Traffic Police' | 'Other'
  final String title;
  final DateTime validFrom;
  final DateTime validTo;
  final ProjectDocument? document;
  final String remarks;

  const ProjectPermission({
    required this.id,
    required this.projectCode,
    required this.authority,
    required this.title,
    required this.validFrom,
    required this.validTo,
    this.document,
    this.remarks = '',
  });

  bool get isExpiringSoon {
    final diff = validTo.difference(DateTime.now()).inDays;
    return diff >= 0 && diff <= 15;
  }

  bool get isExpired => DateTime.now().isAfter(validTo);

  Map<String, dynamic> toJson() => {
        'id': id,
        'project_code': projectCode,
        'authority': authority,
        'title': title,
        'valid_from': validFrom.toIso8601String(),
        'valid_to': validTo.toIso8601String(),
        'document': document?.toJson(),
        'remarks': remarks,
      };

  factory ProjectPermission.fromJson(Map<String, dynamic> json, [String? docId]) =>
      ProjectPermission(
        id: docId ?? json['id'] as String? ?? '',
        projectCode: json['project_code'] as String? ?? '',
        authority: json['authority'] as String? ?? 'Corporation',
        title: json['title'] as String? ?? '',
        validFrom: json['valid_from'] != null
            ? DateTime.tryParse(json['valid_from'].toString()) ?? DateTime.now()
            : DateTime.now(),
        validTo: json['valid_to'] != null
            ? DateTime.tryParse(json['valid_to'].toString()) ?? DateTime.now()
            : DateTime.now(),
        document: json['document'] != null
            ? ProjectDocument.fromJson(Map<String, dynamic>.from(json['document'] as Map))
            : null,
        remarks: json['remarks'] as String? ?? '',
      );
}

class ProjectInsurance {
  final String id;
  final String projectCode;
  final String policyType; // 'Project Insurance' | 'Workmen Compensation'
  final String policyNumber;
  final String insurerName;
  final DateTime expiryDate;
  final ProjectDocument? document;

  const ProjectInsurance({
    required this.id,
    required this.projectCode,
    required this.policyType,
    required this.policyNumber,
    required this.insurerName,
    required this.expiryDate,
    this.document,
  });

  bool get isExpiringSoon {
    final diff = expiryDate.difference(DateTime.now()).inDays;
    return diff >= 0 && diff <= 30;
  }

  bool get isExpired => DateTime.now().isAfter(expiryDate);

  Map<String, dynamic> toJson() => {
        'id': id,
        'project_code': projectCode,
        'policy_type': policyType,
        'policy_number': policyNumber,
        'insurer_name': insurerName,
        'expiry_date': expiryDate.toIso8601String(),
        'document': document?.toJson(),
      };

  factory ProjectInsurance.fromJson(Map<String, dynamic> json, [String? docId]) =>
      ProjectInsurance(
        id: docId ?? json['id'] as String? ?? '',
        projectCode: json['project_code'] as String? ?? '',
        policyType: json['policy_type'] as String? ?? 'Project Insurance',
        policyNumber: json['policy_number'] as String? ?? '',
        insurerName: json['insurer_name'] as String? ?? '',
        expiryDate: json['expiry_date'] != null
            ? DateTime.tryParse(json['expiry_date'].toString()) ?? DateTime.now()
            : DateTime.now(),
        document: json['document'] != null
            ? ProjectDocument.fromJson(Map<String, dynamic>.from(json['document'] as Map))
            : null,
      );
}

class IncidentLogEntry {
  final String id;
  final String projectCode;
  final DateTime incidentDate;
  final String photoUrl;
  final String remarks;
  final double restorationCost;
  final DateTime createdAt;

  const IncidentLogEntry({
    required this.id,
    required this.projectCode,
    required this.incidentDate,
    required this.photoUrl,
    required this.remarks,
    this.restorationCost = 0.0,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'project_code': projectCode,
        'incident_date': incidentDate.toIso8601String(),
        'photo_url': photoUrl,
        'remarks': remarks,
        'restoration_cost': restorationCost,
        'created_at': createdAt.toIso8601String(),
      };

  factory IncidentLogEntry.fromJson(Map<String, dynamic> json, [String? docId]) =>
      IncidentLogEntry(
        id: docId ?? json['id'] as String? ?? '',
        projectCode: json['project_code'] as String? ?? '',
        incidentDate: json['incident_date'] != null
            ? DateTime.tryParse(json['incident_date'].toString()) ?? DateTime.now()
            : DateTime.now(),
        photoUrl: json['photo_url'] as String? ?? '',
        remarks: json['remarks'] as String? ?? '',
        restorationCost: (json['restoration_cost'] as num?)?.toDouble() ?? 0.0,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
}

