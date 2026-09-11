import 'attendance_record.dart';

class AttendanceSession {
  const AttendanceSession({
    this.id = '',
    this.type = 'office',
    required this.checkInTime,
    this.checkOutTime = '',
    this.checkInVerificationStatus = 'Verified',
    this.checkOutVerificationStatus = '',
    this.checkInSimilarityScore = 0.0,
    this.checkOutSimilarityScore = 0.0,
    this.checkInLatitude,
    this.checkInLongitude,
    this.checkOutLatitude,
    this.checkOutLongitude,
    this.checkInMethod = 'Face + Geofence',
    this.checkOutMethod = '',
    this.assignmentId,
    this.purpose,
    this.destination,
    this.destinationAddress,
    this.destinationLatitude,
    this.destinationLongitude,
    this.destinationRadius = 100,
    this.durationHours = 0.0,
    this.durationMinutes = 0,
    this.notes = '',
    this.createdAt = '',
  });

  final String id;

  /// Session type: 'office' or 'od' (On Duty). Defaults to 'office'.
  final String type;

  final String checkInTime;
  final String checkOutTime;

  String get formattedCheckInTime => formatToLocal12HourTime(checkInTime);
  String get formattedCheckOutTime => formatToLocal12HourTime(checkOutTime);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #formattedCheckInTime) {
      return formattedCheckInTime;
    }
    if (invocation.memberName == #formattedCheckOutTime) {
      return formattedCheckOutTime;
    }
    return super.noSuchMethod(invocation);
  }
  final String checkInVerificationStatus;
  final String checkOutVerificationStatus;
  final double checkInSimilarityScore;
  final double checkOutSimilarityScore;
  final double? checkInLatitude;
  final double? checkInLongitude;
  final double? checkOutLatitude;
  final double? checkOutLongitude;
  final String checkInMethod;
  final String checkOutMethod;

  /// Optional assignment ID for On-Duty sessions.
  final int? assignmentId;

  /// Optional purpose/task title for On-Duty sessions.
  final String? purpose;

  /// Optional destination name for On-Duty sessions.
  final String? destination;

  /// Optional destination address for On-Duty sessions.
  final String? destinationAddress;

  /// Target destination coordinates for geofence validation
  final double? destinationLatitude;
  final double? destinationLongitude;
  final int destinationRadius;

  final double durationHours;
  final int durationMinutes;
  final String notes;
  final String createdAt;

  /// Returns true if the session is currently active (checked in, but not checked out).
  bool get isActive => checkInTime.isNotEmpty && checkOutTime.isEmpty;

  /// Returns true if the session has both check-in and check-out completed.
  bool get isCompleted => checkInTime.isNotEmpty && checkOutTime.isNotEmpty;

  /// Helper to check if this is an Office session.
  bool get isOffice => type.toLowerCase() == 'office';

  /// Helper to check if this is an On-Duty (OD) session.
  bool get isOd => type.toLowerCase() == 'od';

  /// Computes effective duration in hours if durationHours is not explicitly set.
  double get effectiveDurationHours {
    if (durationHours > 0) return durationHours;
    if (durationMinutes > 0) return durationMinutes / 60.0;
    if (isCompleted) {
      final inMinutes = _parseTimeToMinutes(checkInTime);
      final outMinutes = _parseTimeToMinutes(checkOutTime);
      if (inMinutes != null && outMinutes != null && outMinutes >= inMinutes) {
        return (outMinutes - inMinutes) / 60.0;
      }
    }
    return 0.0;
  }

  /// Computes effective duration in minutes if durationMinutes is not explicitly set.
  int get effectiveDurationMinutes {
    if (durationMinutes > 0) return durationMinutes;
    if (durationHours > 0) return (durationHours * 60).round();
    if (isCompleted) {
      final inMinutes = _parseTimeToMinutes(checkInTime);
      final outMinutes = _parseTimeToMinutes(checkOutTime);
      if (inMinutes != null && outMinutes != null && outMinutes >= inMinutes) {
        return outMinutes - inMinutes;
      }
    }
    return 0;
  }

  static int? _parseTimeToMinutes(String timeStr) {
    try {
      final trimmed = timeStr.trim();
      if (trimmed.isEmpty) return null;

      // Handle ISO strings
      if (trimmed.contains('T')) {
        final dt = DateTime.tryParse(trimmed);
        if (dt != null) return dt.hour * 60 + dt.minute;
      }

      // Handle 12-hour AM/PM formats e.g. "09:30 AM" or "9:30:00 AM"
      final isPm = trimmed.toUpperCase().contains('PM');
      final isAm = trimmed.toUpperCase().contains('AM');
      final clean = trimmed.replaceAll(RegExp(r'[a-zA-Z]'), '').trim();
      final parts = clean.split(':');
      if (parts.length >= 2) {
        int hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        if (isPm && hour < 12) hour += 12;
        if (isAm && hour == 12) hour = 0;
        return hour * 60 + minute;
      }
    } catch (_) {}
    return null;
  }

  AttendanceSession copyWith({
    String? id,
    String? type,
    String? checkInTime,
    String? checkOutTime,
    String? checkInVerificationStatus,
    String? checkOutVerificationStatus,
    double? checkInSimilarityScore,
    double? checkOutSimilarityScore,
    double? checkInLatitude,
    double? checkInLongitude,
    double? checkOutLatitude,
    double? checkOutLongitude,
    String? checkInMethod,
    String? checkOutMethod,
    int? assignmentId,
    String? purpose,
    String? destination,
    String? destinationAddress,
    double? destinationLatitude,
    double? destinationLongitude,
    int? destinationRadius,
    double? durationHours,
    int? durationMinutes,
    String? notes,
    String? createdAt,
  }) {
    return AttendanceSession(
      id: id ?? this.id,
      type: type ?? this.type,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      checkInVerificationStatus:
          checkInVerificationStatus ?? this.checkInVerificationStatus,
      checkOutVerificationStatus:
          checkOutVerificationStatus ?? this.checkOutVerificationStatus,
      checkInSimilarityScore:
          checkInSimilarityScore ?? this.checkInSimilarityScore,
      checkOutSimilarityScore:
          checkOutSimilarityScore ?? this.checkOutSimilarityScore,
      checkInLatitude: checkInLatitude ?? this.checkInLatitude,
      checkInLongitude: checkInLongitude ?? this.checkInLongitude,
      checkOutLatitude: checkOutLatitude ?? this.checkOutLatitude,
      checkOutLongitude: checkOutLongitude ?? this.checkOutLongitude,
      checkInMethod: checkInMethod ?? this.checkInMethod,
      checkOutMethod: checkOutMethod ?? this.checkOutMethod,
      assignmentId: assignmentId ?? this.assignmentId,
      purpose: purpose ?? this.purpose,
      destination: destination ?? this.destination,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      destinationLatitude: destinationLatitude ?? this.destinationLatitude,
      destinationLongitude: destinationLongitude ?? this.destinationLongitude,
      destinationRadius: destinationRadius ?? this.destinationRadius,
      durationHours: durationHours ?? this.durationHours,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id.isNotEmpty) 'id': id,
        'type': type,
        'check_in_time': checkInTime,
        'check_out_time': checkOutTime,
        'check_in_verification_status': checkInVerificationStatus,
        'check_out_verification_status': checkOutVerificationStatus,
        'check_in_similarity_score': checkInSimilarityScore,
        'check_out_similarity_score': checkOutSimilarityScore,
        if (checkInLatitude != null) 'check_in_latitude': checkInLatitude,
        if (checkInLongitude != null) 'check_in_longitude': checkInLongitude,
        if (checkOutLatitude != null) 'check_out_latitude': checkOutLatitude,
        if (checkOutLongitude != null) 'check_out_longitude': checkOutLongitude,
        'check_in_method': checkInMethod,
        'check_out_method': checkOutMethod,
        if (assignmentId != null) 'assignment_id': assignmentId,
        if (purpose != null && purpose!.isNotEmpty) 'purpose': purpose,
        if (destination != null && destination!.isNotEmpty) 'destination': destination,
        if (destinationAddress != null && destinationAddress!.isNotEmpty)
          'destination_address': destinationAddress,
        if (destinationLatitude != null) 'destination_latitude': destinationLatitude,
        if (destinationLongitude != null) 'destination_longitude': destinationLongitude,
        'destination_radius': destinationRadius,
        'duration_hours': durationHours > 0 ? durationHours : effectiveDurationHours,
        'duration_minutes': durationMinutes > 0 ? durationMinutes : effectiveDurationMinutes,
        'notes': notes,
        'created_at': createdAt,
      };

  factory AttendanceSession.fromMap(Map<String, dynamic> map) {
    int? parseId(dynamic val) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val != null) return int.tryParse(val.toString());
      return null;
    }

    return AttendanceSession(
      id: (map['id'] ?? '').toString(),
      type: (map['type'] ?? 'office').toString().toLowerCase(),
      checkInTime: (map['check_in_time'] ?? map['checkInTime'] ?? '').toString(),
      checkOutTime: (map['check_out_time'] ?? map['checkOutTime'] ?? '').toString(),
      checkInVerificationStatus:
          (map['check_in_verification_status'] ?? map['checkInVerificationStatus'] ?? 'Verified').toString(),
      checkOutVerificationStatus:
          (map['check_out_verification_status'] ?? map['checkOutVerificationStatus'] ?? '').toString(),
      checkInSimilarityScore:
          (map['check_in_similarity_score'] ?? map['checkInSimilarityScore'] as num?)?.toDouble() ?? 0.0,
      checkOutSimilarityScore:
          (map['check_out_similarity_score'] ?? map['checkOutSimilarityScore'] as num?)?.toDouble() ?? 0.0,
      checkInLatitude: (map['check_in_latitude'] ?? map['checkInLatitude'] as num?)?.toDouble(),
      checkInLongitude: (map['check_in_longitude'] ?? map['checkInLongitude'] as num?)?.toDouble(),
      checkOutLatitude: (map['check_out_latitude'] ?? map['checkOutLatitude'] as num?)?.toDouble(),
      checkOutLongitude: (map['check_out_longitude'] ?? map['checkOutLongitude'] as num?)?.toDouble(),
      checkInMethod: (map['check_in_method'] ?? map['checkInMethod'] ?? 'Face + Geofence').toString(),
      checkOutMethod: (map['check_out_method'] ?? map['checkOutMethod'] ?? '').toString(),
      assignmentId: parseId(map['assignment_id'] ?? map['assignmentId']),
      purpose: (map['purpose'] ?? map['task'])?.toString(),
      destination: (map['destination'] ?? map['destination_location'])?.toString(),
      destinationAddress: map['destination_address']?.toString(),
      destinationLatitude: (map['destination_latitude'] as num?)?.toDouble(),
      destinationLongitude: (map['destination_longitude'] as num?)?.toDouble(),
      destinationRadius: (map['destination_radius'] as num?)?.toInt() ?? 100,
      durationHours: (map['duration_hours'] ?? map['durationHours'] as num?)?.toDouble() ?? 0.0,
      durationMinutes: (map['duration_minutes'] ?? map['durationMinutes'] as num?)?.toInt() ?? 0,
      notes: (map['notes'] ?? '').toString(),
      createdAt: (map['created_at'] ?? map['createdAt'] ?? '').toString(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AttendanceSession &&
        other.id == id &&
        other.type == type &&
        other.checkInTime == checkInTime &&
        other.checkOutTime == checkOutTime &&
        other.checkInVerificationStatus == checkInVerificationStatus &&
        other.checkOutVerificationStatus == checkOutVerificationStatus &&
        other.checkInSimilarityScore == checkInSimilarityScore &&
        other.checkOutSimilarityScore == checkOutSimilarityScore &&
        other.checkInLatitude == checkInLatitude &&
        other.checkInLongitude == checkInLongitude &&
        other.checkOutLatitude == checkOutLatitude &&
        other.checkOutLongitude == checkOutLongitude &&
        other.checkInMethod == checkInMethod &&
        other.checkOutMethod == checkOutMethod &&
        other.assignmentId == assignmentId &&
        other.purpose == purpose &&
        other.destination == destination &&
        other.destinationAddress == destinationAddress &&
        other.destinationLatitude == destinationLatitude &&
        other.destinationLongitude == destinationLongitude &&
        other.destinationRadius == destinationRadius &&
        other.durationHours == durationHours &&
        other.durationMinutes == durationMinutes &&
        other.notes == notes &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        type,
        checkInTime,
        checkOutTime,
        checkInVerificationStatus,
        checkOutVerificationStatus,
        checkInSimilarityScore,
        checkOutSimilarityScore,
        checkInLatitude,
        checkInLongitude,
        checkOutLatitude,
        checkOutLongitude,
        checkInMethod,
        checkOutMethod,
        assignmentId,
        purpose,
        destination,
        destinationAddress,
        destinationLatitude,
        destinationLongitude,
        destinationRadius,
        durationHours,
        durationMinutes,
        notes,
        createdAt,
      ]);

  @override
  String toString() {
    return 'AttendanceSession(id: $id, type: $type, checkIn: $checkInTime, checkOut: $checkOutTime, durationHours: $effectiveDurationHours)';
  }
}
