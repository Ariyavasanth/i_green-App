import 'package:intl/intl.dart';
import 'attendance_session.dart';

String formatToLocal12HourTime(String timeStr, {bool forceSeconds = false}) {
  final trimmed = timeStr.trim();
  if (trimmed.isEmpty ||
      trimmed == '--:--' ||
      trimmed == '--:--:--' ||
      trimmed == '--' ||
      trimmed.toLowerCase() == 'active' ||
      trimmed.toLowerCase() == 'running') {
    return trimmed;
  }

  try {
    if (trimmed.contains('T')) {
      final dt = DateTime.tryParse(trimmed);
      if (dt != null) {
        return DateFormat(forceSeconds ? 'hh:mm:ss a' : 'hh:mm a').format(dt.toLocal());
      }
    }

    final formats = [
      'HH:mm:ss',
      'HH:mm',
      'hh:mm:ss a',
      'hh:mm a',
      'h:mm:ss a',
      'h:mm a',
      'H:m:s',
      'H:m',
    ];

    for (final fmt in formats) {
      try {
        final parsed = DateFormat(fmt).parse(trimmed);
        final hasSecondsInInput = trimmed.split(':').length >= 3 && !trimmed.contains(' ');
        final useSeconds = forceSeconds || hasSecondsInInput;
        final outFmt = useSeconds ? 'hh:mm:ss a' : 'hh:mm a';
        return DateFormat(outFmt).format(parsed);
      } catch (_) {}
    }
  } catch (_) {}

  return trimmed;
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
  String get formattedCheckInTime => formatToLocal12HourTime(effectiveCheckInTime);
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
  String get effectiveCheckInVerification =>
      checkInVerificationStatus.isNotEmpty ? checkInVerificationStatus : verificationStatus;
  double get effectiveCheckInSimilarity =>
      checkInSimilarityScore > 0 ? checkInSimilarityScore : similarityScore;
  bool get isMissingCheckOut => status == 'Missing Check-Out';
  bool get requiresCorrection =>
      isMissingCheckOut || (effectiveCheckInTime.isNotEmpty && checkOutTime.isEmpty && status != 'Absent' && status != 'On Leave');

  String get formattedTotalHours {
    int totalSeconds = 0;
    if (sessions.isNotEmpty) {
      totalSeconds = sessions.fold<int>(0, (sum, s) {
        if (s.durationMinutes > 0) {
          return sum + (s.durationMinutes * 60);
        }
        return sum;
      });
    }

    if (totalSeconds == 0 && totalHours > 0) {
      totalSeconds = (totalHours * 3600).round();
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

