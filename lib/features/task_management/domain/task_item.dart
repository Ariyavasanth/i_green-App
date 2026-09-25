enum TaskPriority {
  low('LOW', 'Low (30 days)', Duration(days: 30), 720),
  medium('MEDIUM', 'Medium (15 days)', Duration(days: 15), 360),
  high('HIGH', 'High (8 hours)', Duration(hours: 8), 8),
  veryHigh('VERY_HIGH', 'Very High (3 hours)', Duration(hours: 3), 3);

  final String code;
  final String label;
  final Duration duration;
  final int slaHours;

  const TaskPriority(this.code, this.label, this.duration, this.slaHours);

  static TaskPriority fromString(String? val) {
    if (val == null) return TaskPriority.medium;
    final normalized = val.toUpperCase().replaceAll(' ', '_');
    for (final p in TaskPriority.values) {
      if (p.code == normalized || p.name.toUpperCase() == normalized) {
        return p;
      }
    }
    return TaskPriority.medium;
  }
}

class TaskItem {
  final String id;
  final String title;
  final String projectOrOfficeCode;
  final String assignedBy;
  final String assignedTo;
  final DateTime createdAt;
  final DateTime startTime;
  final DateTime? endTime;
  final String status; // 'TODO', 'IN_PROGRESS', 'COMPLETED'
  final String priority; // 'LOW', 'MEDIUM', 'HIGH', 'VERY_HIGH'
  final int slaDurationHours;
  final DateTime deadline;
  final bool? breached;
  final String? completionDescription;
  final String? completionPhotoUrl;
  final bool isPaused;
  final int accumulatedSeconds;
  final DateTime? lastResumedAt;

  TaskItem({
    required this.id,
    required this.title,
    required this.projectOrOfficeCode,
    required this.assignedBy,
    required this.assignedTo,
    DateTime? createdAt,
    DateTime? startTime,
    this.endTime,
    this.status = 'TODO',
    this.priority = 'MEDIUM',
    int? slaDurationHours,
    DateTime? deadline,
    this.breached,
    this.completionDescription,
    this.completionPhotoUrl,
    this.isPaused = false,
    this.accumulatedSeconds = 0,
    this.lastResumedAt,
  })  : createdAt = createdAt ?? startTime ?? DateTime.now(),
        startTime = startTime ?? createdAt ?? DateTime.now(),
        slaDurationHours = slaDurationHours ?? TaskPriority.fromString(priority).slaHours,
        deadline = deadline ??
            (createdAt ?? startTime ?? DateTime.now()).add(
              Duration(hours: slaDurationHours ?? TaskPriority.fromString(priority).slaHours),
            );

  TaskPriority get priorityEnum => TaskPriority.fromString(priority);

  Duration get duration {
    final baseDuration = Duration(seconds: accumulatedSeconds);
    if (status == 'COMPLETED') {
      if (accumulatedSeconds > 0) return baseDuration;
      final end = endTime ?? DateTime.now();
      return end.difference(startTime);
    }
    if (isPaused) {
      return baseDuration;
    }
    if (status == 'IN_PROGRESS') {
      final resumeRef = lastResumedAt ?? startTime;
      final runningDiff = DateTime.now().difference(resumeRef);
      return baseDuration + (runningDiff.isNegative ? Duration.zero : runningDiff);
    }
    return Duration.zero;
  }

  double get durationInHours => duration.inMinutes / 60.0;

  String get formattedDuration {
    final dur = duration;
    final hours = dur.inHours;
    final mins = dur.inMinutes.remainder(60);
    final secs = dur.inSeconds.remainder(60);
    if (hours > 0 && mins > 0) {
      return '$hours hr $mins min';
    } else if (hours > 0) {
      return '$hours hr${hours > 1 ? 's' : ''}';
    } else if (mins > 0) {
      return '$mins min';
    } else {
      return '$secs s';
    }
  }

  bool get isBreached {
    if (status == 'COMPLETED') {
      final effectiveEnd = endTime ?? DateTime.now();
      return effectiveEnd.isAfter(deadline);
    }
    return DateTime.now().isAfter(deadline);
  }

  Duration get breachDuration {
    if (!isBreached) return Duration.zero;
    final compareTime = (status == 'COMPLETED' && endTime != null) ? endTime! : DateTime.now();
    return compareTime.difference(deadline);
  }

  String get formattedBreachDuration {
    final diff = breachDuration;
    if (diff <= Duration.zero) return '';
    final days = diff.inDays;
    final hours = diff.inHours.remainder(24);
    final mins = diff.inMinutes.remainder(60);
    if (days > 0) {
      return '$days d ${hours > 0 ? '$hours hr' : ''}'.trim();
    } else if (diff.inHours > 0) {
      return '$hours hr ${mins > 0 ? '$mins min' : ''}'.trim();
    } else {
      return '$mins min';
    }
  }

  Duration get remainingSlaDuration {
    if (isBreached || status == 'COMPLETED') return Duration.zero;
    return deadline.difference(DateTime.now());
  }

