import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/employee/domain/employee.dart';
import 'package:flutter_application_1/features/employee/domain/registration_link.dart';
import 'package:flutter_application_1/features/employee/data/firebase_employee_repository.dart';

Employee _createEmployee({
  int id = 1,
  String employeeId = 'EMP-001',
  String firstName = 'Test',
  String lastName = 'User',
  String emailAddress = 'test@example.com',
  String phoneNumber = '+919999999999',
  String gender = 'Male',
  String dob = '1995-01-01',
  String organizationName = 'Acme Corp',
  String department = 'Engineering',
  String designation = 'Developer',
  String employmentType = 'Full-Time',
  String joiningDate = '2024-01-01',
  String status = 'Active',
  String reportingManager = '',
  String reportingManagerId = '',
  String reportingManagerTitle = '',
}) {
  return Employee(
    id: id,
    employeeId: employeeId,
    firstName: firstName,
    lastName: lastName,
    emailAddress: emailAddress,
    phoneNumber: phoneNumber,
    gender: gender,
    dob: dob,
    organizationName: organizationName,
    department: department,
    designation: designation,
    employmentType: employmentType,
    joiningDate: joiningDate,
    status: status,
    reportingManager: reportingManager,
    reportingManagerId: reportingManagerId,
    reportingManagerTitle: reportingManagerTitle,
  );
}

