class SiteVisitRecord {
  final String id;
  final String tenderId;
  final String projectCode;
  final String photoUrl;
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
    required this.photoUrl,
    required this.visitDateTime,
    this.latitude,
    this.longitude,
    this.locationAddress = '',
    required this.visitedBy,
    required this.remarks,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'tender_id': tenderId,
        'project_code': projectCode,
        'photo_url': photoUrl,
        'visit_date_time': visitDateTime.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'location_address': locationAddress,
        'visited_by': visitedBy,
        'remarks': remarks,
        'created_at': createdAt.toIso8601String(),
      };

  factory SiteVisitRecord.fromJson(Map<String, dynamic> json, [String? docId]) =>
      SiteVisitRecord(
        id: docId ?? json['id'] as String? ?? '',
        tenderId: json['tender_id'] as String? ?? '',
        projectCode: json['project_code'] as String? ?? '',
        photoUrl: json['photo_url'] as String? ?? '',
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

