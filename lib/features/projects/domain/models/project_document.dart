class ProjectDocument {
  const ProjectDocument({
    required this.name,
    required this.size,
    this.downloadUrl = '',
    this.localPath = '',
    this.category = '',
    required this.uploadedAt,
  });

  final String name;
  final int size;
  final String downloadUrl;
  final String localPath;
  final String category;
  final DateTime uploadedAt;

  Map<String, dynamic> toJson() => {
        'name': name,
        'size': size,
        'download_url': downloadUrl,
        'local_path': localPath,
        'category': category,
        'uploaded_at': uploadedAt.toIso8601String(),
      };

  factory ProjectDocument.fromJson(Map<String, dynamic> json) =>
      ProjectDocument(
        name: json['name'] as String? ?? '',
        size: (json['size'] as num?)?.toInt() ?? 0,
        downloadUrl: json['download_url'] as String? ?? '',
        localPath: json['local_path'] as String? ?? '',
        category: json['category'] as String? ?? '',
        uploadedAt: json['uploaded_at'] != null
            ? DateTime.tryParse(json['uploaded_at'].toString()) ??
                DateTime.now()
            : DateTime.now(),
      );

  ProjectDocument copyWith({
    String? name,
    int? size,
    String? downloadUrl,
    String? localPath,
    String? category,
    DateTime? uploadedAt,
  }) {
    return ProjectDocument(
      name: name ?? this.name,
      size: size ?? this.size,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      localPath: localPath ?? this.localPath,
      category: category ?? this.category,
      uploadedAt: uploadedAt ?? this.uploadedAt,
    );
  }
}
