import 'dart:convert';
import 'package:crypto/crypto.dart';

class CorrectionRequest {
  const CorrectionRequest({
    required this.id,
    required this.candidateResponseId,
    required this.candidateId,
    required this.linkId,
    required this.remarks,
    required this.status, // 'active', 'completed', 'expired', 'cancelled'
    this.allowEditing = true,
    required this.tokenHash,
    required this.createdAt,
    required this.expiresAt,
    this.usedAt,
    this.requestedBy = '',
  });

  final String id;
  final String candidateResponseId;
  final String candidateId;
  final String linkId;
  final String remarks;
  final String status;
  final bool allowEditing;
  final String tokenHash;
  final String createdAt;
  final String expiresAt;
  final String? usedAt;
  final String requestedBy;

  bool get isExpired {
    try {
      final exp = DateTime.parse(expiresAt);
      return DateTime.now().isAfter(exp);
    } catch (_) {
      return false;
    }
  }

  bool get isValidActive => status == 'active' && !isExpired && usedAt == null;

  static String hashToken(String rawToken) {
    return sha256.convert(utf8.encode(rawToken.trim())).toString();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'candidate_response_id': candidateResponseId,
      'candidate_id': candidateId,
      'link_id': linkId,
      'remarks': remarks,
      'status': status,
      'allow_editing': allowEditing,
      'token_hash': tokenHash,
      'created_at': createdAt,
      'expires_at': expiresAt,
      if (usedAt != null) 'used_at': usedAt,
      'requested_by': requestedBy,
    };
  }

  factory CorrectionRequest.fromMap(Map<String, dynamic> map, [String? docId]) {
    return CorrectionRequest(
      id: docId ?? map['id']?.toString() ?? '',
      candidateResponseId: map['candidate_response_id']?.toString() ?? '',
      candidateId: map['candidate_id']?.toString() ?? '',
      linkId: map['link_id']?.toString() ?? '',
      remarks: map['remarks']?.toString() ?? '',
      status: map['status']?.toString() ?? 'active',
      allowEditing: map['allow_editing'] as bool? ?? (map['allowEditing'] as bool? ?? true),
      tokenHash: map['token_hash']?.toString() ?? map['tokenHash']?.toString() ?? '',
      createdAt: map['created_at']?.toString() ?? map['createdAt']?.toString() ?? '',
      expiresAt: map['expires_at']?.toString() ?? map['expiresAt']?.toString() ?? '',
      usedAt: map['used_at']?.toString() ?? map['usedAt']?.toString(),
      requestedBy: map['requested_by']?.toString() ?? map['requestedBy']?.toString() ?? '',
    );
  }

  CorrectionRequest copyWith({
    String? id,
    String? candidateResponseId,
    String? candidateId,
    String? linkId,
    String? remarks,
    String? status,
    bool? allowEditing,
    String? tokenHash,
    String? createdAt,
    String? expiresAt,
    String? usedAt,
    String? requestedBy,
  }) {
    return CorrectionRequest(
      id: id ?? this.id,
      candidateResponseId: candidateResponseId ?? this.candidateResponseId,
      candidateId: candidateId ?? this.candidateId,
      linkId: linkId ?? this.linkId,
      remarks: remarks ?? this.remarks,
      status: status ?? this.status,
      allowEditing: allowEditing ?? this.allowEditing,
      tokenHash: tokenHash ?? this.tokenHash,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      usedAt: usedAt ?? this.usedAt,
      requestedBy: requestedBy ?? this.requestedBy,
    );
  }
}
