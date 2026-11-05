import '../../../projects/domain/models/project_document.dart';

class Tender {
  const Tender({
    this.id = '',
    required this.tenderId,
    this.title = '',
    this.clientName = '',
    this.tenderType = 'Open',
    this.qualified = 'Yes',
    this.tenderAmount = 0.0,
    this.tenderSpecRemark = '',
    this.tenderSpecDocuments = const [],
    this.openingDate,
    this.openingDateRemark = '',
    this.closingDate,
    this.closingDateRemark = '',
    this.bqrRemark = '',
    this.bqrDocuments = const [],
    this.emdRemark = '',
    this.emdDocuments = const [],
    this.status = 'Active',
    required this.createdAt,
    required this.updatedAt,
    this.createdBy = '',
  });

  final String id;
  final String tenderId;
  final String title;
  final String clientName;
  final String tenderType;
  final String qualified;
  final double tenderAmount;
  final String tenderSpecRemark;
  final List<ProjectDocument> tenderSpecDocuments;
  final DateTime? openingDate;
  final String openingDateRemark;
  final DateTime? closingDate;
  final String closingDateRemark;
  final String bqrRemark;
  final List<ProjectDocument> bqrDocuments;
  final String emdRemark;
  final List<ProjectDocument> emdDocuments;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  Map<String, dynamic> toJson() => {
        'id': id,
        'tender_id': tenderId,
        'title': title,
        'client_name': clientName,
        'tender_type': tenderType,
        'qualified': qualified,
        'tender_amount': tenderAmount,
        'tender_spec_remark': tenderSpecRemark,
        'tender_spec_documents':
            tenderSpecDocuments.map((d) => d.toJson()).toList(),
        'opening_date': openingDate?.toIso8601String(),
        'opening_date_remark': openingDateRemark,
        'closing_date': closingDate?.toIso8601String(),
        'closing_date_remark': closingDateRemark,
        'bqr_remark': bqrRemark,
        'bqr_documents': bqrDocuments.map((d) => d.toJson()).toList(),
        'emd_remark': emdRemark,
        'emd_documents': emdDocuments.map((d) => d.toJson()).toList(),
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'created_by': createdBy,
      };

  factory Tender.fromJson(Map<String, dynamic> json, [String? docId]) => Tender(
        id: docId ?? json['id'] as String? ?? '',
        tenderId: json['tender_id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        clientName: json['client_name'] as String? ?? '',
        tenderType: json['tender_type'] as String? ?? 'Open',
        qualified: json['qualified'] as String? ?? 'Yes',
        tenderAmount: (json['tender_amount'] as num?)?.toDouble() ?? 0.0,
        tenderSpecRemark: json['tender_spec_remark'] as String? ?? '',
        tenderSpecDocuments: (json['tender_spec_documents'] as List<dynamic>?)
                ?.map((d) => ProjectDocument.fromJson(d as Map<String, dynamic>))
                .toList() ??
            const [],
        openingDate: json['opening_date'] != null
            ? DateTime.tryParse(json['opening_date'].toString())
            : null,
        openingDateRemark: json['opening_date_remark'] as String? ?? '',
        closingDate: json['closing_date'] != null
            ? DateTime.tryParse(json['closing_date'].toString())
            : null,
        closingDateRemark: json['closing_date_remark'] as String? ?? '',
        bqrRemark: json['bqr_remark'] as String? ?? '',
        bqrDocuments: (json['bqr_documents'] as List<dynamic>?)
                ?.map((d) => ProjectDocument.fromJson(d as Map<String, dynamic>))
                .toList() ??
            const [],
        emdRemark: json['emd_remark'] as String? ?? '',
        emdDocuments: (json['emd_documents'] as List<dynamic>?)
                ?.map((d) => ProjectDocument.fromJson(d as Map<String, dynamic>))
                .toList() ??
            const [],
        status: json['status'] as String? ?? 'Active',
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        createdBy: json['created_by'] as String? ?? '',
      );

  Tender copyWith({
    String? id,
    String? tenderId,
    String? title,
    String? clientName,
    String? tenderType,
    String? qualified,
    double? tenderAmount,
    String? tenderSpecRemark,
    List<ProjectDocument>? tenderSpecDocuments,
    DateTime? openingDate,
    String? openingDateRemark,
    DateTime? closingDate,
    String? closingDateRemark,
    String? bqrRemark,
    List<ProjectDocument>? bqrDocuments,
    String? emdRemark,
    List<ProjectDocument>? emdDocuments,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) =>
      Tender(
        id: id ?? this.id,
        tenderId: tenderId ?? this.tenderId,
        title: title ?? this.title,
        clientName: clientName ?? this.clientName,
        tenderType: tenderType ?? this.tenderType,
        qualified: qualified ?? this.qualified,
        tenderAmount: tenderAmount ?? this.tenderAmount,
        tenderSpecRemark: tenderSpecRemark ?? this.tenderSpecRemark,
        tenderSpecDocuments: tenderSpecDocuments ?? this.tenderSpecDocuments,
        openingDate: openingDate ?? this.openingDate,
        openingDateRemark: openingDateRemark ?? this.openingDateRemark,
        closingDate: closingDate ?? this.closingDate,
        closingDateRemark: closingDateRemark ?? this.closingDateRemark,
        bqrRemark: bqrRemark ?? this.bqrRemark,
        bqrDocuments: bqrDocuments ?? this.bqrDocuments,
        emdRemark: emdRemark ?? this.emdRemark,
        emdDocuments: emdDocuments ?? this.emdDocuments,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        createdBy: createdBy ?? this.createdBy,
      );
}
