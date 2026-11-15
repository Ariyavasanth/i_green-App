import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/projects/domain/models/project_document.dart';

/// Lifecycle status for Retention & SD Claims.
enum RetentionClaimStatus {
  pending('Pending'),
  submitted('Claim Submitted'),
  released('Released');

  const RetentionClaimStatus(this.label);
  final String label;

  static RetentionClaimStatus fromString(String? val) {
    if (val == null) return RetentionClaimStatus.pending;
    final normalized = val.trim().toLowerCase();
    if (normalized == 'claim submitted' || normalized == 'submitted') {
      return RetentionClaimStatus.submitted;
    }
    if (normalized == 'released') {
      return RetentionClaimStatus.released;
    }
    return RetentionClaimStatus.pending;
  }

  Color get badgeColor {
    switch (this) {
      case RetentionClaimStatus.pending:
        return const Color(0xFFD97706); // Amber
      case RetentionClaimStatus.submitted:
        return const Color(0xFF0284C7); // Blue
      case RetentionClaimStatus.released:
        return const Color(0xFF16A34A); // Green
    }
  }

  Color get badgeBackground {
    switch (this) {
      case RetentionClaimStatus.pending:
        return const Color(0xFFFEF3C7);
      case RetentionClaimStatus.submitted:
        return const Color(0xFFE0F2FE);
      case RetentionClaimStatus.released:
        return const Color(0xFFDCFCE7);
    }
  }

  IconData get icon {
    switch (this) {
      case RetentionClaimStatus.pending:
        return Icons.hourglass_top_rounded;
      case RetentionClaimStatus.submitted:
        return Icons.send_rounded;
      case RetentionClaimStatus.released:
        return Icons.check_circle_outline_rounded;
    }
  }
}

/// Details of a Bank Guarantee (BG) submitted for SD or Retention.
class BankGuaranteeDetail {
  const BankGuaranteeDetail({
    this.bgNumber = '',
    this.bankName = '',
    this.branchName = '',
    this.bgAmount = 0.0,
    this.issueDate,
    this.expiryDate,
    this.claimExpiryDate,
    this.status = 'Active',
    this.remarks = '',
    this.documents = const [],
  });

  final String bgNumber;
  final String bankName;
  final String branchName;
  final double bgAmount;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final DateTime? claimExpiryDate;
  final String status;
  final String remarks;
  final List<ProjectDocument> documents;

