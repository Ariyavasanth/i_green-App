class ProjectAuditLog {
  const ProjectAuditLog({
    required this.id,
    required this.projectId,
    required this.employeeId,
    required this.employeeName,
    required this.designation,
    required this.changeNote,
    required this.timestamp,
  });

  final String id;
  final String projectId;
  final String employeeId;
  final String employeeName;
  final String designation;
  final String changeNote;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'id': id,
        'project_id': projectId,
        'employee_id': employeeId,
        'employee_name': employeeName,
        'designation': designation,
        'change_note': changeNote,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ProjectAuditLog.fromJson(Map<String, dynamic> json, {String? docId}) {
    return ProjectAuditLog(
      id: docId ?? (json['id'] as String? ?? ''),
      projectId: json['project_id'] as String? ?? '',
      employeeId: json['employee_id'] as String? ?? '',
      employeeName: json['employee_name'] as String? ?? '',
      designation: json['designation'] as String? ?? '',
      changeNote: json['change_note'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

