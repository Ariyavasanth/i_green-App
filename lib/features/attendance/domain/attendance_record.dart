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

  String get effectiveCheckInTime => checkInTime.isNotEmpty ? checkInTime : time;
  String get effectiveCheckInVerification =>
      checkInVerificationStatus.isNotEmpty ? checkInVerificationStatus : verificationStatus;
  double get effectiveCheckInSimilarity =>
      checkInSimilarityScore > 0 ? checkInSimilarityScore : similarityScore;
  bool get isMissingCheckOut => status == 'Missing Check-Out';
  bool get requiresCorrection =>
      isMissingCheckOut || (effectiveCheckInTime.isNotEmpty && checkOutTime.isEmpty && status != 'Absent' && status != 'On Leave');


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
    );
  }
}
