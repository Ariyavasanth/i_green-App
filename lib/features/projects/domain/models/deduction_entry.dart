class DeductionEntry {
  const DeductionEntry({
    required this.deductionId,
    required this.deductionType,
    required this.deductionAmount,
  });

  final String deductionId;
  final String deductionType;
  final double deductionAmount;

  Map<String, dynamic> toJson() => {
        'deduction_id': deductionId,
        'deduction_type': deductionType,
        'deduction_amount': deductionAmount,
      };

  factory DeductionEntry.fromJson(Map<String, dynamic> json) => DeductionEntry(
        deductionId: json['deduction_id'] as String? ?? '',
        deductionType: json['deduction_type'] as String? ?? '',
        deductionAmount:
            (json['deduction_amount'] as num?)?.toDouble() ?? 0.0,
      );

  DeductionEntry copyWith({
    String? deductionId,
    String? deductionType,
    double? deductionAmount,
  }) {
    return DeductionEntry(
      deductionId: deductionId ?? this.deductionId,
      deductionType: deductionType ?? this.deductionType,
      deductionAmount: deductionAmount ?? this.deductionAmount,
    );
  }
}

