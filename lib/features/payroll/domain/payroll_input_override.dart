class PayrollInputOverride {
  final String employeeId; // Numeric string or code (e.g. "6" or "EMP6")
  final String? employeeName;

  // Standard Earnings Overrides
  final double? basic;
  final double? hra;
  final double? educationAllowance;
  final double? specialAllowance;
  final double? travelAllowance;
  final double? otherAllowance;

  // Monthly Additional Earnings
  final double? incentive;
  final double? othersEarning;
  final double? bonus;
  final double? ot;

  // Deductions Overrides
  final double? pf;
  final double? tax; // TDS
  final double? esi;
  final double? salaryAdvance;
  final double? othersDeduction;
  final double? staffWelfare;
  final double? companyLoan;

  const PayrollInputOverride({
    required this.employeeId,
    this.employeeName,
    this.basic,
    this.hra,
    this.educationAllowance,
    this.specialAllowance,
    this.travelAllowance,
    this.otherAllowance,
    this.incentive,
    this.othersEarning,
    this.bonus,
    this.ot,
    this.pf,
    this.tax,
    this.esi,
    this.salaryAdvance,
    this.othersDeduction,
    this.staffWelfare,
    this.companyLoan,
  });
}

class PayrollFieldChange {
  final String key;
  final String label;
  final double oldValue;
  final double newValue;

  const PayrollFieldChange({
    required this.key,
    required this.label,
    required this.oldValue,
    required this.newValue,
  });

  String get formattedOldValue => _formatCurrency(oldValue);
  String get formattedNewValue => _formatCurrency(newValue);

  static String _formatCurrency(double val) {
    if (val == val.roundToDouble()) {
      return '₹${val.toInt()}';
    }
    return '₹${val.toStringAsFixed(2)}';
  }
}

class UploadRowValidation {
  final int rowIndex;
  final String employeeIdRaw;
  final String employeeNameRaw;
  final String email;
  final String contactNumber;
  final String department;
  final String designation;
  final String joiningDate;
  final bool isValid;
  final String? errorMessage;
  final PayrollInputOverride? overrideData;
  final bool hasChanges;
  final List<PayrollFieldChange> changes;

  const UploadRowValidation({
    required this.rowIndex,
    required this.employeeIdRaw,
    required this.employeeNameRaw,
    this.email = '',
    this.contactNumber = '',
    this.department = '',
    this.designation = '',
    this.joiningDate = '',
    required this.isValid,
    this.errorMessage,
    this.overrideData,
    this.hasChanges = false,
    this.changes = const [],
  });
}

class PayrollUploadValidationReport {
  final String fileName;
  final int totalRows;
  final List<UploadRowValidation> validRows;
  final List<UploadRowValidation> invalidRows;
  final List<String> detectedEditableColumns;
  final List<String> detectedSystemColumns;

  bool get hasErrors => invalidRows.isNotEmpty;
  bool get hasValidRows => validRows.isNotEmpty;
  int get changedCount => validRows.where((r) => r.hasChanges).length;
  int get unchangedCount => validRows.where((r) => !r.hasChanges).length;
  List<UploadRowValidation> get changedValidRows => validRows.where((r) => r.hasChanges).toList();

  List<UploadRowValidation> get allRows {
    final list = [...validRows, ...invalidRows];
    list.sort((a, b) => a.rowIndex.compareTo(b.rowIndex));
    return list;
  }

  const PayrollUploadValidationReport({
    required this.fileName,
    required this.totalRows,
    required this.validRows,
    required this.invalidRows,
    this.detectedEditableColumns = const [],
    this.detectedSystemColumns = const [],
  });
}


