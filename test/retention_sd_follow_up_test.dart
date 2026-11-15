import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/projects/domain/models/project_document.dart';
import 'package:flutter_application_1/features/projects/domain/models/site_project.dart';
import 'package:flutter_application_1/features/projects/domain/repositories/project_repository.dart';
import 'package:flutter_application_1/features/projects/providers/project_providers.dart';
import 'package:flutter_application_1/features/retention_sd/domain/models/retention_sd_record.dart';
import 'package:flutter_application_1/features/retention_sd/domain/repositories/retention_sd_repository.dart';
import 'package:flutter_application_1/features/retention_sd/presentation/screens/retention_sd_follow_up_screen.dart';
import 'package:flutter_application_1/features/retention_sd/presentation/widgets/retention_sd_alert_banner.dart';
import 'package:flutter_application_1/features/retention_sd/presentation/widgets/retention_sd_kpi_cards.dart';
import 'package:flutter_application_1/features/retention_sd/providers/retention_sd_providers.dart';

class FakeRetentionSdRepository implements RetentionSdRepository {
  final List<RetentionSdRecord> _records = [];
  final _controller = StreamController<List<RetentionSdRecord>>.broadcast();

  FakeRetentionSdRepository([List<RetentionSdRecord>? initial]) {
    if (initial != null) {
      _records.addAll(initial);
    }
  }

  void emit(List<RetentionSdRecord> records) {
    _records.clear();
    _records.addAll(records);
    _controller.add(List.unmodifiable(_records));
  }

  @override
  Stream<List<RetentionSdRecord>> watchRecords() {
    return _controller.stream;
  }

  @override
  Future<List<RetentionSdRecord>> getRecords() async =>
      List.unmodifiable(_records);

