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
    });

    test('ProjectCodeGenerator generates valid General Code', () {
      final code = ProjectCodeGenerator.generateGeneralCode(
        clientName: 'Larsen & Toubro',
        place: 'Chennai',
        sequenceNumber: 1,
      );

      expect(code.startsWith('GC-'), isTrue);
      expect(code.contains('CHE'), isTrue);
    });

    test('ProjectCodeGenerator generates valid Project Code', () {
      final code = ProjectCodeGenerator.generateProjectCode(
        clientName: 'L&T Infra',
        subOrOwn: 'Own',
        state: 'Tamil Nadu',
        district: 'Chennai',
        area: 'Porur',
        sequenceNumber: 1,
      );

      expect(code.startsWith('PRJ-OWN-'), isTrue);
      expect(code.endsWith('-001'), isTrue);
    });

    test('ProjectCodeGenerator handles empty or special character inputs gracefully', () {
      final genCode = ProjectCodeGenerator.generateGeneralCode(
        clientName: '!@#\$%',
        place: '',
      );
      expect(genCode.startsWith('GC-GEN-LOC-'), isTrue);

      final prjCode = ProjectCodeGenerator.generateProjectCode(
        clientName: '',
        subOrOwn: 'Sub',
        state: '',
        district: '',
      );
      expect(prjCode.startsWith('PRJ-SUB-CLI-IN-DIS-'), isTrue);
    });
  });
}
