class LeaveType {
  final int id;
  final String name;
  final String description;

  const LeaveType({
    required this.id,
    required this.name,
    required this.description,
  });

  Map<String, dynamic> toMap() => {
        if (id != 0) 'id': id,
        'name': name,
        'description': description,
      };

  factory LeaveType.fromMap(Map<String, dynamic> map) => LeaveType(
        id: map['id'] as int? ?? 0,
        name: map['name'] as String? ?? '',
        description: map['description'] as String? ?? '',
      );
}
