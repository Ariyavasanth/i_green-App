class AssetCategory {
  final int id;
  final String name;
  final String description;
  final String? createdAt;

  const AssetCategory({
    required this.id,
    required this.name,
    this.description = '',
    this.createdAt,
  });

  AssetCategory copyWith({
    int? id,
    String? name,
    String? description,
    String? createdAt,
  }) {
    return AssetCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_at': createdAt,
    };
  }

  factory AssetCategory.fromMap(Map<String, dynamic> map, [String? docId]) {
    int parsedId = 0;
    if (map['id'] != null) {
      parsedId = (map['id'] is int)
          ? map['id'] as int
          : int.tryParse(map['id'].toString()) ?? 0;
    } else if (docId != null) {
      parsedId = int.tryParse(docId.replaceAll(RegExp(r'\D'), '')) ?? 0;
    }

    return AssetCategory(
      id: parsedId,
      name: (map['name'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      createdAt: map['created_at'] as String?,
    );
  }
}
