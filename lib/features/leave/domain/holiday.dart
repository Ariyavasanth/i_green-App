class Holiday {
  final String id;
  final String title;
  final String date; // dd-MM-yyyy or yyyy-MM-dd
  final String type; // 'National Holiday', 'Festival', 'Company Holiday', 'Optional Holiday'
  final String description;
  final int year;
  final bool isActive;
  final String? createdAt;

  const Holiday({
    required this.id,
    required this.title,
    required this.date,
    this.type = 'National Holiday',
    this.description = '',
    required this.year,
    this.isActive = true,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'name': title, // compatibility
      'date': date,
      'type': type,
      'description': description,
      'year': year,
      'is_active': isActive,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
    };
  }

  factory Holiday.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawDate = map['date']?.toString() ?? '';
    final rawYear = map['year'];
    int parsedYear = DateTime.now().year;
    if (rawYear is int) {
      parsedYear = rawYear;
    } else if (rawDate.isNotEmpty) {
      final parts = rawDate.split('-');
      if (parts.length == 3) {
        if (parts[0].length == 4) {
          parsedYear = int.tryParse(parts[0]) ?? parsedYear;
        } else {
          parsedYear = int.tryParse(parts[2]) ?? parsedYear;
        }
      }
    }

    return Holiday(
      id: docId ?? map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: map['title']?.toString() ?? map['name']?.toString() ?? 'Holiday',
      date: rawDate,
      type: map['type']?.toString() ?? 'National Holiday',
      description: map['description']?.toString() ?? '',
      year: parsedYear,
      isActive: map['is_active'] as bool? ?? true,
      createdAt: map['created_at']?.toString(),
    );
  }

  Holiday copyWith({
    String? id,
    String? title,
    String? date,
    String? type,
    String? description,
    int? year,
    bool? isActive,
    String? createdAt,
  }) {
    return Holiday(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      type: type ?? this.type,
      description: description ?? this.description,
      year: year ?? this.year,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
