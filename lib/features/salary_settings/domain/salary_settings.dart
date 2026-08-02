class SalarySettings {
  final double hraPercentage;
  final double specialAllowancePercentage;
  final double educationAllowancePercentage;
  final double travelAllowancePercentage;
  final double pfPercentage;
  final double taxPercentage;
  final double professionalTaxPercentage;

  const SalarySettings({
    this.hraPercentage = 25.0,
    this.specialAllowancePercentage = 25.0,
    this.educationAllowancePercentage = 0.0,
    this.travelAllowancePercentage = 0.0,
    this.pfPercentage = 12.0,
    this.taxPercentage = 0.0,
    this.professionalTaxPercentage = 0.0,
  });

  Map<String, dynamic> toMap() => {
        'hra_percentage': hraPercentage,
        'special_allowance_percentage': specialAllowancePercentage,
        'education_allowance_percentage': educationAllowancePercentage,
        'travel_allowance_percentage': travelAllowancePercentage,
        'pf_percentage': pfPercentage,
        'tax_percentage': taxPercentage,
        'professional_tax_percentage': professionalTaxPercentage,
      };

  factory SalarySettings.fromMap(Map<String, dynamic> map) {
    return SalarySettings(
      hraPercentage: (map['hra_percentage'] as num?)?.toDouble() ?? 25.0,
      specialAllowancePercentage:
          (map['special_allowance_percentage'] as num?)?.toDouble() ?? 25.0,
      educationAllowancePercentage:
          (map['education_allowance_percentage'] as num?)?.toDouble() ?? 0.0,
      travelAllowancePercentage:
          (map['travel_allowance_percentage'] as num?)?.toDouble() ?? 0.0,
      pfPercentage: (map['pf_percentage'] as num?)?.toDouble() ?? 12.0,
      taxPercentage: (map['tax_percentage'] as num?)?.toDouble() ?? 0.0,
      professionalTaxPercentage:
          (map['professional_tax_percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  SalarySettings copyWith({
    double? hraPercentage,
    double? specialAllowancePercentage,
    double? educationAllowancePercentage,
    double? travelAllowancePercentage,
    double? pfPercentage,
    double? taxPercentage,
    double? professionalTaxPercentage,
  }) {
    return SalarySettings(
      hraPercentage: hraPercentage ?? this.hraPercentage,
      specialAllowancePercentage:
          specialAllowancePercentage ?? this.specialAllowancePercentage,
      educationAllowancePercentage:
          educationAllowancePercentage ?? this.educationAllowancePercentage,
      travelAllowancePercentage:
          travelAllowancePercentage ?? this.travelAllowancePercentage,
      pfPercentage: pfPercentage ?? this.pfPercentage,
      taxPercentage: taxPercentage ?? this.taxPercentage,
      professionalTaxPercentage:
          professionalTaxPercentage ?? this.professionalTaxPercentage,
    );
  }
}
