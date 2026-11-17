import '../../../projects/domain/models/project_document.dart';
import 'bqr_requirement_item.dart';
import 'site_visit_record.dart';

class Tender {
  const Tender({
    this.id = '',
    required this.tenderId,
    this.tenderRefNo = '',
    this.title = '',
    this.clientName = '',
    this.tenderType = 'Open',
    this.qualified = 'Yes',
    this.tenderAmount = 0.0,
    this.siteVisits = const [],
    this.financialBidDocuments = const [],
    this.tenderNoticeDocuments = const [],
    this.noticeUploadedAt,
    this.tenderSpecRemark = '',
    this.tenderSpecDocuments = const [],
    this.openingDate,
    this.openingDateRemark = '',
    this.closingDate,
    this.closingDateRemark = '',
    this.bqrRemark = '',
    this.bqrDocuments = const [],
    this.bqrRequirements = const [],
    this.isEmdExempted = 'No',
    this.emdAmount = 0.0,
    this.emdExemptionDocuments = const [],
    this.emdRemark = '',
    this.emdDocuments = const [],
    this.status = 'Submitted',
    // Won fields
    this.awardDocType = '',
    this.awardDocNumber = '',
    this.awardDate,
    this.awardedValue = 0.0,
    this.awardDocuments = const [],
    // Rejected fields
    this.competitorName = '',
    this.competitorQuotedValue = 0.0,
    this.ourQuotedValue = 0.0,
    this.reasonForLoss = '',
    required this.createdAt,
    required this.updatedAt,
    this.createdBy = '',
    this.lastModifiedBy = '',
  });

  final String id;
  final String tenderId;
  final String tenderRefNo;
  final String title;
  final String clientName;
  final String tenderType;
  final String qualified;
  final double tenderAmount;
  final List<SiteVisitRecord> siteVisits;
  final List<ProjectDocument> financialBidDocuments;
  final List<ProjectDocument> tenderNoticeDocuments;
  final DateTime? noticeUploadedAt;
  final String tenderSpecRemark;
  final List<ProjectDocument> tenderSpecDocuments;
  final DateTime? openingDate;
  final String openingDateRemark;
  final DateTime? closingDate;
  final String closingDateRemark;
  final String bqrRemark;
  final List<ProjectDocument> bqrDocuments;
  final List<BqrRequirementItem> bqrRequirements;
  final String isEmdExempted;
  final double emdAmount;
  final List<ProjectDocument> emdExemptionDocuments;
  final String emdRemark;
  final List<ProjectDocument> emdDocuments;
  final String status;

  // Won fields
  final String awardDocType;
  final String awardDocNumber;
  final DateTime? awardDate;
  final double awardedValue;
  final List<ProjectDocument> awardDocuments;

  // Rejected fields
  final String competitorName;
  final double competitorQuotedValue;
  final double ourQuotedValue;
  final String reasonForLoss;

  // Audit
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String lastModifiedBy;

  bool get hasSiteVisit => siteVisits.isNotEmpty;
  bool get hasFinancialBid => financialBidDocuments.isNotEmpty;
  int get pendingBqrCount =>
      bqrRequirements.where((r) => !r.isUploaded).length;

  bool get isFinalizedStatus {
    final s = status.trim().toLowerCase();
    return s == 'won' || s == 'rejected' || s == 'lost';
  }

  /// Missing key submission documents outside the BQR checklist.
  List<String> get missingCoreDocumentLabels {
    final missing = <String>[];
    if (financialBidDocuments.isEmpty) {
      missing.add('Financial Bid');
    }
    if (isEmdExempted == 'Yes') {
      if (emdExemptionDocuments.isEmpty) {
        missing.add('EMD Exemption');
      }
    } else if (emdAmount > 0 && emdDocuments.isEmpty) {
      missing.add('EMD');
    }
    return missing;
  }

  /// Total count of pending documents (pending BQR items + missing core submission docs).
  int get pendingDocumentCount =>
      pendingBqrCount + missingCoreDocumentLabels.length;

  /// Calendar days left until [closingDate] (0 = closes today, negative = closed).
  int? get daysUntilClosing {
    if (closingDate == null) return null;
    final now = DateTime.now();
    if (closingDate!.isBefore(now)) {
      final today = DateTime(now.year, now.month, now.day);
      final closeDay =
          DateTime(closingDate!.year, closingDate!.month, closingDate!.day);
      final dayDiff = closeDay.difference(today).inDays;
      return dayDiff < 0 ? dayDiff : -1;
    }
    final today = DateTime(now.year, now.month, now.day);
    final closeDay =
        DateTime(closingDate!.year, closingDate!.month, closingDate!.day);
    return closeDay.difference(today).inDays;
  }

