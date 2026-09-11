import 'on_duty_site.dart';

class OnDutyAssignment {
  const OnDutyAssignment({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.odType,
    required this.purpose,
    required this.destination,
    this.destinationName = '',
    this.destinationAddress = '',
    this.destinationLatitude,
    this.destinationLongitude,
    this.destinationRadius = 100,
    this.sites = const [],
    required this.date,
    this.plannedStartTime = '',
    this.plannedEndTime,
    this.actualStartTime,
    this.actualEndTime,
    this.startLatitude,
    this.startLongitude,
    this.endLatitude,
    this.endLongitude,
    this.startPhoto,
    this.endPhoto,
    this.travelStartTime,
    this.reachedTime,
    this.reachedPhoto,
    this.workCompletedTime,
    this.workPhoto,
    this.returnStartTime,
    this.officeReachedTime,
    this.startTripLatitude,
    this.startTripLongitude,
    this.reachedLatitude,
    this.reachedLongitude,
    this.workEndLatitude,
    this.workEndLongitude,
    this.returnLatitude,
    this.returnLongitude,
    this.officeLatitude,
    this.officeLongitude,
    this.travelToSiteDurationMinutes = 0,
    this.onSiteWorkDurationMinutes = 0,
    this.returnTravelDurationMinutes = 0,
    required this.status,
    this.notes = '',
    required this.assignedBy,
    this.durationMinutes = 0,
    this.afterCompletionOption = 'RETURN_TO_OFFICE',
    required this.createdAt,
  });

  final int id;
  final int employeeId;
  final String employeeName;
  final String odType; // 'Customer Visit', 'Branch Visit', 'External Meeting', 'Govt Office', 'Field Work', 'Other'
  final String purpose;
  final String destination;
  final String destinationName;
  final String destinationAddress;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final int destinationRadius; // Allowed geofence radius in meters (default 100)
  final List<OnDutySite> sites;
  final String date; // 'dd-MM-yyyy'
  final String plannedStartTime; // '10:00 AM'
  final String? plannedEndTime; // '04:00 PM'
  final String? actualStartTime;
  final String? actualEndTime;
  final double? startLatitude;
  final double? startLongitude;
  final double? endLatitude;
  final double? endLongitude;
  final String? startPhoto;
  final String? endPhoto;

  // Multi-step State Machine Timestamps & Photos
  final String? travelStartTime; // Step 1: Start OD Trip clicked
  final String? reachedTime; // Step 2: Reached site clicked
  final String? reachedPhoto; // Live camera photo when reached
  final String? workCompletedTime; // Step 3: Complete OD work clicked
  final String? workPhoto; // Proof of work photo
  final String? returnStartTime; // Step 4: Return to office clicked
  final String? officeReachedTime; // Step 5: Came to office confirmed

  // Multi-step GPS Coordinates
  final double? startTripLatitude;
  final double? startTripLongitude;
  final double? reachedLatitude;
  final double? reachedLongitude;
  final double? workEndLatitude;
  final double? workEndLongitude;
  final double? returnLatitude;
  final double? returnLongitude;
  final double? officeLatitude;
  final double? officeLongitude;

  // Segment Durations (in minutes)
  final int travelToSiteDurationMinutes;
  final int onSiteWorkDurationMinutes;
  final int returnTravelDurationMinutes;

  final String status; // 'ASSIGNED', 'TRAVELING_TO_DESTINATION', 'IN_PROGRESS', 'REACHED_DESTINATION', 'WORK_COMPLETED', 'RETURNING_TO_OFFICE', 'COMPLETED', 'CANCELLED'
  final String notes;
  final String assignedBy;
  final int durationMinutes;
  final String afterCompletionOption; // 'RETURN_TO_OFFICE', 'CHECKOUT_FROM_OD'
  final String createdAt;

  /// Status helpers
  bool get isAssigned => status == 'ASSIGNED';
  bool get isTravelingToDestination =>
      status == 'TRAVELING_TO_DESTINATION' || (status == 'IN_PROGRESS' && reachedTime == null);
  bool get isReachedDestination => status == 'REACHED_DESTINATION';
  bool get isWorkCompleted => status == 'WORK_COMPLETED';
  bool get isReturningToOffice => status == 'RETURNING_TO_OFFICE';
  bool get isCompleted => status == 'COMPLETED';
  bool get isCancelled => status == 'CANCELLED';

