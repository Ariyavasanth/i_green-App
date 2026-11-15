import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/project_incentive/domain/models/project_incentive_record.dart';
import 'package:flutter_application_1/features/project_incentive/domain/models/project_incentive_settings.dart';
import 'package:flutter_application_1/features/project_incentive/domain/repositories/project_incentive_repository.dart';
import 'package:flutter_application_1/features/project_incentive/domain/services/project_incentive_calculator.dart';
import 'package:flutter_application_1/features/project_incentive/presentation/screens/project_incentive_engine_screen.dart';
import 'package:flutter_application_1/features/project_incentive/presentation/widgets/project_incentive_details_dialog.dart';
import 'package:flutter_application_1/features/project_incentive/providers/project_incentive_providers.dart';
import 'package:flutter_application_1/features/projects/domain/models/daily_progress_entry.dart';
import 'package:flutter_application_1/features/projects/domain/models/project_compliance_record.dart';
import 'package:flutter_application_1/features/projects/domain/models/project_document.dart';
import 'package:flutter_application_1/features/projects/domain/models/site_project.dart';
import 'package:flutter_application_1/features/projects/domain/repositories/project_repository.dart';
import 'package:flutter_application_1/features/projects/providers/project_providers.dart';

class FakeProjectIncentiveRepository implements ProjectIncentiveRepository {
  final List<ProjectIncentiveRecord> _records = [];
  final _controller = StreamController<List<ProjectIncentiveRecord>>.broadcast();
  ProjectIncentiveSettings _settings = const ProjectIncentiveSettings();
  final _settingsController = StreamController<ProjectIncentiveSettings>.broadcast();

  FakeProjectIncentiveRepository([List<ProjectIncentiveRecord>? initial]) {
    if (initial != null) {
      _records.addAll(initial);
    }
  }

  void emit(List<ProjectIncentiveRecord> records) {
    _records.clear();
    _records.addAll(records);
    _controller.add(List.unmodifiable(_records));
  }

  @override
  Stream<List<ProjectIncentiveRecord>> watchIncentiveRecords() {
    return _controller.stream;
  }

  @override
  Future<List<ProjectIncentiveRecord>> getIncentiveRecords() async =>
      List.unmodifiable(_records);