  bool get isClosingSoon {
    if (isFinalizedStatus) return false;
    final days = daysUntilClosing;
    return days != null && days >= 0 && days <= 5;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tender_id': tenderId,
        'tender_ref_no': tenderRefNo,
        'title': title,
        'client_name': clientName,
        'tender_type': tenderType,
        'qualified': qualified,
        'tender_amount': tenderAmount,
        'site_visits': siteVisits.map((v) => v.toJson()).toList(),
        'financial_bid_documents':
            financialBidDocuments.map((d) => d.toJson()).toList(),
        'tender_notice_documents':
            tenderNoticeDocuments.map((d) => d.toJson()).toList(),
        'notice_uploaded_at': noticeUploadedAt?.toIso8601String(),
        'tender_spec_remark': tenderSpecRemark,
        'tender_spec_documents':
            tenderSpecDocuments.map((d) => d.toJson()).toList(),
        'opening_date': openingDate?.toIso8601String(),
        'opening_date_remark': openingDateRemark,
        'closing_date': closingDate?.toIso8601String(),
        'closing_date_remark': closingDateRemark,
        'bqr_remark': bqrRemark,
        'bqr_documents': bqrDocuments.map((d) => d.toJson()).toList(),
        'bqr_requirements': bqrRequirements.map((r) => r.toJson()).toList(),
        'is_emd_exempted': isEmdExempted,
        'emd_amount': emdAmount,
        'emd_exemption_documents':
            emdExemptionDocuments.map((d) => d.toJson()).toList(),
        'emd_remark': emdRemark,
        'emd_documents': emdDocuments.map((d) => d.toJson()).toList(),
        'status': status,
        'award_doc_type': awardDocType,
        'award_doc_number': awardDocNumber,
        'award_date': awardDate?.toIso8601String(),
        'awarded_value': awardedValue,
        'award_documents': awardDocuments.map((d) => d.toJson()).toList(),
        'competitor_name': competitorName,
        'competitor_quoted_value': competitorQuotedValue,
        'our_quoted_value': ourQuotedValue,
        'reason_for_loss': reasonForLoss,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'created_by': createdBy,
        'last_modified_by': lastModifiedBy,
      };

  static double _parseAmount(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    final clean = val.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(clean) ?? 0.0;
  }

  factory Tender.fromJson(Map<String, dynamic> json, [String? docId]) => Tender(
        id: docId ?? json['id'] as String? ?? '',
        tenderId: json['tender_id'] as String? ?? '',
        tenderRefNo: json['tender_ref_no'] as String? ?? '',
        title: json['title'] as String? ?? '',
        clientName: json['client_name'] as String? ?? '',
        tenderType: json['tender_type'] as String? ?? 'Open',
        qualified: json['qualified'] as String? ?? 'Yes',
        tenderAmount: _parseAmount(json['tender_amount']),
        siteVisits: (json['site_visits'] as List<dynamic>?)
                ?.map((v) => SiteVisitRecord.fromJson(v as Map<String, dynamic>))
                .toList() ??
            const [],
        financialBidDocuments: (json['financial_bid_documents'] as List<dynamic>?)
                ?.map((d) => ProjectDocument.fromJson(d as Map<String, dynamic>))
                .toList() ??
            const [],
        tenderNoticeDocuments: (json['tender_notice_documents'] as List<dynamic>?)
                ?.map((d) => ProjectDocument.fromJson(d as Map<String, dynamic>))
                .toList() ??
            const [],
        noticeUploadedAt: json['notice_uploaded_at'] != null
            ? DateTime.tryParse(json['notice_uploaded_at'].toString())
            : null,
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
        bqrRequirements: (json['bqr_requirements'] as List<dynamic>?)
                ?.map((r) => BqrRequirementItem.fromJson(r as Map<String, dynamic>))
                .toList() ??
            const [],
        isEmdExempted: json['is_emd_exempted'] as String? ?? 'No',
        emdAmount: _parseAmount(json['emd_amount']),
        emdExemptionDocuments: (json['emd_exemption_documents'] as List<dynamic>?)
                ?.map((d) => ProjectDocument.fromJson(d as Map<String, dynamic>))
                .toList() ??
            const [],
        emdRemark: json['emd_remark'] as String? ?? '',
        emdDocuments: (json['emd_documents'] as List<dynamic>?)
                ?.map((d) => ProjectDocument.fromJson(d as Map<String, dynamic>))
                .toList() ??
            const [],
        status: json['status'] as String? ?? 'Submitted',
        awardDocType: json['award_doc_type'] as String? ?? '',
        awardDocNumber: json['award_doc_number'] as String? ?? '',
        awardDate: json['award_date'] != null
            ? DateTime.tryParse(json['award_date'].toString())
            : null,
        awardedValue: _parseAmount(json['awarded_value']),
        awardDocuments: (json['award_documents'] as List<dynamic>?)
                ?.map((d) => ProjectDocument.fromJson(d as Map<String, dynamic>))
                .toList() ??
            const [],
        competitorName: json['competitor_name'] as String? ?? '',
        competitorQuotedValue: _parseAmount(json['competitor_quoted_value']),
        ourQuotedValue: _parseAmount(json['our_quoted_value']),
        reasonForLoss: json['reason_for_loss'] as String? ?? '',
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        createdBy: json['created_by'] as String? ?? '',
        lastModifiedBy: json['last_modified_by'] as String? ?? '',
      );

