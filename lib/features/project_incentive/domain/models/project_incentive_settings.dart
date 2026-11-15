class ProjectIncentiveSettings {
  final double baseRatePerUnit; // e.g. ₹50 per metre done
  final double timelyBillBonusPercentage; // e.g. 10% bonus if billed on time
  final double delayedBillPenaltyPercentage; // e.g. 15% deduction if bill delayed
  final double minCollectionThresholdPct; // e.g. 70% minimum collection for full release
  final bool autoDisqualifyOnIncident; // Automatically disqualify when an incident is logged
  final bool trackRestorationCostSeparately; // Keep restoration cost distinct from incentive ledger
  final double targetCompletionBonusPct; // Bonus if project delivered before target completion date

  const ProjectIncentiveSettings({
    this.baseRatePerUnit = 50.0,
    this.timelyBillBonusPercentage = 10.0,
    this.delayedBillPenaltyPercentage = 15.0,
    this.minCollectionThresholdPct = 80.0,
    this.autoDisqualifyOnIncident = true,
    this.trackRestorationCostSeparately = true,
    this.targetCompletionBonusPct = 5.0,
  });

  Map<String, dynamic> toJson() => {
        'base_rate_per_unit': baseRatePerUnit,
        'timely_bill_bonus_percentage': timelyBillBonusPercentage,
        'delayed_bill_penalty_percentage': delayedBillPenaltyPercentage,
        'min_collection_threshold_pct': minCollectionThresholdPct,
        'auto_disqualify_on_incident': autoDisqualifyOnIncident,
        'track_restoration_cost_separately': trackRestorationCostSeparately,
        'target_completion_bonus_pct': targetCompletionBonusPct,
      };

  factory ProjectIncentiveSettings.fromJson(Map<String, dynamic> json) =>
      ProjectIncentiveSettings(
        baseRatePerUnit: (json['base_rate_per_unit'] as num?)?.toDouble() ?? 50.0,
        timelyBillBonusPercentage:
            (json['timely_bill_bonus_percentage'] as num?)?.toDouble() ?? 10.0,
        delayedBillPenaltyPercentage:
            (json['delayed_bill_penalty_percentage'] as num?)?.toDouble() ?? 15.0,
        minCollectionThresholdPct:
            (json['min_collection_threshold_pct'] as num?)?.toDouble() ?? 80.0,
        autoDisqualifyOnIncident: json['auto_disqualify_on_incident'] as bool? ?? true,
        trackRestorationCostSeparately:
            json['track_restoration_cost_separately'] as bool? ?? true,
        targetCompletionBonusPct:
            (json['target_completion_bonus_pct'] as num?)?.toDouble() ?? 5.0,
      );

  ProjectIncentiveSettings copyWith({
    double? baseRatePerUnit,
    double? timelyBillBonusPercentage,
    double? delayedBillPenaltyPercentage,
    double? minCollectionThresholdPct,
    bool? autoDisqualifyOnIncident,
    bool? trackRestorationCostSeparately,
    double? targetCompletionBonusPct,
  }) {
    return ProjectIncentiveSettings(
      baseRatePerUnit: baseRatePerUnit ?? this.baseRatePerUnit,
      timelyBillBonusPercentage:
          timelyBillBonusPercentage ?? this.timelyBillBonusPercentage,
      delayedBillPenaltyPercentage:
          delayedBillPenaltyPercentage ?? this.delayedBillPenaltyPercentage,
      minCollectionThresholdPct:
          minCollectionThresholdPct ?? this.minCollectionThresholdPct,
      autoDisqualifyOnIncident:
          autoDisqualifyOnIncident ?? this.autoDisqualifyOnIncident,
      trackRestorationCostSeparately:
          trackRestorationCostSeparately ?? this.trackRestorationCostSeparately,
      targetCompletionBonusPct:
          targetCompletionBonusPct ?? this.targetCompletionBonusPct,
    );
  }
}
