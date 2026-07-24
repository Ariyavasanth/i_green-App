import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter_application_1/features/organization/data/sqlite_organization_repository.dart';
import 'package:flutter_application_1/features/organization/domain/column_preference.dart';
import 'package:flutter_application_1/features/organization/domain/department.dart';
import 'package:flutter_application_1/features/organization/domain/organization.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SqliteOrganizationRepository Tests', () {
    late SqliteOrganizationRepository repo;

    setUp(() {
      repo = SqliteOrganizationRepository();
    });

    test('getOrganizations returns initial seeded records', () async {
      final orgs = await repo.getOrganizations();
      expect(orgs.isNotEmpty, isTrue);
      expect(orgs.any((o) => o.name == 'iGreen Technologies'), isTrue);
    });

    test('addOrganization inserts a new record', () async {
      final newOrg = const Organization(
        id: 0,
        name: 'Test Organization Inc.',
        businessType: 'Partnership',
        industryType: 'Energy',
        businessUnits: 'Solar',
        locations: 'Berlin',
        address: '123 Test St',
        phoneNumber: '+49 12345678',
        emailAddress: 'test@org.de',
        website: 'https://test.de',
        taxId: 'DE123456789',
      );

      await repo.addOrganization(newOrg);
      final orgs = await repo.getOrganizations();
      expect(orgs.any((o) => o.name == 'Test Organization Inc.'), isTrue);
    });

    test('updateOrganization modifies existing record', () async {
      final orgs = await repo.getOrganizations();
      final target = orgs.first;
      final updated = target.copyWith(name: '${target.name} Updated');

      await repo.updateOrganization(updated);
      final reFetched = await repo.getOrganizations();
      expect(reFetched.any((o) => o.name == '${target.name} Updated'), isTrue);
    });

    test('deleteOrganization removes record', () async {
      final orgs = await repo.getOrganizations();
      final initialLength = orgs.length;
      final targetId = orgs.last.id;

      await repo.deleteOrganization(targetId);
      final updatedOrgs = await repo.getOrganizations();
      expect(updatedOrgs.length, equals(initialLength - 1));
      expect(updatedOrgs.any((o) => o.id == targetId), isFalse);
    });

    test('getDepartments returns initial seeded records', () async {
      final depts = await repo.getDepartments();
      expect(depts.isNotEmpty, isTrue);
      expect(depts.any((d) => d.departmentName == 'Production'), isTrue);
    });

    test('addDepartment and deleteDepartment work correctly', () async {
      const newDept = Department(
        id: 0,
        departmentName: 'Quality Assurance (QA)',
        departmentHead: 'Alice Smith',
        reportingHierarchy: 'Supervisor',
        workLocation: 'Office',
      );

      await repo.addDepartment(newDept);
      var depts = await repo.getDepartments();
      final added = depts.firstWhere((d) => d.departmentName == 'Quality Assurance (QA)');
      expect(added, isNotNull);

      await repo.deleteDepartment(added.id);
      depts = await repo.getDepartments();
      expect(depts.any((d) => d.departmentName == 'Quality Assurance (QA)'), isFalse);
    });

    test('saveColumnPreference and getColumnPreference work correctly', () async {
      const pref = ColumnPreference(
        tableId: 'test_table',
        visibleColumns: ['Col A', 'Col B'],
        columnOrder: ['Col B', 'Col A', 'Col C'],
      );

      await repo.saveColumnPreference(pref);
      final loaded = await repo.getColumnPreference('test_table');
      expect(loaded, isNotNull);
      expect(loaded!.visibleColumns, equals(['Col A', 'Col B']));
      expect(loaded.columnOrder, equals(['Col B', 'Col A', 'Col C']));
    });
  });
}
