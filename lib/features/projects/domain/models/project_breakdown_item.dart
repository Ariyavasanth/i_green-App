import 'package:flutter/foundation.dart';

enum BreakdownItemType {
  material('Material / Supply'),
  service('Service / Work');

  const BreakdownItemType(this.label);
  final String label;

  static BreakdownItemType fromString(String? value) {
    if (value == null) return BreakdownItemType.material;
    final lower = value.toLowerCase();
    if (lower.contains('service') || lower.contains('work')) {
      return BreakdownItemType.service;
    }
    return BreakdownItemType.material;
  }
}

@immutable
class ProjectBreakdownItem {
  const ProjectBreakdownItem({
    required this.id,
    required this.description,
    required this.unit,
    required this.quantity,
    required this.rate,
    required this.amount,
    this.type = BreakdownItemType.material,
    this.remarks = '',
  });

  final String id;
  final String description;
  final String unit;
  final double quantity;
  final double rate;
  final double amount;
  final BreakdownItemType type;
  final String remarks;

  factory ProjectBreakdownItem.create({
    String? id,
    required String description,
    required String unit,
    required double quantity,
    required double rate,
    BreakdownItemType type = BreakdownItemType.material,
    String remarks = '',
  }) {
    final computedAmount = (quantity * rate * 100).roundToDouble() / 100;
    return ProjectBreakdownItem(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      description: description.trim(),
      unit: unit.trim(),
      quantity: quantity,
      rate: rate,
      amount: computedAmount,
      type: type,
      remarks: remarks.trim(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'unit': unit,
        'quantity': quantity,
        'rate': rate,
        'amount': amount,
        'type': type.name,
        'remarks': remarks,
      };

  factory ProjectBreakdownItem.fromJson(Map<String, dynamic> json) {
    final qty = (json['quantity'] as num?)?.toDouble() ?? 0.0;
    final rate = (json['rate'] as num?)?.toDouble() ?? 0.0;
    final storedAmount = (json['amount'] as num?)?.toDouble();
    final computedAmount = storedAmount ?? ((qty * rate * 100).roundToDouble() / 100);

    return ProjectBreakdownItem(
      id: json['id'] as String? ?? '',
      description: json['description'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      quantity: qty,
      rate: rate,
      amount: computedAmount,
      type: BreakdownItemType.fromString(json['type'] as String?),
      remarks: json['remarks'] as String? ?? '',
    );
  }

  ProjectBreakdownItem copyWith({
    String? id,
    String? description,
    String? unit,
    double? quantity,
    double? rate,
    double? amount,
    BreakdownItemType? type,
    String? remarks,
  }) {
    final newQty = quantity ?? this.quantity;
    final newRate = rate ?? this.rate;
    return ProjectBreakdownItem(
      id: id ?? this.id,
      description: description ?? this.description,
      unit: unit ?? this.unit,
      quantity: newQty,
      rate: newRate,
      amount: amount ?? ((newQty * newRate * 100).roundToDouble() / 100),
      type: type ?? this.type,
      remarks: remarks ?? this.remarks,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectBreakdownItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          description == other.description &&
          unit == other.unit &&
          quantity == other.quantity &&
          rate == other.rate &&
          amount == other.amount &&
          type == other.type &&
          remarks == other.remarks;

  @override
  int get hashCode =>
      id.hashCode ^
      description.hashCode ^
      unit.hashCode ^
      quantity.hashCode ^
      rate.hashCode ^
      amount.hashCode ^
      type.hashCode ^
      remarks.hashCode;
}

