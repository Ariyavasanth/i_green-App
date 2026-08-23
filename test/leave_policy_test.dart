import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_application_1/features/employee/domain/employee.dart';
import 'package:flutter_application_1/features/employee/data/sqlite_employee_repository.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late SqliteEmployeeRepository employeeRepo;

  setUp(() {
    employeeRepo = SqliteEmployeeRepository();
  });

  group('Phase 1 — Employee Leave Policy Configuration Tests', () {
    test('Test 1 — As Needed Policy Configuration', () {
      const emp = Employee(
        id: 1,
        employeeId: 'EMP-001',
        firstName: 'John',
        lastName: 'Doe',
        emailAddress: 'john@example.com',
        phoneNumber: '9876543210',
        gender: 'Male',
        dob: '1990-01-01',
        organizationName: 'iGreen Tech',
        department: 'Engineering',
        designation: 'Software Engineer',
        employmentType: 'Full-time',
        joiningDate: '2025-01-01',
        status: 'Active',
        leaveType: 'As Needed',
        monthlyLeaveAllowance: 3.0,
      );

      expect(emp.leavePolicy, 'As Needed');
      expect(emp.leaveType, 'As Needed');
      
      final map = emp.toMap();
      expect(map['leave_type'], 'As Needed');
      expect(map['monthly_leave_allowance'], 3.0);

      final rehydrated = Employee.fromMap(map);
      expect(rehydrated.leavePolicy, 'As Needed');
      expect(rehydrated.monthlyLeaveAllowance, 3.0);
    });

    test('Test 2 — Monthly Allocation Policy Configuration', () {
      const emp = Employee(
        id: 2,
        employeeId: 'EMP-002',
        firstName: 'Jane',
        lastName: 'Smith',
        emailAddress: 'jane@example.com',
        phoneNumber: '9876543211',
        gender: 'Female',
        dob: '1992-05-15',
        organizationName: 'iGreen Tech',
        department: 'HR',
        designation: 'HR Executive',
        employmentType: 'Full-time',
        joiningDate: '2025-01-01',
        status: 'Active',
        leaveType: 'Monthly Allocation',
        monthlyLeaveAllowance: 3.0,
        allowedLeaves: 3.0,
      );

      expect(emp.leavePolicy, 'Monthly Allocation');
      expect(emp.monthlyLeaveAllowance, 3.0);

      final map = emp.toMap();
      expect(map['leave_type'], 'Monthly Allocation');
      expect(map['monthly_leave_allowance'], 3.0);

      final rehydrated = Employee.fromMap(map);
      expect(rehydrated.leavePolicy, 'Monthly Allocation');
      expect(rehydrated.monthlyLeaveAllowance, 3.0);
    });

    test('Test 3 — No Leave Policy Configuration', () {
      const emp = Employee(
        id: 3,
        employeeId: 'EMP-003',
        firstName: 'Alex',
        lastName: 'Taylor',
        emailAddress: 'alex@example.com',
        phoneNumber: '9876543212',
        gender: 'Other',
        dob: '1995-10-10',
        organizationName: 'iGreen Tech',
        department: 'Operations',
        designation: 'Operations Specialist',
        employmentType: 'Contract',
        joiningDate: '2025-01-01',
        status: 'Active',
        leaveType: 'No Leave',
        monthlyLeaveAllowance: 0.0,
        allowedLeaves: 0.0,
      );

      expect(emp.leavePolicy, 'No Leave');
      expect(emp.allowedLeaves, 0.0);

      final map = emp.toMap();
      expect(map['leave_type'], 'No Leave');
      expect(map['allowed_leaves'], 0.0);

      final rehydrated = Employee.fromMap(map);
      expect(rehydrated.leavePolicy, 'No Leave');
      expect(rehydrated.allowedLeaves, 0.0);
    });
  });
}
