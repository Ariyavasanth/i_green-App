class SiteVisitRecord {
  final String id;
  final String tenderId;
  final String projectCode;
  final String photoUrl;
  final List<String> photoUrls;
  final DateTime visitDateTime;
  final double? latitude;
  final double? longitude;
  final String locationAddress;
  final String visitedBy;
  final String remarks;
  final DateTime createdAt;

  const SiteVisitRecord({
    this.id = '',
    this.tenderId = '',
    this.projectCode = '',
    this.photoUrl = '',
    this.photoUrls = const [],
    required this.visitDateTime,
    this.latitude,
    this.longitude,
    this.locationAddress = '',
    required this.visitedBy,
    required this.remarks,
    required this.createdAt,
  });

  List<String> get allPhotos {
    final list = <String>[];
    for (final p in photoUrls) {
      final s = p.trim();
      if (s.isNotEmpty && !list.contains(s)) list.add(s);
    }
    final single = photoUrl.trim();
    if (single.isNotEmpty && !list.contains(single)) {
      list.insert(0, single);
    }
    return list;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tender_id': tenderId,
        'project_code': projectCode,
        'photo_url': photoUrl.isNotEmpty
            ? photoUrl
            : (photoUrls.isNotEmpty ? photoUrls.first : ''),
        'photo_urls': allPhotos,
        'visit_date_time': visitDateTime.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'location_address': locationAddress,
        'visited_by': visitedBy,
        'remarks': remarks,
        'created_at': createdAt.toIso8601String(),
      };

  factory SiteVisitRecord.fromJson(Map<String, dynamic> json, [String? docId]) {
    final pUrl = json['photo_url'] as String? ?? '';
    final pList = (json['photo_urls'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((s) => s.trim().isNotEmpty)
            .toList() ??
        (pUrl.isNotEmpty ? [pUrl] : const <String>[]);
    return SiteVisitRecord(
      id: docId ?? json['id'] as String? ?? '',
      tenderId: json['tender_id'] as String? ?? '',
      projectCode: json['project_code'] as String? ?? '',
      photoUrl: pUrl.isNotEmpty ? pUrl : (pList.isNotEmpty ? pList.first : ''),
      photoUrls: pList,
      visitDateTime: json['visit_date_time'] != null
          ? DateTime.tryParse(json['visit_date_time'].toString()) ?? DateTime.now()
          : DateTime.now(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationAddress: json['location_address'] as String? ?? '',
      visitedBy: json['visited_by'] as String? ?? '',
      remarks: json['remarks'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

