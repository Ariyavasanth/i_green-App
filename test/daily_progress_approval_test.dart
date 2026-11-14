import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/employee/domain/models/employee.dart';
import 'package:flutter_application_1/features/employee/providers/employee_providers.dart';
import 'package:flutter_application_1/features/projects/domain/models/daily_progress_entry.dart';
import 'package:flutter_application_1/features/projects/domain/models/project_audit_log.dart';
import 'package:flutter_application_1/features/projects/domain/models/project_compliance_record.dart';
import 'package:flutter_application_1/features/projects/domain/models/project_document.dart';
import 'package:flutter_application_1/features/projects/domain/models/project_inventory_item.dart';
import 'package:flutter_application_1/features/projects/domain/models/site_project.dart';
import 'package:flutter_application_1/features/projects/domain/repositories/project_repository.dart';
import 'package:flutter_application_1/features/projects/presentation/screens/manage_project_screen.dart';
import 'package:flutter_application_1/features/projects/providers/project_providers.dart';

class _FakeProgressProjectRepository implements ProjectRepository {
  final List<DailyProgressEntry> entries = [];
  String? lastApprovedId;
  String? lastApprovedBy;

  @override
  Stream<List<DailyProgressEntry>> watchDailyProgress(String projectCode) {
    return Stream.value(entries.where((e) => e.projectCode == projectCode).toList());
  }

  @override
  Future<void> addDailyProgress(DailyProgressEntry entry) async {
    final status = DailyProgressEntry.isBackdatedBeyondLimit(entry.date)
        ? 'pending_approval'
        : 'approved';
    final saved = DailyProgressEntry(
      id: 'gen_${entries.length + 1}',
      projectCode: entry.projectCode,
      date: entry.date,
      quantityDone: entry.quantityDone,
      totalQuantity: entry.totalQuantity,
      unit: entry.unit,
      remarks: entry.remarks,
      approvalStatus: status,
      createdBy: entry.createdBy,
      createdAt: entry.createdAt,
    );
    entries.insert(0, saved);
  }

  @override
  Future<void> approveDailyProgress(String entryId, String approvedBy) async {
    lastApprovedId = entryId;
    lastApprovedBy = approvedBy;
    final idx = entries.indexWhere((e) => e.id == entryId);
    if (idx != -1) {
      final old = entries[idx];
      entries[idx] = DailyProgressEntry(
        id: old.id,
        projectCode: old.projectCode,
        date: old.date,
        quantityDone: old.quantityDone,
        totalQuantity: old.totalQuantity,
        unit: old.unit,
        remarks: old.remarks,
        approvalStatus: 'approved',
        approvedBy: approvedBy,
        approvedAt: DateTime.now(),
        createdBy: old.createdBy,
        createdAt: old.createdAt,
      );
    }
  }

  @override
  Future<SiteProject> createProject(SiteProject project, {Map<String, dynamic>? filesByCategory}) async => project;
  @override
  Future<List<SiteProject>> getProjects() async => [];
  @override
  Stream<List<SiteProject>> watchProjects() => Stream.value([]);
  @override
  Future<SiteProject?> getProjectById(String id) async => null;
  @override
  Future<void> updateProject(SiteProject project, {Map<String, dynamic>? filesByCategory, String? auditNote, String? auditEmployeeId, String? auditEmployeeName, String? auditDesignation}) async {}
  @override
  Future<void> updateProjectBreakdown({required String projectId, required List<dynamic> materials, required List<dynamic> services, String? auditEmployeeId, String? auditEmployeeName, String? auditDesignation, String? auditNote}) async {}
  @override
  Future<void> updateProjectBudget({required String projectId, required dynamic budget, double contractValue = 0.0, String? auditEmployeeId, String? auditEmployeeName, String? auditDesignation, String? auditNote}) async {}
  @override
  Future<void> deleteProject(String id) async {}
  @override
  Future<List<String>> getTenderTypes() async => ['Open', 'Close'];
  @override
  Future<int> getNextProjectSequence() async => 1;
  @override
  Future<List<ProjectAuditLog>> getProjectAuditLogs(String projectId) async => [];
  @override
  Future<void> addAuditLog(ProjectAuditLog log) async {}
  @override
  Stream<List<ProjectInventoryItem>> watchProjectInventory(String projectCode) => Stream.value([]);
  @override
  Future<void> updateProjectInventory(ProjectInventoryItem item) async {}
  @override
  Future<void> deleteProjectInventory(String id, String projectCode) async {}
  @override
  Stream<List<ProjectPermission>> watchPermissions(String projectCode) => Stream.value([]);
  @override
  Future<void> addPermission(ProjectPermission record) async {}
  @override
  Stream<List<ProjectInsurance>> watchInsurances(String projectCode) => Stream.value([]);
  @override
  Future<void> addInsurance(ProjectInsurance record) async {}
  @override
  Stream<List<ProjectIncident>> watchIncidents(String projectCode) => Stream.value([]);
  @override
  Future<void> addIncident(ProjectIncident record) async {}
  @override
  Stream<List<ProjectDocument>> watchProjectDocuments(String projectCode) => Stream.value([]);
  @override
  Future<void> addProjectDocument(ProjectDocument doc) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Daily Progress calculation & backdate limit tests', () {
    test('Calculates progress percentage accurately (50 / 100 = 50%)', () {
      final entry = DailyProgressEntry(
        id: '1',
        projectCode: 'PRJ-001',
        date: DateTime.now(),
        quantityDone: 50,
        totalQuantity: 100,
        unit: 'metres',
        createdBy: 'Supervisor',
        createdAt: DateTime.now(),
      );
      expect(entry.percentageComplete, 50.0);
    });

