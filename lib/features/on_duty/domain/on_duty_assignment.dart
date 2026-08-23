class OnDutyAssignment {
  const OnDutyAssignment({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.odType,
    required this.purpose,
    required this.destination,
    required this.date,
    required this.plannedStartTime,
    this.plannedEndTime,
    this.actualStartTime,
    this.actualEndTime,
    this.startLatitude,
    this.startLongitude,
    this.endLatitude,
    this.endLongitude,
    this.startPhoto,
    this.endPhoto,
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
  final String status; // 'ASSIGNED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'
  final String notes;
  final String assignedBy;
  final int durationMinutes;
  final String afterCompletionOption; // 'RETURN_TO_OFFICE', 'CHECKOUT_FROM_OD'
  final String createdAt;

  Map<String, dynamic> toMap() => {
        if (id != 0) 'id': id,
        'employee_id': employeeId,
        'employee_name': employeeName,
        'od_type': odType,
        'purpose': purpose,
        'destination': destination,
        'date': date,
        'planned_start_time': plannedStartTime,
        'planned_end_time': plannedEndTime,
        'actual_start_time': actualStartTime,
        'actual_end_time': actualEndTime,
        'start_latitude': startLatitude,
        'start_longitude': startLongitude,
        'end_latitude': endLatitude,
        'end_longitude': endLongitude,
        'start_photo': startPhoto,
        'end_photo': endPhoto,
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

    return OnDutyAssignment(
      id: parseId(map['id']),
      employeeId: parseId(map['employee_id']),
      employeeName: map['employee_name']?.toString() ?? '',
      odType: map['od_type']?.toString() ?? map['task']?.toString() ?? 'Customer Visit',
      purpose: map['purpose']?.toString() ?? map['task']?.toString() ?? '',
      destination: map['destination']?.toString() ?? map['destination_location']?.toString() ?? map['from_location']?.toString() ?? '',
      date: map['date']?.toString() ?? '',
      plannedStartTime: map['planned_start_time']?.toString() ?? map['assigned_time']?.toString() ?? '',
      plannedEndTime: map['planned_end_time']?.toString(),
      actualStartTime: map['actual_start_time']?.toString() ?? map['started_time']?.toString(),
      actualEndTime: map['actual_end_time']?.toString() ?? map['completed_time']?.toString(),
      startLatitude: (map['start_latitude'] as num?)?.toDouble() ?? (map['from_latitude'] as num?)?.toDouble(),
      startLongitude: (map['start_longitude'] as num?)?.toDouble() ?? (map['from_longitude'] as num?)?.toDouble(),
      endLatitude: (map['end_latitude'] as num?)?.toDouble() ?? (map['destination_latitude'] as num?)?.toDouble(),
      endLongitude: (map['end_longitude'] as num?)?.toDouble() ?? (map['destination_longitude'] as num?)?.toDouble(),
      startPhoto: map['start_photo']?.toString(),
      endPhoto: map['end_photo']?.toString() ?? map['photo_proof_path']?.toString(),
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
      status: status ?? this.status,
      notes: notes ?? this.notes,
      assignedBy: assignedBy ?? this.assignedBy,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      afterCompletionOption: afterCompletionOption ?? this.afterCompletionOption,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
