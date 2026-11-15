import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/projects/domain/models/eot_letter.dart';
import 'package:flutter_application_1/features/projects/domain/models/project_document.dart';
import 'package:flutter_application_1/features/projects/domain/models/site_project.dart';

void main() {
  group('EOT Letters Domain Tests', () {
    test('EotLetter serializes and deserializes accurately', () {
      final now = DateTime(2026, 11, 14, 10, 0);
      final letter = EotLetter(
        id: 'EOT-001',
        projectCode: 'PRJ-2026-001',
        letterRefNo: 'LTR/EOT/2026/09',
        letterDate: DateTime(2026, 11, 1),
        extendedCompletionDate: DateTime(2027, 2, 28),
        extendedDays: 90,
        reason: 'Client site handover delayed and heavy monsoon rains',
        document: ProjectDocument(
          name: 'eot_approval_letter.pdf',
          size: 204800,
          downloadUrl: 'https://example.com/eot_approval_letter.pdf',
          category: 'eot_letters',
          uploadedAt: now,
        ),
        uploadedBy: 'EMP-001',
        uploadedByName: 'Senior Engineer',
        createdAt: now,
      );

      final json = letter.toJson();
      expect(json['id'], 'EOT-001');
      expect(json['letter_ref_no'], 'LTR/EOT/2026/09');
      expect(json['extended_days'], 90);
      expect(json['reason'], contains('monsoon rains'));
      expect(json['document']['name'], 'eot_approval_letter.pdf');

      final restored = EotLetter.fromJson(json);
      expect(restored.id, 'EOT-001');
      expect(restored.letterRefNo, 'LTR/EOT/2026/09');
      expect(restored.extendedDays, 90);
      expect(restored.extendedCompletionDate, DateTime(2027, 2, 28));
      expect(restored.document.name, 'eot_approval_letter.pdf');
    });

    test('SiteProject correctly tracks EOT letters and effectiveTargetCompletionDate', () {
      final targetDate = DateTime(2026, 11, 30);
      final extendedDate = DateTime(2027, 1, 31);

      final project = SiteProject(
        projectCode: 'PRJ-001',
        employeeName: 'Engineer A',
        clientName: 'Client X',
        generalCode: 'GC-001',
        targetCompletionDate: targetDate,
      );

      expect(project.effectiveTargetCompletionDate, targetDate);
      expect(project.eotLetters, isEmpty);

      final eotLetter = EotLetter(
        id: 'EOT-1',
        projectCode: 'PRJ-001',
        letterRefNo: 'EOT/01',
        letterDate: DateTime(2026, 11, 10),
        extendedCompletionDate: extendedDate,
        extendedDays: 62,
        reason: 'Material supply chain delay',
        document: ProjectDocument(
          name: 'eot.pdf',
          size: 1000,
          uploadedAt: DateTime.now(),
        ),
        createdAt: DateTime.now(),
      );

      final updatedProject = project.copyWith(
        eotLetters: [eotLetter],
        revisedCompletionDate: extendedDate,
      );

      expect(updatedProject.effectiveTargetCompletionDate, extendedDate);
      expect(updatedProject.eotLetters, hasLength(1));

      // Test JSON roundtrip
      final json = updatedProject.toJson();
      expect(json['eot_letters'], hasLength(1));
      expect(json['revised_completion_date'], isNotNull);

      final restored = SiteProject.fromJson(json);
      expect(restored.effectiveTargetCompletionDate, extendedDate);
      expect(restored.eotLetters.first.letterRefNo, 'EOT/01');
    });
  });

  group('Completion Certificate 30-Day Deadline & Vault Compliance Tests', () {
    test('Calculates 30-day deadline from payment date correctly', () {
      final paymentDate = DateTime.now();
      final deadline = paymentDate.add(const Duration(days: 30));

      final project = SiteProject(
        projectCode: 'PRJ-001',
        employeeName: 'Engineer A',
        clientName: 'Client X',
        generalCode: 'GC-001',
        paymentAmount: 500000.0,
        paymentReceivedDate: paymentDate,
        completionCertificateDeadline: deadline,
        isCompletionCertificateUploaded: false,
      );

      expect(project.isCompletionCertificateUploaded, isFalse);
      expect(project.isCompletionCertificateOverdue, isFalse);
      expect(project.completionCertificateDaysRemaining, inInclusiveRange(29, 30));
    });

    test('Identifies overdue completion certificate when past 30 days', () {
      final pastPaymentDate = DateTime.now().subtract(const Duration(days: 35));
      final pastDeadline = pastPaymentDate.add(const Duration(days: 30)); // 5 days ago

      final project = SiteProject(
        projectCode: 'PRJ-001',
        employeeName: 'Engineer A',
        clientName: 'Client X',
        generalCode: 'GC-001',
        paymentAmount: 250000.0,
        paymentReceivedDate: pastPaymentDate,
        completionCertificateDeadline: pastDeadline,
        isCompletionCertificateUploaded: false,
      );

      expect(project.isCompletionCertificateOverdue, isTrue);
      expect(project.completionCertificateDaysRemaining, isNegative);
    });

    test('Uploaded completion certificate resolves overdue state and saves metadata', () {
      final pastPaymentDate = DateTime.now().subtract(const Duration(days: 35));
      final pastDeadline = pastPaymentDate.add(const Duration(days: 30));

      final project = SiteProject(
        projectCode: 'PRJ-001',
        employeeName: 'Engineer A',
        clientName: 'Client X',
        generalCode: 'GC-001',
        paymentAmount: 250000.0,
        paymentReceivedDate: pastPaymentDate,
        completionCertificateDeadline: pastDeadline,
        isCompletionCertificateUploaded: true,
        completionCertificateUploadedAt: DateTime.now(),
        completionCertificateDocId: 'DOC-VAULT-123',
        completionCertificateTaskId: 'TASK-CC-999',
      );

      expect(project.isCompletionCertificateUploaded, isTrue);
      expect(project.isCompletionCertificateOverdue, isFalse);
      expect(project.completionCertificateDocId, 'DOC-VAULT-123');

      // Test JSON roundtrip
      final json = project.toJson();
      expect(json['is_completion_certificate_uploaded'], isTrue);
      expect(json['completion_certificate_doc_id'], 'DOC-VAULT-123');
      expect(json['completion_certificate_task_id'], 'TASK-CC-999');

      final restored = SiteProject.fromJson(json);
      expect(restored.isCompletionCertificateUploaded, isTrue);
      expect(restored.isCompletionCertificateOverdue, isFalse);
      expect(restored.completionCertificateDocId, 'DOC-VAULT-123');
    });
  });
}

