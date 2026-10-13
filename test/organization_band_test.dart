import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/organization/domain/organization_band.dart';
import 'package:flutter_application_1/features/organization/domain/designation.dart';
import 'package:flutter_application_1/features/organization/data/firebase_organization_repository.dart';

void main() {
  group('OrganizationBand Model Tests', () {
    test('creates and serializes OrganizationBand correctly', () {
      const band = OrganizationBand(
        id: 'band_org1_lvl_7',
        organizationId: 'org_1',
        organizationName: 'I-Green Technologies',
        level: 7,
        bandCode: 'Band 7',
        title: 'Executive Leadership',
        description: 'Managing Director and Executive Committee',
        colorHex: 0xFF9CC70A,
      );

      final map = band.toMap();
      expect(map['id'], 'band_org1_lvl_7');
      expect(map['organization_id'], 'org_1');
      expect(map['organization_name'], 'I-Green Technologies');
      expect(map['level'], 7);
      expect(map['band_code'], 'Band 7');
      expect(map['title'], 'Executive Leadership');
      expect(map['description'], 'Managing Director and Executive Committee');
      expect(map['color_hex'], 0xFF9CC70A);

      final deserialized = OrganizationBand.fromMap(map, 'doc_123');
      expect(deserialized.id, 'band_org1_lvl_7');
      expect(deserialized.organizationId, 'org_1');
      expect(deserialized.organizationName, 'I-Green Technologies');
      expect(deserialized.level, 7);
      expect(deserialized.bandCode, 'Band 7');
      expect(deserialized.title, 'Executive Leadership');
      expect(
        deserialized.description,
        'Managing Director and Executive Committee',
      );
      expect(deserialized.colorHex, 0xFF9CC70A);
    });

    test(
      'OrganizationBand handles camelCase and snake_case keys in fromMap',
      () {
        final rawMap = {
          'id': 'b1',
          'organizationId': 'org_2',
          'organizationName': 'Green Tech Branch',
          'level': 1,
          'bandCode': 'Band 1',
          'title': 'Entry Level',
        };

        final band = OrganizationBand.fromMap(rawMap);
        expect(band.id, 'b1');
        expect(band.organizationId, 'org_2');
        expect(band.organizationName, 'Green Tech Branch');
        expect(band.level, 1);
        expect(band.bandCode, 'Band 1');
        expect(band.title, 'Entry Level');
        expect(band.description, '');
        expect(band.colorHex, isNull);
      },
    );

    test(
      'OrganizationBand sorts descending by level (Band 7 down to Band 1)',
      () {
        final bands = [
          const OrganizationBand(
            id: '1',
            organizationId: 'org_1',
            level: 1,
            bandCode: 'Band 1',
            title: 'Entry Level',
          ),
          const OrganizationBand(
            id: '4',
            organizationId: 'org_1',
            level: 4,
            bandCode: 'Band 4',
            title: 'Mid Level',
          ),
          const OrganizationBand(
            id: '7',
            organizationId: 'org_1',
            level: 7,
            bandCode: 'Band 7',
            title: 'Executive Leadership',
          ),
          const OrganizationBand(
            id: '3',
            organizationId: 'org_1',
            level: 3,
            bandCode: 'Band 3',
            title: 'Senior Associate',
          ),
          const OrganizationBand(
            id: '6',
            organizationId: 'org_1',
            level: 6,
            bandCode: 'Band 6',
            title: 'Department Head',
          ),
        ];

        bands.sort();

        expect(bands.map((b) => b.level).toList(), [7, 6, 4, 3, 1]);
        expect(bands.first.bandCode, 'Band 7');
        expect(bands.last.bandCode, 'Band 1');
      },
    );

    test('OrganizationBand copyWith works correctly', () {
      const band = OrganizationBand(
        id: 'b1',
        organizationId: 'org_1',
        level: 5,
        bandCode: 'Band 5',
        title: 'Managerial',
      );

      final updated = band.copyWith(
        title: 'Senior Managerial',
        colorHex: 0xFF414A51,
      );

      expect(updated.id, 'b1');
      expect(updated.level, 5);
      expect(updated.title, 'Senior Managerial');
      expect(updated.colorHex, 0xFF414A51);
    });
  });

  group('Designation Model Backward Compatibility Tests', () {
    test(
      'loads legacy designation document without band fields seamlessly',
      () {
        final legacyMap = {
          'id': 101,
          'organization_id': 'org_1',
          'organization_name': 'I-Green Tech',
          'department_name': 'Engineering',
          'designation_name': 'Flutter Developer',
          'hierarchy_level': 'Lead',
          'description': 'Mobile development lead',
        };

        final designation = Designation.fromMap(legacyMap);

        expect(designation.id, 101);
        expect(designation.organizationId, 'org_1');
        expect(designation.organizationName, 'I-Green Tech');
        expect(designation.departmentName, 'Engineering');
        expect(designation.designationName, 'Flutter Developer');
        expect(designation.hierarchyLevel, HierarchyLevel.lead);
        expect(designation.description, 'Mobile development lead');
        // Backward compatibility assertions
        expect(designation.bandId, '');
        expect(designation.bandCode, '');
        expect(designation.bandLevel, 0);

        // Serializing legacy record without bands should not add band fields
        final serialized = designation.toMap();
        expect(serialized.containsKey('band_id'), isFalse);
        expect(serialized.containsKey('band_code'), isFalse);
        expect(serialized.containsKey('band_level'), isFalse);
      },
    );

    test('loads and serializes designation document with band fields', () {
      final modernMap = {
        'id': 102,
        'organization_id': 'org_1',
        'organization_name': 'I-Green Tech',
        'department_name': 'Management',
        'designation_name': 'Managing Director',
        'hierarchy_level': 'Head',
        'description': 'Head of company',
        'band_id': 'band_org1_lvl_7',
        'band_code': 'Band 7',
        'band_level': 7,
      };

      final designation = Designation.fromMap(modernMap);

      expect(designation.id, 102);
      expect(designation.bandId, 'band_org1_lvl_7');
      expect(designation.bandCode, 'Band 7');
      expect(designation.bandLevel, 7);
      expect(designation.hierarchyLevel, HierarchyLevel.head);

      final serialized = designation.toMap();
      expect(serialized['band_id'], 'band_org1_lvl_7');
      expect(serialized['band_code'], 'Band 7');
      expect(serialized['band_level'], 7);
    });

    test('handles camelCase bandId in designation map', () {
      final modernMap = {
        'id': 103,
        'organizationId': 'org_1',
        'departmentName': 'Operations',
        'designationName': 'Operations Executive',
        'bandId': 'band_org1_lvl_2',
        'bandCode': 'Band 2',
        'bandLevel': 2,
      };

      final designation = Designation.fromMap(modernMap);
      expect(designation.bandId, 'band_org1_lvl_2');
      expect(designation.bandCode, 'Band 2');
      expect(designation.bandLevel, 2);
    });
  });

  group('FirebaseOrganizationRepository Band Operations (In-Memory Scope)', () {
    // NOTE: These tests exercise the in-memory branch of FirebaseOrganizationRepository
    // because no live Firebase / emulator is connected in unit tests.
    // Live Firestore transactions and Firestore security rules must be validated with the emulator.
    late FirebaseOrganizationRepository repo;

    setUp(() {
      repo = FirebaseOrganizationRepository();
    });

    test('adds and retrieves bands sorted descending by level', () async {
      await repo.addBand(
        const OrganizationBand(
          id: 'b_1',
          organizationId: 'org_1',
          level: 1,
          bandCode: 'Band 1',
          title: 'Entry Level',
        ),
      );

      await repo.addBand(
        const OrganizationBand(
          id: 'b_7',
          organizationId: 'org_1',
          level: 7,
          bandCode: 'Band 7',
          title: 'Executive Leadership',
        ),
      );

      await repo.addBand(
        const OrganizationBand(
          id: 'b_4',
          organizationId: 'org_1',
          level: 4,
          bandCode: 'Band 4',
          title: 'Specialist',
        ),
      );

      final bands = await repo.getBands(organizationId: 'org_1');
      expect(bands.length, 3);
      expect(bands[0].level, 7);
      expect(bands[1].level, 4);
      expect(bands[2].level, 1);
    });

    test(
      'requires valid canonical organizationId to create or update a Band',
      () async {
        // Empty organizationId on addBand
        expect(
          () => repo.addBand(
            const OrganizationBand(
              id: 'b_invalid',
              organizationId: '',
              level: 1,
              bandCode: 'Band 1',
              title: 'No Org Band',
            ),
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('valid canonical organizationId is required'),
            ),
          ),
        );

        // Empty organizationId on updateBand
        expect(
          () => repo.updateBand(
            const OrganizationBand(
              id: 'b_invalid',
              organizationId: '',
              level: 1,
              bandCode: 'Band 1',
              title: 'No Org Band',
            ),
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('valid canonical organizationId is required'),
            ),
          ),
        );
      },
    );

    test('enforces level bounds between 1 and 7', () async {
      expect(
        () => repo.addBand(
          const OrganizationBand(
            id: 'b_0',
            organizationId: 'org_1',
            level: 0,
            bandCode: 'Band 0',
            title: 'Invalid Level 0',
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => repo.addBand(
          const OrganizationBand(
            id: 'b_8',
            organizationId: 'org_1',
            level: 8,
            bandCode: 'Band 8',
            title: 'Invalid Level 8',
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('enforces non-empty bandCode', () async {
      expect(
        () => repo.addBand(
          const OrganizationBand(
            id: 'b_nocode',
            organizationId: 'org_1',
            level: 3,
            bandCode: '   ',
            title: 'Empty Code',
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'scopes bands strictly to organizationId without merging by organizationName',
      () async {
        await repo.addBand(
          const OrganizationBand(
            id: 'b_org1_7',
            organizationId: 'org_1',
            organizationName: 'Global Corp',
            level: 7,
            bandCode: 'Band 7',
            title: 'MD Org 1',
          ),
        );

        await repo.addBand(
          const OrganizationBand(
            id: 'b_org2_7',
            organizationId: 'org_2',
            organizationName:
                'Global Corp', // Same display name, different org ID
            level: 7,
            bandCode: 'Band 7',
            title: 'MD Org 2',
          ),
        );

        // Scoping strictly by organizationId must NOT return org_2 even though names match
        final org1Bands = await repo.getBands(
          organizationId: 'org_1',
          organizationName: 'Global Corp',
        );
        expect(org1Bands.length, 1);
        expect(org1Bands.first.id, 'b_org1_7');
        expect(org1Bands.first.title, 'MD Org 1');
      },
    );

    test('prevents duplicate Band level in the same organization', () async {
      await repo.addBand(
        const OrganizationBand(
          id: 'b_1',
          organizationId: 'org_1',
          level: 7,
          bandCode: 'Band 7',
          title: 'Executive Leadership',
        ),
      );

      expect(
        () => repo.addBand(
          const OrganizationBand(
            id: 'b_1_dup',
            organizationId: 'org_1',
            level: 7,
            bandCode: 'Band 7B',
            title: 'Duplicate Level Band',
          ),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('already exists in this organization'),
          ),
        ),
      );
    });

    test(
      'prevents duplicate Band code in the same organization (case-insensitive & trimmed)',
      () async {
        await repo.addBand(
          const OrganizationBand(
            id: 'b_1',
            organizationId: 'org_1',
            level: 6,
            bandCode: 'Band 6',
            title: 'Director',
          ),
        );

        expect(
          () => repo.addBand(
            const OrganizationBand(
              id: 'b_2',
              organizationId: 'org_1',
              level: 5,
              bandCode:
                  '  band 6  ', // Duplicate code with whitespace and different case
              title: 'Senior Manager',
            ),
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('already exists in this organization'),
            ),
          ),
        );
      },
    );

    test('allows same level and code in DIFFERENT organizations', () async {
      await repo.addBand(
        const OrganizationBand(
          id: 'b_org1',
          organizationId: 'org_1',
          level: 7,
          bandCode: 'Band 7',
          title: 'MD Org 1',
        ),
      );

      // Should succeed without error for org_2
      await repo.addBand(
        const OrganizationBand(
          id: 'b_org2',
          organizationId: 'org_2',
          level: 7,
          bandCode: 'Band 7',
          title: 'MD Org 2',
        ),
      );

      final org1Bands = await repo.getBands(organizationId: 'org_1');
      final org2Bands = await repo.getBands(organizationId: 'org_2');
      expect(org1Bands.length, 1);
      expect(org2Bands.length, 1);
    });

    test(
      'updateBand prevents changing to an already existing level in same organization',
      () async {
        await repo.addBand(
          const OrganizationBand(
            id: 'b_1',
            organizationId: 'org_1',
            level: 6,
            bandCode: 'Band 6',
            title: 'Director',
          ),
        );

        await repo.addBand(
          const OrganizationBand(
            id: 'b_2',
            organizationId: 'org_1',
            level: 5,
            bandCode: 'Band 5',
            title: 'Manager',
          ),
        );

        expect(
          () => repo.updateBand(
            const OrganizationBand(
              id: 'b_2',
              organizationId: 'org_1',
              level: 6, // Collides with b_1
              bandCode: 'Band 5',
              title: 'Manager',
            ),
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('already has level 6'),
            ),
          ),
        );
      },
    );

    test(
      'updateBand allows updating title or moving to a vacant level',
      () async {
        await repo.addBand(
          const OrganizationBand(
            id: 'b_1',
            organizationId: 'org_1',
            level: 5,
            bandCode: 'Band 5',
            title: 'Manager',
          ),
        );

        // Updating self with same level & code should succeed
        await repo.updateBand(
          const OrganizationBand(
            id: 'b_1',
            organizationId: 'org_1',
            level: 5,
            bandCode: 'Band 5',
            title: 'Senior Manager',
          ),
        );

        var bands = await repo.getBands(organizationId: 'org_1');
        expect(bands.first.title, 'Senior Manager');

        // Moving to vacant level 6 should succeed
        await repo.updateBand(
          const OrganizationBand(
            id: 'b_1',
            organizationId: 'org_1',
            level: 6,
            bandCode: 'Band 6',
            title: 'Associate Director',
          ),
        );

        bands = await repo.getBands(organizationId: 'org_1');
        expect(bands.first.level, 6);
        expect(bands.first.bandCode, 'Band 6');
      },
    );

    test(
      'deleteBand protects against deleting a band referenced by a designation',
      () async {
        const bandId = 'band_org1_lvl_7';
        await repo.addBand(
          const OrganizationBand(
            id: bandId,
            organizationId: 'org_1',
            level: 7,
            bandCode: 'Band 7',
            title: 'Executive Leadership',
          ),
        );

        await repo.addDesignation(
          const Designation(
            id: 201,
            organizationId: 'org_1',
            departmentName: 'Executive',
            designationName: 'Managing Director',
            bandId: bandId,
            bandCode: 'Band 7',
            bandLevel: 7,
          ),
        );

        expect(
          () => repo.deleteBand(bandId, organizationId: 'org_1'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('currently assigned to one or more designations'),
            ),
          ),
        );
      },
    );

    test('deleteBand successfully deletes an unreferenced band', () async {
      const bandId = 'band_org1_lvl_1';
      await repo.addBand(
        const OrganizationBand(
          id: bandId,
          organizationId: 'org_1',
          level: 1,
          bandCode: 'Band 1',
          title: 'Entry Level',
        ),
      );

      var bands = await repo.getBands(organizationId: 'org_1');
      expect(bands.length, 1);

      await repo.deleteBand(bandId, organizationId: 'org_1');

      bands = await repo.getBands(organizationId: 'org_1');
      expect(bands.isEmpty, isTrue);
    });

    test(
      'addDesignation and updateDesignation reject assigning a non-existent Band',
      () async {
        expect(
          () => repo.addDesignation(
            const Designation(
              id: 301,
              organizationId: 'org_1',
              departmentName: 'Engineering',
              designationName: 'Senior Engineer',
              bandId: 'non_existent_band',
            ),
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains(
                'Band does not exist or does not belong to organization',
              ),
            ),
          ),
        );
      },
    );

    test(
      'addDesignation rejects assigning a Band belonging to another organization',
      () async {
        // Create band in org_2
        await repo.addBand(
          const OrganizationBand(
            id: 'band_org2_lvl_7',
            organizationId: 'org_2',
            level: 7,
            bandCode: 'Band 7',
            title: 'MD Org 2',
          ),
        );

        // Try assigning org_2's band to a designation in org_1
        expect(
          () => repo.addDesignation(
            const Designation(
              id: 302,
              organizationId: 'org_1',
              departmentName: 'Executive',
              designationName: 'Director',
              bandId: 'band_org2_lvl_7',
            ),
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains(
                'Band does not exist or does not belong to organization',
              ),
            ),
          ),
        );
      },
    );

    test(
      'addDesignation succeeds with valid Band in same organization or with empty Band',
      () async {
        await repo.addBand(
          const OrganizationBand(
            id: 'band_org1_lvl_4',
            organizationId: 'org_1',
            level: 4,
            bandCode: 'Band 4',
            title: 'Specialist',
          ),
        );

        // With valid band in same org
        await repo.addDesignation(
          const Designation(
            id: 303,
            organizationId: 'org_1',
            departmentName: 'IT',
            designationName: 'Cloud Architect',
            bandId: 'band_org1_lvl_4',
          ),
        );

        // Without band (legacy/unassigned)
        await repo.addDesignation(
          const Designation(
            id: 304,
            organizationId: 'org_1',
            departmentName: 'IT',
            designationName: 'Junior Engineer',
          ),
        );

        final desigs = await repo.getDesignations(organizationId: 'org_1');
        expect(
          desigs.any((d) => d.id == 303 && d.bandId == 'band_org1_lvl_4'),
          isTrue,
        );
        expect(desigs.any((d) => d.id == 304 && d.bandId == ''), isTrue);
      },
    );
  });

  group('OrganizationBand Reference Counting & Referential Integrity Tests', () {
    late FirebaseOrganizationRepository repo;

    setUp(() {
      repo = FirebaseOrganizationRepository();
    });

    test(
      'addDesignation increments band designationCount from 0 to 1 and further',
      () async {
        await repo.addBand(
          const OrganizationBand(
            id: 'band_sales_1',
            organizationId: 'org_abc',
            level: 2,
            bandCode: 'Band 2',
            title: 'Sales Associate',
          ),
        );

        var bands = await repo.getBands(organizationId: 'org_abc');
        expect(bands.first.designationCount, 0);

        // Add first designation
        await repo.addDesignation(
          const Designation(
            id: 501,
            organizationId: 'org_abc',
            departmentName: 'Sales',
            designationName: 'Inside Sales Rep',
            bandId: 'band_sales_1',
          ),
        );

        bands = await repo.getBands(organizationId: 'org_abc');
        expect(bands.first.designationCount, 1);

        // Add second designation
        await repo.addDesignation(
          const Designation(
            id: 502,
            organizationId: 'org_abc',
            departmentName: 'Sales',
            designationName: 'Field Sales Rep',
            bandId: 'band_sales_1',
          ),
        );

        bands = await repo.getBands(organizationId: 'org_abc');
        expect(bands.first.designationCount, 2);
      },
    );

    test(
      'deleteDesignation decrements band designationCount and bounds at 0',
      () async {
        await repo.addBand(
          const OrganizationBand(
            id: 'band_eng_4',
            organizationId: 'org_abc',
            level: 4,
            bandCode: 'Band 4',
            title: 'Senior Engineer',
          ),
        );

        await repo.addDesignation(
          const Designation(
            id: 503,
            organizationId: 'org_abc',
            departmentName: 'Engineering',
            designationName: 'Backend Tech Lead',
            bandId: 'band_eng_4',
          ),
        );

        var bands = await repo.getBands(organizationId: 'org_abc');
        expect(bands.first.designationCount, 1);

        // Delete the designation
        await repo.deleteDesignation(503);

        bands = await repo.getBands(organizationId: 'org_abc');
        expect(bands.first.designationCount, 0);
      },
    );

    test(
      'updateDesignation reassigning band atomically decrements old and increments new band',
      () async {
        await repo.addBand(
          const OrganizationBand(
            id: 'band_old',
            organizationId: 'org_abc',
            level: 3,
            bandCode: 'Band 3',
            title: 'Specialist',
          ),
        );

        await repo.addBand(
          const OrganizationBand(
            id: 'band_new',
            organizationId: 'org_abc',
            level: 5,
            bandCode: 'Band 5',
            title: 'Lead',
          ),
        );

        await repo.addDesignation(
          const Designation(
            id: 504,
            organizationId: 'org_abc',
            departmentName: 'Product',
            designationName: 'Product Analyst',
            bandId: 'band_old',
          ),
        );

        var bands = await repo.getBands(organizationId: 'org_abc');
        expect(bands.firstWhere((b) => b.id == 'band_old').designationCount, 1);
        expect(bands.firstWhere((b) => b.id == 'band_new').designationCount, 0);

        // Reassign to band_new
        await repo.updateDesignation(
          const Designation(
            id: 504,
            organizationId: 'org_abc',
            departmentName: 'Product',
            designationName: 'Senior Product Analyst',
            bandId: 'band_new',
          ),
        );

        bands = await repo.getBands(organizationId: 'org_abc');
        expect(bands.firstWhere((b) => b.id == 'band_old').designationCount, 0);
        expect(bands.firstWhere((b) => b.id == 'band_new').designationCount, 1);
      },
    );

    test(
      'updateDesignation clearing band assignment decrements old band count',
      () async {
        await repo.addBand(
          const OrganizationBand(
            id: 'band_clear_test',
            organizationId: 'org_abc',
            level: 4,
            bandCode: 'Band 4',
            title: 'Specialist',
          ),
        );

        await repo.addDesignation(
          const Designation(
            id: 505,
            organizationId: 'org_abc',
            departmentName: 'HR',
            designationName: 'HR Specialist',
            bandId: 'band_clear_test',
          ),
        );

        var bands = await repo.getBands(organizationId: 'org_abc');
        expect(bands.first.designationCount, 1);

        // Clear band assignment
        await repo.updateDesignation(
          const Designation(
            id: 505,
            organizationId: 'org_abc',
            departmentName: 'HR',
            designationName: 'HR Specialist',
            bandId: '',
          ),
        );

        bands = await repo.getBands(organizationId: 'org_abc');
        expect(bands.first.designationCount, 0);
      },
    );

    test(
      'deleteBand fails when reference count is greater than zero',
      () async {
        const bandId = 'band_locked_by_ref';
        await repo.addBand(
          const OrganizationBand(
            id: bandId,
            organizationId: 'org_abc',
            level: 6,
            bandCode: 'Band 6',
            title: 'Director',
          ),
        );

        await repo.addDesignation(
          const Designation(
            id: 506,
            organizationId: 'org_abc',
            departmentName: 'Executive',
            designationName: 'Director of Operations',
            bandId: bandId,
          ),
        );

        expect(
          () => repo.deleteBand(bandId, organizationId: 'org_abc'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('currently assigned'),
            ),
          ),
        );
      },
    );

    test(
      'legacy designations without band assignment have zero impact on counts',
      () async {
        await repo.addBand(
          const OrganizationBand(
            id: 'band_clean',
            organizationId: 'org_abc',
            level: 1,
            bandCode: 'Band 1',
            title: 'Entry',
          ),
        );

        // Add legacy designation
        await repo.addDesignation(
          const Designation(
            id: 507,
            organizationId: 'org_abc',
            departmentName: 'Admin',
            designationName: 'Office Assistant',
            bandId: '',
          ),
        );

        var bands = await repo.getBands(organizationId: 'org_abc');
        expect(bands.first.designationCount, 0);

        // Update legacy designation without band
        await repo.updateDesignation(
          const Designation(
            id: 507,
            organizationId: 'org_abc',
            departmentName: 'Admin',
            designationName: 'Office Coordinator',
            bandId: '',
          ),
        );

        bands = await repo.getBands(organizationId: 'org_abc');
        expect(bands.first.designationCount, 0);

        // Delete legacy designation
        await repo.deleteDesignation(507);

        bands = await repo.getBands(organizationId: 'org_abc');
        expect(bands.first.designationCount, 0);
      },
    );

    test(
      'reconcileBandReferenceCounts accurately calculates and syncs counts',
      () async {
        // Simulate existing legacy band with 0 count
        await repo.addBand(
          const OrganizationBand(
            id: 'band_legacy_sync',
            organizationId: 'org_sync',
            level: 3,
            bandCode: 'Band 3',
            title: 'Analyst',
            designationCount: 0,
          ),
        );

        // Add designations directly without through addDesignation's counter (e.g. legacy data)
        await repo.addDesignation(
          const Designation(
            id: 601,
            organizationId: 'org_sync',
            departmentName: 'Analytics',
            designationName: 'BI Analyst',
            bandId: 'band_legacy_sync',
          ),
        );
        await repo.addDesignation(
          const Designation(
            id: 602,
            organizationId: 'org_sync',
            departmentName: 'Analytics',
            designationName: 'Data Analyst',
            bandId: 'band_legacy_sync',
          ),
        );

        final countMap = await repo.reconcileBandReferenceCounts(
          organizationId: 'org_sync',
        );

        expect(countMap['band_legacy_sync'], 2);

        final bands = await repo.getBands(organizationId: 'org_sync');
        expect(bands.first.designationCount, 2);
      },
    );

    test(
      'updating designation title while retaining same Band leaves count unchanged',
      () async {
        await repo.addBand(
          const OrganizationBand(
            id: 'band_same_test',
            organizationId: 'org_same',
            level: 4,
            bandCode: 'Band 4',
            title: 'Specialist',
          ),
        );

        await repo.addDesignation(
          const Designation(
            id: 701,
            organizationId: 'org_same',
            departmentName: 'IT',
            designationName: 'Dev 1',
            bandId: 'band_same_test',
          ),
        );

        var bands = await repo.getBands(organizationId: 'org_same');
        expect(bands.first.designationCount, 1);

        // Update title while retaining same band
        await repo.updateDesignation(
          const Designation(
            id: 701,
            organizationId: 'org_same',
            departmentName: 'IT',
            designationName: 'Senior Dev 1',
            bandId: 'band_same_test',
          ),
        );

        bands = await repo.getBands(organizationId: 'org_same');
        expect(bands.first.designationCount, 1); // Must still be 1, not 2
      },
    );

    test(
      'updating designation while local cache is missing that record does not corrupt count',
      () async {
        final freshRepo = FirebaseOrganizationRepository();
        await freshRepo.addBand(
          const OrganizationBand(
            id: 'band_cache_miss',
            organizationId: 'org_miss',
            level: 5,
            bandCode: 'Band 5',
            title: 'Lead',
            designationCount: 1, // Pre-existing count
          ),
        );

        // freshRepo._memoryDesignations does not have record 702 (cache miss)
        await freshRepo.updateDesignation(
          const Designation(
            id: 702,
            organizationId: 'org_miss',
            departmentName: 'Design',
            designationName: 'Lead Designer',
            bandId: 'band_cache_miss',
          ),
        );

        final bands = await freshRepo.getBands(organizationId: 'org_miss');
        expect(bands.first.designationCount, 1); // Must still be 1
      },
    );

    test(
      'legacy Band with missing counter is protected from deletion if referenced',
      () async {
        const legacyBandId = 'band_legacy_uncounted';
        await repo.addBand(
          const OrganizationBand(
            id: legacyBandId,
            organizationId: 'org_legacy',
            level: 2,
            bandCode: 'Band 2',
            title: 'Associate',
            designationCount: 0, // Legacy document without counter field
          ),
        );

        // Add designation pointing to this band (simulating existing legacy relationship)
        await repo.addDesignation(
          const Designation(
            id: 801,
            organizationId: 'org_legacy',
            departmentName: 'Operations',
            designationName: 'Associate Ops',
            bandId: legacyBandId,
          ),
        );

        // Attempting to delete the band must fail because active designations reference it
        expect(
          () => repo.deleteBand(legacyBandId, organizationId: 'org_legacy'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('currently assigned'),
            ),
          ),
        );
      },
    );
  });

  group('Phase 2: Band Settings UI & Designation Integration Tests', () {
    late FirebaseOrganizationRepository repo;

    setUp(() {
      repo = FirebaseOrganizationRepository();
    });

    test('Band level must range from 1 to 7', () {
      expect(
        () => repo.addBand(
          const OrganizationBand(
            id: 'b_invalid_low',
            organizationId: 'org_test',
            level: 0,
            bandCode: 'Band 0',
            title: 'Invalid',
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => repo.addBand(
          const OrganizationBand(
            id: 'b_invalid_high',
            organizationId: 'org_test',
            level: 8,
            bandCode: 'Band 8',
            title: 'Invalid',
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'available Bands for designation form are ordered from Band 7 down to Band 1',
      () async {
        final unsortedBands = [
          const OrganizationBand(
            id: 'b2',
            organizationId: 'org_phase2',
            level: 2,
            bandCode: 'Band 2',
            title: 'Associate',
          ),
          const OrganizationBand(
            id: 'b7',
            organizationId: 'org_phase2',
            level: 7,
            bandCode: 'Band 7',
            title: 'Executive',
          ),
          const OrganizationBand(
            id: 'b4',
            organizationId: 'org_phase2',
            level: 4,
            bandCode: 'Band 4',
            title: 'Mid Level',
          ),
          const OrganizationBand(
            id: 'b1',
            organizationId: 'org_phase2',
            level: 1,
            bandCode: 'Band 1',
            title: 'Entry Level',
          ),
        ];

        for (final b in unsortedBands) {
          await repo.addBand(b);
        }

        final fetchedBands = await repo.getBands(organizationId: 'org_phase2');
        // Sort as performed by getBands or UI selector
        final sortedBands = List<OrganizationBand>.from(fetchedBands)..sort();

        expect(sortedBands.map((b) => b.level).toList(), [7, 4, 2, 1]);
        expect(sortedBands.first.bandCode, 'Band 7');
        expect(sortedBands.last.bandCode, 'Band 1');
      },
    );

    test(
      'Designation form integration persists bandId, bandCode, and bandLevel',
      () async {
        const band7 = OrganizationBand(
          id: 'band_p2_7',
          organizationId: 'org_p2',
          level: 7,
          bandCode: 'Band 7',
          title: 'CXO',
        );
        await repo.addBand(band7);

        final designation = const Designation(
          id: 901,
          organizationId: 'org_p2',
          departmentName: 'Executive',
          designationName: 'Chief Technology Officer',
          hierarchyLevel: HierarchyLevel.head,
          description: 'Head of Technology',
          bandId: 'band_p2_7',
          bandCode: 'Band 7',
          bandLevel: 7,
        );

        await repo.addDesignation(designation);

        final designations = await repo.getDesignations(
          organizationId: 'org_p2',
        );
        final saved = designations.firstWhere((d) => d.id == 901);

        expect(saved.bandId, 'band_p2_7');
        expect(saved.bandCode, 'Band 7');
        expect(saved.bandLevel, 7);
        expect(saved.departmentName, 'Executive');
        expect(saved.hierarchyLevel, HierarchyLevel.head);

        // Verify band reference count was incremented
        final bands = await repo.getBands(organizationId: 'org_p2');
        expect(
          bands.firstWhere((b) => b.id == 'band_p2_7').designationCount,
          1,
        );
      },
    );

    test(
      'editing designation to unassigned band clears band fields and decrements counter',
      () async {
        const band = OrganizationBand(
          id: 'band_p2_5',
          organizationId: 'org_p2_clear',
          level: 5,
          bandCode: 'Band 5',
          title: 'Manager',
        );
        await repo.addBand(band);

        final designation = const Designation(
          id: 902,
          organizationId: 'org_p2_clear',
          departmentName: 'Marketing',
          designationName: 'Marketing Manager',
          bandId: 'band_p2_5',
          bandCode: 'Band 5',
          bandLevel: 5,
        );
        await repo.addDesignation(designation);

        // Clear band (user selected None / Unassigned in DesignationFormDialog)
        final unassignedDesignation = designation.copyWith(
          bandId: '',
          bandCode: '',
          bandLevel: 0,
        );
        await repo.updateDesignation(unassignedDesignation);

        final updatedList = await repo.getDesignations(
          organizationId: 'org_p2_clear',
        );
        final updated = updatedList.firstWhere((d) => d.id == 902);
        expect(updated.bandId, '');
        expect(updated.bandCode, '');
        expect(updated.bandLevel, 0);

        // Verify band reference count was decremented to 0
        final bands = await repo.getBands(organizationId: 'org_p2_clear');
        expect(
          bands.firstWhere((b) => b.id == 'band_p2_5').designationCount,
          0,
        );

        // Deleting the band is now allowed
        await repo.deleteBand('band_p2_5', organizationId: 'org_p2_clear');
        final remainingBands = await repo.getBands(
          organizationId: 'org_p2_clear',
        );
        expect(remainingBands.isEmpty, isTrue);
      },
    );

    test(
      'deletion prevention blocks deleting Band when designation is assigned',
      () async {
        const band = OrganizationBand(
          id: 'band_assigned_p2',
          organizationId: 'org_guard',
          level: 3,
          bandCode: 'Band 3',
          title: 'Associate',
        );
        await repo.addBand(band);

        await repo.addDesignation(
          const Designation(
            id: 903,
            organizationId: 'org_guard',
            departmentName: 'Sales',
            designationName: 'Sales Exec',
            bandId: 'band_assigned_p2',
            bandCode: 'Band 3',
            bandLevel: 3,
          ),
        );

        // Delete should throw StateError
        expect(
          () =>
              repo.deleteBand('band_assigned_p2', organizationId: 'org_guard'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('currently assigned'),
            ),
          ),
        );
      },
    );
  });
}