  @override
  Future<ProjectIncentiveRecord?> getIncentiveRecordByProject(String projectCodeOrId) async {
    try {
      return _records.firstWhere((r) => r.projectId == projectCodeOrId || r.projectCode == projectCodeOrId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveIncentiveRecord(ProjectIncentiveRecord record) async {
    final idx = _records.indexWhere((r) => r.id == record.id || r.projectCode == record.projectCode);
    if (idx >= 0) {
      _records[idx] = record;
    } else {
      _records.add(record);
    }
    _controller.add(List.unmodifiable(_records));
  }

  @override
  Future<ProjectIncentiveRecord> recalculateProjectIncentive(String projectId) async {
    final rec = _records.firstWhere((r) => r.projectId == projectId);
    return rec;
  }

  @override
  Future<void> recalculateAllIncentives() async {
    _controller.add(List.unmodifiable(_records));
  }

  @override
  Future<ProjectIncentiveSettings> getSettings() async => _settings;

  @override
  Stream<ProjectIncentiveSettings> watchSettings() => _settingsController.stream;

  @override
  Future<void> updateSettings(ProjectIncentiveSettings settings) async {
    _settings = settings;
    _settingsController.add(_settings);
  }

  @override
  Future<void> deleteIncentiveRecord(String id) async {
    _records.removeWhere((r) => r.id == id);
    _controller.add(List.unmodifiable(_records));
  }
}

void main() {
  group('Project Incentive Engine - Calculation Unit Tests', () {
    final testProject = SiteProject(
      id: 'proj_101',
      projectCode: 'PRJ-HDD-2026-001',
      employeeName: 'Ramesh Kumar',
      clientName: 'L&T Construction',
      generalCode: 'HDD Pipeline Tiruchi',
      division: 'South 1',
      actualProjectValue: 1000000.0,
      paymentAmount: 850000.0, // 85% collected
      targetCompletionDate: DateTime(2026, 11, 10),
      billingDetailsDocuments: [
        ProjectDocument(
          name: 'RA_Bill_01.pdf',
          downloadUrl: 'https://example.com/bill.pdf',
          size: 1024,
          uploadedAt: DateTime(2026, 11, 5), // On-time before Nov 10
        ),
      ],
      flowOfBillsStatus: 'JE Approved',
    );

    final dailyEntries = [
      DailyProgressEntry(
        id: 'dp_1',
        projectCode: 'PRJ-HDD-2026-001',
        date: DateTime(2026, 11, 1),
        quantityDone: 200.0,
        totalQuantity: 500.0,
        unit: 'metres',
        approvalStatus: 'approved',
        createdBy: 'Supervisor',
        createdAt: DateTime(2026, 11, 1),
      ),
      DailyProgressEntry(
        id: 'dp_2',
        projectCode: 'PRJ-HDD-2026-001',
        date: DateTime(2026, 11, 2),
        quantityDone: 150.0,
        totalQuantity: 500.0,
        unit: 'metres',
        approvalStatus: 'approved',
        createdBy: 'Supervisor',
        createdAt: DateTime(2026, 11, 2),
      ),
      DailyProgressEntry(
        id: 'dp_3',
        projectCode: 'PRJ-HDD-2026-001',
        date: DateTime(2026, 11, 3),
        quantityDone: 50.0,
        totalQuantity: 500.0,
        unit: 'metres',
        approvalStatus: 'pending_approval', // Not approved yet
        createdBy: 'Supervisor',
        createdAt: DateTime(2026, 11, 3),
      ),
    ];

    test('1. Calculate incentives using daily progress', () {
      final rec = ProjectIncentiveCalculator.calculate(
        project: testProject,
        dailyProgressEntries: dailyEntries,
        incidents: [],
        settings: const ProjectIncentiveSettings(
          baseRatePerUnit: 50.0, // ₹50/metre
          timelyBillBonusPercentage: 0.0,
          delayedBillPenaltyPercentage: 0.0,
        ),
        calculationDate: DateTime(2026, 11, 6),
      );

      // Only approved entries (200 + 150 = 350 metres) should be counted
      expect(rec.approvedQuantityDone, equals(350.0));
      expect(rec.approvedEntriesCount, equals(2));
      // Base incentive: 350m * ₹50 = ₹17,500
      expect(rec.baseProgressIncentive, equals(17500.0));
      expect(rec.isDisqualified, isFalse);
      expect(rec.status, equals('ELIGIBLE'));
    });

    test('2. Consider timely bill submission (+10% on-time vs -15% delayed)', () {
      // Test on-time submission (submitted Nov 5 before Nov 10 target)
      final onTimeRec = ProjectIncentiveCalculator.calculate(
        project: testProject,
        dailyProgressEntries: dailyEntries,
        incidents: [],
        settings: const ProjectIncentiveSettings(
          baseRatePerUnit: 50.0,
          timelyBillBonusPercentage: 10.0,
          delayedBillPenaltyPercentage: 15.0,
        ),
        billSubmissionDate: DateTime(2026, 11, 5),
        calculationDate: DateTime(2026, 11, 6),
      );

      expect(onTimeRec.isBillTimely, isTrue);
      expect(onTimeRec.billTimelinessMultiplier, equals(1.10));
      expect(onTimeRec.timelyBillAdjustmentAmount, equals(1750.0)); // +10% of 17,500
      expect(onTimeRec.grossEarnedIncentive, equals(19250.0));

      // Test delayed submission (submitted Nov 15 after Nov 10 target)
      final delayedRec = ProjectIncentiveCalculator.calculate(
        project: testProject,
        dailyProgressEntries: dailyEntries,
        incidents: [],
        settings: const ProjectIncentiveSettings(
          baseRatePerUnit: 50.0,
          timelyBillBonusPercentage: 10.0,
          delayedBillPenaltyPercentage: 15.0,
        ),
        billSubmissionDate: DateTime(2026, 11, 15),
        calculationDate: DateTime(2026, 11, 16),
      );

      expect(delayedRec.isBillTimely, isFalse);
      expect(delayedRec.billTimelinessMultiplier, equals(0.85));
      expect(delayedRec.timelyBillAdjustmentAmount, equals(-2625.0)); // -15% of 17,500
      expect(delayedRec.grossEarnedIncentive, equals(14875.0));
    });

    test('3. Consider payment collection efficiency', () {
      // 85% collected with 80% threshold -> 100% payout factor
      final fullCollectionRec = ProjectIncentiveCalculator.calculate(
        project: testProject,
        dailyProgressEntries: dailyEntries,
        incidents: [],
        settings: const ProjectIncentiveSettings(
          baseRatePerUnit: 50.0,
          timelyBillBonusPercentage: 0.0,
          minCollectionThresholdPct: 80.0,
        ),
        calculationDate: DateTime(2026, 11, 6),
      );

      expect(fullCollectionRec.paymentCollectionPercentage, equals(85.0));
      expect(fullCollectionRec.paymentCollectionFactor, equals(1.0));
      expect(fullCollectionRec.netPayableIncentive, equals(17500.0));

      // Low collection: 40% collected with 80% threshold -> 50% pro-rata factor
      final lowCollectionProject = SiteProject(
        id: 'proj_low',
        projectCode: 'PRJ-LOW',
        employeeName: 'Ramesh',
        clientName: 'Client',
        generalCode: 'Pipeline Low',
        actualProjectValue: 1000000.0,
        paymentAmount: 400000.0, // 40%
      );

      final lowRec = ProjectIncentiveCalculator.calculate(
        project: lowCollectionProject,
        dailyProgressEntries: dailyEntries,
        incidents: [],
        settings: const ProjectIncentiveSettings(
          baseRatePerUnit: 50.0,
          timelyBillBonusPercentage: 0.0,
          minCollectionThresholdPct: 80.0,
        ),
        calculationDate: DateTime(2026, 11, 6),
      );

      expect(lowRec.paymentCollectionPercentage, equals(40.0));
      expect(lowRec.paymentCollectionFactor, equals(0.5)); // 40% / 80% = 0.5
      expect(lowRec.netPayableIncentive, equals(8750.0)); // 17,500 * 0.5 = 8,750
    });

    test('4. Automatically disqualify incentive when an incident is recorded', () {
      final incidents = [
        IncidentLogEntry(
          id: 'inc_1',
          projectCode: 'PRJ-HDD-2026-001',
          incidentDate: DateTime(2026, 11, 4),
          photoUrl: 'https://example.com/damage.jpg',
          remarks: 'OFC optic cable cut during trenching operation at Ch. 12+400',
          restorationCost: 45000.0,
          createdAt: DateTime(2026, 11, 4),
        ),
      ];

      final rec = ProjectIncentiveCalculator.calculate(
        project: testProject,
        dailyProgressEntries: dailyEntries,
        incidents: incidents,
        settings: const ProjectIncentiveSettings(
          baseRatePerUnit: 50.0,
          autoDisqualifyOnIncident: true,
        ),
        calculationDate: DateTime(2026, 11, 6),
      );

      // Must be automatically disqualified
      expect(rec.isDisqualified, isTrue);
      expect(rec.status, equals('DISQUALIFIED'));
      expect(rec.incidentCount, equals(1));
      expect(rec.netPayableIncentive, equals(0.0)); // Forfeited to ₹0
      expect(rec.disqualificationReason, contains('Automatically disqualified: 1 incident(s) logged'));
    });

    test('5. Track restoration costs separately in dedicated damage ledger', () {
      final incidents = [
        IncidentLogEntry(
          id: 'inc_1',
          projectCode: 'PRJ-HDD-2026-001',
          incidentDate: DateTime(2026, 11, 4),
          photoUrl: 'https://example.com/cable.jpg',
          remarks: 'OFC Cable Damage',
          restorationCost: 35000.0,
          createdAt: DateTime(2026, 11, 4),
        ),
        IncidentLogEntry(
          id: 'inc_2',
          projectCode: 'PRJ-HDD-2026-001',
          incidentDate: DateTime(2026, 11, 5),
          photoUrl: 'https://example.com/pipe.jpg',
          remarks: 'Water pipeline joint burst',
          restorationCost: 15000.0,
          createdAt: DateTime(2026, 11, 5),
        ),
      ];

      final rec = ProjectIncentiveCalculator.calculate(
        project: testProject,
        dailyProgressEntries: dailyEntries,
        incidents: incidents,
        settings: const ProjectIncentiveSettings(
          baseRatePerUnit: 50.0,
          autoDisqualifyOnIncident: true,
          trackRestorationCostSeparately: true,
        ),
        calculationDate: DateTime(2026, 11, 6),
      );

      // Restoration costs tracked separately in damage ledger: 35,000 + 15,000 = 50,000
      expect(rec.totalRestorationCost, equals(50000.0));
      expect(rec.hasRestorationCosts, isTrue);
      expect(rec.restorationIncidents.length, equals(2));
      expect(rec.restorationIncidents.first.remarks, equals('OFC Cable Damage'));
      expect(rec.restorationIncidents.first.restorationCost, equals(35000.0));

      // Separate ledger verification: incentive is 0, not negative ₹50,000
      expect(rec.netPayableIncentive, equals(0.0));
      expect(rec.isDisqualified, isTrue);
    });
  });

  group('Project Incentive Engine - UI Widget Tests', () {
    testWidgets('Renders KPI Cards and Project Details Dialog correctly', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockRecord = ProjectIncentiveRecord(
        id: 'inc_1',
        projectId: 'proj_101',
        projectCode: 'PRJ-HDD-2026-001',
        projectName: 'HDD Pipeline Tiruchi',
        clientName: 'L&T Construction',
        division: 'South 1',
        contractValue: 1000000.0,
        approvedQuantityDone: 350.0,
        totalQuantityTarget: 500.0,
        unit: 'metres',
        approvedEntriesCount: 2,
        baseProgressIncentive: 17500.0,
        progressCompletionPercentage: 70.0,
        isBillSubmitted: true,
        isBillTimely: true,
        timelyBillAdjustmentAmount: 1750.0,
        paymentCollectedAmount: 850000.0,
        paymentCollectionPercentage: 85.0,
        grossEarnedIncentive: 19250.0,
        netPayableIncentive: 19250.0,
        status: 'ELIGIBLE',
        incidentCount: 0,
        isDisqualified: false,
        totalRestorationCost: 0.0,
        calculatedAt: DateTime(2026, 11, 6),
      );

      final fakeRepo = FakeProjectIncentiveRepository([mockRecord]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            projectIncentiveRepositoryProvider.overrideWithValue(fakeRepo),
            liveProjectIncentivesStreamProvider.overrideWith((ref) => Stream.value([mockRecord])),
          ],
          child: const MaterialApp(
            home: ProjectIncentiveEngineScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('PROJECT INCENTIVE ENGINE'), findsOneWidget);

      // Verify KPI Cards
      expect(find.text('Net Payable Incentive'), findsOneWidget);
      expect(find.text('Disqualified Projects'), findsOneWidget);
      expect(find.text('Restoration Costs (Separate)'), findsOneWidget);

      // Verify Table Record
      expect(find.text('PRJ-HDD-2026-001'), findsOneWidget);
      expect(find.text('ELIGIBLE (0)'), findsOneWidget);

      // Tap on Details Dialog
      await tester.ensureVisible(find.byIcon(Icons.analytics_outlined));
      await tester.tap(find.byIcon(Icons.analytics_outlined));
      await tester.pumpAndSettle();

      // Verify Details Dialog content
      expect(find.text('INCENTIVE CALCULATION: PRJ-HDD-2026-001'), findsOneWidget);
      expect(find.text('1. Daily Progress Incentive'), findsOneWidget);
      expect(find.text('2. Timely Bill Submission'), findsOneWidget);
      expect(find.text('3. Payment Collection Consideration'), findsOneWidget);
      expect(find.text('4 & 5. Site Incidents & Dedicated Restoration Costs'), findsOneWidget);
    });

    testWidgets('Details Dialog shows disqualification banner and separate restoration ledger when incident logged', (tester) async {
      final disqualifiedRecord = ProjectIncentiveRecord(
        id: 'inc_2',
        projectId: 'proj_102',
        projectCode: 'PRJ-DISQ-999',
        projectName: 'Gas Pipeline Salem',
        clientName: 'GAIL India',
        contractValue: 2000000.0,
        approvedQuantityDone: 400.0,
        totalQuantityTarget: 500.0,
        unit: 'metres',
        baseProgressIncentive: 20000.0,
        progressCompletionPercentage: 80.0,
        isBillSubmitted: true,
        isBillTimely: false,
        timelyBillAdjustmentAmount: -3000.0,
        grossEarnedIncentive: 17000.0,
        netPayableIncentive: 0.0, // Forfeited
        status: 'DISQUALIFIED',
        incidentCount: 1,
        isDisqualified: true,
        disqualificationReason: 'Automatically disqualified: 1 incident(s) logged on site (utility damage / safety incident).',
        totalRestorationCost: 65000.0,
        restorationIncidents: [
          RestorationIncidentItem(
            incidentId: 'inc_item_1',
            incidentDate: DateTime(2026, 11, 2),
            remarks: 'HT Underground electrical cable damaged',
            restorationCost: 65000.0,
          ),
        ],
        calculatedAt: DateTime(2026, 11, 6),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProjectIncentiveDetailsDialog(record: disqualifiedRecord),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Disqualification Header
      expect(find.text('AUTOMATICALLY DISQUALIFIED FROM INCENTIVE'), findsOneWidget);
      expect(find.textContaining('1 incident(s) logged on site'), findsOneWidget);

      // Verify Separate Restoration Ledger
      expect(find.text('TRACKED SEPARATELY'), findsOneWidget);
      expect(find.text('HT Underground electrical cable damaged'), findsOneWidget);
    });
  });
}
