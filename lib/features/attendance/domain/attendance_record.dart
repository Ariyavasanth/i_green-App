import '../../../core/utils/time_formatter.dart';
import 'attendance_session.dart';

String formatToLocal12HourTime(String timeStr, {bool forceSeconds = false}) {
  return TimeFormatter.formatToLocal12HourTime(timeStr, forceSeconds: forceSeconds);
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.employeeId,
    this.employeeCode = '',
    required this.employeeName,
    required this.date,
    required this.time,
    required this.status,
    required this.verificationStatus,
    required this.similarityScore,
    this.checkInTime = '',
    this.checkOutTime = '',
    this.checkInVerificationStatus = '',
    this.checkOutVerificationStatus = '',
    this.checkInSimilarityScore = 0.0,
    this.checkOutSimilarityScore = 0.0,
    this.totalHours = 0.0,
    this.notes = '',
    this.markedAt = '',
    this.sessions = const [],
  });

  final int id;
  final int employeeId;
  final String employeeCode;
  final String employeeName;
  final String date;
  final String time; // Represents Check In time by default for backward compatibility
  final String status; // Present, Late, Checked Out, Half Day, Absent
  final String verificationStatus;
  final double similarityScore;
  final String checkInTime;
  final String checkOutTime;
  final String checkInVerificationStatus;
  final String checkOutVerificationStatus;
  final double checkInSimilarityScore;
  final double checkOutSimilarityScore;
  final double totalHours;
  final String notes;
  final String markedAt;
  final List<AttendanceSession> sessions;

  String get effectiveCheckInTime => checkInTime.isNotEmpty ? checkInTime : time;
  String get formattedCheckInTime => TimeFormatter.formatToLocal12HourTime(effectiveCheckInTime);
  String get formattedCheckOutTime => TimeFormatter.formatToLocal12HourTime(checkOutTime);

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
  String get effectiveCheckInVerification =>
      checkInVerificationStatus.isNotEmpty ? checkInVerificationStatus : verificationStatus;
  double get effectiveCheckInSimilarity =>
      checkInSimilarityScore > 0 ? checkInSimilarityScore : similarityScore;
  bool get isMissingCheckOut => status == 'Missing Check-Out';
  bool get requiresCorrection =>
      isMissingCheckOut || (effectiveCheckInTime.isNotEmpty && checkOutTime.isEmpty && status != 'Absent' && status != 'On Leave');

  static bool _isOfficeType(String type) {
    final t = type.trim().toLowerCase();
    return t == 'office' || t == 'general work' || t == 'work';
  }

  static bool _isOdType(String type) {
    final t = type.trim().toLowerCase();
    return t == 'od' || t == 'on duty' || t == 'on-duty';
  }

  static bool _isLunchType(String type) {
    final t = type.trim().toLowerCase();
    return t.contains('lunch');
  }

  static bool _isTeaBreakType(String type) {
    final t = type.trim().toLowerCase();
    return (t.contains('tea') || t.contains('coffee') || t.contains('break')) && !t.contains('lunch');
  }

  static bool _isMeetingOtherType(String type) {
    return !_isOfficeType(type) && !_isOdType(type) && !_isLunchType(type) && !_isTeaBreakType(type);
  }

  /// Computes the total working hours by summing all valid completed sessions
  /// (Office, OD, Lunch Break, Tea Break, Meeting, and other activity sessions).
  /// Falls back to top-level check-in and check-out difference if sessions list is empty.
  double get computedTotalHours {
    if (sessions.isNotEmpty) {
      double sum = 0.0;
      for (final s in sessions) {
        if (s.isCompleted) {
          sum += s.effectiveDurationHours;
        }
      }
      if (sum > 0) {
        return double.parse(sum.toStringAsFixed(2));
      }
    }

    if (totalHours > 0) return totalHours;

    if (effectiveCheckInTime.isNotEmpty && checkOutTime.isNotEmpty) {
      final inMins = AttendanceSession.parseTimeToMinutes(effectiveCheckInTime);
      final outMins = AttendanceSession.parseTimeToMinutes(checkOutTime);
      if (inMins != null && outMins != null && outMins > inMins) {
        return double.parse(((outMins - inMins) / 60.0).toStringAsFixed(2));
      }
    }

    return 0.0;
  }

  /// Computes total office session hours (includes General Work, Work, and Office).
  /// Falls back to computedTotalHours if no sessions list is provided.
  double get computedOfficeHours {
    if (sessions.isNotEmpty) {
      double sum = 0.0;
      for (final s in sessions) {
        if (s.isCompleted && (s.isOffice || _isOfficeType(s.type))) {
          sum += s.effectiveDurationHours;
        }
      }
      return double.parse(sum.toStringAsFixed(2));
    }
    return computedTotalHours;
  }

  /// Computes total OD (On Duty) session hours.
  double get computedOdHours {
    if (sessions.isNotEmpty) {
      double sum = 0.0;
      for (final s in sessions) {
        if (s.isCompleted && (s.isOd || _isOdType(s.type))) {
          sum += s.effectiveDurationHours;
        }
      }
      return double.parse(sum.toStringAsFixed(2));
    }
    return 0.0;
  }

  /// Computes total Lunch Break session hours (counted toward Total Working Hours).
  double get computedLunchHours {
    if (sessions.isNotEmpty) {
      double sum = 0.0;
      for (final s in sessions) {
        if (s.isCompleted && (s.isLunch || _isLunchType(s.type))) {
          sum += s.effectiveDurationHours;
        }
      }
      return double.parse(sum.toStringAsFixed(2));
    }
    return 0.0;
  }

  /// Computes total Tea Break session hours (counted toward Total Working Hours).
  double get computedTeaBreakHours {
    if (sessions.isNotEmpty) {
      double sum = 0.0;
      for (final s in sessions) {
        if (s.isCompleted && (s.isTeaBreak || _isTeaBreakType(s.type))) {
          sum += s.effectiveDurationHours;
        }
      }
      return double.parse(sum.toStringAsFixed(2));
    }
    return 0.0;
  }

  /// Computes total Meeting & other activity session hours.
  double get computedMeetingOtherHours {
    if (sessions.isNotEmpty) {
      double sum = 0.0;
      for (final s in sessions) {
        if (s.isCompleted && (s.isMeetingOrOther || _isMeetingOtherType(s.type))) {
          sum += s.effectiveDurationHours;
        }
      }
      return double.parse(sum.toStringAsFixed(2));
    }
    return 0.0;
  }

  /// Calculates shortfall against employee required working hours.
  /// Shortfall is strictly 0.0 when computedTotalHours >= requiredHours (No Overtime).
  double calculateShortfall([double requiredHours = 9.0]) {
    final req = requiredHours > 0 ? requiredHours : 9.0;
    final diff = req - computedTotalHours;
    return diff > 0 ? double.parse(diff.toStringAsFixed(2)) : 0.0;
  }

  /// Formats any double hours into readable string (e.g. "8hr 30min", "45min", "--").
  static String formatHours(double hours) {
    if (hours <= 0) return '--';
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h > 0 && m > 0) {
      return '${h}hr ${m}min';
    } else if (h > 0 && m == 0) {
      return '${h}hr';
    } else if (m > 0) {
      return '${m}min';
    }
    return '--';
  }

  String get formattedOfficeHours => formatHours(computedOfficeHours);
  String get formattedOdHours => formatHours(computedOdHours);
  String get formattedLunchHours => formatHours(computedLunchHours);
  String get formattedTeaBreakHours => formatHours(computedTeaBreakHours);
  String get formattedMeetingOtherHours => formatHours(computedMeetingOtherHours);

  String formattedShortfall([double requiredHours = 9.0]) {
    final sf = calculateShortfall(requiredHours);
    if (sf <= 0) return '0hr';
    return formatHours(sf);
  }

  String get formattedTotalHours {
    int totalSeconds = 0;
    if (sessions.isNotEmpty) {
      totalSeconds = sessions.fold<int>(0, (sum, s) {
        if (s.isCompleted) {
          if (s.durationMinutes > 0) {
            return sum + (s.durationMinutes * 60);
          } else if (s.effectiveDurationMinutes > 0) {
            return sum + (s.effectiveDurationMinutes * 60);
          }
        }
        return sum;
      });
    }

    if (totalSeconds == 0 && totalHours > 0) {
      totalSeconds = (totalHours * 3600).round();
    }

    if (totalSeconds == 0 && effectiveCheckInTime.isNotEmpty && checkOutTime.isNotEmpty) {
      final inMins = AttendanceSession.parseTimeToMinutes(effectiveCheckInTime);
      final outMins = AttendanceSession.parseTimeToMinutes(checkOutTime);
      if (inMins != null && outMins != null && outMins > inMins) {
        totalSeconds = (outMins - inMins) * 60;
      }
    }

    if (totalSeconds <= 0) return '--';

    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;

    if (h > 0 && m > 0) {
      return '${h}hr ${m}min';
    } else if (h > 0 && m == 0) {
      return '${h}hr';
    } else if (m > 0 && s > 0) {
      return '${m}m ${s}s';
    } else if (m > 0) {
      return '${m}min';
    } else if (s > 0) {
      return '${s}s';
    } else {
      return '--';
    }
  }


  AttendanceRecord copyWith({
    int? id,
    int? employeeId,
    String? employeeCode,
    String? employeeName,
    String? date,
    String? time,
    String? status,
    String? verificationStatus,
    double? similarityScore,
    String? checkInTime,
    String? checkOutTime,
    String? checkInVerificationStatus,
    String? checkOutVerificationStatus,
    double? checkInSimilarityScore,
    double? checkOutSimilarityScore,
    double? totalHours,
    String? notes,
    String? markedAt,
    List<AttendanceSession>? sessions,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeCode: employeeCode ?? this.employeeCode,
      employeeName: employeeName ?? this.employeeName,
      date: date ?? this.date,
      time: time ?? this.time,
      status: status ?? this.status,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      similarityScore: similarityScore ?? this.similarityScore,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      checkInVerificationStatus: checkInVerificationStatus ?? this.checkInVerificationStatus,
      checkOutVerificationStatus: checkOutVerificationStatus ?? this.checkOutVerificationStatus,
      checkInSimilarityScore: checkInSimilarityScore ?? this.checkInSimilarityScore,
      checkOutSimilarityScore: checkOutSimilarityScore ?? this.checkOutSimilarityScore,
      totalHours: totalHours ?? this.totalHours,
      notes: notes ?? this.notes,
      markedAt: markedAt ?? this.markedAt,
      sessions: sessions ?? this.sessions,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != 0) 'id': id,
        'employee_id': employeeId,
        if (employeeCode.isNotEmpty) 'employee_code': employeeCode,
        'employee_name': employeeName,
        'date': date,
        'time': effectiveCheckInTime,
        'status': status,
        'verification_status': effectiveCheckInVerification,
        'similarity_score': effectiveCheckInSimilarity,
        'check_in_time': effectiveCheckInTime,
        'check_out_time': checkOutTime,
        'check_in_verification_status': effectiveCheckInVerification,
        'check_out_verification_status': checkOutVerificationStatus,
        'check_in_similarity_score': effectiveCheckInSimilarity,
        'check_out_similarity_score': checkOutSimilarityScore,
        'total_hours': totalHours,
        'notes': notes,
        'marked_at': markedAt,
        if (sessions.isNotEmpty) 'sessions': sessions.map((s) => s.toMap()).toList(),
      };

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    final rawTime = map['time'] as String? ?? '';
    final rawCheckIn = map['check_in_time'] as String? ?? rawTime;
    final rawVer = map['verification_status'] as String? ?? 'Verified';
    final rawCheckInVer = map['check_in_verification_status'] as String? ?? rawVer;
    final rawScore = (map['similarity_score'] as num?)?.toDouble() ?? 0.0;
    final rawCheckInScore = (map['check_in_similarity_score'] as num?)?.toDouble() ?? rawScore;
    final rawEmpCode = (map['employee_code'] ?? (map['employee_id'] is String ? map['employee_id'] : ''))?.toString().trim() ?? '';
    final rawEmpId = map['employee_id'] is int
        ? map['employee_id'] as int
        : (int.tryParse(map['employee_id']?.toString() ?? '') ?? 0);

    final rawSessions = map['sessions'];
    final List<AttendanceSession> parsedSessions = (rawSessions is List)
        ? rawSessions
            .whereType<Map>()
            .map((s) => AttendanceSession.fromMap(Map<String, dynamic>.from(s)))
            .toList()
        : const [];

    return AttendanceRecord(
      id: map['id'] as int? ?? 0,
      employeeId: rawEmpId,
      employeeCode: rawEmpCode,
      employeeName: map['employee_name'] as String? ?? '',
      date: map['date'] as String? ?? '',
      time: rawTime.isNotEmpty ? rawTime : rawCheckIn,
      status: map['status'] as String? ?? 'Present',
      verificationStatus: rawVer,
      similarityScore: rawScore,
      checkInTime: rawCheckIn,
      checkOutTime: map['check_out_time'] as String? ?? '',
      checkInVerificationStatus: rawCheckInVer,
      checkOutVerificationStatus: map['check_out_verification_status'] as String? ?? '',
      checkInSimilarityScore: rawCheckInScore,
      checkOutSimilarityScore: (map['check_out_similarity_score'] as num?)?.toDouble() ?? 0.0,
      totalHours: (map['total_hours'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] as String? ?? '',
      markedAt: map['marked_at'] as String? ?? '',
      sessions: parsedSessions,
    );
  }
}

