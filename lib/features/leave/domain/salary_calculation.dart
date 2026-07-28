class SalaryCalculation {
  final double grossMonthlySalary;
  final int totalWorkingDays;
  final double perDaySalary;
  final double totalApprovedLeaveDays;
  final double totalLopDays;
  final double lopDeductionAmount;
  final double finalPayableSalary;

  const SalaryCalculation({
    required this.grossMonthlySalary,
    required this.totalWorkingDays,
    required this.perDaySalary,
    required this.totalApprovedLeaveDays,
    required this.totalLopDays,
    required this.lopDeductionAmount,
    required this.finalPayableSalary,
  });
}