  int? get daysUntilExpiry {
    if (expiryDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(expiryDate!.year, expiryDate!.month, expiryDate!.day);
    return target.difference(today).inDays;
  }

  bool get isExpiringSoon {
    if (status.toLowerCase() == 'released') return false;
    final days = daysUntilExpiry;
    return days != null && days <= 30 && days >= 0;
  }

  bool get isExpired {
    if (status.toLowerCase() == 'released') return false;
    final days = daysUntilExpiry;
    return days != null && days < 0;
  }

  String get expiryStatusLabel {
    if (status.toLowerCase() == 'released') return 'Released';
    if (expiryDate == null) return 'No Expiry Set';
    final days = daysUntilExpiry!;
    if (days < 0) return 'Expired ${-days} day${-days == 1 ? '' : 's'} ago';
    if (days == 0) return 'Expires Today!';
    if (days == 1) return 'Expires Tomorrow!';
    if (days <= 30) return 'Expires in $days days';
    return 'Valid ($days days)';
  }

  Map<String, dynamic> toJson() => {
        'bg_number': bgNumber,
        'bank_name': bankName,
        'branch_name': branchName,
        'bg_amount': bgAmount,
        'issue_date': issueDate?.toIso8601String(),
        'expiry_date': expiryDate?.toIso8601String(),
        'claim_expiry_date': claimExpiryDate?.toIso8601String(),
        'status': status,
        'remarks': remarks,
        'documents': documents.map((d) => d.toJson()).toList(),
      };

  factory BankGuaranteeDetail.fromJson(Map<String, dynamic> json) =>
      BankGuaranteeDetail(
        bgNumber: (json['bg_number'] ?? json['bgNumber'] ?? '').toString(),
        bankName: (json['bank_name'] ?? json['bankName'] ?? '').toString(),
        branchName:
            (json['branch_name'] ?? json['branchName'] ?? '').toString(),
        bgAmount: (json['bg_amount'] as num?)?.toDouble() ??
            (json['bgAmount'] as num?)?.toDouble() ??
            0.0,
        issueDate: json['issue_date'] != null
            ? DateTime.tryParse(json['issue_date'].toString())
            : (json['issueDate'] != null
                ? DateTime.tryParse(json['issueDate'].toString())
                : null),
        expiryDate: json['expiry_date'] != null
            ? DateTime.tryParse(json['expiry_date'].toString())
            : (json['expiryDate'] != null
                ? DateTime.tryParse(json['expiryDate'].toString())
                : null),
        claimExpiryDate: json['claim_expiry_date'] != null
            ? DateTime.tryParse(json['claim_expiry_date'].toString())
            : (json['claimExpiryDate'] != null
                ? DateTime.tryParse(json['claimExpiryDate'].toString())
                : null),
        status: (json['status'] ?? 'Active').toString(),
        remarks: (json['remarks'] ?? '').toString(),
        documents: (json['documents'] as List<dynamic>?)
                ?.map((e) => ProjectDocument.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
      );

  BankGuaranteeDetail copyWith({
    String? bgNumber,
    String? bankName,
    String? branchName,
    double? bgAmount,
    DateTime? issueDate,
    DateTime? expiryDate,
    DateTime? claimExpiryDate,
    String? status,
    String? remarks,
    List<ProjectDocument>? documents,
  }) {
    return BankGuaranteeDetail(
      bgNumber: bgNumber ?? this.bgNumber,
      bankName: bankName ?? this.bankName,
      branchName: branchName ?? this.branchName,
      bgAmount: bgAmount ?? this.bgAmount,
      issueDate: issueDate ?? this.issueDate,
      expiryDate: expiryDate ?? this.expiryDate,
      claimExpiryDate: claimExpiryDate ?? this.claimExpiryDate,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      documents: documents ?? this.documents,
    );
  }
}

/// Centralized model tracking Retention Money and Security Deposit (SD) Follow-up.
class RetentionSdRecord {
  const RetentionSdRecord({
    required this.id,
    required this.projectId,
    required this.projectCode,
    this.projectName = '',
    this.clientName = '',
    this.division = '',
    // Retention Details
    this.retentionAmount = 0.0,
    this.retentionDueDate,
    this.retentionRemarks = '',
    // SD (Security Deposit) Details
    this.sdAmount = 0.0,
    this.sdDueDate,
    this.sdAgreementNo = '',
    this.sdRemarks = '',
    // Claim Lifecycle
    this.claimStatus = RetentionClaimStatus.pending,
    this.claimSubmissionDate,
    this.claimReferenceNo = '',
    this.claimRemarks = '',
    this.releasedDate,
    this.releasedAmount = 0.0,
    this.releaseRemarks = '',
    this.claimDocuments = const [],
    // Bank Guarantee Details
    this.hasBg = false,
    this.bg,
    // Metadata
    required this.createdAt,
    required this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final String projectId;
  final String projectCode;
  final String projectName;
  final String clientName;
  final String division;

  // Retention
  final double retentionAmount;
  final DateTime? retentionDueDate;
  final String retentionRemarks;

  // Security Deposit
  final double sdAmount;
  final DateTime? sdDueDate;
  final String sdAgreementNo;
  final String sdRemarks;

  // Claim Lifecycle
  final RetentionClaimStatus claimStatus;
  final DateTime? claimSubmissionDate;
  final String claimReferenceNo;
  final String claimRemarks;
  final DateTime? releasedDate;
  final double releasedAmount;
  final String releaseRemarks;
  final List<ProjectDocument> claimDocuments;

  // Bank Guarantee
  final bool hasBg;
  final BankGuaranteeDetail? bg;

  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedBy;

  // ── Helpers ──
  double get totalFollowUpAmount => retentionAmount + sdAmount;

  double get effectiveBgAmount => bg?.bgAmount ?? 0.0;

  bool get isBgExpiringSoon => bg?.isExpiringSoon ?? false;

  bool get isBgExpired => bg?.isExpired ?? false;

  int? get daysUntilBgExpiry => bg?.daysUntilExpiry;

  int? get daysUntilRetentionDue {
    if (retentionDueDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(
        retentionDueDate!.year, retentionDueDate!.month, retentionDueDate!.day);
    return target.difference(today).inDays;
  }

  int? get daysUntilSdDue {
    if (sdDueDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(sdDueDate!.year, sdDueDate!.month, sdDueDate!.day);
    return target.difference(today).inDays;
  }

  bool get isRetentionOverdue {
    if (claimStatus == RetentionClaimStatus.released) return false;
    final days = daysUntilRetentionDue;
    return days != null && days < 0;
  }

  bool get isSdOverdue {
    if (claimStatus == RetentionClaimStatus.released) return false;
    final days = daysUntilSdDue;
    return days != null && days < 0;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'project_id': projectId,
        'project_code': projectCode,
        'project_name': projectName,
        'client_name': clientName,
        'division': division,
        // Retention
        'retention_amount': retentionAmount,
        'retention_due_date': retentionDueDate?.toIso8601String(),
        'retention_remarks': retentionRemarks,
        // SD
        'sd_amount': sdAmount,
        'sd_due_date': sdDueDate?.toIso8601String(),
        'sd_agreement_no': sdAgreementNo,
        'sd_remarks': sdRemarks,
        // Claim
        'claim_status': claimStatus.name,
        'claim_submission_date': claimSubmissionDate?.toIso8601String(),
        'claim_reference_no': claimReferenceNo,
        'claim_remarks': claimRemarks,
        'released_date': releasedDate?.toIso8601String(),
        'released_amount': releasedAmount,
        'release_remarks': releaseRemarks,
        'claim_documents': claimDocuments.map((d) => d.toJson()).toList(),
        // BG
        'has_bg': hasBg,
        'bg': bg?.toJson(),
        // Metadata
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'updated_by': updatedBy,
      };

  factory RetentionSdRecord.fromJson(Map<String, dynamic> json) =>
      RetentionSdRecord(
        id: (json['id'] ?? '').toString(),
        projectId: (json['project_id'] ?? json['projectId'] ?? '').toString(),
        projectCode:
            (json['project_code'] ?? json['projectCode'] ?? '').toString(),
        projectName:
            (json['project_name'] ?? json['projectName'] ?? '').toString(),
        clientName:
            (json['client_name'] ?? json['clientName'] ?? '').toString(),
        division: (json['division'] ?? '').toString(),
        // Retention
        retentionAmount: (json['retention_amount'] as num?)?.toDouble() ??
            (json['retentionAmount'] as num?)?.toDouble() ??
            0.0,
        retentionDueDate: json['retention_due_date'] != null
            ? DateTime.tryParse(json['retention_due_date'].toString())
            : (json['retentionDueDate'] != null
                ? DateTime.tryParse(json['retentionDueDate'].toString())
                : null),
        retentionRemarks: (json['retention_remarks'] ??
                json['retentionRemarks'] ??
                '')
            .toString(),
        // SD
        sdAmount: (json['sd_amount'] as num?)?.toDouble() ??
            (json['sdAmount'] as num?)?.toDouble() ??
            0.0,
        sdDueDate: json['sd_due_date'] != null
            ? DateTime.tryParse(json['sd_due_date'].toString())
            : (json['sdDueDate'] != null
                ? DateTime.tryParse(json['sdDueDate'].toString())
                : null),
        sdAgreementNo:
            (json['sd_agreement_no'] ?? json['sdAgreementNo'] ?? '').toString(),
        sdRemarks:
            (json['sd_remarks'] ?? json['sdRemarks'] ?? '').toString(),
        // Claim
        claimStatus: RetentionClaimStatus.fromString(
            (json['claim_status'] ?? json['claimStatus'])?.toString()),
        claimSubmissionDate: json['claim_submission_date'] != null
            ? DateTime.tryParse(json['claim_submission_date'].toString())
            : (json['claimSubmissionDate'] != null
                ? DateTime.tryParse(json['claimSubmissionDate'].toString())
                : null),
        claimReferenceNo: (json['claim_reference_no'] ??
                json['claimReferenceNo'] ??
                '')
            .toString(),
        claimRemarks:
            (json['claim_remarks'] ?? json['claimRemarks'] ?? '').toString(),
        releasedDate: json['released_date'] != null
            ? DateTime.tryParse(json['released_date'].toString())
            : (json['releasedDate'] != null
                ? DateTime.tryParse(json['releasedDate'].toString())
                : null),
        releasedAmount: (json['released_amount'] as num?)?.toDouble() ??
            (json['releasedAmount'] as num?)?.toDouble() ??
            0.0,
        releaseRemarks:
            (json['release_remarks'] ?? json['releaseRemarks'] ?? '').toString(),
        claimDocuments: (json['claim_documents'] as List<dynamic>?)
                ?.map((e) => ProjectDocument.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            (json['claimDocuments'] as List<dynamic>?)
                ?.map((e) => ProjectDocument.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        // BG
        hasBg: (json['has_bg'] ?? json['hasBg']) as bool? ?? false,
        bg: json['bg'] != null
            ? BankGuaranteeDetail.fromJson(
                Map<String, dynamic>.from(json['bg'] as Map))
            : null,
        // Metadata
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        updatedBy: json['updated_by']?.toString(),
      );

  RetentionSdRecord copyWith({
    String? id,
    String? projectId,
    String? projectCode,
    String? projectName,
    String? clientName,
    String? division,
    double? retentionAmount,
    DateTime? retentionDueDate,
    String? retentionRemarks,
    double? sdAmount,
    DateTime? sdDueDate,
    String? sdAgreementNo,
    String? sdRemarks,
    RetentionClaimStatus? claimStatus,
    DateTime? claimSubmissionDate,
    String? claimReferenceNo,
    String? claimRemarks,
    DateTime? releasedDate,
    double? releasedAmount,
    String? releaseRemarks,
    List<ProjectDocument>? claimDocuments,
    bool? hasBg,
    BankGuaranteeDetail? bg,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return RetentionSdRecord(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      projectCode: projectCode ?? this.projectCode,
      projectName: projectName ?? this.projectName,
      clientName: clientName ?? this.clientName,
      division: division ?? this.division,
      retentionAmount: retentionAmount ?? this.retentionAmount,
      retentionDueDate: retentionDueDate ?? this.retentionDueDate,
      retentionRemarks: retentionRemarks ?? this.retentionRemarks,
      sdAmount: sdAmount ?? this.sdAmount,
      sdDueDate: sdDueDate ?? this.sdDueDate,
      sdAgreementNo: sdAgreementNo ?? this.sdAgreementNo,
      sdRemarks: sdRemarks ?? this.sdRemarks,
      claimStatus: claimStatus ?? this.claimStatus,
      claimSubmissionDate: claimSubmissionDate ?? this.claimSubmissionDate,
      claimReferenceNo: claimReferenceNo ?? this.claimReferenceNo,
      claimRemarks: claimRemarks ?? this.claimRemarks,
      releasedDate: releasedDate ?? this.releasedDate,
      releasedAmount: releasedAmount ?? this.releasedAmount,
      releaseRemarks: releaseRemarks ?? this.releaseRemarks,
      claimDocuments: claimDocuments ?? this.claimDocuments,
      hasBg: hasBg ?? this.hasBg,
      bg: bg ?? this.bg,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
