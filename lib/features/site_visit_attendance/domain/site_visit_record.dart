class SiteVisitRecord {
  const SiteVisitRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.siteName,
    required this.visitDate,
    required this.visitTime,
    required this.photoUrl,
    this.photoPublicId = '',
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.notes,
    required this.createdAt,
  });

  final int id;
  final int employeeId;
  final String employeeName;
  final String siteName;
  final String visitDate;
  final String visitTime;
  final String photoUrl;
  final String photoPublicId;
  final double latitude;
  final double longitude;
  final String address;
  final String notes;
  final String createdAt;

  Map<String, dynamic> toMap() => {
        if (id != 0) 'id': id,
        'employee_id': employeeId,
        'employee_name': employeeName,
        'site_name': siteName,
        'visit_date': visitDate,
        'visit_time': visitTime,
        'photo_url': photoUrl,
        'photo_public_id': photoPublicId,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'notes': notes,
        'created_at': createdAt,
      };

  factory SiteVisitRecord.fromMap(Map<String, dynamic> map) => SiteVisitRecord(
        id: map['id'] as int? ?? 0,
        employeeId: map['employee_id'] as int? ?? 0,
        employeeName: map['employee_name'] as String? ?? '',
        siteName: map['site_name'] as String? ?? '',
        visitDate: map['visit_date'] as String? ?? '',
        visitTime: map['visit_time'] as String? ?? '',
        photoUrl: map['photo_url'] as String? ?? '',
        photoPublicId: map['photo_public_id'] as String? ?? '',
        latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
        address: map['address'] as String? ?? '',
        notes: map['notes'] as String? ?? '',
        createdAt: map['created_at'] as String? ?? '',
      );

  SiteVisitRecord copyWith({
    int? id,
    int? employeeId,
    String? employeeName,
    String? siteName,
    String? visitDate,
    String? visitTime,
    String? photoUrl,
    String? photoPublicId,
    double? latitude,
    double? longitude,
    String? address,
    String? notes,
    String? createdAt,
  }) {
    return SiteVisitRecord(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      siteName: siteName ?? this.siteName,
      visitDate: visitDate ?? this.visitDate,
      visitTime: visitTime ?? this.visitTime,
      photoUrl: photoUrl ?? this.photoUrl,
      photoPublicId: photoPublicId ?? this.photoPublicId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
