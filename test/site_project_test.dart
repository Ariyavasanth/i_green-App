import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/projects/domain/models/project_document.dart';
import 'package:flutter_application_1/features/projects/domain/models/site_project.dart';
import 'package:flutter_application_1/features/projects/domain/services/project_code_generator.dart';

void main() {
  group('SiteProject Domain Model Tests', () {
    test('Correctly serializes and deserializes SiteProject to/from JSON map', () {
      final now = DateTime(2026, 9, 23, 10, 0);
      final project = SiteProject(
        id: 'proj_123',
        employeeName: 'Ariya Vasanth',
        employeeId: 'EMP-0002',
        clientName: 'Acme Infra Ltd',
        clientId: 42,
        generalDetails: 'Pipeline construction and site trenching',
        place: 'Chennai',
        generalCode: 'GC-ACME-CHE-260901',
        subOrOwn: 'Own',
        state: 'Tamil Nadu',
        district: 'Chennai',
        area: 'Porur',
        projectCode: 'PRJ-OWN-ACM-TN-CHE-001',
        tenderType: 'Open Tender',
        tenderSpecRemark: 'Standard spec documents attached',
        tenderSpecDocuments: [
          ProjectDocument(
            name: 'spec_v1.pdf',
            size: 1024 * 500,
            downloadUrl: 'https://storage.example.com/spec_v1.pdf',
            category: 'tender_spec',
            uploadedAt: now,
          ),
        ],
        assignedToEmployeeName: 'Saravanan G S',
        assignedToEmployeeId: 'EMP-0001',
        openingDate: DateTime(2026, 9, 25),
        openingDateRemark: 'Opening at 10 AM',
        closingDate: DateTime(2026, 10, 25),
        closingDateRemark: 'Closing at 5 PM',
        bqrRemark: 'BQR clearance approved',
        bqrDocuments: const [],
        emdRemark: 'EMD Exemption certificate attached',
        emdDocuments: const [],
        status: 'Active',
        createdAt: now,
        updatedAt: now,
        createdBy: 'Admin User',
      );

      final json = project.toJson();
      expect(json['id'], 'proj_123');
      expect(json['employee_name'], 'Ariya Vasanth');
      expect(json['client_name'], 'Acme Infra Ltd');
      expect(json['general_code'], 'GC-ACME-CHE-260901');
      expect(json['project_code'], 'PRJ-OWN-ACM-TN-CHE-001');
      expect(json['tender_type'], 'Open Tender');
      expect(json['tender_spec_documents'], hasLength(1));

      final restored = SiteProject.fromJson(json, docId: 'proj_123');
      expect(restored.id, 'proj_123');
      expect(restored.employeeName, 'Ariya Vasanth');
      expect(restored.clientName, 'Acme Infra Ltd');
      expect(restored.generalCode, 'GC-ACME-CHE-260901');
      expect(restored.projectCode, 'PRJ-OWN-ACM-TN-CHE-001');
      expect(restored.tenderType, 'Open Tender');
      expect(restored.tenderSpecDocuments, hasLength(1));
      expect(restored.tenderSpecDocuments.first.name, 'spec_v1.pdf');
    });

    test('SiteProject handles multiple assigned employees and retains legacy compatibility', () {
      final now = DateTime(2026, 9, 23);
      final project = SiteProject(
        id: 'proj_multi',
        employeeName: 'Admin',
        clientName: 'Client X',
        generalDetails: 'Multi-assignment test',
        place: 'Coimbatore',
        generalCode: 'GC-CLI-COI-001',
        subOrOwn: 'Own',
        state: 'Tamil Nadu',
        district: 'Coimbatore',
        area: 'Peelamedu',
        projectCode: 'PRJ-OWN-CLI-TN-COI-001',
        tenderType: 'Limited',
        assignedToEmployeeNames: const ['Sandya K', 'Saravanan G S'],
        assignedToEmployeeIds: const ['EMP-5403', 'EMP-0001'],
        openingDate: now,
        closingDate: now.add(const Duration(days: 30)),
        status: 'Active',
        createdAt: now,
        updatedAt: now,
        createdBy: 'Admin',
      );

      // Verify getters join the lists
      expect(project.assignedToEmployeeName, 'Sandya K, Saravanan G S');
      expect(project.assignedToEmployeeId, 'EMP-5403, EMP-0001');

      // Verify JSON serialization
      final json = project.toJson();
      expect(json['assigned_to_employee_names'], ['Sandya K', 'Saravanan G S']);
      expect(json['assigned_to_employee_ids'], ['EMP-5403', 'EMP-0001']);
      expect(json['assigned_to_employee_name'], 'Sandya K, Saravanan G S');

      // Verify deserialization
      final restored = SiteProject.fromJson(json, docId: 'proj_multi');
      expect(restored.assignedToEmployeeNames, ['Sandya K', 'Saravanan G S']);
      expect(restored.assignedToEmployeeIds, ['EMP-5403', 'EMP-0001']);

      // Verify backward compatibility with legacy single employee json
      final legacyJson = {
        'id': 'proj_legacy',
        'employee_name': 'Admin',
        'client_name': 'Legacy Client',
        'general_code': 'GC-LEG-001',
        'project_code': 'PRJ-LEG-001',
        'tender_type': 'Open',
        'assigned_to_employee_name': 'Single Employee',
        'assigned_to_employee_id': 'EMP-9999',
        'status': 'Active',
      };
      final restoredLegacy = SiteProject.fromJson(legacyJson, docId: 'proj_legacy');
      expect(restoredLegacy.assignedToEmployeeNames, ['Single Employee']);
      expect(restoredLegacy.assignedToEmployeeIds, ['EMP-9999']);
      expect(restoredLegacy.assignedToEmployeeName, 'Single Employee');
      expect(restoredLegacy.updatedBy, isNull);
      expect(restoredLegacy.updatedByName, isNull);
    });

    test('SiteProject serializes and deserializes updatedBy and updatedByName correctly', () {
      final now = DateTime(2026, 10, 29, 2, 15);
      final project = SiteProject(
        id: 'proj_updated',
        employeeName: 'Admin',
        clientName: 'Client Y',
        generalCode: 'GC-CLI-002',
        projectCode: 'PRJ-OWN-CLI-TN-002',
        createdAt: now,
        updatedAt: now,
        createdBy: 'Admin User',
        updatedBy: 'EMP-0005',
        updatedByName: 'Ravi Kumar',
      );

      final json = project.toJson();
      expect(json['updated_by'], 'EMP-0005');
      expect(json['updated_by_name'], 'Ravi Kumar');

      final restored = SiteProject.fromJson(json, docId: 'proj_updated');
      expect(restored.updatedBy, 'EMP-0005');
      expect(restored.updatedByName, 'Ravi Kumar');

      final copied = restored.copyWith(
        updatedBy: 'EMP-0009',
        updatedByName: 'Priya S',
      );
      expect(copied.updatedBy, 'EMP-0009');
      expect(copied.updatedByName, 'Priya S');
    });

    test('SiteProject handles Approximate Project Value and Actual Project Value correctly', () {
      final now = DateTime(2026, 10, 30);
      final project = SiteProject(
        id: 'proj_values',
        employeeName: 'Admin',
        clientName: 'SHRISHTI POWER',
        generalCode: 'GC-SHR-001',
        projectCode: 'PRJ-SUB-001',
        approximateProjectValue: 2500000.0,
        actualProjectValue: 2000000.0,
        createdAt: now,
        updatedAt: now,
      );

      final json = project.toJson();
      expect(json['approximate_project_value'], 2500000.0);
      expect(json['actual_project_value'], 2000000.0);

      // Deserialization restores both values
      final restored = SiteProject.fromJson(json, docId: 'proj_values');
      expect(restored.approximateProjectValue, 2500000.0);
      expect(restored.actualProjectValue, 2000000.0);

      // Verify independence: Updating actual does not alter approximate
      final updatedActualOnly = restored.copyWith(actualProjectValue: 2200000.0);
      expect(updatedActualOnly.approximateProjectValue, 2500000.0);
      expect(updatedActualOnly.actualProjectValue, 2200000.0);

      // Verify independence: Updating approximate does not alter actual
      final updatedApproxOnly = restored.copyWith(approximateProjectValue: 2800000.0);
      expect(updatedApproxOnly.approximateProjectValue, 2800000.0);
      expect(updatedApproxOnly.actualProjectValue, 2000000.0);

      // Legacy project without value fields defaults safely to 0.0 without errors
      final legacyJson = Map<String, dynamic>.from(json)
        ..remove('approximate_project_value')
        ..remove('actual_project_value');
      final legacyRestored = SiteProject.fromJson(legacyJson, docId: 'legacy_proj');
      expect(legacyRestored.approximateProjectValue, 0.0);
      expect(legacyRestored.actualProjectValue, 0.0);
    });

    test('SiteProject serializes and deserializes assignment details correctly', () {
      final assignedDate = DateTime(2026, 11, 6, 10, 30);
      final project = SiteProject(
        id: 'proj_assign',
        employeeName: 'Admin',
        clientName: 'Client X',
        generalDetails: 'Assignment test',
        place: 'Chennai',
        generalCode: 'GC-001',
        subOrOwn: 'Own',
        state: 'Tamil Nadu',
        district: 'Chennai',
        area: 'Guindy',
        projectCode: 'PRJ-001',
        tenderType: 'Open',
        assignedToEmployeeName: 'John Doe',
        assignedToEmployeeId: 'EMP-1001',
        assignedToDesignation: 'Project Manager',
        assignedToContactNumber: '9876543210',
        assignedToEmail: 'john.doe@example.com',
        assignedDate: assignedDate,
      );

      final json = project.toJson();
      expect(json['assigned_to_employee_name'], 'John Doe');
      expect(json['assigned_to_employee_id'], 'EMP-1001');
      expect(json['assigned_to_designation'], 'Project Manager');
      expect(json['assigned_to_contact_number'], '9876543210');
      expect(json['assigned_to_email'], 'john.doe@example.com');
      expect(json['assigned_date'], assignedDate.toIso8601String());

      final restored = SiteProject.fromJson(json, docId: 'proj_assign');
      expect(restored.assignedToEmployeeName, 'John Doe');
      expect(restored.assignedToEmployeeId, 'EMP-1001');
      expect(restored.assignedToDesignation, 'Project Manager');
      expect(restored.assignedToContactNumber, '9876543210');
      expect(restored.assignedToEmail, 'john.doe@example.com');
      expect(restored.assignedDate, assignedDate);
    });

    test('SiteProject serializes and deserializes workOrderDocuments correctly', () {
      final now = DateTime(2026, 11, 6);
      final project = SiteProject(
        id: 'proj_wo',
        employeeName: 'Admin',
        clientName: 'Client Y',
        generalDetails: 'Work order document test',
        place: 'Chennai',
        generalCode: 'GC-002',
        subOrOwn: 'Main',
        state: 'Tamil Nadu',
        district: 'Chennai',
        area: 'Ambattur',
        projectCode: 'PRJ-002',
        tenderType: 'Open',
        workOrderRemark: 'Approved WO #WO-2026-99',
        workOrderDocuments: [
          ProjectDocument(
            name: 'work_order_contract.pdf',
            size: 204800,
            downloadUrl: 'https://storage.googleapis.com/test-bucket/work_order_contract.pdf',
            category: 'work_order',
            uploadedAt: now,
          ),
        ],
      );

      final json = project.toJson();
      expect(json['work_order_remark'], 'Approved WO #WO-2026-99');
      expect(json['work_order_documents'], hasLength(1));
      expect(json['work_order_documents'].first['name'], 'work_order_contract.pdf');

      final restored = SiteProject.fromJson(json, docId: 'proj_wo');
      expect(restored.workOrderRemark, 'Approved WO #WO-2026-99');
      expect(restored.workOrderDocuments, hasLength(1));
      expect(restored.workOrderDocuments.first.name, 'work_order_contract.pdf');
      expect(restored.workOrderDocuments.first.downloadUrl,
          'https://storage.googleapis.com/test-bucket/work_order_contract.pdf');
    });

    test('ProjectCodeGenerator generates valid General Code', () {
      final code = ProjectCodeGenerator.generateGeneralCode(
        clientName: 'AE POWER',
        details: 'asdfsdf',
        place: 'chennai',
        sequenceNumber: 1,
      );

      expect(code, 'AE POWER-asdfsdf-chennai-01');
    });

    test('ProjectCodeGenerator generates valid Project Code', () {
      final code = ProjectCodeGenerator.generateProjectCode(
        clientName: 'SHRISHTI POWER',
        subOrOwn: 'SUB',
        state: 'Tamil Nadu',
        district: 'Chengalpattu',
        area: '250mm HDPE-Siruseri',
        sequenceNumber: 2,
      );

      expect(code.startsWith('SHRISHTI POWER-SUB-'), isTrue);
      expect(code.contains('-2-TN-Chengalpattu-250mm HDPE-Siruseri'), isTrue);
    });

    test('ProjectCodeGenerator handles empty or fallback inputs gracefully', () {
      final genCode = ProjectCodeGenerator.generateGeneralCode(
        clientName: '',
        place: '',
      );
      expect(genCode, 'GEN-DETAILS-LOC-01');

      final prjCode = ProjectCodeGenerator.generateProjectCode(
        clientName: '',
        subOrOwn: 'Sub',
        state: '',
        district: '',
      );
      expect(prjCode.startsWith('CLI-SUB-'), isTrue);
      expect(prjCode.endsWith('-1-IN-DIS-AREA'), isTrue);
    });
  });
}