void main() {
  group('Employee Module Basic Tests', () {
    test('Employee model serialization toMap and fromMap', () {
      final emp = _createEmployee(
        id: 1,
        employeeId: 'EMP-001',
        firstName: 'Alice',
        lastName: 'Wonderland',
        emailAddress: 'alice@example.com',
        phoneNumber: '+919999999999',
        gender: 'Female',
        dob: '1995-01-01',
        organizationName: 'Acme Corp',
        department: 'Engineering',
        designation: 'Software Developer',
        employmentType: 'Full-Time',
        joiningDate: '2024-01-01',
        status: 'Active',
      );

      final map = emp.toMap();
      expect(map['employee_id'], 'EMP-001');
      expect(map['first_name'], 'Alice');

      final reconstructed = Employee.fromMap(map);
      expect(reconstructed.fullName, 'Alice Wonderland');
      expect(reconstructed.organizationName, 'Acme Corp');
    });

    test('RegistrationLink model serialization and fullUrl', () {
      const link = RegistrationLink(
        id: 1,
        linkId: 'TEST1234',
        generatedBy: 'Admin',
        generatedDate: '2026-07-24 10:00',
        expiryDate: '2026-07-31 10:00',
        linkStatus: 'Pending',
      );

      expect(link.fullUrl, '/#/employee/register/TEST1234');
      expect(
        link.buildFullUrl(customBaseUrl: 'https://app.igreentech.in'),
        'https://app.igreentech.in/#/employee/register/TEST1234',
      );
      final map = link.toMap();
      expect(map['link_id'], 'TEST1234');
    });

    test('RegistrationLink status transitions', () {
      const link = RegistrationLink(
        id: 1,
        linkId: 'TEST1234',
        generatedBy: 'Admin',
        generatedDate: '2026-07-24 10:00',
        expiryDate: '2026-07-31 10:00',
        linkStatus: 'Pending',
      );

      final acceptedLink = link.copyWith(linkStatus: 'Accepted');
      expect(acceptedLink.linkStatus, 'Accepted');

      final completedLink = acceptedLink.copyWith(linkStatus: 'Completed');
      expect(completedLink.linkStatus, 'Completed');
    });
  });

  group('Phase 3 — Reporting Manager Persistence and Validation (In-Memory Tests)', () {
    late FirebaseEmployeeRepository repository;

    setUp(() {
      repository = FirebaseEmployeeRepository(isInMemory: true);
    });

    test(
      '1. Model serialization preserves reportingManagerId and handles camelCase fallback',
      () {
        final emp = _createEmployee(
          id: 10,
          employeeId: 'EMP-010',
          firstName: 'John',
          lastName: 'Doe',
          organizationName: 'Acme Corp',
          department: 'Operations',
          designation: 'Staff',
          status: 'Active',
          reportingManager: 'Alice Smith',
          reportingManagerId: 'EMP-001',
          reportingManagerTitle: 'Operations Manager',
        );

        final map = emp.toMap();
        expect(map['reporting_manager_id'], 'EMP-001');
        expect(map['reporting_manager'], 'Alice Smith');
        expect(map['reporting_manager_title'], 'Operations Manager');

        // fromMap with snake_case
        final fromSnake = Employee.fromMap(map);
        expect(fromSnake.reportingManagerId, 'EMP-001');
        expect(fromSnake.reportingManager, 'Alice Smith');
        expect(fromSnake.reportingManagerTitle, 'Operations Manager');

        // fromMap with camelCase fallback
        final camelMap = {
          'id': 10,
          'employee_id': 'EMP-010',
          'first_name': 'John',
          'last_name': 'Doe',
          'email_address': 'john@example.com',
          'phone_number': '+919999999999',
          'gender': 'Male',
          'dob': '1995-01-01',
          'organization_name': 'Acme Corp',
          'department': 'Operations',
          'designation': 'Staff',
          'employment_type': 'Full-Time',
          'joining_date': '2024-01-01',
          'status': 'Active',
          'reportingManagerId': 'EMP-001',
          'reportingManager': 'Alice Smith',
          'reportingManagerTitle': 'Operations Manager',
        };
        final fromCamel = Employee.fromMap(camelMap);
        expect(fromCamel.reportingManagerId, 'EMP-001');
        expect(fromCamel.reportingManager, 'Alice Smith');
        expect(fromCamel.reportingManagerTitle, 'Operations Manager');
      },
    );

    test(
      '2. Creating an employee with an active manager in the same organization succeeds',
      () async {
        // Create Manager
        final manager = await repository.addEmployee(
          _createEmployee(
            id: 1,
            employeeId: 'EMP-001',
            firstName: 'Alice',
            lastName: 'Manager',
            organizationName: 'Acme Corp',
            department: 'Engineering',
            designation: 'Engineering Lead',
            status: 'Active',
          ),
        );
        expect(manager.employeeId, 'EMP-001');

        // Create Employee reporting to Manager
        final emp = await repository.addEmployee(
          _createEmployee(
            id: 2,
            employeeId: 'EMP-002',
            firstName: 'Bob',
            lastName: 'Developer',
            organizationName: 'Acme Corp',
            department: 'Engineering',
            designation: 'Software Developer',
            status: 'Active',
            reportingManagerId: 'EMP-001',
            reportingManager: 'Alice Manager',
            reportingManagerTitle: 'Engineering Lead',
          ),
        );

        expect(emp.employeeId, 'EMP-002');
        expect(emp.reportingManagerId, 'EMP-001');
        expect(emp.reportingManager, 'Alice Manager');
        expect(emp.reportingManagerTitle, 'Engineering Lead');

        final fetched = await repository.getEmployeeById(2);
        expect(fetched, isNotNull);
        expect(fetched!.reportingManagerId, 'EMP-001');
      },
    );

    test(
      '3. Editing an employee preserves existing reportingManagerId without overwriting',
      () async {
        // Setup Manager & Employee
        await repository.addEmployee(
          _createEmployee(
            id: 1,
            employeeId: 'EMP-001',
            firstName: 'Alice',
            lastName: 'Manager',
            organizationName: 'Acme Corp',
            department: 'Engineering',
            designation: 'Engineering Lead',
            status: 'Active',
          ),
        );

        final emp = await repository.addEmployee(
          _createEmployee(
            id: 2,
            employeeId: 'EMP-002',
            firstName: 'Bob',
            lastName: 'Developer',
            phoneNumber: '+911111111111',
            organizationName: 'Acme Corp',
            department: 'Engineering',
            designation: 'Software Developer',
            status: 'Active',
            reportingManagerId: 'EMP-001',
            reportingManager: 'Alice Manager',
            reportingManagerTitle: 'Engineering Lead',
          ),
        );

        // Update employee with new phone number, ensuring reportingManagerId is untouched
        final updated = emp.copyWith(phoneNumber: '+919999999999');
        await repository.updateEmployee(updated);

        final fetched = await repository.getEmployeeById(2);
        expect(fetched, isNotNull);
        expect(fetched!.phoneNumber, '+919999999999');
        expect(fetched.reportingManagerId, 'EMP-001');
        expect(fetched.reportingManager, 'Alice Manager');
      },
    );

    test('4. Changing and clearing reporting manager', () async {
      // Setup Managers
      await repository.addEmployee(
        _createEmployee(
          id: 1,
          employeeId: 'EMP-001',
          firstName: 'Alice',
          lastName: 'Manager',
          organizationName: 'Acme Corp',
          status: 'Active',
        ),
      );
      await repository.addEmployee(
        _createEmployee(
          id: 2,
          employeeId: 'EMP-002',
          firstName: 'Charlie',
          lastName: 'Lead',
          organizationName: 'Acme Corp',
          status: 'Active',
        ),
      );

      // Create Employee reporting to EMP-001
      var emp = await repository.addEmployee(
        _createEmployee(
          id: 3,
          employeeId: 'EMP-003',
          firstName: 'David',
          lastName: 'Junior',
          organizationName: 'Acme Corp',
          status: 'Active',
          reportingManagerId: 'EMP-001',
          reportingManager: 'Alice Manager',
        ),
      );

      // Change manager to EMP-002
      emp = emp.copyWith(
        reportingManagerId: 'EMP-002',
        reportingManager: 'Charlie Lead',
      );
      await repository.updateEmployee(emp);

      var fetched = await repository.getEmployeeById(3);
      expect(fetched!.reportingManagerId, 'EMP-002');
      expect(fetched.reportingManager, 'Charlie Lead');

      // Clear manager
      emp = emp.copyWith(
        reportingManagerId: '',
        reportingManager: '',
        reportingManagerTitle: '',
      );
      await repository.updateEmployee(emp);

      fetched = await repository.getEmployeeById(3);
      expect(fetched!.reportingManagerId, isEmpty);
      expect(fetched.reportingManager, isEmpty);
    });

    test('5. Rejecting self-reporting on creation and update', () async {
      // Add employee trying to report to self (matching employeeId)
      expect(
        () => repository.addEmployee(
          _createEmployee(
            id: 5,
            employeeId: 'EMP-005',
            firstName: 'Self',
            lastName: 'Reporter',
            organizationName: 'Acme Corp',
            status: 'Active',
            reportingManagerId: 'EMP-005',
          ),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('cannot report to themselves'),
          ),
        ),
      );

      // Create valid employee first
      final emp = await repository.addEmployee(
        _createEmployee(
          id: 6,
          employeeId: 'EMP-006',
          firstName: 'Valid',
          lastName: 'Emp',
          organizationName: 'Acme Corp',
          status: 'Active',
        ),
      );

      // Attempt to update employee to report to self
      expect(
        () => repository.updateEmployee(
          emp.copyWith(reportingManagerId: 'EMP-006'),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('cannot report to themselves'),
          ),
        ),
      );
    });

    test('6. Rejecting cross-organization reporting', () async {
      // Manager in Org A
      await repository.addEmployee(
        _createEmployee(
          id: 1,
          employeeId: 'EMP-001',
          firstName: 'Org A',
          lastName: 'Manager',
          organizationName: 'Acme Corp',
          status: 'Active',
        ),
      );

      // Employee in Org B trying to report to Org A Manager
      expect(
        () => repository.addEmployee(
          _createEmployee(
            id: 2,
            employeeId: 'EMP-002',
            firstName: 'Org B',
            lastName: 'Employee',
            organizationName: 'Beta Corp',
            status: 'Active',
            reportingManagerId: 'EMP-001',
          ),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains(
              'manager belongs to "Acme Corp", but employee belongs to "Beta Corp"',
            ),
          ),
        ),
      );
    });

    test('7. Handling missing or deleted manager ID', () async {
      expect(
        () => repository.addEmployee(
          _createEmployee(
            id: 10,
            employeeId: 'EMP-010',
            firstName: 'Orphan',
            lastName: 'Emp',
            organizationName: 'Acme Corp',
            status: 'Active',
            reportingManagerId: 'NON-EXISTENT-999',
          ),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('manager does not exist'),
          ),
        ),
      );
    });

    test(
      '8. Handling inactive managers: reject new assignment but preserve legacy records',
      () async {
        // Create Manager (initially Active)
        var mgr = await repository.addEmployee(
          _createEmployee(
            id: 1,
            employeeId: 'EMP-001',
            firstName: 'Future Inactive',
            lastName: 'Mgr',
            organizationName: 'Acme Corp',
            status: 'Active',
          ),
        );

        // Active Manager 2
        await repository.addEmployee(
          _createEmployee(
            id: 2,
            employeeId: 'EMP-002',
            firstName: 'Active',
            lastName: 'Mgr',
            organizationName: 'Acme Corp',
            status: 'Active',
          ),
        );

        // Employee 5 was created while EMP-001 was active
        final existingEmp = await repository.addEmployee(
          _createEmployee(
            id: 5,
            employeeId: 'EMP-005',
            firstName: 'Legacy',
            lastName: 'Emp',
            organizationName: 'Acme Corp',
            status: 'Active',
            reportingManagerId: 'EMP-001',
            reportingManager: 'Future Inactive Mgr',
          ),
        );

        // Now EMP-001 becomes inactive
        mgr = mgr.copyWith(status: 'Inactive');
        await repository.updateEmployee(mgr);

        // Cannot assign inactive manager to a new employee
        expect(
          () => repository.addEmployee(
            _createEmployee(
              id: 3,
              employeeId: 'EMP-003',
              firstName: 'New',
              lastName: 'Emp',
              organizationName: 'Acme Corp',
              status: 'Active',
              reportingManagerId: 'EMP-001',
            ),
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Cannot assign inactive employee'),
            ),
          ),
        );

        // Create employee 4 assigned to Active Mgr 2
        final emp4 = await repository.addEmployee(
          _createEmployee(
            id: 4,
            employeeId: 'EMP-004',
            firstName: 'Emp',
            lastName: 'Four',
            organizationName: 'Acme Corp',
            status: 'Active',
            reportingManagerId: 'EMP-002',
          ),
        );

        // Employee 4 cannot switch to inactive manager EMP-001
        expect(
          () => repository.updateEmployee(
            emp4.copyWith(reportingManagerId: 'EMP-001'),
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Cannot assign inactive employee'),
            ),
          ),
        );

        // Existing employee 5 updating phone without changing reportingManagerId succeeds
        final updatedExisting = existingEmp.copyWith(
          phoneNumber: '+919876543210',
        );
        await repository.updateEmployee(updatedExisting);

        final fetched = await repository.getEmployeeById(5);
        expect(fetched!.phoneNumber, '+919876543210');
        expect(fetched.reportingManagerId, 'EMP-001');
      },
    );

    test(
      '9. Preserving legacy employee records with missing or empty manager IDs',
      () async {
        // Legacy employee with empty reportingManagerId
        final legacyEmp = await repository.addEmployee(
          _createEmployee(
            id: 7,
            employeeId: 'EMP-007',
            firstName: 'Legacy',
            lastName: 'Unassigned',
            organizationName: 'Acme Corp',
            status: 'Active',
            reportingManagerId: '',
            reportingManager: '',
          ),
        );

        expect(legacyEmp.reportingManagerId, isEmpty);
        expect(legacyEmp.reportingManager, isEmpty);

        // Update without manager
        final updated = legacyEmp.copyWith(department: 'Quality Assurance');
        await repository.updateEmployee(updated);

        final fetched = await repository.getEmployeeById(7);
        expect(fetched!.department, 'Quality Assurance');
        expect(fetched.reportingManagerId, isEmpty);
        expect(fetched.reportingManager, isEmpty);
      },
    );
  });
}
