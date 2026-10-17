import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/employee/domain/employee.dart';
import 'package:flutter_application_1/features/employee/domain/employee_repository.dart';
import 'package:flutter_application_1/features/organization/domain/business_unit.dart';
import 'package:flutter_application_1/features/organization/domain/column_preference.dart';
import 'package:flutter_application_1/features/organization/domain/department.dart';
import 'package:flutter_application_1/features/organization/domain/designation.dart';
import 'package:flutter_application_1/features/organization/domain/location.dart';
import 'package:flutter_application_1/features/organization/domain/organization.dart';
import 'package:flutter_application_1/features/organization/domain/organization_band.dart';
import 'package:flutter_application_1/features/organization/domain/organization_repository.dart';
import 'package:flutter_application_1/features/hierarchy/domain/hierarchy_node.dart';
import 'package:flutter_application_1/features/hierarchy/domain/hierarchy_tree.dart';
import 'package:flutter_application_1/features/hierarchy/data/firebase_hierarchy_repository.dart';

/// In-memory mock employee repository for deterministic testing.
class MockEmployeeRepository implements EmployeeRepository {
  List<Employee> employees;
  MockEmployeeRepository(this.employees);

  @override
  Future<List<Employee>> getEmployees() async => List.from(employees);

  @override
  Future<List<Employee>> getAllEmployees() async => List.from(employees);

  @override
  Future<Employee?> getEmployeeById(int id) async =>
      employees.where((e) => e.id == id).firstOrNull;

  @override
  Future<Employee> addEmployee(Employee employee) async {
    employees.add(employee);
    return employee;
  }

  @override
  Future<void> updateEmployee(Employee employee) async {
    final idx = employees.indexWhere((e) => e.id == employee.id || e.employeeId == employee.employeeId);
    if (idx != -1) employees[idx] = employee;
  }

  @override
  Future<void> deleteEmployee(int id) async =>
      employees.removeWhere((e) => e.id == id);

  @override
  Future<void> updateEmployeeStatus(int id, String status) async {
    final idx = employees.indexWhere((e) => e.id == id);
    if (idx != -1) employees[idx] = employees[idx].copyWith(status: status);
  }