  @override
  Future<RetentionSdRecord?> getRecordById(String id) async {
    try {
      return _records.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<RetentionSdRecord?> getRecordByProjectId(String projectId) async {
    try {
      return _records.firstWhere((r) => r.projectId == projectId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveRecord(
    RetentionSdRecord record, {
    List<PlatformFile>? claimFiles,
    List<PlatformFile>? bgFiles,
  }) async {
    final idx = _records.indexWhere((r) => r.id == record.id);
    if (idx >= 0) {
      _records[idx] = record;
    } else {
      final id = record.id.isNotEmpty ? record.id : 'REC-${_records.length + 1}';
      _records.add(record.copyWith(id: id));
    }
    emit(_records);
  }

  @override
  Future<void> updateClaimStatus({
    required String recordId,
    required RetentionClaimStatus status,
    DateTime? submissionDate,
    String? referenceNo,
    DateTime? releasedDate,
    double? releasedAmount,
    String? remarks,
    List<PlatformFile>? documents,
    String? updatedBy,
  }) async {
    final idx = _records.indexWhere((r) => r.id == recordId);
    if (idx >= 0) {
      final cur = _records[idx];
      _records[idx] = cur.copyWith(
        claimStatus: status,
        claimSubmissionDate: submissionDate ?? cur.claimSubmissionDate,
        claimReferenceNo: referenceNo ?? cur.claimReferenceNo,
        claimRemarks: remarks ?? cur.claimRemarks,
        releasedDate: releasedDate ?? cur.releasedDate,
        releasedAmount: releasedAmount ?? cur.releasedAmount,
        updatedAt: DateTime.now(),
      );
      emit(_records);
    }
  }

  @override
  Future<void> updateBgDetails({
    required String recordId,
    required BankGuaranteeDetail bg,
    List<PlatformFile>? documents,
    String? updatedBy,
  }) async {
    final idx = _records.indexWhere((r) => r.id == recordId);
    if (idx >= 0) {
      _records[idx] = _records[idx].copyWith(
        hasBg: true,
        bg: bg,
        updatedAt: DateTime.now(),
      );
      emit(_records);
    }
  }

  @override
  Future<void> deleteRecord(String id) async {
    _records.removeWhere((r) => r.id == id);
    emit(_records);
  }

  @override
  Future<void> syncWithSiteProjects(List<SiteProject> projects) async {
    for (final p in projects) {
      final totalRet =
          p.sdRetentionAmount + p.emdRetentionAmount + p.otherRetentionAmount;
      if (totalRet > 0 || p.sdAmount > 0) {
        if (!_records.any((r) => r.projectId == p.id)) {
          _records.add(
            RetentionSdRecord(
              id: 'SYNC-${p.id}',
              projectId: p.id,
              projectCode: p.projectCode,
              projectName: p.projectName,
              clientName: p.clientName,
              division: p.division,
              retentionAmount: totalRet,
              retentionDueDate: p.sdRetentionDate,
              sdAmount: p.sdAmount,
              sdDueDate: p.sdAgreementDate,
              sdAgreementNo: p.sdAgreementNo,
              claimStatus: RetentionClaimStatus.pending,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
        }
      }
    }
    emit(_records);
  }
}

class FakeProjectRepository implements ProjectRepository {
  final List<SiteProject> _projects;
  FakeProjectRepository([this._projects = const []]);

  @override
  Future<List<SiteProject>> getProjects() async => _projects;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('RetentionSdRecord Domain Tests', () {
    test('BankGuaranteeDetail correctly identifies 30-day expiry alert', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Expiring in 15 days
      final expiringBg = BankGuaranteeDetail(
        bgNumber: 'BG-SBI-101',
        bankName: 'State Bank of India',
        bgAmount: 500000.0,
        expiryDate: today.add(const Duration(days: 15)),
      );
      expect(expiringBg.daysUntilExpiry, 15);
      expect(expiringBg.isExpiringSoon, isTrue);
      expect(expiringBg.isExpired, isFalse);
      expect(expiringBg.expiryStatusLabel, 'Expires in 15 days');

      // Expiring in 45 days (not soon)
      final safeBg = BankGuaranteeDetail(
        bgNumber: 'BG-HDFC-202',
        bankName: 'HDFC Bank',
        bgAmount: 300000.0,
        expiryDate: today.add(const Duration(days: 45)),
      );
      expect(safeBg.isExpiringSoon, isFalse);
      expect(safeBg.isExpired, isFalse);

      // Expired 5 days ago
      final expiredBg = BankGuaranteeDetail(
        bgNumber: 'BG-ICICI-303',
        bankName: 'ICICI Bank',
        bgAmount: 250000.0,
        expiryDate: today.subtract(const Duration(days: 5)),
      );
      expect(expiredBg.isExpiringSoon, isFalse);
      expect(expiredBg.isExpired, isTrue);
      expect(expiredBg.expiryStatusLabel, 'Expired 5 days ago');

      // Released BG is not considered expiring
      final releasedBg = BankGuaranteeDetail(
        bgNumber: 'BG-CAN-404',
        status: 'Released',
        expiryDate: today.add(const Duration(days: 5)),
      );
      expect(releasedBg.isExpiringSoon, isFalse);
      expect(releasedBg.expiryStatusLabel, 'Released');
    });

    test('RetentionSdRecord serialization and status transitions', () {
      final now = DateTime(2026, 11, 15, 12, 0);
      final record = RetentionSdRecord(
        id: 'REC-001',
        projectId: 'PRJ-ID-1',
        projectCode: 'PRJ-2024-001',
        projectName: 'Substation Civil Work',
        clientName: 'Power Grid Corp',
        division: 'Transmission',
        retentionAmount: 250000.0,
        retentionDueDate: DateTime(2027, 3, 31),
        sdAmount: 100000.0,
        sdDueDate: DateTime(2026, 12, 31),
        claimStatus: RetentionClaimStatus.submitted,
        claimSubmissionDate: DateTime(2026, 11, 10),
        claimReferenceNo: 'CLAIM/PGC/2026/01',
        hasBg: true,
        bg: BankGuaranteeDetail(
          bgNumber: 'BG-9988',
          bankName: 'SBI',
          bgAmount: 100000.0,
          expiryDate: DateTime(2026, 12, 10),
        ),
        createdAt: now,
        updatedAt: now,
      );

      final json = record.toJson();
      expect(json['id'], 'REC-001');
      expect(json['project_code'], 'PRJ-2024-001');
      expect(json['retention_amount'], 250000.0);
      expect(json['sd_amount'], 100000.0);
      expect(json['claim_status'], 'submitted');
      expect(json['claim_reference_no'], 'CLAIM/PGC/2026/01');
      expect(json['has_bg'], isTrue);
      expect(json['bg']['bg_number'], 'BG-9988');

      final deserialized = RetentionSdRecord.fromJson(json);
      expect(deserialized.id, 'REC-001');
      expect(deserialized.projectCode, 'PRJ-2024-001');
      expect(deserialized.retentionAmount, 250000.0);
      expect(deserialized.sdAmount, 100000.0);
      expect(deserialized.claimStatus, RetentionClaimStatus.submitted);
      expect(deserialized.bg?.bgNumber, 'BG-9988');
      expect(deserialized.totalFollowUpAmount, 350000.0);
    });

    test('RetentionClaimStatus fromString parses various formats', () {
      expect(RetentionClaimStatus.fromString('Pending'), RetentionClaimStatus.pending);
      expect(RetentionClaimStatus.fromString('Claim Submitted'), RetentionClaimStatus.submitted);
      expect(RetentionClaimStatus.fromString('submitted'), RetentionClaimStatus.submitted);
      expect(RetentionClaimStatus.fromString('Released'), RetentionClaimStatus.released);
      expect(RetentionClaimStatus.fromString(null), RetentionClaimStatus.pending);
    });
  });

  group('Retention SD Repository & Sync Tests', () {
    test('FakeRetentionSdRepository saves, updates claim and BG details', () async {
      final repo = FakeRetentionSdRepository();
      final now = DateTime.now();

      final record = RetentionSdRecord(
        id: 'R-1',
        projectId: 'P-1',
        projectCode: 'PRJ-101',
        projectName: 'Line Work',
        retentionAmount: 150000.0,
        sdAmount: 50000.0,
        createdAt: now,
        updatedAt: now,
      );

      await repo.saveRecord(record);
      expect((await repo.getRecords()).length, 1);

      // Update claim to submitted
      await repo.updateClaimStatus(
        recordId: 'R-1',
        status: RetentionClaimStatus.submitted,
        submissionDate: DateTime(2026, 11, 12),
        referenceNo: 'REF-888',
      );

      final updated = await repo.getRecordById('R-1');
      expect(updated?.claimStatus, RetentionClaimStatus.submitted);
      expect(updated?.claimReferenceNo, 'REF-888');

      // Update BG details
      await repo.updateBgDetails(
        recordId: 'R-1',
        bg: const BankGuaranteeDetail(
          bgNumber: 'BG-NEW-1',
          bankName: 'Bank of Baroda',
          bgAmount: 50000.0,
        ),
      );

      final bgUpdated = await repo.getRecordById('R-1');
      expect(bgUpdated?.hasBg, isTrue);
      expect(bgUpdated?.bg?.bgNumber, 'BG-NEW-1');
      expect(bgUpdated?.bg?.bankName, 'Bank of Baroda');
    });

    test('syncWithSiteProjects correctly auto-populates retention and SD records', () async {
      final repo = FakeRetentionSdRepository();
      final projects = [
        SiteProject(
          id: 'PRJ-100',
          projectCode: 'PRJ-100',
          clientName: 'Client Alpha',
          generalDetails: 'Feeder Separation',
          division: 'Distribution',
          sdRetentionAmount: 75000.0,
          sdRetentionDate: DateTime(2027, 1, 15),
          sdAmount: 25000.0,
          sdAgreementNo: 'BG-SD-100',
        ),
        SiteProject(
          id: 'PRJ-200',
          projectCode: 'PRJ-200',
          clientName: 'Client Beta',
          generalDetails: 'Transformer Overhaul',
          division: 'Transmission',
          // No retention or SD
          sdRetentionAmount: 0.0,
          sdAmount: 0.0,
        ),
      ];

      await repo.syncWithSiteProjects(projects);
      final records = await repo.getRecords();

      // Only PRJ-100 should be synced
      expect(records.length, 1);
      expect(records.first.projectCode, 'PRJ-100');
      expect(records.first.retentionAmount, 75000.0);
      expect(records.first.sdAmount, 25000.0);
      expect(records.first.claimStatus, RetentionClaimStatus.pending);
    });
  });

  group('Retention SD Widgets Tests', () {
    testWidgets('RetentionSdAlertBanner renders 30-day BG expiry alert', (tester) async {
      final now = DateTime.now();
      final expiringRecord = RetentionSdRecord(
        id: 'REC-EXP',
        projectId: 'P-EXP',
        projectCode: 'PRJ-ALERT-1',
        projectName: 'Solar Park',
        clientName: 'Green Energy',
        hasBg: true,
        bg: BankGuaranteeDetail(
          bgNumber: 'BG-777',
          bankName: 'SBI',
          bgAmount: 100000.0,
          expiryDate: now.add(const Duration(days: 10)),
        ),
        createdAt: now,
        updatedAt: now,
      );

      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RetentionSdAlertBanner(
              expiringRecords: [expiringRecord],
              onRecordTap: (_) => tapped = true,
            ),
          ),
        ),
      );

      expect(find.textContaining('30-Day Bank Guarantee Expiry Alert'), findsOneWidget);
      expect(find.textContaining('Expires in 10d'), findsOneWidget);
      expect(find.textContaining('PRJ-ALERT-1'), findsOneWidget);

      await tester.tap(find.textContaining('PRJ-ALERT-1'));
      expect(tapped, isTrue);
    });

    testWidgets('RetentionSdKpiCards displays counts and handles filter selection', (tester) async {
      const metrics = RetentionSdMetrics(
        totalRecordsCount: 10,
        totalRetentionAmount: 1000000.0,
        totalSdAmount: 500000.0,
        pendingCount: 6,
        pendingAmount: 800000.0,
        submittedCount: 3,
        submittedAmount: 500000.0,
        releasedCount: 1,
        releasedAmount: 200000.0,
        bgExpiringSoonCount: 2,
        bgExpiringSoonAmount: 300000.0,
      );

      String selected = 'All';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RetentionSdKpiCards(
              metrics: metrics,
              activeStatusFilter: selected,
              onSelectFilter: (filter) => selected = filter,
              screenWidth: 1100,
            ),
          ),
        ),
      );

      expect(find.text('Total Tracked'), findsOneWidget);
      expect(find.text('Pending Claims'), findsOneWidget);
      expect(find.text('Claims Submitted'), findsOneWidget);
      expect(find.text('Released Amount'), findsOneWidget);
      expect(find.text('BG Expiring (≤30d)'), findsOneWidget);

      // Tap on 'Pending Claims' card
      await tester.tap(find.text('Pending Claims'));
      expect(selected, 'Pending');
    });

    testWidgets('RetentionSdFollowUpScreen renders table with retention & SD amounts', (tester) async {
      final now = DateTime.now();
      final records = [
        RetentionSdRecord(
          id: 'R-101',
          projectId: 'P-101',
          projectCode: 'PRJ-101',
          projectName: 'Bay Extension',
          clientName: 'State Electricity Board',
          division: 'Transmission',
          retentionAmount: 180000.0,
          retentionDueDate: now.add(const Duration(days: 60)),
          sdAmount: 50000.0,
          sdDueDate: now.add(const Duration(days: 20)),
          claimStatus: RetentionClaimStatus.pending,
          hasBg: true,
          bg: BankGuaranteeDetail(
            bgNumber: 'BG-SEB-101',
            bankName: 'SBI',
            bgAmount: 50000.0,
            expiryDate: now.add(const Duration(days: 20)),
          ),
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final fakeRepo = FakeRetentionSdRepository(records);
      final fakeProjectRepo = FakeProjectRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            retentionSdRepositoryProvider.overrideWithValue(fakeRepo),
            projectRepositoryProvider.overrideWithValue(fakeProjectRepo),
          ],
          child: const MaterialApp(
            home: RetentionSdFollowUpScreen(),
          ),
        ),
      );

      // Emit stream data
      fakeRepo.emit(records);
      await tester.pumpAndSettle();

      expect(find.text('RETENTION CUM SD FOLLOW-UP'), findsOneWidget);
      expect(find.text('PRJ-101'), findsWidgets);
      expect(find.text('Bay Extension'), findsWidgets);
      expect(find.text('Transmission'), findsWidgets);
      expect(find.text('Pending'), findsWidgets);
      expect(find.textContaining('BG-SEB-101'), findsWidgets);
    });
  });
}
