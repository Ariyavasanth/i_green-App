import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/payroll/domain/payroll.dart';

void main() {
  group('Payroll Integration Step 2 — 20th-to-20th Payroll Period Tests', () {
    const settings = PayrollSettings();

    test('A, C, D. September 2026 Payroll Period (20 Aug 2026 -> 20 Sep 2026 exclusive, Process/Pay: 21 Sep 2026)', () {
      // For September 2026 (year: 2026, month: 9)
      final period = settings.getPayrollPeriod(2026, 9);

      // A. start = 20 Aug 2026, endExclusive = 20 Sep 2026
      expect(period.startDate, equals(DateTime(2026, 8, 20)));
      expect(period.endDateExclusive, equals(DateTime(2026, 9, 20)));

      // C & D. Processing date = 21 Sep 2026, Payment date = 21 Sep 2026
      expect(period.processingDate, equals(DateTime(2026, 9, 21)));
      expect(period.paymentDate, equals(DateTime(2026, 9, 21)));

      // Check formatted strings
      expect(period.startDateFormatted, equals('20-08-2026'));
      expect(period.endDateFormatted, equals('19-09-2026')); // Last inclusive day
      expect(period.processingDateFormatted, equals('21-09-2026'));
      expect(period.paymentDateFormatted, equals('21-09-2026'));
      expect(period.displayPeriodString, equals('20 Aug 2026 – 19 Sep 2026'));
    });

    test('B. Boundary behavior — 20 Aug included, 19 Sep included, 20 Sep excluded', () {
      final period = settings.getPayrollPeriod(2026, 9);

      final aug20 = DateTime(2026, 8, 20);
      final sep19 = DateTime(2026, 9, 19, 23, 59, 59);
      final sep20 = DateTime(2026, 9, 20, 0, 0, 0);

      // 20 Aug is at or after startDate
      expect(aug20.isAfter(period.startDate) || aug20.isAtSameMomentAs(period.startDate), isTrue);

      // 19 Sep 23:59:59 is strictly before endDateExclusive
      expect(sep19.isBefore(period.endDateExclusive), isTrue);

      // 20 Sep 00:00:00 is NOT before endDateExclusive (it equals endDateExclusive -> EXCLUDED)
      expect(sep20.isBefore(period.endDateExclusive), isFalse);
    });

    test('E. January / year-boundary case — January 2027 Payroll (20 Dec 2026 -> 20 Jan 2027 exclusive)', () {
      final period = settings.getPayrollPeriod(2027, 1);

      // startDate = 20 Dec 2026
      expect(period.startDate, equals(DateTime(2026, 12, 20)));

      // endDateExclusive = 20 Jan 2027
      expect(period.endDateExclusive, equals(DateTime(2027, 1, 20)));

      // Processing date = 21 Jan 2027
      expect(period.processingDate, equals(DateTime(2027, 1, 21)));

      // Payment date = 21 Jan 2027
      expect(period.paymentDate, equals(DateTime(2027, 1, 21)));

      expect(period.startDateFormatted, equals('20-12-2026'));
      expect(period.endDateFormatted, equals('19-01-2027'));
      expect(period.processingDateFormatted, equals('21-01-2027'));
      expect(period.paymentDateFormatted, equals('21-01-2027'));
      expect(period.displayPeriodString, equals('20 Dec 2026 – 19 Jan 2027'));
    });

    test('F. PayrollSettings defaults, serialization (toMap / fromMap), and copyWith', () {
      expect(settings.payrollStartDay, equals(20));
      expect(settings.payrollEndDay, equals(20));
      expect(settings.processingDay, equals(21));
      expect(settings.paymentDay, equals(21));
      expect(settings.payrollCutoffDay, equals(20));

      final map = settings.toMap();
      expect(map['payroll_start_day'], equals(20));
      expect(map['payroll_end_day'], equals(20));
      expect(map['processing_day'], equals(21));
      expect(map['payment_day'], equals(21));

      final restored = PayrollSettings.fromMap(map);
      expect(restored.payrollStartDay, equals(20));
      expect(restored.payrollEndDay, equals(20));
      expect(restored.processingDay, equals(21));
      expect(restored.paymentDay, equals(21));

      final copied = settings.copyWith(payrollStartDay: 20, payrollEndDay: 20);
      expect(copied.payrollStartDay, equals(20));
      expect(copied.payrollEndDay, equals(20));
    });
  });
}
