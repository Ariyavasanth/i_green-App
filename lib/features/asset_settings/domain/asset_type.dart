class AssetType {
  const AssetType({
    required this.id,
    required this.name,
    this.description = '',
    this.category = 'Hardware',
    this.status = 'Active',
    this.createdAt,
  });

  final int id;
  final String name;
  final String description;
  final String category;
  final String status;
  final String? createdAt;

  AssetType copyWith({
    int? id,
    String? name,
    String? description,
    String? category,
    String? status,
    String? createdAt,
  }) {
    return AssetType(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'category': category,
        'status': status,
        'created_at': createdAt,
      };

  factory AssetType.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawId = map['id'];
    int idVal = 0;
    if (rawId is int) {
      idVal = rawId;
    } else if (rawId is num) {
      idVal = rawId.toInt();
    } else if (docId != null) {
      idVal = docId.hashCode & 0x7FFFFFFF;
    }

    return AssetType(
      id: idVal,
      name: (map['name'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      category: (map['category'] as String?) ?? 'Hardware',
      status: (map['status'] as String?) ?? 'Active',
      createdAt: map['created_at'] as String?,
    );
  }
}
