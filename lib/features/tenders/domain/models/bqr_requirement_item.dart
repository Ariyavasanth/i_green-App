import '../../../projects/domain/models/project_document.dart';

class BqrRequirementItem {
  final String id;
  final String title;
  final String description;
  final String status; // 'pending' | 'uploaded'
  final List<ProjectDocument> documents;

  const BqrRequirementItem({
    required this.id,
    required this.title,
    this.description = '',
    this.status = 'pending',
    this.documents = const [],
  });

  bool get isUploaded => status == 'uploaded' || documents.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'status': status,
        'documents': documents.map((d) => d.toJson()).toList(),
      };

  factory BqrRequirementItem.fromJson(Map<String, dynamic> json) =>
      BqrRequirementItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
        documents: (json['documents'] as List<dynamic>?)
                ?.map((d) => ProjectDocument.fromJson(d as Map<String, dynamic>))
                .toList() ??
            const [],
      );

  BqrRequirementItem copyWith({
    String? id,
    String? title,
    String? description,
    String? status,
    List<ProjectDocument>? documents,
  }) =>
      BqrRequirementItem(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        status: status ?? this.status,
        documents: documents ?? this.documents,
      );
}

