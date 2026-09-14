class OnDutySite {
  const OnDutySite({
    required this.siteId,
    required this.siteName,
    required this.purpose,
    required this.destination,
    this.destinationAddress = '',
    this.latitude,
    this.longitude,
    this.radius = 100,
    this.status = 'PENDING',
    this.travelStartTime,
    this.reachedTime,
    this.reachedPhoto,
    this.workCompletedTime,
    String? workPhoto,
    this.workPhotos = const [],
    this.startLatitude,
    this.startLongitude,
    this.reachedLatitude,
    this.reachedLongitude,
    this.workEndLatitude,
    this.workEndLongitude,
    this.travelDurationMinutes = 0,
    this.workDurationMinutes = 0,
    this.notes = '',
  }) : _workPhoto = workPhoto;

  final String siteId;
  final String siteName;
  final String purpose;
  final String destination;
  final String destinationAddress;
  final double? latitude;
  final double? longitude;
  final int radius; // Geofence radius in meters
  final String status; // 'PENDING', 'TRAVELING', 'REACHED', 'COMPLETED'
  final String? travelStartTime;
  final String? reachedTime;
  final String? reachedPhoto;
  final String? workCompletedTime;
  final String? _workPhoto;
  String? get workPhoto => _workPhoto ?? (workPhotos.isNotEmpty ? workPhotos.first : null);
  final List<String> workPhotos;
  final double? startLatitude;
  final double? startLongitude;
  final double? reachedLatitude;
  final double? reachedLongitude;
  final double? workEndLatitude;
  final double? workEndLongitude;
  final int travelDurationMinutes;
  final int workDurationMinutes;
  final String notes;

  bool get isPending => status == 'PENDING';
  bool get isTraveling => status == 'TRAVELING';
  bool get isReached => status == 'REACHED';
  bool get isCompleted => status == 'COMPLETED';

  String get effectiveName {
    if (siteName.trim().isNotEmpty) return siteName.trim();
    if (destination.trim().isNotEmpty) return destination.trim();
    return 'Site Visit';
  }

  String get destinationName => siteName.isNotEmpty ? siteName : destination;

  /// Returns effective list of proof photos (or single workPhoto wrapped in list if workPhotos is empty)
  List<String> get effectiveWorkPhotos {
    if (workPhotos.isNotEmpty) return workPhotos;
    if (workPhoto != null && workPhoto!.isNotEmpty) return [workPhoto!];
    return [];
  }

  Map<String, dynamic> toMap() => {
        'site_id': siteId,
        'site_name': siteName,
        'purpose': purpose,
        'destination': destination,
        if (destinationAddress.isNotEmpty) 'destination_address': destinationAddress,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'radius': radius,
        'status': status,
        if (travelStartTime != null) 'travel_start_time': travelStartTime,
        if (reachedTime != null) 'reached_time': reachedTime,
        if (reachedPhoto != null) 'reached_photo': reachedPhoto,
        if (workCompletedTime != null) 'work_completed_time': workCompletedTime,
        if (workPhoto != null) 'work_photo': workPhoto,
        if (workPhotos.isNotEmpty) 'work_photos': workPhotos,
        if (startLatitude != null) 'start_latitude': startLatitude,
        if (startLongitude != null) 'start_longitude': startLongitude,
        if (reachedLatitude != null) 'reached_latitude': reachedLatitude,
        if (reachedLongitude != null) 'reached_longitude': reachedLongitude,
        if (workEndLatitude != null) 'work_end_latitude': workEndLatitude,
        if (workEndLongitude != null) 'work_end_longitude': workEndLongitude,
        'travel_duration_minutes': travelDurationMinutes,
        'work_duration_minutes': workDurationMinutes,
        if (notes.isNotEmpty) 'notes': notes,
      };

  factory OnDutySite.fromMap(Map<String, dynamic> map) {
    List<String> parsedWorkPhotos = [];
    if (map['work_photos'] != null && map['work_photos'] is List) {
      parsedWorkPhotos = (map['work_photos'] as List).map((x) => x.toString()).where((x) => x.isNotEmpty).toList();
    } else if (map['work_photo'] != null && map['work_photo'].toString().isNotEmpty) {
      parsedWorkPhotos = [map['work_photo'].toString()];
    }

    return OnDutySite(
      siteId: map['site_id']?.toString() ?? map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      siteName: map['site_name']?.toString() ?? map['destination_name']?.toString() ?? '',
      purpose: map['purpose']?.toString() ?? '',
      destination: map['destination']?.toString() ?? map['site_name']?.toString() ?? '',
      destinationAddress: map['destination_address']?.toString() ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? (map['destination_latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble() ?? (map['destination_longitude'] as num?)?.toDouble(),
      radius: (map['radius'] as num?)?.toInt() ?? (map['destination_radius'] as num?)?.toInt() ?? 100,
      status: (map['status']?.toString() ?? 'PENDING').toUpperCase(),
      travelStartTime: map['travel_start_time']?.toString(),
      reachedTime: map['reached_time']?.toString(),
      reachedPhoto: map['reached_photo']?.toString(),
      workCompletedTime: map['work_completed_time']?.toString(),
      workPhoto: map['work_photo']?.toString() ?? (parsedWorkPhotos.isNotEmpty ? parsedWorkPhotos.first : null),
      workPhotos: parsedWorkPhotos,
      startLatitude: (map['start_latitude'] as num?)?.toDouble(),
      startLongitude: (map['start_longitude'] as num?)?.toDouble(),
      reachedLatitude: (map['reached_latitude'] as num?)?.toDouble(),
      reachedLongitude: (map['reached_longitude'] as num?)?.toDouble(),
      workEndLatitude: (map['work_end_latitude'] as num?)?.toDouble(),
      workEndLongitude: (map['work_end_longitude'] as num?)?.toDouble(),
      travelDurationMinutes: (map['travel_duration_minutes'] as num?)?.toInt() ?? 0,
      workDurationMinutes: (map['work_duration_minutes'] as num?)?.toInt() ?? 0,
      notes: map['notes']?.toString() ?? '',
    );
  }

  OnDutySite copyWith({
    String? siteId,
    String? siteName,
    String? purpose,
    String? destination,
    String? destinationAddress,
    double? latitude,
    double? longitude,
    int? radius,
    String? status,
    String? travelStartTime,
    String? reachedTime,
    String? reachedPhoto,
    String? workCompletedTime,
    String? workPhoto,
    List<String>? workPhotos,
    double? startLatitude,
    double? startLongitude,
    double? reachedLatitude,
    double? reachedLongitude,
    double? workEndLatitude,
    double? workEndLongitude,
    int? travelDurationMinutes,
    int? workDurationMinutes,
    String? notes,
  }) {
    return OnDutySite(
      siteId: siteId ?? this.siteId,
      siteName: siteName ?? this.siteName,
      purpose: purpose ?? this.purpose,
      destination: destination ?? this.destination,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radius: radius ?? this.radius,
      status: status ?? this.status,
      travelStartTime: travelStartTime ?? this.travelStartTime,
      reachedTime: reachedTime ?? this.reachedTime,
      reachedPhoto: reachedPhoto ?? this.reachedPhoto,
      workCompletedTime: workCompletedTime ?? this.workCompletedTime,
      workPhoto: workPhoto ?? this.workPhoto,
      workPhotos: workPhotos ?? this.workPhotos,
      startLatitude: startLatitude ?? this.startLatitude,
      startLongitude: startLongitude ?? this.startLongitude,
      reachedLatitude: reachedLatitude ?? this.reachedLatitude,
      reachedLongitude: reachedLongitude ?? this.reachedLongitude,
      workEndLatitude: workEndLatitude ?? this.workEndLatitude,
      workEndLongitude: workEndLongitude ?? this.workEndLongitude,
      travelDurationMinutes: travelDurationMinutes ?? this.travelDurationMinutes,
      workDurationMinutes: workDurationMinutes ?? this.workDurationMinutes,
      notes: notes ?? this.notes,
    );
  }
}
