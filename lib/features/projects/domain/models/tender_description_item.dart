class TenderDescriptionItem {
  const TenderDescriptionItem({
    required this.description,
    required this.unit,
    required this.quantity,
    required this.rate,
    required this.amount,
  });

  final String description;
  final String unit;
  final double quantity;
  final double rate;
  final double amount;

  Map<String, dynamic> toJson() => {
        'description': description,
        'unit': unit,
        'quantity': quantity,
        'rate': rate,
        'amount': amount,
      };

  factory TenderDescriptionItem.fromJson(Map<String, dynamic> json) =>
      TenderDescriptionItem(
        description: json['description'] as String? ?? '',
        unit: json['unit'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
        rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      );

  TenderDescriptionItem copyWith({
    String? description,
    String? unit,
    double? quantity,
    double? rate,
    double? amount,
  }) {
    return TenderDescriptionItem(
      description: description ?? this.description,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      amount: amount ?? this.amount,
    );
  }
}

