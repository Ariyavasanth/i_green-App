class OnDutyAssignment {
  const OnDutyAssignment({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    this.attendanceId,
    required this.fromLocation,
    this.fromLatitude,
    this.fromLongitude,
    required this.destination,
    this.destinationLatitude,
    this.destinationLongitude,
    required this.task,
    this.instructions = '',
    required this.assignedBy,
    required this.assignedTime,
    this.startedTime,
    this.completedTime,
    this.durationMinutes = 0,
    this.allowCheckoutFromDestination = false,
    this.photoProofPath,
    required this.status,
    required this.date,
    required this.createdAt,
  });

  final int id;
  final int employeeId;
  final String employeeName;
  final int? attendanceId;
  final String fromLocation;
  final double? fromLatitude;
  final double? fromLongitude;
  final String destination;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final String task;
  final String instructions;
  final String assignedBy;
  final String assignedTime;
  final String? startedTime;
  final String? completedTime;
  final int durationMinutes;
  final bool allowCheckoutFromDestination;
  final String? photoProofPath;
  final String status; // 'assigned', 'active', 'completed', 'requires_review', 'cancelled'
  final String date; // 'dd-MM-yyyy'
  final String createdAt;

  Map<String, dynamic> toMap() => {
        if (id != 0) 'id': id,
        'employee_id': employeeId,
        'employee_name': employeeName,
        'attendance_id': attendanceId,
        'from_location': fromLocation,
        'from_latitude': fromLatitude,
        'from_longitude': fromLongitude,
        'destination': destination,
        'destination_latitude': destinationLatitude,
        'destination_longitude': destinationLongitude,
        'task': task,
        'instructions': instructions,
        'assigned_by': assignedBy,
        'assigned_time': assignedTime,
        'started_time': startedTime,
        'completed_time': completedTime,
        'duration_minutes': durationMinutes,
        'allow_checkout_from_destination': allowCheckoutFromDestination ? 1 : 0,
        'photo_proof_path': photoProofPath,
        'status': status,
        'date': date,
        'created_at': createdAt,
      };

  factory OnDutyAssignment.fromMap(Map<String, dynamic> map) => OnDutyAssignment(
        id: map['id'] as int? ?? 0,
        employeeId: map['employee_id'] as int? ?? 0,
        employeeName: map['employee_name'] as String? ?? '',
        attendanceId: map['attendance_id'] as int?,
        fromLocation: map['from_location'] as String? ?? '',
        fromLatitude: (map['from_latitude'] as num?)?.toDouble(),
        fromLongitude: (map['from_longitude'] as num?)?.toDouble(),
        destination: map['destination'] as String? ?? '',
        destinationLatitude: (map['destination_latitude'] as num?)?.toDouble(),
        destinationLongitude: (map['destination_longitude'] as num?)?.toDouble(),
        task: map['task'] as String? ?? '',
        instructions: map['instructions'] as String? ?? '',
        assignedBy: map['assigned_by'] as String? ?? 'Supervisor',
        assignedTime: map['assigned_time'] as String? ?? '',
        startedTime: map['started_time'] as String?,
        completedTime: map['completed_time'] as String?,
        durationMinutes: map['duration_minutes'] as int? ?? 0,
        allowCheckoutFromDestination: (map['allow_checkout_from_destination'] as int? ?? 0) == 1 || (map['allow_checkout_from_destination'] as bool? ?? false),
        photoProofPath: map['photo_proof_path'] as String?,
        status: map['status'] as String? ?? 'assigned',
        date: map['date'] as String? ?? '',
        createdAt: map['created_at'] as String? ?? '',
      );

  OnDutyAssignment copyWith({
    int? id,
    int? employeeId,
    String? employeeName,
    int? attendanceId,
    String? fromLocation,
    double? fromLatitude,
    double? fromLongitude,
    String? destination,
    double? destinationLatitude,
    double? destinationLongitude,
    String? task,
    String? instructions,
    String? assignedBy,
    String? assignedTime,
    String? startedTime,
    String? completedTime,
    int? durationMinutes,
    bool? allowCheckoutFromDestination,
    String? photoProofPath,
    String? status,
    String? date,
    String? createdAt,
  }) {
    return OnDutyAssignment(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      attendanceId: attendanceId ?? this.attendanceId,
      fromLocation: fromLocation ?? this.fromLocation,
      fromLatitude: fromLatitude ?? this.fromLatitude,
      fromLongitude: fromLongitude ?? this.fromLongitude,
      destination: destination ?? this.destination,
      destinationLatitude: destinationLatitude ?? this.destinationLatitude,
      destinationLongitude: destinationLongitude ?? this.destinationLongitude,
      task: task ?? this.task,
      instructions: instructions ?? this.instructions,
      assignedBy: assignedBy ?? this.assignedBy,
      assignedTime: assignedTime ?? this.assignedTime,
      startedTime: startedTime ?? this.startedTime,
      completedTime: completedTime ?? this.completedTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      allowCheckoutFromDestination: allowCheckoutFromDestination ?? this.allowCheckoutFromDestination,
      photoProofPath: photoProofPath ?? this.photoProofPath,
      status: status ?? this.status,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
