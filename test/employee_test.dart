import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/employee/domain/employee.dart';
import 'package:flutter_application_1/features/employee/domain/registration_link.dart';
import 'package:flutter_application_1/features/employee/data/sqlite_employee_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Employee Module Tests', () {
    test('Employee model serialization toMap and fromMap', () {
      const emp = Employee(
        id: 1,
        employeeId: 'EMP-0001',
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
      expect(map['employee_id'], 'EMP-0001');
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

      expect(link.fullUrl, 'https://app.company.com/employee/register/TEST1234');
      final map = link.toMap();
      expect(map['link_id'], 'TEST1234');
    });
  });
}
