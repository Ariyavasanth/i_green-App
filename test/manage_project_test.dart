import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/projects/domain/models/project_audit_log.dart';
import 'package:flutter_application_1/features/projects/domain/models/site_project.dart';
import 'package:flutter_application_1/features/projects/domain/repositories/project_repository.dart';
import 'package:flutter_application_1/features/projects/presentation/screens/assigned_projects_screen.dart';
import 'package:flutter_application_1/features/projects/presentation/screens/manage_project_screen.dart';
import 'package:flutter_application_1/features/projects/providers/project_providers.dart';
import 'package:flutter_application_1/features/tenders/domain/models/tender.dart';
import 'package:flutter_application_1/features/tenders/providers/tender_providers.dart';

class _FakeProjectRepository implements ProjectRepository {
  final List<SiteProject> _projects = [];

  _FakeProjectRepository([List<SiteProject>? initial]) {
    if (initial != null) _projects.addAll(initial);
  }

  @override
  Future<SiteProject> createProject(SiteProject project, {Map<String, dynamic>? filesByCategory}) async {
    _projects.add(project);
    return project;
  }

  @override
  Future<List<SiteProject>> getProjects() async => _projects;

  @override
  Stream<List<SiteProject>> watchProjects() => Stream.value(_projects);

  @override
  Future<SiteProject?> getProjectById(String id) async {
    return _projects.cast<SiteProject?>().firstWhere((p) => p?.id == id, orElse: () => null);
  }

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final testProject1 = SiteProject(
    id: 'proj_001',
    employeeName: 'Saravanan Lead',
    employeeId: 'EMP-001',
    clientName: 'TNEB Chennai',
    generalDetails: 'Chennai Cable Work',
    generalCode: 'GC-CHE-001',
    place: 'Chennai',
    district: 'Chennai',
    state: 'Tamil Nadu',
    projectCode: 'PRJ-CHE-001',
    status: 'Ongoing',
    approximateProjectValue: 5000000.0,
    actualProjectValue: 5200000.0,
    isMappedToTender: 'Yes',
    tenderId: 'TND-2026-99',
    tenderRefNo: 'TND/REF/2026/099',
    tenderCategory: 'Electrical Cabling',
    tenderType: 'Open Tender',
    tenderAmount: 5100000.0,
    assignedToEmployeeNames: ['Saravanan Lead', 'Karthik Engineer'],
    assignedToEmployeeIds: ['EMP-001', 'EMP-002'],
    assignedToDesignation: 'Lead Site Engineer',
    assignedToContactNumber: '9876543210',
    assignedToEmail: 'lead@igreen.com',
    assignedDate: DateTime(2026, 3, 1),
    createdAt: DateTime(2026, 3, 1),
    updatedAt: DateTime(2026, 3, 1),
  );

