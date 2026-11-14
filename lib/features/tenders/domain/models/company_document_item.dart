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
  final DateTime? expiryDate; // for licences / vendor auth
  final ProjectDocument document;
  final DateTime createdAt;

  const CompanyDocumentItem({
    required this.id,
    required this.docType,
    required this.title,
    this.financialYear,
    this.monthYear,
    this.projectCode,
    this.expiryDate,
    required this.document,
    required this.createdAt,
  });

  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final diff = expiryDate!.difference(DateTime.now()).inDays;
    return diff >= 0 && diff <= 30;
  }

  bool get isExpired {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'doc_type': docType.code,
        'title': title,
        'financial_year': financialYear,
        'month_year': monthYear,
        'project_code': projectCode,
        'expiry_date': expiryDate?.toIso8601String(),
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
        expiryDate: json['expiry_date'] != null
            ? DateTime.tryParse(json['expiry_date'].toString())
            : null,
        document: ProjectDocument.fromJson(
            Map<String, dynamic>.from(json['document'] as Map? ?? {})),
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
}