  String get formattedRemainingSla {
    final rem = remainingSlaDuration;
    if (rem <= Duration.zero) return '0 min';
    final days = rem.inDays;
    final hours = rem.inHours.remainder(24);
    final mins = rem.inMinutes.remainder(60);
    if (days > 0) {
      return '$days d ${hours > 0 ? '$hours hr' : ''}'.trim();
    } else if (rem.inHours > 0) {
      return '$hours hr ${mins > 0 ? '$mins min' : ''}'.trim();
    } else {
      return '$mins min';
    }
  }

  DateTime get assignedAt => createdAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'project_or_office_code': projectOrOfficeCode,
      'assigned_by': assignedBy,
      'assigned_to': assignedTo,
      'created_at': createdAt.toIso8601String(),
      'assigned_at': createdAt.toIso8601String(),
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'status': status,
      'priority': priority,
      'sla_duration_hours': slaDurationHours,
      'deadline': deadline.toIso8601String(),
      'breached': isBreached,
      'completion_description': completionDescription,
      'completion_photo_url': completionPhotoUrl,
      'is_paused': isPaused,
      'accumulated_seconds': accumulatedSeconds,
      'last_resumed_at': lastResumedAt?.toIso8601String(),
    };
  }

  factory TaskItem.fromMap(Map<String, dynamic> map) {
    final created = map['assigned_at'] != null
        ? DateTime.tryParse(map['assigned_at'].toString()) ?? DateTime.now()
        : (map['created_at'] != null
            ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
            : (map['start_time'] != null
                ? DateTime.tryParse(map['start_time'].toString()) ?? DateTime.now()
                : DateTime.now()));

    final priorityStr = map['priority'] as String? ?? 'MEDIUM';
    final priorityObj = TaskPriority.fromString(priorityStr);
    final slaHours = (map['sla_duration_hours'] as num?)?.toInt() ?? priorityObj.slaHours;

    DateTime calculatedDeadline;
    if (map['deadline'] != null) {
      calculatedDeadline = DateTime.tryParse(map['deadline'].toString()) ?? created.add(Duration(hours: slaHours));
    } else {
      calculatedDeadline = created.add(Duration(hours: slaHours));
    }

    return TaskItem(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      projectOrOfficeCode: map['project_or_office_code'] as String? ?? 'GENERAL',
      assignedBy: map['assigned_by'] as String? ?? '',
      assignedTo: map['assigned_to'] as String? ?? '',
      createdAt: created,
      startTime: map['start_time'] != null
          ? DateTime.tryParse(map['start_time'].toString()) ?? created
          : created,
      endTime: map['end_time'] != null ? DateTime.tryParse(map['end_time'].toString()) : null,
      status: map['status'] as String? ?? 'TODO',
      priority: priorityStr,
      slaDurationHours: slaHours,
      deadline: calculatedDeadline,
      breached: map['breached'] as bool?,
      completionDescription: map['completion_description'] as String?,
      completionPhotoUrl: map['completion_photo_url'] as String?,
      isPaused: map['is_paused'] as bool? ?? false,
      accumulatedSeconds: (map['accumulated_seconds'] as num?)?.toInt() ?? 0,
      lastResumedAt: map['last_resumed_at'] != null
          ? DateTime.tryParse(map['last_resumed_at'].toString())
          : null,
    );
  }

  TaskItem copyWith({
    String? id,
    String? title,
    String? projectOrOfficeCode,
    String? assignedBy,
    String? assignedTo,
    DateTime? createdAt,
    DateTime? startTime,
    DateTime? endTime,
    String? status,
    String? priority,
    int? slaDurationHours,
    DateTime? deadline,
    bool? breached,
    String? completionDescription,
    String? completionPhotoUrl,
    bool? isPaused,
    int? accumulatedSeconds,
    DateTime? lastResumedAt,
  }) {
    final effectivePriority = priority ?? this.priority;
    final effectiveSla = slaDurationHours ??
        (priority != null ? TaskPriority.fromString(priority).slaHours : this.slaDurationHours);
    final effectiveCreated = createdAt ?? this.createdAt;
    final effectiveDeadline = deadline ??
        (priority != null || createdAt != null || slaDurationHours != null
            ? effectiveCreated.add(Duration(hours: effectiveSla))
            : this.deadline);

    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      projectOrOfficeCode: projectOrOfficeCode ?? this.projectOrOfficeCode,
      assignedBy: assignedBy ?? this.assignedBy,
      assignedTo: assignedTo ?? this.assignedTo,
      createdAt: effectiveCreated,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      priority: effectivePriority,
      slaDurationHours: effectiveSla,
      deadline: effectiveDeadline,
      breached: breached ?? this.breached,
      completionDescription: completionDescription ?? this.completionDescription,
      completionPhotoUrl: completionPhotoUrl ?? this.completionPhotoUrl,
      isPaused: isPaused ?? this.isPaused,
      accumulatedSeconds: accumulatedSeconds ?? this.accumulatedSeconds,
      lastResumedAt: lastResumedAt ?? this.lastResumedAt,
    );
  }
}