  final testLinkedTender = Tender(
    id: 'TND-2026-99',
    tenderId: 'TND-2026-99',
    title: 'Underground 33kV Cabling Scheme',
    tenderRefNo: 'TND/REF/2026/099',
    clientName: 'TNEB Authority',
    openingDate: DateTime(2026, 1, 10),
    closingDate: DateTime(2026, 2, 10),
    bqrRemark: 'Must not be shown in project screen',
    emdAmount: 100000.0,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final independentProject = SiteProject(
    id: 'proj_002',
    employeeName: 'Admin',
    clientName: 'Private Client Ltd',
    generalDetails: 'Warehouse Solar Setup',
    generalCode: 'GC-SLR-002',
    place: 'Coimbatore',
    projectCode: 'PRJ-CBE-002',
    status: 'Ongoing',
    isMappedToTender: 'No',
    createdAt: DateTime(2026, 3, 5),
    updatedAt: DateTime(2026, 3, 5),
  );

  group('ManageProjectScreen Widget Tests', () {
    testWidgets('Renders Manage Project with project details and all 10 section tabs', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = _FakeProjectRepository([testProject1]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            projectRepositoryProvider.overrideWithValue(repo),
            projectsStreamProvider.overrideWith((ref) => Stream.value([testProject1])),
            tenderByIdProvider(testProject1.tenderId).overrideWith((ref) => Future.value(testLinkedTender)),
          ],
          child: MaterialApp(
            home: ManageProjectScreen(
              projectId: 'proj_001',
              initialProject: testProject1,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('PRJ-CHE-001'), findsWidgets);
      expect(find.text('Chennai Cable Work'), findsWidgets);
      expect(find.text('TNEB Chennai'), findsWidgets);
      expect(find.text('Ongoing'), findsWidgets);
      expect(find.text('Linked Tender'), findsOneWidget);

      // Verify all 10 section tabs exist in navigation
      expect(find.text('Project Overview'), findsOneWidget);
      expect(find.text('Project Assignment'), findsOneWidget);
      expect(find.text('Project Breakdown'), findsOneWidget);
      expect(find.text('Project Budget'), findsOneWidget);
      expect(find.text('Profile Drawings'), findsOneWidget);
      expect(find.text('Billing'), findsOneWidget);
      expect(find.text('Payment Received'), findsOneWidget);
      expect(find.text('EMD & Retention'), findsOneWidget);
      expect(find.text('Project Expenses'), findsOneWidget);
      expect(find.text('Project Profit / Loss'), findsOneWidget);

      // Verify Section 1: Overview displays General Info & Linked Tender Ref without repeating Tender dates/BQR/EMD
      expect(find.text('General Project Information'), findsOneWidget);
      expect(find.text('Tender Mapping Details'), findsOneWidget);
      expect(find.text('TND/REF/2026/099'), findsOneWidget);
      expect(find.text('Must not be shown in project screen'), findsNothing); // Strictly no BQR repetition
    });

    testWidgets('Tapping section tab switches content to Project Assignment', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = _FakeProjectRepository([testProject1]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            projectRepositoryProvider.overrideWithValue(repo),
            projectsStreamProvider.overrideWith((ref) => Stream.value([testProject1])),
            tenderByIdProvider(testProject1.tenderId).overrideWith((ref) => Future.value(testLinkedTender)),
          ],
          child: MaterialApp(
            home: ManageProjectScreen(
              projectId: 'proj_001',
              initialProject: testProject1,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on Section 2: Project Assignment
      await tester.tap(find.text('Project Assignment'));
      await tester.pumpAndSettle();

      expect(find.text('Project Assignment & Team Allocation'), findsOneWidget);
      expect(find.textContaining('Saravanan Lead'), findsWidgets);
      expect(find.text('Lead Site Engineer'), findsOneWidget);
      expect(find.text('9876543210'), findsOneWidget);
      expect(find.text('lead@igreen.com'), findsOneWidget);
    });

    testWidgets('Independent project displays independent badge and message', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = _FakeProjectRepository([independentProject]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            projectRepositoryProvider.overrideWithValue(repo),
            projectsStreamProvider.overrideWith((ref) => Stream.value([independentProject])),
          ],
          child: MaterialApp(
            home: ManageProjectScreen(
              projectId: 'proj_002',
              initialProject: independentProject,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Independent Project'), findsWidgets);
      expect(find.text('This site project was created independently and is not mapped to any tender record.'), findsOneWidget);
    });
  });

  group('AssignedProjectsScreen Project List Tests', () {
    testWidgets('Displays Project List with View / Manage Project button', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = _FakeProjectRepository([testProject1]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            projectRepositoryProvider.overrideWithValue(repo),
            projectsStreamProvider.overrideWith((ref) => Stream.value([testProject1])),
            tenderByIdProvider(testProject1.tenderId).overrideWith((ref) => Future.value(testLinkedTender)),
          ],
          child: MaterialApp(
            home: const AssignedProjectsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // App bar has PROJECT LIST and New Project button
      expect(find.text('PROJECT LIST'), findsOneWidget);
      expect(find.text('New Project'), findsOneWidget);

      // Desktop table displays project code, name, and status
      expect(find.text('PRJ-CHE-001'), findsOneWidget);
      expect(find.text('Chennai Cable Work'), findsOneWidget);
      expect(find.text('Ongoing'), findsOneWidget);

      // "View / Manage" button is rendered
      expect(find.text('View / Manage'), findsOneWidget);
    });
  });
}
