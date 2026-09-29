import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/permission/domain/permission_policy.dart';
import 'package:flutter_application_1/features/permission/domain/permission_balance.dart';
import 'package:flutter_application_1/features/permission/domain/permission_request.dart';
import 'package:flutter_application_1/features/permission/domain/permission_enums.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_record.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_status_helper.dart';
import 'package:flutter_application_1/features/attendance/domain/monthly_attendance_result.dart';
import 'package:flutter_application_1/features/employee/domain/employee.dart';

void main() {
  group('Permission Allowance & Consecutive Rules Policy Tests', () {
    test('1. Policy Defaults: Daily limit is 2 hours, Monthly limit is 6 hours', () {
      const policy = PermissionPolicy();
      expect(policy.dailyLimitHours, 2.0);
      expect(policy.monthlyLimitHours, 6.0);

      final map = policy.toMap();
      expect(map['daily_limit_hours'], 2.0);
      expect(map['monthly_limit_hours'], 6.0);

      final restored = PermissionPolicy.fromMap({});
      expect(restored.dailyLimitHours, 2.0);
      expect(restored.monthlyLimitHours, 6.0);
    });

    test('2. Automatic 2-Hour Daily Quota Exhaustion per permission applied', () {
      final now = DateTime(2026, 9, 10);
      const policy = PermissionPolicy(dailyLimitHours: 2.0, monthlyLimitHours: 6.0);
      final dailyLimitMins = (policy.dailyLimitHours * 60).round(); // 120
      final monthlyLimitMins = (policy.monthlyLimitHours * 60).round(); // 360

      // Employee applied for only 15 minutes of permission on Sep 1st
      final requests = [
        PermissionRequest(
          id: 1,
          employeeId: 101,
          employeeName: 'John Doe',
          employeeCode: 'EMP-101',
          department: 'Engineering',
          date: DateTime(2026, 9, 1),
          fromTime: '09:00',
          toTime: '09:15',
          durationMinutes: 15, // Only 15 mins requested
          permissionType: PermissionType.lateArrival,
          reason: 'Traffic delay',
          status: PermissionStatus.approved,
          submittedAt: DateTime(2026, 9, 1, 8, 30),
        ),
      ];

      // Evaluation of balance: 1 day with permission exhausts full 2h daily allowance (120m)
      final activeDaysInMonth = requests
          .where((r) => r.status != PermissionStatus.rejected && r.status != PermissionStatus.cancelled)
          .map((r) => r.date.toIso8601String().split('T').first)
          .toSet();

      final monthUsed = activeDaysInMonth.length * dailyLimitMins;
      final balance = PermissionBalance(
        employeeId: 101,
        month: now,
        monthlyLimitMinutes: monthlyLimitMins,
        monthlyUsedMinutes: monthUsed,
        todayLimitMinutes: dailyLimitMins,
        todayUsedMinutes: 0,
      );

      // Verify that even for 15 mins request, exactly 2 hours (120 mins) quota is used
      expect(balance.monthlyUsedMinutes, 120);
      expect(balance.monthlyUsedHours, 2.0);
      expect(balance.monthlyUsedFormatted, '2h');
      expect(balance.monthlyRemainingMinutes, 240);
      expect(balance.monthlyRemainingHours, 4.0);
      expect(balance.monthlyRemainingFormatted, '4h');
      expect(balance.monthlyLimitHours, 6.0);
      expect(balance.monthlyLimitFormatted, '6h');
    });

    test('3. Three permissions in a month exhaust full 6-hour monthly limit (3 x 2h = 6h)', () {
      final now = DateTime(2026, 9, 15);
      const policy = PermissionPolicy(dailyLimitHours: 2.0, monthlyLimitHours: 6.0);
      final dailyLimitMins = (policy.dailyLimitHours * 60).round(); // 120
      final monthlyLimitMins = (policy.monthlyLimitHours * 60).round(); // 360

      final requests = [
        PermissionRequest(
          id: 1,
          employeeId: 101,
          employeeName: 'John Doe',
          employeeCode: 'EMP-101',
          department: 'Engineering',
          date: DateTime(2026, 9, 1),
          fromTime: '09:00',
          toTime: '09:30',
          durationMinutes: 30,
          permissionType: PermissionType.lateArrival,
          reason: 'Doctor appointment',
          status: PermissionStatus.approved,
          submittedAt: DateTime(2026, 9, 1),
        ),
        PermissionRequest(
          id: 2,
          employeeId: 101,
          employeeName: 'John Doe',
          employeeCode: 'EMP-101',
          department: 'Engineering',
          date: DateTime(2026, 9, 5),
          fromTime: '17:00',
          toTime: '18:00',
          durationMinutes: 60,
          permissionType: PermissionType.earlyDeparture,
          reason: 'Personal',
          status: PermissionStatus.approved,
          submittedAt: DateTime(2026, 9, 5),
        ),
        PermissionRequest(
          id: 3,
          employeeId: 101,
          employeeName: 'John Doe',
          employeeCode: 'EMP-101',
          department: 'Engineering',
          date: DateTime(2026, 9, 10),
          fromTime: '09:00',
          toTime: '10:00',
          durationMinutes: 60,
          permissionType: PermissionType.lateArrival,
          reason: 'Car breakdown',
          status: PermissionStatus.approved,
          submittedAt: DateTime(2026, 9, 10),
        ),
      ];

      final activeDaysInMonth = requests
          .where((r) => r.status != PermissionStatus.rejected && r.status != PermissionStatus.cancelled)
          .map((r) => r.date.toIso8601String().split('T').first)
          .toSet();

      final monthUsed = activeDaysInMonth.length * dailyLimitMins;
      final balance = PermissionBalance(
        employeeId: 101,
        month: now,
        monthlyLimitMinutes: monthlyLimitMins,
        monthlyUsedMinutes: monthUsed,
        todayLimitMinutes: dailyLimitMins,
        todayUsedMinutes: 0,
      );

      expect(balance.monthlyUsedMinutes, 360);
      expect(balance.monthlyUsedHours, 6.0);
      expect(balance.monthlyRemainingMinutes, 0);
      expect(balance.monthlyRemainingHours, 0.0);
      expect(balance.monthlyRemainingFormatted, '0m');
    });

    test('4. Consecutive Day Permission Check: Block Sep 2 if Sep 1 has permission, allow Sep 3', () {
      final existingRequests = [
        PermissionRequest(
          id: 1,
          employeeId: 101,
          employeeName: 'John Doe',
          employeeCode: 'EMP-101',
          department: 'Engineering',
          date: DateTime(2026, 9, 1),
          fromTime: '09:00',
          toTime: '10:00',
          durationMinutes: 60,
          permissionType: PermissionType.lateArrival,
          reason: 'Test',
          status: PermissionStatus.approved,
          submittedAt: DateTime(2026, 9, 1),
        ),
      ];

      bool isConsecutiveAllowed(DateTime candidateDate) {
        final candDay = DateTime(candidateDate.year, candidateDate.month, candidateDate.day);
        for (final ex in existingRequests) {
          if (ex.status == PermissionStatus.rejected || ex.status == PermissionStatus.cancelled) continue;
          final exDay = DateTime(ex.date.year, ex.date.month, ex.date.day);
          if (candDay.difference(exDay).inDays.abs() == 1) {
            return false; // Consecutive prohibited
          }
        }
        return true;
      }

      // Sep 2nd is consecutive to Sep 1st -> Not Allowed
      expect(isConsecutiveAllowed(DateTime(2026, 9, 2)), isFalse);

      // Sep 3rd is NOT consecutive to Sep 1st -> Allowed
      expect(isConsecutiveAllowed(DateTime(2026, 9, 3)), isTrue);

      // Aug 31st is consecutive to Sep 1st -> Not Allowed
      expect(isConsecutiveAllowed(DateTime(2026, 8, 31)), isFalse);

      // Aug 30th is NOT consecutive to Sep 1st -> Allowed
      expect(isConsecutiveAllowed(DateTime(2026, 8, 30)), isTrue);
    });

    test('5. Consecutive Late Days: Late on Sep 1 + Late on Sep 2 -> both remain Late (no LOP penalty conversion)', () {
      final employee = Employee.fromMap({
        'id': 1,
        'employee_id': 'EMP-001',
        'first_name': 'Test',
        'last_name': 'User',
        'email_address': 'test@example.com',
        'phone_number': '1234567890',
        'gender': 'Male',
        'dob': '1990-01-01',
        'organization_name': 'Company',
        'department': 'Tech',
        'designation': 'Engineer',
        'employment_type': 'Full-Time',
        'joining_date': '01-09-2026',
        'status': 'Active',
        'in_time': '09:00',
        'out_time': '18:00',
        'required_working_hours': 9.0,
      });

      final records = <AttendanceRecord>[
        // Sep 1: Late arrival (First late)
        const AttendanceRecord(
          id: 1,
          employeeId: 1,
          employeeCode: 'EMP-001',
          employeeName: 'Test User',
          date: '01-09-2026',
          time: '09:30',
          checkInTime: '09:30',
          checkOutTime: '18:30',
          verificationStatus: 'Verified',
          similarityScore: 1.0,
          totalHours: 9.0,
          status: 'Late',
          notes: 'Late = 20 minutes',
        ),
        // Sep 2: Consecutive Late arrival (Second late)
        const AttendanceRecord(
          id: 2,
          employeeId: 1,
          employeeCode: 'EMP-001',
          employeeName: 'Test User',
          date: '02-09-2026',
          time: '09:25',
          checkInTime: '09:25',
          checkOutTime: '18:25',
          verificationStatus: 'Verified',
          similarityScore: 1.0,
          totalHours: 9.0,
          status: 'Late',
          notes: 'Late = 15 minutes',
        ),
        // Sep 3: On-time check-in
        const AttendanceRecord(
          id: 3,
          employeeId: 1,
          employeeCode: 'EMP-001',
          employeeName: 'Test User',
          date: '03-09-2026',
          time: '09:00',
          checkInTime: '09:00',
          checkOutTime: '18:00',
          verificationStatus: 'Verified',
          similarityScore: 1.0,
          totalHours: 9.0,
          status: 'Present',
          notes: 'On time',
        ),
      ];

      final result = MonthlyAttendanceCalculator.calculate(
        employee: employee,
        year: 2026,
        month: 9,
        records: records,
        startDate: DateTime(2026, 9, 1),
        endDateExclusive: DateTime(2026, 9, 4),
        referenceDate: DateTime(2026, 9, 4),
      );

      final day1 = result.dailyResults.firstWhere((d) => d.dateStr == '01-09-2026');
      final day2 = result.dailyResults.firstWhere((d) => d.dateStr == '02-09-2026');
      final day3 = result.dailyResults.firstWhere((d) => d.dateStr == '03-09-2026');

      // Day 1: Late
      expect(day1.statusInfo, AttendanceStatusInfo.late);
      expect(day1.statusCode, 'L');

      // Day 2: Late (preserved as Late, no LOP penalty)
      expect(day2.statusInfo, AttendanceStatusInfo.late);
      expect(day2.statusCode, 'L');

      // Day 3: Present
      expect(day3.statusInfo, AttendanceStatusInfo.present);
      expect(day3.statusCode, 'P');

      // Summary counts
      expect(result.lateCount, 2);
      expect(result.absentCount, 0);
      expect(result.presentCount, 1);
    });
  });
}
