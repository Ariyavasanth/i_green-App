import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/on_duty/domain/on_duty_assignment.dart';
import 'package:flutter_application_1/features/on_duty/domain/on_duty_site.dart';

void main() {
  group('On-Duty Postpone and Multi-Photo Proof Tests', () {
    test('OnDutySite supports 1 to 4 work photos proof with backward compatibility', () {
      final siteWithSinglePhoto = OnDutySite(
        siteId: '1',
        siteName: 'Client Site A',
        purpose: 'Audit',
        destination: 'Location A',
        workPhoto: 'photo_single_base64',
      );

      expect(siteWithSinglePhoto.effectiveWorkPhotos, equals(['photo_single_base64']));
      expect(siteWithSinglePhoto.workPhoto, equals('photo_single_base64'));

      final siteWithMultiplePhotos = OnDutySite(
        siteId: '2',
        siteName: 'Client Site B',
        purpose: 'Inspection',
        destination: 'Location B',
        workPhotos: ['photo_1', 'photo_2', 'photo_3', 'photo_4'],
      );

      expect(siteWithMultiplePhotos.effectiveWorkPhotos.length, equals(4));
      expect(siteWithMultiplePhotos.workPhoto, equals('photo_1'));

      final map = siteWithMultiplePhotos.toMap();
      expect(map['work_photos'], equals(['photo_1', 'photo_2', 'photo_3', 'photo_4']));
      expect(map['work_photo'], equals('photo_1'));

      final restored = OnDutySite.fromMap(map);
      expect(restored.effectiveWorkPhotos, equals(['photo_1', 'photo_2', 'photo_3', 'photo_4']));
      expect(restored.workPhoto, equals('photo_1'));
    });

    test('OnDutyAssignment correctly aggregates effectiveWorkPhotos', () {
      final site1 = OnDutySite(
        siteId: '1',
        siteName: 'Site 1',
        purpose: 'Setup',
        destination: 'Dest 1',
        status: 'COMPLETED',
        workPhotos: ['proof_p1', 'proof_p2'],
      );

      final assignment = OnDutyAssignment(
        id: 101,
        employeeId: 5,
        employeeName: 'John Doe',
        odType: 'Customer Visit',
        purpose: 'Site Visits',
        destination: 'Dest 1',
        sites: [site1],
        date: '13-09-2026',
        status: 'IN_PROGRESS',
        assignedBy: 'Admin',
        createdAt: '2026-09-13T10:00:00',
      );

      expect(assignment.effectiveWorkPhotos, equals(['proof_p1', 'proof_p2']));

      final map = assignment.toMap();
      final restored = OnDutyAssignment.fromMap(map);
      expect(restored.sites.first.effectiveWorkPhotos, equals(['proof_p1', 'proof_p2']));
    });

    test('OnDutyAssignment postpone resets status and updates date', () {
      final activeSite = OnDutySite(
        siteId: '1',
        siteName: 'Site 1',
        purpose: 'Work',
        destination: 'Dest 1',
        status: 'REACHED',
        travelStartTime: '09:00 AM',
        reachedTime: '09:30 AM',
      );

      final assignment = OnDutyAssignment(
        id: 202,
        employeeId: 7,
        employeeName: 'Alice',
        odType: 'Field Work',
        purpose: 'Survey',
        destination: 'Dest 1',
        sites: [activeSite],
        date: '13-09-2026',
        status: 'REACHED_DESTINATION',
        assignedBy: 'Admin',
        createdAt: '2026-09-13T08:00:00',
      );

      // Postpone to next date 14-09-2026
      final resetSites = assignment.sites.map((s) => s.copyWith(
        status: 'PENDING',
        travelStartTime: null,
        reachedTime: null,
        reachedPhoto: null,
        workCompletedTime: null,
        workPhoto: null,
        workPhotos: [],
      )).toList();

      final postponedAssignment = assignment.copyWith(
        date: '14-09-2026',
        status: 'ASSIGNED',
        travelStartTime: null,
        reachedTime: null,
        reachedPhoto: null,
        workCompletedTime: null,
        workPhoto: null,
        workPhotos: [],
        returnStartTime: null,
        officeReachedTime: null,
        actualStartTime: null,
        actualEndTime: null,
        sites: resetSites,
        notes: 'Postponed to 14-09-2026: Rain delay',
      );

      expect(postponedAssignment.date, equals('14-09-2026'));
      expect(postponedAssignment.status, equals('ASSIGNED'));
      expect(postponedAssignment.isOngoing, isTrue);
      expect(postponedAssignment.sites.first.status, equals('PENDING'));
      expect(postponedAssignment.notes, contains('Postponed to 14-09-2026'));
    });
  });
}
