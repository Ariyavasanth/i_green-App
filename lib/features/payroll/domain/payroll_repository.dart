import 'payroll.dart';

abstract class PayrollRepository {
  Future<List<PayrollRecord>> getPayrollRecordsForMonth(String month);
  Future<List<PayrollRecord>> getAllPayrollRecords();
  Future<PayrollRecord?> getPayrollRecordById(int id);
  Future<PayrollRecord?> getPayrollRecordForEmployee(int employeeId, String month);
  Future<List<PayrollRecord>> getPayrollRecordsForEmployee(int employeeId);
  Future<PayrollRecord> savePayrollRecord(PayrollRecord record);
  Future<void> deletePayrollRecord(int id);
  Future<PayrollSettings> getPayrollSettings();
  Future<void> savePayrollSettings(PayrollSettings settings);
}
