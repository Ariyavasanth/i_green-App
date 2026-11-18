import '../../../core/utils/time_formatter.dart';
import 'attendance_session.dart';
export 'attendance_session.dart';

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
    this.requiredHours = 0.0,
    this.scheduledInTime = '',
    this.scheduledOutTime = '',
    this.notes = '',
    this.markedAt = '',
    this.sessions = const [],
    this.locationInterruptions = const [],
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
  final double requiredHours;
  final String scheduledInTime;
  final String scheduledOutTime;
  final String notes;
  final String markedAt;
  final List<AttendanceSession> sessions;
  final List<Map<String, dynamic>> locationInterruptions;

  String get effectiveCheckInTime => checkInTime.isNotEmpty ? checkInTime : time;
  String get formattedCheckInTime => TimeFormatter.formatToLocal12HourTime(effectiveCheckInTime);
  String get formattedCheckOutTime => TimeFormatter.formatToLocal12HourTime(checkOutTime);

  /// Returns the sessions list, or synthesizes a default office session from
  /// effectiveCheckInTime and checkOutTime if [sessions] is empty.
  List<AttendanceSession> get effectiveSessions {
    if (sessions.isNotEmpty) return sessions;
    if (effectiveCheckInTime.isNotEmpty) {
      final durMin = (totalHours > 0)
          ? (totalHours * 60).round()
          : (checkOutTime.isNotEmpty
              ? ((TimeFormatter.calculateElapsedSeconds(effectiveCheckInTime, checkOutTime) ?? 0) ~/ 60)
              : 0);
      return [
        AttendanceSession(
          id: 'session_1',
          type: 'office',
          checkInTime: effectiveCheckInTime,
          checkOutTime: checkOutTime,
          durationHours: totalHours,
          durationMinutes: durMin,
        ),
      ];
    }
    return const [];
  }

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

  /// Computes exact non-overlapping work duration in seconds across all completed
  /// sessions (Office, OD, Lunch Break, Tea Break, Meeting, etc.) by merging
  /// overlapping [start, end] intervals.
  static int calculateNonOverlappingDurationSeconds(List<AttendanceSession> sessions) {
    final List<({int start, int end})> intervals = [];
    int fallbackSeconds = 0;

    for (final s in sessions) {
      if (!s.isCompleted && s.durationMinutes <= 0 && s.durationHours <= 0) continue;

      final startSec = s.checkInTime.isNotEmpty
          ? TimeFormatter.parseTimeToSeconds(s.checkInTime)
          : null;
      final endSec = s.checkOutTime.isNotEmpty
          ? TimeFormatter.parseTimeToSeconds(s.checkOutTime)
          : null;

      if (startSec != null && endSec != null) {
        int adjustedEnd = endSec;
        if (adjustedEnd < startSec) {
          adjustedEnd += 86400; // Overnight wrap-around
        }
        final rawElapsed = adjustedEnd - startSec;
        if (s.durationMinutes > 0 && (rawElapsed - s.durationMinutes * 60).abs() >= 60) {
          // Preserve explicit stored durationMinutes when timestamps have legacy AM/PM discrepancy
          adjustedEnd = startSec + (s.durationMinutes * 60);
        }
        if (adjustedEnd > startSec) {
          intervals.add((start: startSec, end: adjustedEnd));
        }
      } else if (s.isCompleted || s.durationMinutes > 0 || s.durationHours > 0) {
        // Legacy completed session without parseable timestamps
        fallbackSeconds += s.effectiveDurationSeconds;
      }
    }

    if (intervals.isEmpty) return fallbackSeconds;

    intervals.sort((a, b) {
      final cmp = a.start.compareTo(b.start);
      return cmp != 0 ? cmp : a.end.compareTo(b.end);
    });

    int mergedTotalSeconds = 0;
    int curStart = intervals.first.start;
    int curEnd = intervals.first.end;

    for (int i = 1; i < intervals.length; i++) {
      final next = intervals[i];
      if (next.start <= curEnd) {
        if (next.end > curEnd) curEnd = next.end;
      } else {
        mergedTotalSeconds += (curEnd - curStart);
        curStart = next.start;
        curEnd = next.end;
      }
    }
    mergedTotalSeconds += (curEnd - curStart);

    return mergedTotalSeconds + fallbackSeconds;
  }

  /// Computes exact non-overlapping work duration in hours (rounded to 2 decimals).
  static double calculateNonOverlappingDurationHours(List<AttendanceSession> sessions) {
    final secs = calculateNonOverlappingDurationSeconds(sessions);
    if (secs <= 0) return 0.0;
    return double.parse((secs / 3600.0).toStringAsFixed(2));
  }

  /// Returns true if any two completed sessions overlap in time (historical data check).
  bool get hasOverlappingSessions {
    final List<({int start, int end})> intervals = [];
    for (final s in effectiveSessions) {
      if (!s.isCompleted) continue;
      final startSec = TimeFormatter.parseTimeToSeconds(s.checkInTime);
      final endSec = TimeFormatter.parseTimeToSeconds(s.checkOutTime);
      if (startSec == null || endSec == null) continue;
      final adjustedEnd = endSec < startSec ? endSec + 86400 : endSec;
      if (adjustedEnd > startSec) {
        intervals.add((start: startSec, end: adjustedEnd));
      }
    }
    if (intervals.length < 2) return false;
    intervals.sort((a, b) => a.start.compareTo(b.start));
    for (int i = 1; i < intervals.length; i++) {
      if (intervals[i].start < intervals[i - 1].end) return true;
    }
    return false;
  }

  /// Flags historical records containing an auto-synced OD session with an
  /// unverified start time (e.g., legacy '08:00 AM' fallback) for admin review.
  bool get hasUnverifiedOdStartTime {
    return effectiveSessions.any((s) {
      if (!s.isOd) return false;
      final isAutoSynced = s.checkInMethod.trim().toLowerCase() == 'od auto sync';
      if (!isAutoSynced) return false;
      if (s.checkInTime.trim().isEmpty) return true;
      final normalized = TimeFormatter.formatTo24HourTime(s.checkInTime);
      return normalized == '08:00:00' && hasOverlappingSessions;
    });
  }

  /// Read-only flag indicating this record should be reviewed by an admin.
  bool get requiresAdminTimeReview => hasOverlappingSessions || hasUnverifiedOdStartTime;

  /// Computes the total working hours by merging all valid completed sessions
  /// (Office, OD, Lunch Break, Tea Break, Meeting, and other activity sessions)
  /// without double-counting overlapping time intervals.
  /// Falls back to top-level check-in and check-out difference if sessions list is empty.
  double get computedTotalHours {
    if (sessions.isNotEmpty) {
      final mergedHours = calculateNonOverlappingDurationHours(sessions);
      if (mergedHours > 0) {
        return mergedHours;
      }
    }

    if (totalHours > 0) return totalHours;

    if (effectiveCheckInTime.isNotEmpty && checkOutTime.isNotEmpty) {
      final inMins = AttendanceSession.parseTimeToMinutes(effectiveCheckInTime);
      final outMins = AttendanceSession.parseTimeToMinutes(checkOutTime);
      if (inMins != null && outMins != null) {
        int diff = outMins - inMins;
        if (diff < 0) {
          diff += 1440; // 24 hours wrap-around for overnight work session
        }
        return double.parse((diff / 60.0).toStringAsFixed(2));
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

  /// Calculates overtime in minutes past (shiftOutTime + bufferMinutes).
  /// E.g. shift ends at 7:00 PM, buffer is 30 mins -> OT begins at 7:30 PM.
  /// If checkout is at 8:10 PM -> OT = 40 minutes.
  /// If checkout is at 9:15 PM -> OT = 105 minutes (1 hr 45 min).
  int calculateOvertimeMinutes({String? shiftOutTime, int bufferMinutes = 30}) {
    final effectiveShiftOut = (shiftOutTime != null && shiftOutTime.trim().isNotEmpty)
        ? shiftOutTime
        : (scheduledOutTime.trim().isNotEmpty ? scheduledOutTime : '07:00 PM');
    final shiftOutMins = TimeFormatter.parseTimeToMinutes(effectiveShiftOut) ?? 1140;
    final otStartMins = shiftOutMins + bufferMinutes;

    int? outMins;
    if (checkOutTime.trim().isNotEmpty) {
      outMins = TimeFormatter.parseTimeToMinutes(checkOutTime);
    } else if (effectiveCheckInTime.trim().isNotEmpty && sessions.any((s) => s.isActive)) {
      final now = DateTime.now();
      outMins = now.hour * 60 + now.minute;
    }

    if (outMins != null && outMins > otStartMins) {
      return outMins - otStartMins;
    }
    return 0;
  }

  /// Calculates overtime in hours past (shiftOutTime + bufferMinutes).
  double calculateOvertimeHours({String? shiftOutTime, int bufferMinutes = 30}) {
    final mins = calculateOvertimeMinutes(shiftOutTime: shiftOutTime, bufferMinutes: bufferMinutes);
    if (mins <= 0) return 0.0;
    return double.parse((mins / 60.0).toStringAsFixed(2));
  }

  /// Checks whether the employee has met the minimum required OT duration (e.g. 60 mins / 1 hour).
  bool hasMetMinOvertimeThreshold({
    String? shiftOutTime,
    int bufferMinutes = 30,
    int minOtMinutes = 60,
  }) {
    return calculateOvertimeMinutes(shiftOutTime: shiftOutTime, bufferMinutes: bufferMinutes) >= minOtMinutes;
  }

  /// Formatted overtime string (e.g. "1hr 45min", "40min", "0hr").
  String formattedOvertimeHours({String? shiftOutTime, int bufferMinutes = 30}) {
    final mins = calculateOvertimeMinutes(shiftOutTime: shiftOutTime, bufferMinutes: bufferMinutes);
    if (mins <= 0) return '0hr';
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h > 0 && m > 0) {
      return '${h}hr ${m}min';
    } else if (h > 0 && m == 0) {
      return '${h}hr';
    } else {
      return '${m}min';
    }
  }

  String get formattedTotalHours {
    int totalSeconds = 0;
    if (sessions.isNotEmpty) {
      totalSeconds = calculateNonOverlappingDurationSeconds(sessions);
    }

    if (totalSeconds == 0 && totalHours > 0) {
      totalSeconds = (totalHours * 3600).round();
    }

    if (totalSeconds == 0 && effectiveCheckInTime.isNotEmpty && checkOutTime.isNotEmpty) {
      final inMins = AttendanceSession.parseTimeToMinutes(effectiveCheckInTime);
      final outMins = AttendanceSession.parseTimeToMinutes(checkOutTime);
      if (inMins != null && outMins != null) {
        int diff = outMins - inMins;
        if (diff < 0) {
          diff += 1440;
        }
        totalSeconds = diff * 60;
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

  /// Computes total non-overlapping work duration in seconds across all completed sessions,
  /// falling back to totalHours or checkIn/checkOut difference.
  int get totalWorkDurationSeconds {
    int totalSeconds = 0;
    final list = effectiveSessions;
    if (list.isNotEmpty) {
      totalSeconds = calculateNonOverlappingDurationSeconds(list);
    }

    if (totalSeconds == 0 && totalHours > 0) {
      totalSeconds = (totalHours * 3600).round();
    }

    if (totalSeconds == 0 && effectiveCheckInTime.isNotEmpty && checkOutTime.isNotEmpty) {
      final elapsed = TimeFormatter.calculateElapsedSeconds(effectiveCheckInTime, checkOutTime);
      if (elapsed != null && elapsed > 0) {
        totalSeconds = elapsed;
      }
    }

    return totalSeconds;
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
    double? requiredHours,
    String? scheduledInTime,
    String? scheduledOutTime,
    String? notes,
    String? markedAt,
    List<AttendanceSession>? sessions,
    List<Map<String, dynamic>>? locationInterruptions,
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
      requiredHours: requiredHours ?? this.requiredHours,
      scheduledInTime: scheduledInTime ?? this.scheduledInTime,
      scheduledOutTime: scheduledOutTime ?? this.scheduledOutTime,
      notes: notes ?? this.notes,
      markedAt: markedAt ?? this.markedAt,
      sessions: sessions ?? this.sessions,
      locationInterruptions: locationInterruptions ?? this.locationInterruptions,
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
        if (requiredHours > 0) 'required_hours': requiredHours,
        if (scheduledInTime.isNotEmpty) 'scheduled_in_time': scheduledInTime,
        if (scheduledOutTime.isNotEmpty) 'scheduled_out_time': scheduledOutTime,
        'notes': notes,
        'marked_at': markedAt,
        if (sessions.isNotEmpty) 'sessions': sessions.map((s) => s.toMap()).toList(),
        if (locationInterruptions.isNotEmpty) 'location_interruptions': locationInterruptions,
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
    final rawReqHours = (map['required_hours'] ?? map['requiredHours'] as num?)?.toDouble() ?? 0.0;
    final rawSchedIn = (map['scheduled_in_time'] ?? map['scheduledInTime'] ?? map['in_time'] ?? map['inTime'] ?? '').toString().trim();
    final rawSchedOut = (map['scheduled_out_time'] ?? map['scheduledOutTime'] ?? map['out_time'] ?? map['outTime'] ?? '').toString().trim();

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
      requiredHours: rawReqHours,
      scheduledInTime: rawSchedIn,
      scheduledOutTime: rawSchedOut,
      notes: map['notes'] as String? ?? '',
      markedAt: map['marked_at'] as String? ?? '',
      sessions: parsedSessions,
      locationInterruptions: (map['location_interruptions'] is List)
          ? (map['location_interruptions'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : const [],
    );
  }
}

