class OrganizationBand implements Comparable<OrganizationBand> {
  const OrganizationBand({
    required this.id,
    this.organizationId = '',
    this.organizationName = '',
    required this.level,
    required this.bandCode,
    required this.title,
    this.description = '',
    this.colorHex,
    this.designationCount = 0,
  });

  final String id;
  final String organizationId;
  final String organizationName;
  final int level; // 1 (Entry level) to 7 (Highest / Managing Director)
  final String bandCode; // e.g. "Band 7", "Band 1"
  final String title; // e.g. "Executive Leadership", "Entry Level"
  final String description; // optional role/scope description
  final int? colorHex; // optional display color integer (e.g. 0xFF9CC70A)
  final int
  designationCount; // Number of designations currently assigned to this band

  OrganizationBand copyWith({
    String? id,
    String? organizationId,
    String? organizationName,
    int? level,
    String? bandCode,
    String? title,
    String? description,
    int? colorHex,
    int? designationCount,
  }) {
    return OrganizationBand(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      organizationName: organizationName ?? this.organizationName,
      level: level ?? this.level,
      bandCode: bandCode ?? this.bandCode,
      title: title ?? this.title,
      description: description ?? this.description,
      colorHex: colorHex ?? this.colorHex,
      designationCount: designationCount ?? this.designationCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      if (organizationName.isNotEmpty) 'organization_name': organizationName,
      'level': level,
      'band_code': bandCode,
      'title': title,
      if (description.isNotEmpty) 'description': description,
      if (colorHex != null) 'color_hex': colorHex,
      if (designationCount > 0) 'designation_count': designationCount,
    };
  }

  factory OrganizationBand.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawId = map['id']?.toString() ?? docId ?? '';
    return OrganizationBand(
      id: rawId,
      organizationId:
          map['organization_id']?.toString() ??
          map['organizationId']?.toString() ??
          map['org_id']?.toString() ??
          '',
      organizationName:
          map['organization_name']?.toString() ??
          map['organizationName']?.toString() ??
          '',
      level: (map['level'] as num?)?.toInt() ?? 0,
      bandCode:
          map['band_code']?.toString() ?? map['bandCode']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      colorHex:
          (map['color_hex'] as num?)?.toInt() ??
          (map['colorHex'] as num?)?.toInt(),
      designationCount:
          (map['designation_count'] as num?)?.toInt() ??
          (map['designationCount'] as num?)?.toInt() ??
          0,
    );
  }

  @override
  int compareTo(OrganizationBand other) {
    // Highest level first: Band 7 down to Band 1
    return other.level.compareTo(level);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrganizationBand &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          organizationId == other.organizationId &&
          level == other.level &&
          bandCode == other.bandCode;

  @override
  int get hashCode => Object.hash(id, organizationId, level, bandCode);

  @override
  String toString() =>
      'OrganizationBand(id: $id, orgId: $organizationId, level: $level, code: $bandCode, title: $title)';
}