  bool get isOngoing =>
      status != 'COMPLETED' && status != 'CANCELLED' && status != 'REJECTED';

  bool get isReturnToOfficeOption =>
      afterCompletionOption == 'RETURN_TO_OFFICE';

  /// Sequential Site Visit Helpers
  OnDutySite? get currentSite {
    if (sites.isEmpty) return null;
    for (final site in sites) {
      if (!site.isCompleted) return site;
    }
    return sites.last;
  }

  int get currentSiteIndex {
    if (sites.isEmpty) return 0;
    final idx = sites.indexWhere((s) => !s.isCompleted);
    return idx != -1 ? idx : (sites.length - 1);
  }

  bool get allSitesCompleted {
    if (sites.isEmpty) return true;
    return sites.every((s) => s.isCompleted);
  }

  bool canStartSite(int index) {
    if (index < 0 || index >= sites.length) return false;
    if (index == 0) return true;
    return sites[index - 1].isCompleted;
  }

  /// Effective target coordinates for destination
  double? get effectiveDestinationLatitude => currentSite?.latitude ?? destinationLatitude ?? endLatitude;
  double? get effectiveDestinationLongitude => currentSite?.longitude ?? destinationLongitude ?? endLongitude;
  int get effectiveDestinationRadius => currentSite?.radius ?? destinationRadius;

  /// Effective display name for destination
  String get effectiveDestinationTitle {
    if (currentSite != null && currentSite!.effectiveName.isNotEmpty) {
      return currentSite!.effectiveName;
    }
    if (destinationName.isNotEmpty) return destinationName;
    if (destination.isNotEmpty) return destination;
    return 'Site Destination';
  }

  /// Effective status display label derived from status & progress milestones
  String get effectiveStatusLabel {
    final s = status.toUpperCase();
    if (s == 'COMPLETED') return 'Completed';
    if (s == 'CANCELLED') return 'Cancelled';
    if (s == 'RETURNING_TO_OFFICE' || (returnStartTime != null && officeReachedTime == null)) {
      return 'Return office from site';
    }
    if (sites.isNotEmpty) {
      final active = currentSite;
      if (active != null) {
        final siteNum = currentSiteIndex + 1;
        if (active.isCompleted && allSitesCompleted) return 'All Sites Completed';
        if (active.isReached) return 'Arrived at Site $siteNum (${active.effectiveName})';
        if (active.isTraveling) return 'Traveling to Site $siteNum (${active.effectiveName})';
        if (active.isPending) return 'Site $siteNum Pending (${active.effectiveName})';
      }
    }
    if (s == 'WORK_COMPLETED' || (workCompletedTime != null && returnStartTime == null)) {
      return 'OD work completed';
    }
    if (s == 'REACHED_DESTINATION' || (reachedTime != null && workCompletedTime == null)) {
      return 'Arrived at site';
    }
    if (s == 'TRAVELING_TO_DESTINATION' || (travelStartTime != null && reachedTime == null)) {
      return 'Traveling to Site';
    }
    if (s == 'ASSIGNED') return 'Assigned';
    return s.replaceAll('_', ' ');
  }

  /// Effective arrival photo
  String? get effectiveReachedPhoto => currentSite?.reachedPhoto ?? reachedPhoto ?? startPhoto;

  /// Effective completion photo
  String? get effectiveWorkPhoto => currentSite?.workPhoto ?? workPhoto ?? endPhoto;

