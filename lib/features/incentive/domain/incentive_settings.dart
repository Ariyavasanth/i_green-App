class IncentiveSettings {
  final bool isLockActive;
  final String lockFromDate;
  final String lockToDate;
  final bool is3TableRuleEnabled;
  final double immediatePercentage;
  final double deferredPercentage;
  final int releaseIntervalCycles;
  final List<String> releaseCycles;

  const IncentiveSettings({
    this.isLockActive = false,
    this.lockFromDate = '',
    this.lockToDate = '',
    this.is3TableRuleEnabled = true,
    this.immediatePercentage = 50.0,
    this.deferredPercentage = 50.0,
    this.releaseIntervalCycles = 3,
    this.releaseCycles = const [],
  });

  bool isReleaseCycle(String cycleMonth, {int? monthNum, int? cycleIndex}) {
    if (!is3TableRuleEnabled) return false;
    final norm = cycleMonth.trim().toLowerCase();
    if (releaseCycles.isNotEmpty) {
      return releaseCycles.any((c) => c.trim().toLowerCase() == norm);
    }
    if (cycleIndex != null && releaseIntervalCycles > 0) {
      return cycleIndex % releaseIntervalCycles == 0;
    }
    if (monthNum != null && releaseIntervalCycles > 0) {
      return monthNum % releaseIntervalCycles == 0;
    }
    return false;
  }


  Map<String, dynamic> toMap() {
    return {
      'id': 1,
      'is_lock_active': isLockActive ? 1 : 0,
      'lock_from_date': lockFromDate,
      'lock_to_date': lockToDate,
      'is_3_table_rule_enabled': is3TableRuleEnabled,
      'immediate_percentage': immediatePercentage,
      'deferred_percentage': deferredPercentage,
      'release_interval_cycles': releaseIntervalCycles,
      'release_cycles': releaseCycles,
    };
  }

  factory IncentiveSettings.fromMap(Map<String, dynamic> map) {
    final rawCycles = map['release_cycles'];
    List<String> parsedCycles = [];
    if (rawCycles is List) {
      parsedCycles = rawCycles.map((e) => e.toString()).toList();
    }
    return IncentiveSettings(
      isLockActive: (map['is_lock_active'] as int? ?? (map['is_lock_active'] == true ? 1 : 0)) == 1,
      lockFromDate: map['lock_from_date'] as String? ?? '',
      lockToDate: map['lock_to_date'] as String? ?? '',
      is3TableRuleEnabled: map['is_3_table_rule_enabled'] as bool? ?? true,
      immediatePercentage: (map['immediate_percentage'] as num?)?.toDouble() ?? 50.0,
      deferredPercentage: (map['deferred_percentage'] as num?)?.toDouble() ?? 50.0,
      releaseIntervalCycles: (map['release_interval_cycles'] as num?)?.toInt() ?? 3,
      releaseCycles: parsedCycles,
    );
  }

  IncentiveSettings copyWith({
    bool? isLockActive,
    String? lockFromDate,
    String? lockToDate,
    bool? is3TableRuleEnabled,
    double? immediatePercentage,
    double? deferredPercentage,
    int? releaseIntervalCycles,
    List<String>? releaseCycles,
  }) {
    return IncentiveSettings(
      isLockActive: isLockActive ?? this.isLockActive,
      lockFromDate: lockFromDate ?? this.lockFromDate,
      lockToDate: lockToDate ?? this.lockToDate,
      is3TableRuleEnabled: is3TableRuleEnabled ?? this.is3TableRuleEnabled,
      immediatePercentage: immediatePercentage ?? this.immediatePercentage,
      deferredPercentage: deferredPercentage ?? this.deferredPercentage,
      releaseIntervalCycles: releaseIntervalCycles ?? this.releaseIntervalCycles,
      releaseCycles: releaseCycles ?? this.releaseCycles,
    );
  }
}