  Tender copyWith({
    String? id,
    String? tenderId,
    String? tenderRefNo,
    String? title,
    String? clientName,
    String? tenderType,
    String? qualified,
    double? tenderAmount,
    List<SiteVisitRecord>? siteVisits,
    List<ProjectDocument>? financialBidDocuments,
    List<ProjectDocument>? tenderNoticeDocuments,
    DateTime? noticeUploadedAt,
    String? tenderSpecRemark,
    List<ProjectDocument>? tenderSpecDocuments,
    DateTime? openingDate,
    String? openingDateRemark,
    DateTime? closingDate,
    String? closingDateRemark,
    String? bqrRemark,
    List<ProjectDocument>? bqrDocuments,
    List<BqrRequirementItem>? bqrRequirements,
    String? isEmdExempted,
    double? emdAmount,
    List<ProjectDocument>? emdExemptionDocuments,
    String? emdRemark,
    List<ProjectDocument>? emdDocuments,
    String? status,
    String? awardDocType,
    String? awardDocNumber,
    DateTime? awardDate,
    double? awardedValue,
    List<ProjectDocument>? awardDocuments,
    String? competitorName,
    double? competitorQuotedValue,
    double? ourQuotedValue,
    String? reasonForLoss,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? lastModifiedBy,
  }) =>
      Tender(
        id: id ?? this.id,
        tenderId: tenderId ?? this.tenderId,
        tenderRefNo: tenderRefNo ?? this.tenderRefNo,
        title: title ?? this.title,
        clientName: clientName ?? this.clientName,
        tenderType: tenderType ?? this.tenderType,
        qualified: qualified ?? this.qualified,
        tenderAmount: tenderAmount ?? this.tenderAmount,
        siteVisits: siteVisits ?? this.siteVisits,
        financialBidDocuments:
            financialBidDocuments ?? this.financialBidDocuments,
        tenderNoticeDocuments:
            tenderNoticeDocuments ?? this.tenderNoticeDocuments,
        noticeUploadedAt: noticeUploadedAt ?? this.noticeUploadedAt,
        tenderSpecRemark: tenderSpecRemark ?? this.tenderSpecRemark,
        tenderSpecDocuments: tenderSpecDocuments ?? this.tenderSpecDocuments,
        openingDate: openingDate ?? this.openingDate,
        openingDateRemark: openingDateRemark ?? this.openingDateRemark,
        closingDate: closingDate ?? this.closingDate,
        closingDateRemark: closingDateRemark ?? this.closingDateRemark,
        bqrRemark: bqrRemark ?? this.bqrRemark,
        bqrDocuments: bqrDocuments ?? this.bqrDocuments,
        bqrRequirements: bqrRequirements ?? this.bqrRequirements,
        isEmdExempted: isEmdExempted ?? this.isEmdExempted,
        emdAmount: emdAmount ?? this.emdAmount,
        emdExemptionDocuments:
            emdExemptionDocuments ?? this.emdExemptionDocuments,
        emdRemark: emdRemark ?? this.emdRemark,
        emdDocuments: emdDocuments ?? this.emdDocuments,
        status: status ?? this.status,
        awardDocType: awardDocType ?? this.awardDocType,
        awardDocNumber: awardDocNumber ?? this.awardDocNumber,
        awardDate: awardDate ?? this.awardDate,
        awardedValue: awardedValue ?? this.awardedValue,
        awardDocuments: awardDocuments ?? this.awardDocuments,
        competitorName: competitorName ?? this.competitorName,
        competitorQuotedValue:
            competitorQuotedValue ?? this.competitorQuotedValue,
        ourQuotedValue: ourQuotedValue ?? this.ourQuotedValue,
        reasonForLoss: reasonForLoss ?? this.reasonForLoss,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        createdBy: createdBy ?? this.createdBy,
        lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      );
}