  Map<String, dynamic> toMap() => {
        if (id != 0) 'id': id,
        'employee_id': employeeId,
        'employee_name': employeeName,
        'od_type': odType,
        'purpose': purpose,
        'destination': destination,
        if (destinationName.isNotEmpty) 'destination_name': destinationName,
        if (destinationAddress.isNotEmpty) 'destination_address': destinationAddress,
        if (effectiveDestinationLatitude != null) 'destination_latitude': effectiveDestinationLatitude,
        if (effectiveDestinationLongitude != null) 'destination_longitude': effectiveDestinationLongitude,
        'destination_radius': destinationRadius,
        'sites': sites.map((s) => s.toMap()).toList(),
        'date': date,
        'planned_start_time': plannedStartTime,
        'planned_end_time': plannedEndTime,
        'actual_start_time': actualStartTime ?? travelStartTime,
        'actual_end_time': actualEndTime ?? officeReachedTime ?? workCompletedTime,
        'start_latitude': startLatitude ?? startTripLatitude,
        'start_longitude': startLongitude ?? startTripLongitude,
        'end_latitude': endLatitude ?? effectiveDestinationLatitude,
        'end_longitude': endLongitude ?? effectiveDestinationLongitude,
        'start_photo': startPhoto ?? reachedPhoto,
        'end_photo': endPhoto ?? workPhoto,
        'travel_start_time': travelStartTime,
        'reached_time': reachedTime,
        'reached_photo': reachedPhoto,
        'work_completed_time': workCompletedTime,
        'work_photo': workPhoto,
        'return_start_time': returnStartTime,
        'office_reached_time': officeReachedTime,
        'start_trip_latitude': startTripLatitude,
        'start_trip_longitude': startTripLongitude,
        'reached_latitude': reachedLatitude,
        'reached_longitude': reachedLongitude,
        'work_end_latitude': workEndLatitude,
        'work_end_longitude': workEndLongitude,
        'return_latitude': returnLatitude,
        'return_longitude': returnLongitude,
        'office_latitude': officeLatitude,
        'office_longitude': officeLongitude,
        'travel_to_site_duration_minutes': travelToSiteDurationMinutes,
        'on_site_work_duration_minutes': onSiteWorkDurationMinutes,
        'return_travel_duration_minutes': returnTravelDurationMinutes,
        'status': status,
        'notes': notes,
        'assigned_by': assignedBy,
        'duration_minutes': durationMinutes,
        'after_completion_option': afterCompletionOption,
        'created_at': createdAt,
      };

