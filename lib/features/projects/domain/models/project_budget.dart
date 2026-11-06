import 'package:flutter/foundation.dart';

enum BudgetStatus {
  draft('Draft'),
  submitted('Submitted'),
  approved('Approved');

  const BudgetStatus(this.label);
  final String label;

  static BudgetStatus fromString(String? val) {
    if (val == null) return BudgetStatus.draft;
    final lower = val.toLowerCase();
    if (lower == 'approved') return BudgetStatus.approved;
    if (lower == 'submitted') return BudgetStatus.submitted;
    return BudgetStatus.draft;
  }
}

@immutable
class ProjectBudgetItem {
  const ProjectBudgetItem({
    required this.id,
    required this.category,
    required this.description,
    required this.allocatedAmount,
    this.percentageOfContract = 0.0,
    this.remarks = '',
  });

  final String id;
  final String category;
  final String description;
  final double allocatedAmount;
  final double percentageOfContract;
  final String remarks;

  factory ProjectBudgetItem.create({
    String? id,
    required String category,
    required String description,
    required double allocatedAmount,
    double contractValue = 0.0,
    String remarks = '',
  }) {
    final pct = contractValue > 0
        ? ((allocatedAmount / contractValue) * 10000).roundToDouble() / 100
        : 0.0;
    return ProjectBudgetItem(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      category: category.trim(),
      description: description.trim(),
      allocatedAmount: allocatedAmount,
      percentageOfContract: pct,
      remarks: remarks.trim(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'description': description,
        'allocated_amount': allocatedAmount,
        'percentage_of_contract': percentageOfContract,
        'remarks': remarks,
      };

  factory ProjectBudgetItem.fromJson(Map<String, dynamic> json) {
    return ProjectBudgetItem(
      id: json['id'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      description: json['description'] as String? ?? '',
      allocatedAmount: (json['allocated_amount'] as num?)?.toDouble() ?? 0.0,
      percentageOfContract:
          (json['percentage_of_contract'] as num?)?.toDouble() ?? 0.0,
      remarks: json['remarks'] as String? ?? '',
    );
  }

  ProjectBudgetItem copyWith({
    String? id,
    String? category,
    String? description,
    double? allocatedAmount,
    double? percentageOfContract,
    String? remarks,
  }) {
    return ProjectBudgetItem(
      id: id ?? this.id,
      category: category ?? this.category,
      description: description ?? this.description,
      allocatedAmount: allocatedAmount ?? this.allocatedAmount,
      percentageOfContract:
          percentageOfContract ?? this.percentageOfContract,
      remarks: remarks ?? this.remarks,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectBudgetItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          category == other.category &&
          description == other.description &&
          allocatedAmount == other.allocatedAmount &&
          percentageOfContract == other.percentageOfContract &&
          remarks == other.remarks;

  @override
  int get hashCode =>
      id.hashCode ^
      category.hashCode ^
      description.hashCode ^
      allocatedAmount.hashCode ^
      percentageOfContract.hashCode ^
      remarks.hashCode;
}

@immutable
class ProjectBudget {
  const ProjectBudget({
    this.status = BudgetStatus.draft,
    this.revision = 1,
    this.items = const [],
    this.createdAt,
    this.updatedAt,
    this.updatedBy,
    this.approvedBy,
    this.approvedAt,
    this.approvalNotes,
  });

  final BudgetStatus status;
  final int revision;
  final List<ProjectBudgetItem> items;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? updatedBy;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? approvalNotes;

  double get totalBudget =>
      items.fold(0.0, (acc, item) => acc + item.allocatedAmount);

  double budgetForCategory(String category) => items
      .where((i) => i.category.toLowerCase() == category.toLowerCase())
      .fold(0.0, (acc, item) => acc + item.allocatedAmount);

  double plannedProfit(double contractValue) => contractValue - totalBudget;

  double plannedMarginPercentage(double contractValue) {
    if (contractValue <= 0) return 0.0;
    final profit = plannedProfit(contractValue);
    return ((profit / contractValue) * 10000).roundToDouble() / 100;
  }

  Map<String, dynamic> toJson({double contractValue = 0.0}) => {
        'status': status.name,
        'revision': revision,
        'total_budget': totalBudget,
        'planned_profit': plannedProfit(contractValue),
        'planned_margin_percentage': plannedMarginPercentage(contractValue),
        'items': items.map((i) => i.toJson()).toList(),
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'updated_by': updatedBy,
        'approved_by': approvedBy,
        'approved_at': approvedAt?.toIso8601String(),
        'approval_notes': approvalNotes,
      };

  factory ProjectBudget.fromJson(Map<String, dynamic> json) {
    List<ProjectBudgetItem> parseItems(dynamic raw) {
      if (raw is List) {
        return raw
            .map((item) => ProjectBudgetItem.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList();
      }
      return const [];
    }

    DateTime? parseDate(dynamic v) {
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    return ProjectBudget(
      status: BudgetStatus.fromString(json['status'] as String?),
      revision: (json['revision'] as num?)?.toInt() ?? 1,
      items: parseItems(json['items']),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
      updatedBy: json['updated_by'] as String?,
      approvedBy: json['approved_by'] as String?,
      approvedAt: parseDate(json['approved_at']),
      approvalNotes: json['approval_notes'] as String?,
    );
  }

  ProjectBudget copyWith({
    BudgetStatus? status,
    int? revision,
    List<ProjectBudgetItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? updatedBy,
    String? approvedBy,
    DateTime? approvedAt,
    String? approvalNotes,
  }) {
    return ProjectBudget(
      status: status ?? this.status,
      revision: revision ?? this.revision,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      approvalNotes: approvalNotes ?? this.approvalNotes,
    );
  }
}
