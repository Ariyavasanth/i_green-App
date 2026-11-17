import 'bqr_requirement_item.dart';

class TenderAiExtractedData {
  const TenderAiExtractedData({
    this.title = '',
    this.clientName = '',
    this.tenderRefNo = '',
    this.tenderId = '',
    this.tenderType = 'Open',
    this.tenderAmount = 0.0,
    this.tenderSpecRemark = '',
    this.openingDate,
    this.openingDateRemark = '',
    this.closingDate,
    this.closingDateRemark = '',
    this.bqrRemark = '',
    this.bqrRequirements = const [],
    this.isEmdExempted = 'No',
    this.emdAmount = 0.0,
    this.emdRemark = '',
    this.summary = '',
    this.rawJson = const {},
  });

  final String title;
  final String clientName;
  final String tenderRefNo;
  final String tenderId;
  final String tenderType;
  final double tenderAmount;
  final String tenderSpecRemark;
  final DateTime? openingDate;
  final String openingDateRemark;
  final DateTime? closingDate;
  final String closingDateRemark;
  final String bqrRemark;
  final List<BqrRequirementItem> bqrRequirements;
  final String isEmdExempted;
  final double emdAmount;
  final String emdRemark;
  final String summary;
  final Map<String, dynamic> rawJson;

  static double _parseAmount(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    final clean = val.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(clean) ?? 0.0;
  }

  static DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    final str = val.toString().trim();
    if (str.isEmpty) return null;
    return DateTime.tryParse(str);
  }

  static List<BqrRequirementItem> _parseBqrRequirements(dynamic raw) {
    if (raw is! List) return const [];
    final items = <BqrRequirementItem>[];
    final seen = <String>{};
    final baseTs = DateTime.now().millisecondsSinceEpoch;

    for (var i = 0; i < raw.length; i++) {
      final entry = raw[i];
      String title = '';
      String description = '';

      if (entry is Map) {
        title = (entry['title'] ?? entry['name'] ?? entry['requirement'] ?? '')
            .toString()
            .trim();
        description =
            (entry['description'] ?? entry['details'] ?? '').toString().trim();
      } else if (entry != null) {
        title = entry.toString().trim();
      }

      if (title.isEmpty) continue;
      final normalized = title.toLowerCase();
      if (!seen.add(normalized)) continue;

      items.add(
        BqrRequirementItem(
          id: 'bqr_${baseTs}_$i',
          title: title,
          description: description,
          status: 'pending',
        ),
      );
    }
    return items;
  }

  factory TenderAiExtractedData.fromJson(Map<String, dynamic> json) {
    String tenderType = json['tender_type']?.toString().trim() ?? 'Open';
    final lowerType = tenderType.toLowerCase();
    if (lowerType.contains('qual')) {
      tenderType = 'Qualified';
    } else if (lowerType.contains('close')) {
      tenderType = 'Closed';
    } else {
      tenderType = 'Open';
    }

    String isEmdExempted = json['is_emd_exempted']?.toString().trim() ?? 'No';
    final lowerEmd = isEmdExempted.toLowerCase();
    if (lowerEmd == 'yes' || lowerEmd == 'true' || lowerEmd == 'exempted') {
      isEmdExempted = 'Yes';
    } else {
      isEmdExempted = 'No';
    }

    return TenderAiExtractedData(
      title: json['title']?.toString().trim() ?? '',
      clientName: json['client_name']?.toString().trim() ?? '',
      tenderRefNo: json['tender_ref_no']?.toString().trim() ?? '',
      tenderId: json['tender_id']?.toString().trim() ?? '',
      tenderType: tenderType,
      tenderAmount: _parseAmount(json['tender_amount']),
      tenderSpecRemark: json['tender_spec_remark']?.toString().trim() ?? '',
      openingDate: _parseDate(json['opening_date']),
      openingDateRemark: json['opening_date_remark']?.toString().trim() ?? '',
      closingDate: _parseDate(json['closing_date']),
      closingDateRemark: json['closing_date_remark']?.toString().trim() ?? '',
      bqrRemark: json['bqr_remark']?.toString().trim() ?? '',
      bqrRequirements: _parseBqrRequirements(json['bqr_requirements']),
      isEmdExempted: isEmdExempted,
      emdAmount: _parseAmount(json['emd_amount']),
      emdRemark: json['emd_remark']?.toString().trim() ?? '',
      summary: json['summary']?.toString().trim() ?? '',
      rawJson: json,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'client_name': clientName,
        'tender_ref_no': tenderRefNo,
        'tender_id': tenderId,
        'tender_type': tenderType,
        'tender_amount': tenderAmount,
        'tender_spec_remark': tenderSpecRemark,
        'opening_date': openingDate?.toIso8601String(),
        'opening_date_remark': openingDateRemark,
        'closing_date': closingDate?.toIso8601String(),
        'closing_date_remark': closingDateRemark,
        'bqr_remark': bqrRemark,
        'bqr_requirements': bqrRequirements.map((r) => r.toJson()).toList(),
        'is_emd_exempted': isEmdExempted,
        'emd_amount': emdAmount,
        'emd_remark': emdRemark,
        'summary': summary,
      };
}

