import '../../../projects/domain/models/project_document.dart';

enum CompanyDocType {
  itr('ITR', 'Income Tax Return (Year-wise)'),
  pfCertificate('PF_CERT', 'PF Registration Certificate'),
  pfChallan('PF_CHALLAN', 'PF Monthly Challan / Receipt'),
  esiCertificate('ESI_CERT', 'ESI Registration Certificate'),
  esiChallan('ESI_CHALLAN', 'ESI Monthly Challan / Receipt'),
  gstCertificate('GST_CERT', 'GST Certificate'),
  gstChallan('GST_CHALLAN', 'GST Monthly Challan / Return'),
  experienceCertificate('EXP_CERT', 'Experience Certificate (Project Code-wise)'),
  license('LICENSE', 'Labour / Trade Licence'),
  vendorAuth('VENDOR_AUTH', 'Vendor Authorisation'),
  registration('REGISTRATION', 'Statutory Registration');

  final String code;
  final String label;
  const CompanyDocType(this.code, this.label);

  static CompanyDocType fromCode(String? code) {
    for (final v in CompanyDocType.values) {
      if (v.code == code) return v;
    }
    return CompanyDocType.license;
  }
}

class CompanyDocumentItem {
  final String id;
  final CompanyDocType docType;
  final String title;
  final String? financialYear; // e.g. "2023-2024"
  final String? monthYear; // e.g. "2024-03" (YYYY-MM)
  final String? projectCode; // for experience certs
  final DateTime? startDate; // issue / effective start date
  final DateTime? expiryDate; // expiry date for alerts
  final int alertBeforeDays; // days before expiry to trigger alert (default 30)
  final ProjectDocument document;
  final DateTime createdAt;

  const CompanyDocumentItem({
    required this.id,
    required this.docType,
    required this.title,
    this.financialYear,
    this.monthYear,
    this.projectCode,
    this.startDate,
    this.expiryDate,
    this.alertBeforeDays = 30,
    required this.document,
    required this.createdAt,
  });

  /// Whole calendar days remaining until [expiryDate].
  /// Returns negative if already expired, 0 if expiring today, positive if upcoming.
  int? get daysUntilExpiry {
    if (expiryDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(expiryDate!.year, expiryDate!.month, expiryDate!.day);
    return exp.difference(today).inDays;
  }

  bool get isExpiringSoon {
    final diff = daysUntilExpiry;
    if (diff == null) return false;
    return diff >= 0 && diff <= alertBeforeDays;
  }

  bool get isExpired {
    final diff = daysUntilExpiry;
    if (diff == null) return false;
    return diff < 0;
  }

  CompanyDocumentItem copyWith({
    String? id,
    CompanyDocType? docType,
    String? title,
    String? financialYear,
    String? monthYear,
    String? projectCode,
    DateTime? startDate,
    DateTime? expiryDate,
    int? alertBeforeDays,
    ProjectDocument? document,
    DateTime? createdAt,
  }) {
    return CompanyDocumentItem(
      id: id ?? this.id,
      docType: docType ?? this.docType,
      title: title ?? this.title,
      financialYear: financialYear ?? this.financialYear,
      monthYear: monthYear ?? this.monthYear,
      projectCode: projectCode ?? this.projectCode,
      startDate: startDate ?? this.startDate,
      expiryDate: expiryDate ?? this.expiryDate,
      alertBeforeDays: alertBeforeDays ?? this.alertBeforeDays,
      document: document ?? this.document,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'doc_type': docType.code,
        'title': title,
        'financial_year': financialYear,
        'month_year': monthYear,
        'project_code': projectCode,
        'start_date': startDate?.toIso8601String(),
        'expiry_date': expiryDate?.toIso8601String(),
        'alert_before_days': alertBeforeDays,
        'document': document.toJson(),
        'created_at': createdAt.toIso8601String(),
      };

  factory CompanyDocumentItem.fromJson(Map<String, dynamic> json, [String? docId]) =>
      CompanyDocumentItem(
        id: docId ?? json['id'] as String? ?? '',
        docType: CompanyDocType.fromCode(json['doc_type'] as String?),
        title: json['title'] as String? ?? '',
        financialYear: json['financial_year'] as String?,
        monthYear: json['month_year'] as String?,
        projectCode: json['project_code'] as String?,
        startDate: json['start_date'] != null
            ? DateTime.tryParse(json['start_date'].toString())
            : null,
        expiryDate: json['expiry_date'] != null
            ? DateTime.tryParse(json['expiry_date'].toString())
            : null,
        alertBeforeDays: (json['alert_before_days'] as num?)?.toInt() ?? 30,
        document: ProjectDocument.fromJson(
            Map<String, dynamic>.from(json['document'] as Map? ?? {})),
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
}
