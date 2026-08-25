import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../data/firebase_payroll_repository.dart';
import '../domain/payroll.dart';
import '../domain/payroll_repository.dart';

final payrollRepositoryProvider = Provider<PayrollRepository>(
  (ref) => FirebasePayrollRepository(),
);

final payrollSettingsProvider = FutureProvider<PayrollSettings>(
  (ref) => ref.watch(payrollRepositoryProvider).getPayrollSettings(),
);

final selectedPayrollMonthProvider = StateProvider<String>((ref) {
  // Format current date as Month Year, e.g. "August 2026"
  return DateFormat('MMMM yyyy').format(DateTime.now());
});

final payrollRecordsForMonthProvider = FutureProvider<List<PayrollRecord>>((ref) async {
  final month = ref.watch(selectedPayrollMonthProvider);
  return ref.watch(payrollRepositoryProvider).getPayrollRecordsForMonth(month);
});

final allPayrollRecordsProvider = FutureProvider<List<PayrollRecord>>((ref) {
  return ref.watch(payrollRepositoryProvider).getAllPayrollRecords();
});

final payrollRecordByIdProvider = FutureProvider.family<PayrollRecord?, int>((ref, id) {
  return ref.watch(payrollRepositoryProvider).getPayrollRecordById(id);
});

final payrollRecordForEmployeeProvider = FutureProvider.family<PayrollRecord?, ({int employeeId, String month})>((ref, arg) {
  return ref.watch(payrollRepositoryProvider).getPayrollRecordForEmployee(arg.employeeId, arg.month);
});

final employeePayrollRecordsProvider = FutureProvider.family<List<PayrollRecord>, int>((ref, employeeId) {
  return ref.watch(payrollRepositoryProvider).getPayrollRecordsForEmployee(employeeId);
});
