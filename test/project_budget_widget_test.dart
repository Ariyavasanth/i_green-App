import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_application_1/features/projects/domain/models/project_audit_log.dart';
import 'package:flutter_application_1/features/projects/domain/models/project_breakdown_item.dart';
import 'package:flutter_application_1/features/projects/domain/models/project_budget.dart';
import 'package:flutter_application_1/features/projects/domain/models/site_project.dart';
import 'package:flutter_application_1/features/projects/domain/repositories/project_repository.dart';
import 'package:flutter_application_1/features/projects/presentation/screens/project_budget_screen.dart';
import 'package:flutter_application_1/features/projects/providers/project_providers.dart';

class FakeProjectRepository implements ProjectRepository {
  SiteProject? currentProject;

  @override
  Future<SiteProject> createProject(SiteProject project,
      {Map<String, List<PlatformFile>>? filesByCategory}) async =>
      project;

  @override
  Future<List<SiteProject>> getProjects() async =>
      currentProject != null ? [currentProject!] : [];

  @override
  Stream<List<SiteProject>> watchProjects() =>
      Stream.value(currentProject != null ? [currentProject!] : []);

  @override
  Future<SiteProject?> getProjectById(String id) async => currentProject;

  @override
  Future<void> updateProject(SiteProject project,
      {Map<String, List<PlatformFile>>? filesByCategory,
      String? auditNote,
      String? auditEmployeeId,
      String? auditEmployeeName,
      String? auditDesignation}) async {
    currentProject = project;
  }

  @override
  Future<void> updateProjectBreakdown({
    required String projectId,
    required List<ProjectBreakdownItem> materials,
    required List<ProjectBreakdownItem> services,
    String? auditEmployeeId,
    String? auditEmployeeName,
    String? auditDesignation,
    String? auditNote,
  }) async {
    if (currentProject != null) {
      currentProject = currentProject!.copyWith(
        breakdownMaterials: materials,
        breakdownServices: services,
      );
    }
  }

  @override
  Future<void> updateProjectBudget({
    required String projectId,
    required ProjectBudget budget,
    double contractValue = 0.0,
    String? auditEmployeeId,
    String? auditEmployeeName,
    String? auditDesignation,
    String? auditNote,
  }) async {
    if (currentProject != null) {
      currentProject = currentProject!.copyWith(budget: budget);
    }
  }

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
}

void main() {
  testWidgets('ProjectBudgetScreen renders summary cards, allocation form, and pre-fill baseline',
      (tester) async {
    final fakeRepo = FakeProjectRepository();
    final testProject = SiteProject(
      id: 'PRJ-200',
      projectCode: 'PRJ-2026-002',
      employeeName: 'Anitha S',
      clientName: 'RailTel Corporation',
      generalCode: 'GC-200',
      actualProjectValue: 1000000.0,
      breakdownMaterials: [
        ProjectBreakdownItem.create(
          id: 'mat_1',
          description: 'OFC Cable 48F',
          unit: 'km',
          quantity: 10.0,
          rate: 30000.0,
          type: BreakdownItemType.material,
        ),
      ],
      breakdownServices: [
        ProjectBreakdownItem.create(
          id: 'ser_1',
          description: 'HDD Bore & Duct Pulling',
          unit: 'm',
          quantity: 2000.0,
          rate: 200.0,
          type: BreakdownItemType.service,
        ),
      ],
    );
    fakeRepo.currentProject = testProject;

    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: MaterialApp(
          home: ProjectBudgetScreen(
            projectId: testProject.id,
            initialProject: testProject,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title & Contract Value are visible
    expect(find.text('PROJECT BUDGET & PROFITABILITY'), findsOneWidget);
    expect(find.textContaining('PRJ-2026-002'), findsOneWidget);
    expect(find.text('CONTRACT / WO VALUE'), findsOneWidget);
    expect(find.text('TOTAL SANCTIONED BUDGET'), findsOneWidget);
    expect(find.text('PLANNED GROSS PROFIT'), findsOneWidget);
    expect(find.text('PLANNED PROFIT MARGIN'), findsOneWidget);

    // Verify initial empty state
    expect(find.textContaining('No budget allocation heads added yet.'), findsOneWidget);
    expect(find.text('Auto-fill Baseline'), findsOneWidget);

    // Tap Pre-fill Baseline button
    await tester.tap(find.text('Auto-fill Baseline'));
    await tester.pumpAndSettle();

    // Baseline should generate items for materials, services and contingency
    expect(find.textContaining('Materials & Equipment Procurement'), findsOneWidget);
    expect(find.textContaining('HDD, Civil & Installation Works'), findsOneWidget);
    expect(find.textContaining('Unforeseen Site Variances & Contingency'), findsOneWidget);

    // Verify Action buttons are available
    expect(find.text('Save Draft'), findsOneWidget);
    expect(find.text('Approve Budget'), findsOneWidget);

    // Tap "Save Draft"
    await tester.tap(find.text('Save Draft'));
    await tester.pumpAndSettle();

    // Verify fakeRepo project now has budget saved
    expect(fakeRepo.currentProject?.budget, isNotNull);
    expect(fakeRepo.currentProject!.budget!.items.length, 3);
    expect(fakeRepo.currentProject!.budget!.status, BudgetStatus.draft);
  });
}
