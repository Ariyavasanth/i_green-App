import 'project_document.dart';

class EotLetter {
  final String id;
  final String projectCode;
  final String letterRefNo;
  final DateTime letterDate;
  final DateTime extendedCompletionDate;
  final int extendedDays;
  final String reason;
  final ProjectDocument document;
  final String uploadedBy;
  final String uploadedByName;
  final DateTime createdAt;

  const EotLetter({
    required this.id,
    required this.projectCode,
    required this.letterRefNo,
    required this.letterDate,
    required this.extendedCompletionDate,
    this.extendedDays = 0,
    this.reason = '',
    required this.document,
    this.uploadedBy = '',
    this.uploadedByName = '',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'project_code': projectCode,
        'letter_ref_no': letterRefNo,
        'letter_date': letterDate.toIso8601String(),
        'extended_completion_date': extendedCompletionDate.toIso8601String(),
        'extended_days': extendedDays,
        'reason': reason,
        'document': document.toJson(),
        'uploaded_by': uploadedBy,
        'uploaded_by_name': uploadedByName,
        'created_at': createdAt.toIso8601String(),
      };

  factory EotLetter.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val == null) return fallback;
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString()) ?? fallback;
    }

    final docMap = json['document'] is Map<String, dynamic>
        ? json['document'] as Map<String, dynamic>
        : <String, dynamic>{};

    return EotLetter(
      id: json['id'] as String? ?? '',
      projectCode: json['project_code'] as String? ?? '',
      letterRefNo: json['letter_ref_no'] as String? ?? '',
      letterDate: parseDate(json['letter_date'], DateTime.now()),
      extendedCompletionDate:
          parseDate(json['extended_completion_date'], DateTime.now()),
      extendedDays: (json['extended_days'] as num?)?.toInt() ?? 0,
      reason: json['reason'] as String? ?? '',
      document: ProjectDocument.fromJson(docMap),
      uploadedBy: json['uploaded_by'] as String? ?? '',
      uploadedByName: json['uploaded_by_name'] as String? ?? '',
      createdAt: parseDate(json['created_at'], DateTime.now()),
    );
  }

  EotLetter copyWith({
    String? id,
    String? projectCode,
    String? letterRefNo,
    DateTime? letterDate,
    DateTime? extendedCompletionDate,
    int? extendedDays,
    String? reason,
    ProjectDocument? document,
    String? uploadedBy,
    String? uploadedByName,
    DateTime? createdAt,
  }) {
    return EotLetter(
      id: id ?? this.id,
      projectCode: projectCode ?? this.projectCode,
      letterRefNo: letterRefNo ?? this.letterRefNo,
      letterDate: letterDate ?? this.letterDate,
      extendedCompletionDate:
          extendedCompletionDate ?? this.extendedCompletionDate,
      extendedDays: extendedDays ?? this.extendedDays,
      reason: reason ?? this.reason,
      document: document ?? this.document,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      uploadedByName: uploadedByName ?? this.uploadedByName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

