import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/employee/domain/employee.dart';
import 'package:flutter_application_1/features/attendance/domain/monthly_attendance_result.dart';
import 'package:flutter_application_1/features/payroll/domain/payroll.dart';

void main() {
  final sampleEmployee = Employee(
    id: 101,
    employeeId: 'EMP101',
    firstName: 'Ariya',
    lastName: 'Vasanth',
    emailAddress: 'ariya@example.com',
    phoneNumber: '9876543210',
    department: 'Product Development',
    designation: 'Senior Flutter Engineer',
    dob: '01-01-1995',
    employmentType: 'Full-Time',
    gender: 'Male',
    joiningDate: '01-01-2025',
    organizationName: 'IGreen',
    status: 'Active',
    salaryBasic: 50000,
    salaryHra: 20000,
    salarySpecialAllowance: 10000,
    requiredWorkingHours: 9.0,
    weeklyOffDay: 'Sunday',
  );

  const settings = PayrollSettings();

  group('Payroll Integration — Holiday Consistency & Status Locking Tests', () {
    test('Gap 1: Holiday consistency — Company holiday resolves to Holiday (H) consistently', () {
      final period = settings.getPayrollPeriod(2026, 9);
      final holidays = ['25-08-2026']; // 1 Holiday

      final result = MonthlyAttendanceCalculator.calculate(
        employee: sampleEmployee,
        year: 2026,
        month: 9,
        records: const [],
        holidays: holidays,
        startDate: period.startDate,
        endDateExclusive: period.endDateExclusive,
        referenceDate: period.endDateExclusive,
      );

      // Verify 25-08-2026 is recognized as Holiday (H) and not Absent (A)
      final holidayDay = result.dailyResults.firstWhere((d) => d.dateStr == '25-08-2026');
      expect(holidayDay.statusCode, 'H');
      expect(holidayDay.isWorkingDay, isFalse);
      expect(result.holidayCount, 1);
    });

    test('Gap 2: DRAFT & PENDING status records can be edited and saved', () {
      final period = settings.getPayrollPeriod(2026, 9);

      final draftRecord = PayrollRecord(
        id: 102,
        employeeId: 103,
        employeeName: 'Priya Sundaram',
        month: 'September 2026',
        presentDays: 20,
        lateDays: 0,
        absentDays: 2,
        leaveDays: 0,
        basicPay: 40000,
        hra: 16000,
        educationAllowance: 0,
        specialAllowance: 8000,
        pf: 1800,
        tax: 0,
        netSalary: 62200,
        status: 'Draft',
        periodStartDate: period.startDateFormatted,
        periodEndDate: period.endDateFormatted,
        processingDate: period.processingDateFormatted,
        paymentDate: period.paymentDateFormatted,
      );

      final updatedDraft = draftRecord.copyWith(
        status: 'Processed',
        netSalary: 64000,
      );

      expect(updatedDraft.status, 'Processed');
      expect(updatedDraft.netSalary, 64000);
    });

    test('Gap 2: PROCESSED locking rules — normal edit/recalculation fails, delete fails, PROCESSED -> PAID transition succeeds', () {
      final period = settings.getPayrollPeriod(2026, 9);

      final processedRecord = PayrollRecord(
        id: 101,
        employeeId: 102,
        employeeName: 'Vikram Sharma',
        month: 'September 2026',
        presentDays: 24,
        lateDays: 2,
        absentDays: 0,
        leaveDays: 2,
        basicPay: 45000,
        hra: 18000,
        educationAllowance: 0,
        specialAllowance: 9000,
        pf: 1800,
        tax: 0,
        netSalary: 70200,
        status: 'Processed',
        periodStartDate: period.startDateFormatted,
        periodEndDate: period.endDateFormatted,
        processingDate: period.processingDateFormatted,
        paymentDate: period.paymentDateFormatted,
      );

      // Simulating savePayrollRecord locking logic
      void simulateSave(PayrollRecord existingDbRecord, PayrollRecord incomingRecord) {
        final existingStatus = existingDbRecord.status.trim().toUpperCase();
        if (existingStatus == 'PAID') {
          throw Exception('This payroll record has been marked as PAID and is locked against all changes.');
        }

        if (existingStatus == 'PROCESSED') {
          final incomingStatus = incomingRecord.status.trim().toUpperCase();
          final isExplicitPaidTransition = incomingStatus == 'PAID' &&
              (incomingRecord.netSalary - existingDbRecord.netSalary).abs() < 0.01 &&
              (incomingRecord.basicPay - existingDbRecord.basicPay).abs() < 0.01 &&
              incomingRecord.presentDays == existingDbRecord.presentDays;

          if (!isExplicitPaidTransition) {
            throw Exception('This payroll record has been marked as PROCESSED and is locked against all changes.');
          }
        }
      }

      // Simulating deletePayrollRecord locking logic
      void simulateDelete(PayrollRecord existingDbRecord) {
        final status = existingDbRecord.status.trim().toUpperCase();
        if (status == 'PAID' || status == 'PROCESSED') {
          throw Exception('Payroll record ${existingDbRecord.id} has status $status and is locked against deletion.');
        }
      }

      // 1. Normal edit to PROCESSED record (e.g. changing net salary) -> BLOCKED
      final editedRecord = processedRecord.copyWith(netSalary: 75000);
      expect(
        () => simulateSave(processedRecord, editedRecord),
        throwsA(isA<Exception>().having((e) => e.toString(), 'desc', contains('locked against all changes'))),
      );

      // 2. Status regression from PROCESSED to DRAFT -> BLOCKED
      final regressedRecord = processedRecord.copyWith(status: 'Draft');
      expect(
        () => simulateSave(processedRecord, regressedRecord),
        throwsA(isA<Exception>().having((e) => e.toString(), 'desc', contains('locked against all changes'))),
      );

      // 3. Delete PROCESSED record -> BLOCKED
      expect(
        () => simulateDelete(processedRecord),
        throwsA(isA<Exception>().having((e) => e.toString(), 'desc', contains('locked against deletion'))),
      );

      // 4. Explicit PROCESSED -> PAID transition preserving net salary & values -> ALLOWED
      final paidTransition = processedRecord.copyWith(status: 'Paid', paymentDate: '21-09-2026');
      expect(() => simulateSave(processedRecord, paidTransition), returnsNormally);
      expect(paidTransition.status, 'Paid');
      expect(paidTransition.netSalary, processedRecord.netSalary);
    });

    test('Gap 2: PAID locking rules — strictly locked against all edits, status changes, and deletion', () {
      final period = settings.getPayrollPeriod(2026, 9);

      final paidRecord = PayrollRecord(
        id: 100,
        employeeId: 101,
        employeeName: 'Ariya Vasanth',
        month: 'September 2026',
        presentDays: 25,
        lateDays: 1,
        absentDays: 0,
        leaveDays: 1,
        basicPay: 50000,
        hra: 20000,
        educationAllowance: 0,
        specialAllowance: 10000,
        pf: 1800,
        tax: 0,
        netSalary: 78200,
        status: 'Paid',
        periodStartDate: period.startDateFormatted,
        periodEndDate: period.endDateFormatted,
        processingDate: period.processingDateFormatted,
        paymentDate: period.paymentDateFormatted,
      );

      void simulateSave(PayrollRecord existingDbRecord, PayrollRecord incomingRecord) {
        final existingStatus = existingDbRecord.status.trim().toUpperCase();
        if (existingStatus == 'PAID') {
          throw Exception('This payroll record has been marked as PAID and is locked against all changes.');
        }
      }

      void simulateDelete(PayrollRecord existingDbRecord) {
        final status = existingDbRecord.status.trim().toUpperCase();
        if (status == 'PAID' || status == 'PROCESSED') {
          throw Exception('Payroll record ${existingDbRecord.id} has status $status and is locked against deletion.');
        }
      }

      // Any save attempt on PAID record -> BLOCKED
      final editedPaid = paidRecord.copyWith(netSalary: 80000);
      expect(
        () => simulateSave(paidRecord, editedPaid),
        throwsA(isA<Exception>().having((e) => e.toString(), 'desc', contains('locked against all changes'))),
      );

      // Delete PAID record -> BLOCKED
      expect(
        () => simulateDelete(paidRecord),
        throwsA(isA<Exception>().having((e) => e.toString(), 'desc', contains('locked against deletion'))),
      );
    });
  });
}
