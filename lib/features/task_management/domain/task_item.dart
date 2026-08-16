class TaskItem {
  final String id;
  final String title;
  final String projectOrOfficeCode;
  final String assignedBy;
  final String assignedTo;
  final DateTime startTime;
  final DateTime? endTime;
  final String status; // 'TODO', 'IN_PROGRESS', 'COMPLETED'

  const TaskItem({
    required this.id,
    required this.title,
    required this.projectOrOfficeCode,
    required this.assignedBy,
    required this.assignedTo,
    required this.startTime,
    this.endTime,
    this.status = 'TODO',
  });

  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  double get durationInHours => duration.inMinutes / 60.0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'project_or_office_code': projectOrOfficeCode,
      'assigned_by': assignedBy,
      'assigned_to': assignedTo,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'status': status,
    };
  }

  factory TaskItem.fromMap(Map<String, dynamic> map) {
    return TaskItem(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      projectOrOfficeCode: map['project_or_office_code'] as String? ?? 'GENERAL',
      assignedBy: map['assigned_by'] as String? ?? '',
      assignedTo: map['assigned_to'] as String? ?? '',
      startTime: map['start_time'] != null
          ? DateTime.tryParse(map['start_time'] as String) ?? DateTime.now()
          : DateTime.now(),
      endTime: map['end_time'] != null ? DateTime.tryParse(map['end_time'] as String) : null,
      status: map['status'] as String? ?? 'TODO',
    );
  }

  TaskItem copyWith({
    String? id,
    String? title,
    String? projectOrOfficeCode,
    String? assignedBy,
    String? assignedTo,
    DateTime? startTime,
    DateTime? endTime,
    String? status,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      projectOrOfficeCode: projectOrOfficeCode ?? this.projectOrOfficeCode,
      assignedBy: assignedBy ?? this.assignedBy,
      assignedTo: assignedTo ?? this.assignedTo,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
    );
  }
}
