import '../../employee/domain/employee.dart';

/// Represents a single node in the organizational reporting structure.
class HierarchyNode {
  HierarchyNode({
    required this.employee,
    this.bandLevel = 0,
    this.bandCode = '',
    this.bandTitle = '',
    this.bandColorHex,
    List<HierarchyNode>? children,
    this.hasCycle = false,
    this.isMissingManager = false,
    this.missingManagerId,
    this.missingManagerName,
    this.depth = 0,
  }) : children = children ?? [];

  final Employee employee;
  final int bandLevel;
  final String bandCode;
  final String bandTitle;
  final int? bandColorHex;
  final List<HierarchyNode> children;
  final bool hasCycle;
  final bool isMissingManager;
  final String? missingManagerId;
  final String? missingManagerName;
  int depth;

  /// Whether this node represents a Band 7 top leadership authority.
  bool get isBand7 => bandLevel == 7;

  /// Whether this node has a valid assigned band.
  bool get hasBand => bandLevel > 0;

  /// Direct reports count.
  int get directReportsCount => children.length;

  /// Total count of all subordinate employees beneath this node recursively.
  int get totalSubordinatesCount {
    int count = children.length;
    for (final child in children) {
      count += child.totalSubordinatesCount;
    }
    return count;
  }

  /// Checks if any descendant node matches the search query.
  bool matchesOrHasDescendantMatch(String query) {
    if (matchesQuery(query)) return true;
    for (final child in children) {
      if (child.matchesOrHasDescendantMatch(query)) return true;
    }
    return false;
  }

  /// Checks if this specific node matches the search query.
  bool matchesQuery(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return false;

    if (employee.fullName.toLowerCase().contains(q)) return true;
    if (employee.employeeId.toLowerCase().contains(q)) return true;
    if (employee.designation.toLowerCase().contains(q)) return true;
    if (employee.department.toLowerCase().contains(q)) return true;
    if (bandCode.toLowerCase().contains(q)) return true;
    if (bandTitle.toLowerCase().contains(q)) return true;

    return false;
  }

  HierarchyNode copyWith({
    Employee? employee,
    int? bandLevel,
    String? bandCode,
    String? bandTitle,
    int? bandColorHex,
    List<HierarchyNode>? children,
    bool? hasCycle,
    bool? isMissingManager,
    String? missingManagerId,
    String? missingManagerName,
    int? depth,
  }) {
    return HierarchyNode(
      employee: employee ?? this.employee,
      bandLevel: bandLevel ?? this.bandLevel,
      bandCode: bandCode ?? this.bandCode,
      bandTitle: bandTitle ?? this.bandTitle,
      bandColorHex: bandColorHex ?? this.bandColorHex,
      children: children ?? List.from(this.children),
      hasCycle: hasCycle ?? this.hasCycle,
      isMissingManager: isMissingManager ?? this.isMissingManager,
      missingManagerId: missingManagerId ?? this.missingManagerId,
      missingManagerName: missingManagerName ?? this.missingManagerName,
      depth: depth ?? this.depth,
    );
  }
}
