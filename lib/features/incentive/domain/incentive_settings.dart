class IncentiveSettings {
  final bool isLockActive;
  final String lockFromDate;
  final String lockToDate;

  const IncentiveSettings({
    this.isLockActive = false,
    this.lockFromDate = '',
    this.lockToDate = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': 1,
      'is_lock_active': isLockActive ? 1 : 0,
      'lock_from_date': lockFromDate,
      'lock_to_date': lockToDate,
    };
  }

  factory IncentiveSettings.fromMap(Map<String, dynamic> map) {
    return IncentiveSettings(
      isLockActive: (map['is_lock_active'] as int? ?? 0) == 1,
      lockFromDate: map['lock_from_date'] as String? ?? '',
      lockToDate: map['lock_to_date'] as String? ?? '',
    );
  }

  IncentiveSettings copyWith({
    bool? isLockActive,
    String? lockFromDate,
    String? lockToDate,
  }) {
    return IncentiveSettings(
      isLockActive: isLockActive ?? this.isLockActive,
      lockFromDate: lockFromDate ?? this.lockFromDate,
      lockToDate: lockToDate ?? this.lockToDate,
    );
  }
}