  @override
  Stream<Employee?> watchEmployee(String emailOrId) => Stream.value(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// In-memory mock organization repository for deterministic testing.
class MockOrganizationRepository implements OrganizationRepository {
  List<Organization> organizations;
  List<Department> departments;
  List<Designation> designations;
  List<OrganizationBand> bands;

  MockOrganizationRepository({
    this.organizations = const [],
    this.departments = const [],
    this.designations = const [],
    this.bands = const [],
  });

  @override
  Future<List<Organization>> getOrganizations({bool includeInactive = true}) async =>
      organizations;

  @override
  Future<List<Department>> getDepartments({
    String? organizationName,
    String? organizationId,
    String? businessUnitName,
    String? workLocation,
  }) async => departments;

  @override
  Future<List<Designation>> getDesignations({
    String? organizationName,
    String? organizationId,
    String? departmentName,
  }) async => designations;

  @override
  Future<List<OrganizationBand>> getBands({
    String? organizationId,
    String? organizationName,
  }) async => bands;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Hierarchy Module Logic & Tree Construction Tests', () {
    late MockEmployeeRepository empRepo;
    late MockOrganizationRepository orgRepo;
    late FirebaseHierarchyRepository hierarchyRepo;

    final testBands = [
      const OrganizationBand(
        id: 'band_7',
        organizationId: 'org_1',
        level: 7,
        bandCode: 'Band 7',
        title: 'Executive Leadership',
        colorHex: 0xFF9CC70A,
      ),
      const OrganizationBand(
        id: 'band_6',
        organizationId: 'org_1',
        level: 6,
        bandCode: 'Band 6',
        title: 'Senior Leadership',
        colorHex: 0xFF2563EB,
      ),
      const OrganizationBand(
        id: 'band_4',
        organizationId: 'org_1',
        level: 4,
        bandCode: 'Band 4',
        title: 'Middle Management',
        colorHex: 0xFF414A51,
      ),
      const OrganizationBand(
        id: 'band_1',
        organizationId: 'org_1',
        level: 1,
        bandCode: 'Band 1',
        title: 'Entry Level',
        colorHex: 0xFF64748B,
      ),
    ];

    final testDesignations = [
      const Designation(
        id: 1,
        organizationId: 'org_1',
        organizationName: 'I-Green',
        departmentName: 'Executive',
        designationName: 'Managing Director',
        bandId: 'band_7',
        bandCode: 'Band 7',
        bandLevel: 7,
      ),
      const Designation(
        id: 2,
        organizationId: 'org_1',
        organizationName: 'I-Green',
        departmentName: 'Engineering',
        designationName: 'Engineering Director',
        bandId: 'band_6',
        bandCode: 'Band 6',
        bandLevel: 6,
      ),
      const Designation(
        id: 3,
        organizationId: 'org_1',
        organizationName: 'I-Green',
        departmentName: 'Engineering',
        designationName: 'Team Lead',
        bandId: 'band_4',
        bandCode: 'Band 4',
        bandLevel: 4,
      ),
      const Designation(
        id: 4,
        organizationId: 'org_1',
        organizationName: 'I-Green',
        departmentName: 'Engineering',
        designationName: 'Junior Developer',
        bandId: 'band_1',
        bandCode: 'Band 1',
        bandLevel: 1,
      ),
      const Designation(
        id: 5,
        organizationId: 'org_1',
        organizationName: 'I-Green',
        departmentName: 'Finance',
        designationName: 'Finance Director',
        bandId: 'band_6',
        bandCode: 'Band 6',
        bandLevel: 6,
      ),
    ];

    Employee createEmp({
      required int id,
      required String empId,
      required String name,
      required String dept,
      required String desig,
      String managerId = '',
      String status = 'Active',
      String orgId = 'org_1',
    }) {
      final names = name.split(' ');
      return Employee(
        id: id,
        employeeId: empId,
        firstName: names.first,
        lastName: names.length > 1 ? names.sublist(1).join(' ') : '',
        emailAddress: '${empId.toLowerCase()}@igreen.com',
        phoneNumber: '+91 9876543210',
        gender: 'Male',
        dob: '1990-01-01',
        organizationId: orgId,
        organizationName: 'I-Green',
        department: dept,
        designation: desig,
        employmentType: 'Full-Time',
        joiningDate: '2023-01-01',
        status: status,
        reportingManagerId: managerId,
      );
    }

    test('Scenario 1: One CEO (Band 7) with several direct reports in multi-level hierarchy', () async {
      final employees = [
        createEmp(id: 1, empId: 'EMP-001', name: 'Alice CEO', dept: 'Executive', desig: 'Managing Director'),
        createEmp(id: 2, empId: 'EMP-002', name: 'Bob EngDir', dept: 'Engineering', desig: 'Engineering Director', managerId: 'EMP-001'),
        createEmp(id: 3, empId: 'EMP-003', name: 'Charlie FinDir', dept: 'Finance', desig: 'Finance Director', managerId: 'EMP-001'),
        createEmp(id: 4, empId: 'EMP-004', name: 'David Lead', dept: 'Engineering', desig: 'Team Lead', managerId: 'EMP-002'),
        createEmp(id: 5, empId: 'EMP-005', name: 'Eve Junior', dept: 'Engineering', desig: 'Junior Developer', managerId: 'EMP-004'),
        createEmp(id: 6, empId: 'EMP-006', name: 'Frank Junior', dept: 'Engineering', desig: 'Junior Developer', managerId: 'EMP-004'),
      ];

      empRepo = MockEmployeeRepository(employees);
      orgRepo = MockOrganizationRepository(bands: testBands, designations: testDesignations);
      hierarchyRepo = FirebaseHierarchyRepository(
        employeeRepository: empRepo,
        organizationRepository: orgRepo,
      );

      final tree = await hierarchyRepo.getHierarchyTree(organizationId: 'org_1');

      // Verify root node
      expect(tree.rootNodes.length, 1);
      final ceoNode = tree.rootNodes.first;
      expect(ceoNode.employee.employeeId, 'EMP-001');
      expect(ceoNode.bandLevel, 7);
      expect(ceoNode.bandTitle, 'Executive Leadership');
      expect(ceoNode.directReportsCount, 2); // Bob and Charlie
      expect(ceoNode.totalSubordinatesCount, 5); // Bob, Charlie, David, Eve, Frank

      // Verify Bob's reports
      final bobNode = ceoNode.children.firstWhere((c) => c.employee.employeeId == 'EMP-002');
      expect(bobNode.bandLevel, 6);
      expect(bobNode.directReportsCount, 1); // David

      // Verify David's reports (multiple employees reporting to one manager)
      final davidNode = bobNode.children.first;
      expect(davidNode.employee.employeeId, 'EMP-004');
      expect(davidNode.directReportsCount, 2); // Eve and Frank
      expect(davidNode.children.map((c) => c.employee.employeeId).toSet(), {'EMP-005', 'EMP-006'});
    });

    test('Scenario 2: Cross-department reporting is preserved without breakage', () async {
      final employees = [
        createEmp(id: 1, empId: 'EMP-001', name: 'Alice CEO', dept: 'Executive', desig: 'Managing Director'),
        createEmp(id: 2, empId: 'EMP-002', name: 'Charlie FinDir', dept: 'Finance', desig: 'Finance Director', managerId: 'EMP-001'),
        // An Engineer reporting to Finance Director:
        createEmp(id: 3, empId: 'EMP-003', name: 'Grace Dev', dept: 'Engineering', desig: 'Junior Developer', managerId: 'EMP-002'),
      ];

      empRepo = MockEmployeeRepository(employees);
      orgRepo = MockOrganizationRepository(bands: testBands, designations: testDesignations);
      hierarchyRepo = FirebaseHierarchyRepository(
        employeeRepository: empRepo,
        organizationRepository: orgRepo,
      );

      final tree = await hierarchyRepo.getHierarchyTree(organizationId: 'org_1');
      final charlieNode = tree.rootNodes.first.children.first;
      expect(charlieNode.employee.department, 'Finance');
      expect(charlieNode.children.length, 1);
      expect(charlieNode.children.first.employee.department, 'Engineering');
    });

    test('Scenario 3: Missing or inactive manager does not drop employee from hierarchy', () async {
      final employees = [
        createEmp(id: 1, empId: 'EMP-001', name: 'Alice CEO', dept: 'Executive', desig: 'Managing Director'),
        // Employee with an unresolvable manager ID (e.g. manager left company)
        createEmp(id: 2, empId: 'EMP-002', name: 'Hannah Orphan', dept: 'Engineering', desig: 'Team Lead', managerId: 'EMP-999'),
        createEmp(id: 3, empId: 'EMP-003', name: 'Ian Sub', dept: 'Engineering', desig: 'Junior Developer', managerId: 'EMP-002'),
      ];

      empRepo = MockEmployeeRepository(employees);
      orgRepo = MockOrganizationRepository(bands: testBands, designations: testDesignations);
      hierarchyRepo = FirebaseHierarchyRepository(
        employeeRepository: empRepo,
        organizationRepository: orgRepo,
      );

      final tree = await hierarchyRepo.getHierarchyTree(organizationId: 'org_1');

      expect(tree.hasMissingManagers, isTrue);
      // Both Alice and Hannah become root candidates so Hannah and Ian are never hidden
      expect(tree.rootNodes.length, 2);

      final hannahNode = tree.rootNodes.firstWhere((n) => n.employee.employeeId == 'EMP-002');
      expect(hannahNode.isMissingManager, isTrue);
      expect(hannahNode.missingManagerId, 'EMP-999');
      // Hannah's child Ian is correctly preserved beneath her:
      expect(hannahNode.directReportsCount, 1);
      expect(hannahNode.children.first.employee.employeeId, 'EMP-003');
    });

    test('Scenario 4: Circular reporting loop detection prevents infinite recursion', () async {
      // Loop: EMP-001 -> EMP-002 -> EMP-003 -> EMP-001
      final employees = [
        createEmp(id: 1, empId: 'EMP-001', name: 'User One', dept: 'Engineering', desig: 'Team Lead', managerId: 'EMP-003'),
        createEmp(id: 2, empId: 'EMP-002', name: 'User Two', dept: 'Engineering', desig: 'Team Lead', managerId: 'EMP-001'),
        createEmp(id: 3, empId: 'EMP-003', name: 'User Three', dept: 'Engineering', desig: 'Team Lead', managerId: 'EMP-002'),
      ];

      empRepo = MockEmployeeRepository(employees);
      orgRepo = MockOrganizationRepository(bands: testBands, designations: testDesignations);
      hierarchyRepo = FirebaseHierarchyRepository(
        employeeRepository: empRepo,
        organizationRepository: orgRepo,
      );

      final tree = await hierarchyRepo.getHierarchyTree(organizationId: 'org_1');

      expect(tree.hasCycles, isTrue);
      // Should not throw StackOverflowError and all 3 employees are accessible
      expect(tree.allNodes.length, 3);
    });

    test('Scenario 5: Empty organization returns empty tree safely', () async {
      empRepo = MockEmployeeRepository([]);
      orgRepo = MockOrganizationRepository();
      hierarchyRepo = FirebaseHierarchyRepository(
        employeeRepository: empRepo,
        organizationRepository: orgRepo,
      );

      final tree = await hierarchyRepo.getHierarchyTree(organizationId: 'org_empty');
      expect(tree.isEmpty, isTrue);
      expect(tree.totalEmployees, 0);
      expect(tree.rootNodes, isEmpty);
    });

    test('Scenario 6: Linear reporting chain from employee up to Band 7 CEO', () async {
      final employees = [
        createEmp(id: 1, empId: 'EMP-001', name: 'Alice CEO', dept: 'Executive', desig: 'Managing Director'),
        createEmp(id: 2, empId: 'EMP-002', name: 'Bob EngDir', dept: 'Engineering', desig: 'Engineering Director', managerId: 'EMP-001'),
        createEmp(id: 3, empId: 'EMP-003', name: 'David Lead', dept: 'Engineering', desig: 'Team Lead', managerId: 'EMP-002'),
        createEmp(id: 4, empId: 'EMP-004', name: 'Eve Junior', dept: 'Engineering', desig: 'Junior Developer', managerId: 'EMP-003'),
      ];

      empRepo = MockEmployeeRepository(employees);
      orgRepo = MockOrganizationRepository(bands: testBands, designations: testDesignations);
      hierarchyRepo = FirebaseHierarchyRepository(
        employeeRepository: empRepo,
        organizationRepository: orgRepo,
      );

      final chain = await hierarchyRepo.getReportingChain('EMP-004', organizationId: 'org_1');

      // Chain should be: Eve (self) -> David (Lead) -> Bob (Director) -> Alice (CEO)
      expect(chain.length, 4);
      expect(chain[0].employee.employeeId, 'EMP-004');
      expect(chain[1].employee.employeeId, 'EMP-003');
      expect(chain[2].employee.employeeId, 'EMP-002');
      expect(chain[3].employee.employeeId, 'EMP-001');
      expect(chain[3].bandLevel, 7);
    });

    test('Scenario 7: Duplicate employee names with different employee IDs are distinguished', () async {
      final employees = [
        createEmp(id: 1, empId: 'EMP-101', name: 'John Doe', dept: 'Engineering', desig: 'Team Lead'),
        createEmp(id: 2, empId: 'EMP-102', name: 'John Doe', dept: 'Finance', desig: 'Junior Developer', managerId: 'EMP-101'),
      ];

      empRepo = MockEmployeeRepository(employees);
      orgRepo = MockOrganizationRepository(bands: testBands, designations: testDesignations);
      hierarchyRepo = FirebaseHierarchyRepository(
        employeeRepository: empRepo,
        organizationRepository: orgRepo,
      );

      final tree = await hierarchyRepo.getHierarchyTree(organizationId: 'org_1');

      expect(tree.rootNodes.length, 1);
      final manager = tree.rootNodes.first;
      expect(manager.employee.employeeId, 'EMP-101');
      expect(manager.directReportsCount, 1);
      expect(manager.children.first.employee.employeeId, 'EMP-102');
    });

    test('Scenario 8: Search matching helper correctly finds employee and descendants', () {
      final emp = createEmp(id: 1, empId: 'EMP-001', name: 'Alice Smith', dept: 'Engineering', desig: 'Senior Lead');
      final node = HierarchyNode(employee: emp, bandCode: 'Band 5', bandTitle: 'Senior Management');

      expect(node.matchesQuery('Alice'), isTrue);
      expect(node.matchesQuery('EMP-001'), isTrue);
      expect(node.matchesQuery('Senior Lead'), isTrue);
      expect(node.matchesQuery('Engineering'), isTrue);
      expect(node.matchesQuery('Band 5'), isTrue);
      expect(node.matchesQuery('NonExistent'), isFalse);
    });
  });
}
