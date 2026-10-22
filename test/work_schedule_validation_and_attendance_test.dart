import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/employee/domain/employee.dart';
import 'package:flutter_application_1/core/utils/time_formatter.dart';

Employee _createTestEmployee({
  required int id,
  required String employeeId,
  String workScheduleType = '',
  bool isDynamic = false,
  bool isStatic = false,
  String inTime = '',
  String outTime = '',
  double requiredWorkingHours = 0.0,
}) {
  return Employee(
    id: id,
    employeeId: employeeId,
    firstName: 'Test',
    lastName: 'User',
    emailAddress: 'test$id@igreen.com',
    phoneNumber: '900000000$id',
    gender: 'Male',
    dob: '1990-01-01',
    organizationName: 'IGREEN',
    department: 'Engineering',
    designation: 'Developer',
    employmentType: 'Full-Time',
    joiningDate: '2026-01-01',
    status: 'Active',
    workScheduleType: workScheduleType,
    isDynamicEmployee: isDynamic,
    isStaticEmployee: isStatic,
    inTime: inTime,
    outTime: outTime,
    requiredWorkingHours: requiredWorkingHours,
  );
}

void main() {
  group('Work Schedule Validation & Attendance Fallback Removal Tests', () {
    test('1. Fixed Schedule: In-Time and Out-Time are required', () {
      List<String> validate(String scheduleType, String inTime, String outTime, String reqHours) {
        final errors = <String>[];
        if (scheduleType.trim().isEmpty) {
          errors.add('Work Schedule Type is required');
        } else if (scheduleType == 'Fixed Schedule') {
          if (inTime.trim().isEmpty) {
            errors.add('In Time is required for Fixed Schedule');
          }
          if (outTime.trim().isEmpty) {
            errors.add('Out Time is required for Fixed Schedule');
          }
        } else if (scheduleType == 'Flexible Schedule') {
          final hoursText = reqHours.trim();
          final hours = double.tryParse(hoursText.replaceAll(RegExp(r'[^0-9.]'), ''));
          if (hoursText.isEmpty) {
            errors.add('Required Working Hours is required for Flexible Schedule');
          } else if (hours == null || hours <= 0) {
            errors.add('Required Working Hours must be greater than 0');
          }
        }
        return errors;
      }

      // Empty schedule type
      expect(validate('', '', '', ''), contains('Work Schedule Type is required'));

      // Fixed schedule missing both
      final fixedMissingBoth = validate('Fixed Schedule', '', '', '');
      expect(fixedMissingBoth, contains('In Time is required for Fixed Schedule'));
      expect(fixedMissingBoth, contains('Out Time is required for Fixed Schedule'));

      // Fixed schedule missing Out-Time
      final fixedMissingOut = validate('Fixed Schedule', '09:00 AM', '', '');
      expect(fixedMissingOut, contains('Out Time is required for Fixed Schedule'));
      expect(fixedMissingOut.length, 1);

      // Fixed schedule complete
      final fixedValid = validate('Fixed Schedule', '09:00 AM', '06:00 PM', '');
      expect(fixedValid.isEmpty, true);
    });

    test('2. Flexible Schedule: Required Working Hours is mandatory, timings not required', () {
      List<String> validate(String scheduleType, String inTime, String outTime, String reqHours) {
        final errors = <String>[];
        if (scheduleType.trim().isEmpty) {
          errors.add('Work Schedule Type is required');
        } else if (scheduleType == 'Fixed Schedule') {
          if (inTime.trim().isEmpty) {
            errors.add('In Time is required for Fixed Schedule');
          }
          if (outTime.trim().isEmpty) {
            errors.add('Out Time is required for Fixed Schedule');
          }
        } else if (scheduleType == 'Flexible Schedule') {
          final hoursText = reqHours.trim();
          final hours = double.tryParse(hoursText.replaceAll(RegExp(r'[^0-9.]'), ''));
          if (hoursText.isEmpty) {
            errors.add('Required Working Hours is required for Flexible Schedule');
          } else if (hours == null || hours <= 0) {
            errors.add('Required Working Hours must be greater than 0');
          }
        }
        return errors;
      }

      // Flexible schedule missing hours
      final flexEmpty = validate('Flexible Schedule', '', '', '');
      expect(flexEmpty, contains('Required Working Hours is required for Flexible Schedule'));

      // Flexible schedule with 0 hours
      final flexZero = validate('Flexible Schedule', '', '', '0 Hours');
      expect(flexZero, contains('Required Working Hours must be greater than 0'));

      // Flexible schedule valid with 9 Hours, timings empty
      final flexValid = validate('Flexible Schedule', '', '', '9 Hours');
      expect(flexValid.isEmpty, true);
    });

    test('3. Attendance without 9:00 AM fallback: Flexible or unassigned schedule receives Present, not Late', () {
      String resolveAttendanceStatus({
        required Employee employee,
        required String actualCheckIn,
        required String scheduledCheckInTime,
        required int gracePeriodMinutes,
      }) {
        final isDynamic = employee.isDynamicEmployee || (employee.workScheduleType == 'Flexible Schedule');
        String schedIn = scheduledCheckInTime.trim().isNotEmpty
            ? scheduledCheckInTime.trim()
            : (employee.inTime.trim().isNotEmpty ? employee.inTime.trim() : '');

        // Fallback removed! No schedIn = '09:00 AM'
        final scheduledMinutes = schedIn.isNotEmpty ? TimeFormatter.parseTimeToMinutes(schedIn) : null;

        if (isDynamic || scheduledMinutes == null) {
          return 'Present';
        } else {
          final checkInMins = TimeFormatter.parseTimeToMinutes(actualCheckIn);
          if (checkInMins != null && checkInMins > (scheduledMinutes + gracePeriodMinutes)) {
            return 'Late';
          }
          return 'Present';
        }
      }

      final flexibleEmployee = _createTestEmployee(
        id: 101,
        employeeId: 'EMP-101',
        workScheduleType: 'Flexible Schedule',
        isDynamic: true,
        inTime: '',
        outTime: '',
        requiredWorkingHours: 9.0,
      );

      // Checking in at 10:30 AM with a 15-minute grace period
      final flexStatus = resolveAttendanceStatus(
        employee: flexibleEmployee,
        actualCheckIn: '10:30 AM',
        scheduledCheckInTime: '',
        gracePeriodMinutes: 15,
      );
      // Under old 9:00 AM fallback, 10:30 AM was flagged Late. With fallback removed, it is Present.
      expect(flexStatus, 'Present');

      final fixedEmployee = _createTestEmployee(
        id: 102,
        employeeId: 'EMP-102',
        workScheduleType: 'Fixed Schedule',
        isStatic: true,
        inTime: '09:00 AM',
        outTime: '06:00 PM',
      );

      // Checking in at 09:10 AM (within 15m grace)
      final onTimeStatus = resolveAttendanceStatus(
        employee: fixedEmployee,
        actualCheckIn: '09:10 AM',
        scheduledCheckInTime: '',
        gracePeriodMinutes: 15,
      );
      expect(onTimeStatus, 'Present');

      // Checking in at 09:25 AM (past 15m grace)
      final lateStatus = resolveAttendanceStatus(
        employee: fixedEmployee,
        actualCheckIn: '09:25 AM',
        scheduledCheckInTime: '',
        gracePeriodMinutes: 15,
      );
      expect(lateStatus, 'Late');
    });

    test('4. Existing employee schedule audit detects unassigned timings', () {
      final employees = [
        _createTestEmployee(
          id: 1,
          employeeId: 'EMP-001',
          workScheduleType: 'Fixed Schedule',
          inTime: '09:00 AM',
          outTime: '06:00 PM',
        ),
        _createTestEmployee(
          id: 2,
          employeeId: 'EMP-002',
          workScheduleType: 'Fixed Schedule',
          inTime: '09:00 AM',
          outTime: '',
        ),
        _createTestEmployee(
          id: 3,
          employeeId: 'EMP-003',
          workScheduleType: '',
          inTime: '',
          outTime: '',
        ),
        _createTestEmployee(
          id: 4,
          employeeId: 'EMP-004',
          workScheduleType: 'Flexible Schedule',
          isDynamic: true,
          requiredWorkingHours: 9.0,
        ),
        _createTestEmployee(
          id: 5,
          employeeId: 'EMP-005',
          workScheduleType: 'Flexible Schedule',
          isDynamic: true,
          requiredWorkingHours: 0.0,
        ),
      ];

      final issues = <Map<String, dynamic>>[];
      for (final emp in employees) {
        final isFixed = emp.workScheduleType == 'Fixed Schedule' ||
            (!emp.isDynamicEmployee && emp.workScheduleType != 'Flexible Schedule');
        if (isFixed) {
          final missingIn = emp.inTime.trim().isEmpty;
          final missingOut = emp.outTime.trim().isEmpty;
          if (missingIn || missingOut) {
            issues.add({
              'employeeId': emp.employeeId,
              'missing': [if (missingIn) 'In-Time', if (missingOut) 'Out-Time'].join(', '),
            });
          }
        } else {
          if (emp.requiredWorkingHours <= 0) {
            issues.add({
              'employeeId': emp.employeeId,
              'missing': 'Required Working Hours',
            });
          }
        }
      }

      expect(issues.length, 3);
      expect(issues.any((i) => i['employeeId'] == 'EMP-002'), true);
      expect(issues.any((i) => i['employeeId'] == 'EMP-003'), true);
      expect(issues.any((i) => i['employeeId'] == 'EMP-005'), true);
    });
  });
}
