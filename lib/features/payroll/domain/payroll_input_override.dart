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
  });
}

class UploadRowValidation {
  final int rowIndex;
  final String employeeIdRaw;
  final String employeeNameRaw;
  final bool isValid;
  final String? errorMessage;
  final PayrollInputOverride? overrideData;

  const UploadRowValidation({
    required this.rowIndex,
    required this.employeeIdRaw,
    required this.employeeNameRaw,
    required this.isValid,
    this.errorMessage,
    this.overrideData,
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

  const PayrollUploadValidationReport({
    required this.fileName,
    required this.totalRows,
    required this.validRows,
    required this.invalidRows,
    this.detectedEditableColumns = const [],
    this.detectedSystemColumns = const [],
  });
}