    test('2-Day backdate limit check', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final twoDaysAgo = today.subtract(const Duration(days: 2));
      final threeDaysAgo = today.subtract(const Duration(days: 3));

      expect(DailyProgressEntry.isBackdatedBeyondLimit(today), false);
      expect(DailyProgressEntry.isBackdatedBeyondLimit(yesterday), false);
      expect(DailyProgressEntry.isBackdatedBeyondLimit(twoDaysAgo), false);
      expect(DailyProgressEntry.isBackdatedBeyondLimit(threeDaysAgo), true);
    });
  });

  group('Daily Progress UI & Manager Approval Widget Tests', () {
    final testProject = SiteProject(
      id: 'proj_daily_1',
      projectCode: 'PRJ-PIPE-001',
      clientName: 'City Water Works',
      employeeName: 'Admin',
      status: 'Ongoing',
      place: 'Chennai',
      isMappedToTender: 'No',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    testWidgets('Renders Daily Progress tab with Pending Approval and Approve button', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = _FakeProgressProjectRepository();
      final now = DateTime.now();
      final threeDaysAgo = now.subtract(const Duration(days: 3));

      // Add a backdated entry (> 2 days)
      repo.entries.add(
        DailyProgressEntry(
          id: 'entry_backdated_1',
          projectCode: 'PRJ-PIPE-001',
          date: threeDaysAgo,
          quantityDone: 50,
          totalQuantity: 100,
          unit: 'metres',
          approvalStatus: 'pending_approval',
          createdBy: 'Site Supervisor',
          createdAt: threeDaysAgo,
        ),
      );

      final dummyManager = Employee(
        id: 101,
        name: 'Manager John',
        designation: 'Project Manager',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            projectRepositoryProvider.overrideWithValue(repo),
            currentEmployeeProvider.overrideWithValue(dummyManager),
          ],
          child: MaterialApp(
            home: ManageProjectScreen(
              projectId: testProject.id,
              initialProject: testProject,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to Tab 3: Daily Progress
      await tester.tap(find.text('Daily Progress'));
      await tester.pumpAndSettle();

      // Verify Snapshot details
      expect(find.text('50.0%'), findsWidgets);
      expect(find.text('50.0 / 100.0 metres'), findsWidgets);
      expect(find.text('Pending Approval (Backdated > 2 days)'), findsOneWidget);

      // Verify the Manager "Approve" button exists on the screen
      expect(find.text('Approve This Entry'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Approve'), findsOneWidget);

      // Tap the Manager Approve button
      await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
      await tester.pumpAndSettle();

      // Verify confirmation dialog
      expect(find.text('Approve Daily Progress'), findsOneWidget);

      // Confirm approval
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Approve'),
      ));
      await tester.pumpAndSettle();

      // Check repository was called with correct entry ID and approver name
      expect(repo.lastApprovedId, 'entry_backdated_1');
      expect(repo.lastApprovedBy, 'Manager John');
    });
  });
}

