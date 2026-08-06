class LeaveType {
  final int id;
  final String name;
  final String description;
  final double annualAllocation;
  final String carryForward;
  final String colorHex;
  final bool isActive;

  const LeaveType({
    required this.id,
    required this.name,
    required this.description,
    this.annualAllocation = 12.0,
    this.carryForward = 'Not allowed',
    this.colorHex = '#6366F1',
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
        if (id != 0) 'id': id,
        'name': name,
        'description': description,
        'annual_allocation': annualAllocation,
        'carry_forward': carryForward,
        'color_hex': colorHex,
        'is_active': isActive ? 1 : 0,
      };

  factory LeaveType.fromMap(Map<String, dynamic> map) => LeaveType(
        id: map['id'] as int? ?? 0,
        name: map['name'] as String? ?? '',
        description: map['description'] as String? ?? '',
        annualAllocation: (map['annual_allocation'] as num?)?.toDouble() ?? 12.0,
        carryForward: map['carry_forward'] as String? ?? 'Not allowed',
        colorHex: map['color_hex'] as String? ?? '#6366F1',
        isActive: map['is_active'] is bool
            ? map['is_active'] as bool
            : (map['is_active'] as int? ?? 1) == 1,
      );

  LeaveType copyWith({
    int? id,
    String? name,
    String? description,
    double? annualAllocation,
    String? carryForward,
    String? colorHex,
    bool? isActive,
  }) {
    return LeaveType(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      annualAllocation: annualAllocation ?? this.annualAllocation,
      carryForward: carryForward ?? this.carryForward,
      colorHex: colorHex ?? this.colorHex,
      isActive: isActive ?? this.isActive,
    );
  }
}
