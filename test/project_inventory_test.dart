import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/projects/domain/models/project_inventory_item.dart';
import 'package:flutter_application_1/features/projects/domain/models/site_project.dart';
import 'package:flutter_application_1/features/projects/domain/repositories/project_repository.dart';
import 'package:flutter_application_1/features/projects/presentation/screens/manage_project_screen.dart';
import 'package:flutter_application_1/features/projects/providers/project_providers.dart';

class _FakeInventoryProjectRepository implements ProjectRepository {
  final List<ProjectInventoryItem> items = [];
  ProjectInventoryItem? lastSavedItem;
  String? lastDeletedId;

  @override
  Stream<List<ProjectInventoryItem>> watchProjectInventory(String projectCode) {
    return Stream.value(items.where((i) => i.projectCode == projectCode).toList());
  }

  @override
  Future<void> updateProjectInventory(ProjectInventoryItem item) async {
    lastSavedItem = item;
    final idx = items.indexWhere((i) => i.id == item.id && item.id.isNotEmpty);
    if (idx != -1) {
      items[idx] = item;
    } else {
      items.add(item);
    }
  }

  @override
  Future<void> deleteProjectInventory(String id, String projectCode) async {
    lastDeletedId = id;
    items.removeWhere((i) => i.id == id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Project Inventory Calculation & Settlement Tests', () {
    test('Calculates balance accurately: 100 - (60 + 10) = 30 bags (Unsettled)', () {
      final item = ProjectInventoryItem(
        id: 'inv_1',
        projectCode: 'PRJ-TEST-001',
        supervisorId: 'kumar',
        supervisorName: 'Kumar',
        itemId: 'cement_bags',
        itemName: 'cement bags',
        unit: 'bags',
        issuedQty: 100,
        usedQty: 60,
        returnedQty: 10,
        updatedAt: DateTime.now(),
      );

      expect(item.balanceQty, 30.0);
      expect(item.isSettled, false);
    });

    test('Zero balance is Settled: 100 - (90 + 10) = 0 bags', () {
      final item = ProjectInventoryItem(
        id: 'inv_2',
        projectCode: 'PRJ-TEST-001',
        supervisorId: 'kumar',
        supervisorName: 'Kumar',
        itemId: 'cement_bags',
        itemName: 'cement bags',
        unit: 'bags',
        issuedQty: 100,
        usedQty: 90,
        returnedQty: 10,
        updatedAt: DateTime.now(),
      );

      expect(item.balanceQty, 0.0);
      expect(item.isSettled, true);
    });
  });

  group('Project Inventory UI Tests in ManageProjectScreen Tab 4', () {
    final testProject = SiteProject(
      id: 'proj_001',
      employeeName: 'Admin',
      clientName: 'TNEB',
      generalDetails: 'Substation Cabling',
      generalCode: 'GC-001',
      place: 'Chennai',
      projectCode: 'PRJ-001',
      status: 'Active',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    testWidgets('Displays unsettled item with 30 bags balance and calculation formula', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = _FakeInventoryProjectRepository();
      repo.items.add(
        ProjectInventoryItem(
          id: 'inv_1',
          projectCode: 'PRJ-001',
          supervisorId: 'kumar',
          supervisorName: 'Kumar',
          itemId: 'cement_bags',
          itemName: 'cement bags',
          unit: 'bags',
          issuedQty: 100,
          usedQty: 60,
          returnedQty: 10,
          updatedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            projectRepositoryProvider.overrideWithValue(repo),
            projectsStreamProvider.overrideWith((ref) => Stream.value([testProject])),
          ],
          child: MaterialApp(
            home: ManageProjectScreen(
              projectId: 'proj_001',
              initialProject: testProject,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to Section 4: Project Inventory
      await tester.tap(find.text('Project Inventory'));
      await tester.pumpAndSettle();

      // Verify header and Record Material button
      expect(find.text('Project Material Inventory'), findsOneWidget);
      expect(find.text('Record Material'), findsOneWidget);

      // Verify supervisor and item name
      expect(find.text('cement bags'), findsOneWidget);
      expect(find.text('Supervisor: Kumar'), findsOneWidget);

      // Verify Issued, Used, Returned breakdown
      expect(find.text('Issued: 100 • Used: 60 • Returned: 10 bags'), findsOneWidget);

      // Verify Exact Calculation formula
      expect(find.text('Calculation: 100 - (60 + 10) = 30 bags'), findsOneWidget);

      // Verify Balance and Unsettled badge
      expect(find.text('Balance: 30 bags'), findsOneWidget);
      expect(find.text('Unsettled'), findsWidgets);
    });

    testWidgets('Clicking Record Material opens dialog with live calculation', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = _FakeInventoryProjectRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            projectRepositoryProvider.overrideWithValue(repo),
            projectsStreamProvider.overrideWith((ref) => Stream.value([testProject])),
          ],
          child: MaterialApp(
            home: ManageProjectScreen(
              projectId: 'proj_001',
              initialProject: testProject,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to Section 4
      await tester.tap(find.text('Project Inventory'));
      await tester.pumpAndSettle();

      // Click Record Material
      await tester.tap(find.text('Record Material'));
      await tester.pumpAndSettle();

      // Verify dialog is open
      expect(find.text('Supervisor In-Charge Name *'), findsOneWidget);
      expect(find.text('Material / Item Name *'), findsOneWidget);

      // Enter test values: Kumar, cement bags, 100, 60, 10
      await tester.enterText(find.widgetWithText(TextField, 'Supervisor In-Charge Name *'), 'Kumar');
      await tester.enterText(find.widgetWithText(TextField, 'Material / Item Name *'), 'cement bags');
      await tester.enterText(find.widgetWithText(TextField, 'Issued Quantity'), '100');
      await tester.enterText(find.widgetWithText(TextField, 'Used Quantity'), '60');
      await tester.enterText(find.widgetWithText(TextField, 'Returned Quantity'), '10');
      await tester.pumpAndSettle();

      // Live calculation in dialog: 100 - (60 + 10) = 30 bags
      expect(find.text('Remaining Balance: 30 bags'), findsOneWidget);
      expect(find.text('Calculation: 100 - (60 + 10) = 30 bags'), findsOneWidget);

      // Click Save Material Record
      await tester.tap(find.text('Save Material Record'));
      await tester.pumpAndSettle();

      expect(repo.lastSavedItem, isNotNull);
      expect(repo.lastSavedItem!.supervisorName, 'Kumar');
      expect(repo.lastSavedItem!.itemName, 'cement bags');
      expect(repo.lastSavedItem!.issuedQty, 100.0);
      expect(repo.lastSavedItem!.usedQty, 60.0);
      expect(repo.lastSavedItem!.returnedQty, 10.0);
      expect(repo.lastSavedItem!.balanceQty, 30.0);
      expect(repo.lastSavedItem!.isSettled, false);
    });
  });
}

