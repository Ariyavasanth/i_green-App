import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_application_1/features/projects/domain/models/project_audit_log.dart';
import 'package:flutter_application_1/features/projects/domain/models/project_breakdown_item.dart';
import 'package:flutter_application_1/features/projects/domain/models/site_project.dart';
import 'package:flutter_application_1/features/projects/domain/repositories/project_repository.dart';
import 'package:flutter_application_1/features/projects/presentation/screens/project_breakdown_screen.dart';
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
    required dynamic budget,
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
  testWidgets('ProjectBreakdownScreen renders initial breakdown and summary metrics',
      (tester) async {
    final fakeRepo = FakeProjectRepository();
    final testProject = SiteProject(
      id: 'PRJ-100',
      projectCode: 'PRJ-2026-001',
      employeeName: 'Ravi Kumar',
      clientName: 'BSNL Telecom',
      generalCode: 'GC-100',
      actualProjectValue: 500000.0,
      breakdownMaterials: [
        ProjectBreakdownItem.create(
          id: 'mat_1',
          description: 'PLB Duct 40mm',
          unit: 'm',
          quantity: 2000.0,
          rate: 50.0,
          type: BreakdownItemType.material,
        ),
      ],
      breakdownServices: [
        ProjectBreakdownItem.create(
          id: 'ser_1',
          description: 'HDD Soil Boring',
          unit: 'm',
          quantity: 2000.0,
          rate: 150.0,
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
          home: ProjectBreakdownScreen(
            projectId: testProject.id,
            initialProject: testProject,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify header title and project details
    expect(find.text('PROJECT BREAKDOWN – MATERIALS & SERVICES'), findsOneWidget);
    expect(find.text('PRJ-2026-001 • BSNL Telecom'), findsOneWidget);

    // Verify summary metric cards
    expect(find.text('CONTRACT / WO VALUE'), findsOneWidget);
    expect(find.text('TOTAL SUPPLIES (MATERIALS)'), findsOneWidget);
    expect(find.text('TOTAL SERVICES (WORKS)'), findsOneWidget);
    expect(find.text('TOTAL BREAKDOWN VALUE'), findsOneWidget);

    // Verify materials item in table
    expect(find.text('PLB Duct 40mm'), findsOneWidget);

    // Switch to Services tab
    await tester.tap(find.text('Services / Works (1)'));
    await tester.pumpAndSettle();

    // Verify services item in table
    expect(find.text('HDD Soil Boring'), findsOneWidget);
  });
}