  factory OnDutyAssignment.fromMap(Map<String, dynamic> map) {
    var rawStatus = (map['status']?.toString() ?? 'ASSIGNED').toUpperCase();
    if (rawStatus == 'ACTIVE') rawStatus = 'IN_PROGRESS';

    int parseId(dynamic val) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val != null) return int.tryParse(val.toString()) ?? 0;
      return 0;
    }

    var opt = map['after_completion_option']?.toString() ?? 'RETURN_TO_OFFICE';
    if (opt.contains('Checkout') || opt.contains('CHECKOUT')) {
      opt = 'CHECKOUT_FROM_OD';
    } else {
      opt = 'RETURN_TO_OFFICE';
    }

    final destLat = (map['destination_latitude'] as num?)?.toDouble() ??
        (map['end_latitude'] as num?)?.toDouble();
    final destLng = (map['destination_longitude'] as num?)?.toDouble() ??
        (map['end_longitude'] as num?)?.toDouble();
    final destRadius = (map['destination_radius'] as num?)?.toInt() ?? 100;

    final destName = map['destination_name']?.toString() ?? '';
    final destAddress = map['destination_address']?.toString() ?? '';
    final destStr = map['destination']?.toString() ??
        map['destination_location']?.toString() ??
        map['from_location']?.toString() ??
        (destName.isNotEmpty ? destName : '');

    List<OnDutySite> parsedSites = [];
    if (map['sites'] != null && map['sites'] is List) {
      final rawSitesList = map['sites'] as List;
      parsedSites = rawSitesList
          .map((item) => OnDutySite.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    // Legacy fallback: if sites list is empty but single destination info exists, create 1 site
    if (parsedSites.isEmpty && (destStr.isNotEmpty || destName.isNotEmpty || destLat != null)) {
      parsedSites = [
        OnDutySite(
          siteId: '1',
          siteName: destName.isNotEmpty ? destName : destStr,
          purpose: map['purpose']?.toString() ?? '',
          destination: destStr,
          destinationAddress: destAddress,
          latitude: destLat,
          longitude: destLng,
          radius: destRadius > 0 ? destRadius : 100,
          status: rawStatus == 'COMPLETED'
              ? 'COMPLETED'
              : (rawStatus == 'REACHED_DESTINATION'
                  ? 'REACHED'
                  : (rawStatus == 'TRAVELING_TO_DESTINATION' || rawStatus == 'IN_PROGRESS'
                      ? 'TRAVELING'
                      : 'PENDING')),
          travelStartTime: map['travel_start_time']?.toString(),
          reachedTime: map['reached_time']?.toString(),
          reachedPhoto: map['reached_photo']?.toString() ?? map['start_photo']?.toString(),
          workCompletedTime: map['work_completed_time']?.toString(),
          workPhoto: map['work_photo']?.toString() ?? map['end_photo']?.toString(),
        )
      ];
    }

    return OnDutyAssignment(
      id: parseId(map['id']),
      employeeId: parseId(map['employee_id']),
      employeeName: map['employee_name']?.toString() ?? '',
      odType: map['od_type']?.toString() ?? map['task']?.toString() ?? 'Customer Visit',
      purpose: map['purpose']?.toString() ?? map['task']?.toString() ?? '',
      destination: destStr,
      destinationName: destName.isNotEmpty ? destName : destStr,
      destinationAddress: destAddress,
      destinationLatitude: destLat,
      destinationLongitude: destLng,
      destinationRadius: destRadius > 0 ? destRadius : 100,
      sites: parsedSites,
      date: map['date']?.toString() ?? '',
      plannedStartTime: map['planned_start_time']?.toString() ?? map['assigned_time']?.toString() ?? '',
      plannedEndTime: map['planned_end_time']?.toString(),
      actualStartTime: map['actual_start_time']?.toString() ?? map['travel_start_time']?.toString() ?? map['started_time']?.toString(),
      actualEndTime: map['actual_end_time']?.toString() ?? map['office_reached_time']?.toString() ?? map['completed_time']?.toString(),
      startLatitude: (map['start_latitude'] as num?)?.toDouble() ?? (map['from_latitude'] as num?)?.toDouble(),
      startLongitude: (map['start_longitude'] as num?)?.toDouble() ?? (map['from_longitude'] as num?)?.toDouble(),
      endLatitude: (map['end_latitude'] as num?)?.toDouble() ?? destLat,
      endLongitude: (map['end_longitude'] as num?)?.toDouble() ?? destLng,
      startPhoto: map['start_photo']?.toString() ?? map['reached_photo']?.toString(),
      endPhoto: map['end_photo']?.toString() ?? map['work_photo']?.toString() ?? map['photo_proof_path']?.toString(),
      travelStartTime: map['travel_start_time']?.toString() ?? map['actual_start_time']?.toString(),
      reachedTime: map['reached_time']?.toString(),
      reachedPhoto: map['reached_photo']?.toString() ?? map['start_photo']?.toString(),
      workCompletedTime: map['work_completed_time']?.toString(),
      workPhoto: map['work_photo']?.toString() ?? map['end_photo']?.toString(),
      returnStartTime: map['return_start_time']?.toString(),
      officeReachedTime: map['office_reached_time']?.toString() ?? map['actual_end_time']?.toString(),
      startTripLatitude: (map['start_trip_latitude'] as num?)?.toDouble() ?? (map['start_latitude'] as num?)?.toDouble(),
      startTripLongitude: (map['start_trip_longitude'] as num?)?.toDouble() ?? (map['start_longitude'] as num?)?.toDouble(),
      reachedLatitude: (map['reached_latitude'] as num?)?.toDouble() ?? destLat,
      reachedLongitude: (map['reached_longitude'] as num?)?.toDouble() ?? destLng,
      workEndLatitude: (map['work_end_latitude'] as num?)?.toDouble(),
      workEndLongitude: (map['work_end_longitude'] as num?)?.toDouble(),
      returnLatitude: (map['return_latitude'] as num?)?.toDouble(),
      returnLongitude: (map['return_longitude'] as num?)?.toDouble(),
      officeLatitude: (map['office_latitude'] as num?)?.toDouble(),
      officeLongitude: (map['office_longitude'] as num?)?.toDouble(),
      travelToSiteDurationMinutes: parseId(map['travel_to_site_duration_minutes']),
      onSiteWorkDurationMinutes: parseId(map['on_site_work_duration_minutes']),
      returnTravelDurationMinutes: parseId(map['return_travel_duration_minutes']),
      status: rawStatus,
      notes: map['notes']?.toString() ?? map['instructions']?.toString() ?? '',
      assignedBy: map['assigned_by']?.toString() ?? 'Admin',
      durationMinutes: parseId(map['duration_minutes']),
      afterCompletionOption: opt,
      createdAt: map['created_at']?.toString() ?? map['createdAt']?.toString() ?? '',
    );
  }

  OnDutyAssignment copyWith({
    int? id,
    int? employeeId,
    String? employeeName,
    String? odType,
    String? purpose,
    String? destination,
    String? destinationName,
    String? destinationAddress,
    double? destinationLatitude,
    double? destinationLongitude,
    int? destinationRadius,
    List<OnDutySite>? sites,
    String? date,
    String? plannedStartTime,
    String? plannedEndTime,
    String? actualStartTime,
    String? actualEndTime,
    double? startLatitude,
    double? startLongitude,
    double? endLatitude,
    double? endLongitude,
    String? startPhoto,
    String? endPhoto,
    String? travelStartTime,
    String? reachedTime,
    String? reachedPhoto,
    String? workCompletedTime,
    String? workPhoto,
    String? returnStartTime,
    String? officeReachedTime,
    double? startTripLatitude,
    double? startTripLongitude,
    double? reachedLatitude,
    double? reachedLongitude,
    double? workEndLatitude,
    double? workEndLongitude,
    double? returnLatitude,
    double? returnLongitude,
    double? officeLatitude,
    double? officeLongitude,
    int? travelToSiteDurationMinutes,
    int? onSiteWorkDurationMinutes,
    int? returnTravelDurationMinutes,
    String? status,
    String? notes,
    String? assignedBy,
    int? durationMinutes,
    String? afterCompletionOption,
    String? createdAt,
  }) {
    return OnDutyAssignment(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      odType: odType ?? this.odType,
      purpose: purpose ?? this.purpose,
      destination: destination ?? this.destination,
      destinationName: destinationName ?? this.destinationName,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      destinationLatitude: destinationLatitude ?? this.destinationLatitude,
      destinationLongitude: destinationLongitude ?? this.destinationLongitude,
      destinationRadius: destinationRadius ?? this.destinationRadius,
      sites: sites ?? this.sites,
      date: date ?? this.date,
      plannedStartTime: plannedStartTime ?? this.plannedStartTime,
      plannedEndTime: plannedEndTime ?? this.plannedEndTime,
      actualStartTime: actualStartTime ?? this.actualStartTime,
      actualEndTime: actualEndTime ?? this.actualEndTime,
      startLatitude: startLatitude ?? this.startLatitude,
      startLongitude: startLongitude ?? this.startLongitude,
      endLatitude: endLatitude ?? this.endLatitude,
      endLongitude: endLongitude ?? this.endLongitude,
      startPhoto: startPhoto ?? this.startPhoto,
      endPhoto: endPhoto ?? this.endPhoto,
      travelStartTime: travelStartTime ?? this.travelStartTime,
      reachedTime: reachedTime ?? this.reachedTime,
      reachedPhoto: reachedPhoto ?? this.reachedPhoto,
      workCompletedTime: workCompletedTime ?? this.workCompletedTime,
      workPhoto: workPhoto ?? this.workPhoto,
      returnStartTime: returnStartTime ?? this.returnStartTime,
      officeReachedTime: officeReachedTime ?? this.officeReachedTime,
      startTripLatitude: startTripLatitude ?? this.startTripLatitude,
      startTripLongitude: startTripLongitude ?? this.startTripLongitude,
      reachedLatitude: reachedLatitude ?? this.reachedLatitude,
      reachedLongitude: reachedLongitude ?? this.reachedLongitude,
      workEndLatitude: workEndLatitude ?? this.workEndLatitude,
      workEndLongitude: workEndLongitude ?? this.workEndLongitude,
      returnLatitude: returnLatitude ?? this.returnLatitude,
      returnLongitude: returnLongitude ?? this.returnLongitude,
      officeLatitude: officeLatitude ?? this.officeLatitude,
      officeLongitude: officeLongitude ?? this.officeLongitude,
      travelToSiteDurationMinutes: travelToSiteDurationMinutes ?? this.travelToSiteDurationMinutes,
      onSiteWorkDurationMinutes: onSiteWorkDurationMinutes ?? this.onSiteWorkDurationMinutes,
      returnTravelDurationMinutes: returnTravelDurationMinutes ?? this.returnTravelDurationMinutes,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      assignedBy: assignedBy ?? this.assignedBy,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      afterCompletionOption: afterCompletionOption ?? this.afterCompletionOption,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
