import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/employee/domain/employee.dart';
import 'package:flutter_application_1/features/employee/providers/employee_providers.dart';
import 'package:flutter_application_1/features/projects/presentation/screens/new_project_form_screen.dart';
import 'package:flutter_application_1/features/projects/providers/project_providers.dart';
import 'package:flutter_application_1/features/tenders/domain/models/tender.dart';
import 'package:flutter_application_1/features/tenders/providers/tender_providers.dart';
import 'package:flutter_application_1/models/customer.dart';
import 'package:flutter_application_1/providers/customer_providers.dart';

void main() {
  final testEmp1 = Employee(
    id: 1,
    employeeId: 'EMP-001',
    firstName: 'Saravanan',
    lastName: 'G S',
    emailAddress: 'saravanan@igreentech.com',
    phoneNumber: '9876543210',
    gender: 'Male',
    dob: '1990-01-01',
    organizationName: 'iGreen',
    department: 'Projects',
    designation: 'Senior Project Lead',
    employmentType: 'Full-time',
    joiningDate: '2020-01-01',
    status: 'Active',
  );

  final testCustomer = Customer(
    id: 1,
    displayName: 'Client Corp',
    companyName: 'Client Corp Ltd',
    gstTreatment: 'Consumer',
    placeOfSupply: 'Tamil Nadu',
  );

  final wonTender = Tender(
    tenderId: 'TND-2024-001',
    tenderRefNo: 'REF-WON-99',
    title: 'Chennai Solar Installation',
    clientName: 'Client Corp',
    tenderType: 'Open Tender',
    status: 'Won',
    tenderAmount: 2500000.0,
    awardedValue: 2450000.0,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  testWidgets('A & E: General Code section keeps Client, Project Details, Place; removes Employee Name, General Code, and Assigned To',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allEmployeesProvider.overrideWith((ref) => Future.value([testEmp1])),
          currentEmployeeProvider.overrideWithValue(testEmp1),
          activeCustomersProvider.overrideWith((ref) => Future.value([testCustomer])),
          tendersStreamProvider.overrideWith((ref) => Stream.value([wonTender])),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: NewProjectFormScreen(initialTabIndex: 1),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify SECTION 1 - PROJECT DETAILS
    expect(find.text('SECTION 1'), findsOneWidget);
    expect(find.text('PROJECT DETAILS'), findsOneWidget);

    // Kept fields: Client, Project Name / Details, Place
    expect(find.text('Project Name / Details *'), findsOneWidget);
    expect(find.text('Place'), findsOneWidget);

    // Employee Name must NOT be present in creation form
    expect(find.text('Employee Name *'), findsNothing);

    // General Code and CREATE CODE button must be removed from Section 1
    expect(find.text('General Code'), findsNothing);

    // Section 4 (Tender Spec) and Section 5 (Assigned To) must be removed from New Project form
    expect(find.text('TENDER SPEC / ENQUIRY SPEC'), findsNothing);
    expect(find.text('ASSIGNED TO'), findsNothing);
  });

  testWidgets('B: Project Code section has auto-generation, Sub Division, Area, Project Value; removes Approximate Value',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allEmployeesProvider.overrideWith((ref) => Future.value([testEmp1])),
          currentEmployeeProvider.overrideWithValue(testEmp1),
          activeCustomersProvider.overrideWith((ref) => Future.value([testCustomer])),
          tendersStreamProvider.overrideWith((ref) => Stream.value([wonTender])),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: NewProjectFormScreen(initialTabIndex: 1),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Section 2 header
    expect(find.text('SECTION 2'), findsOneWidget);
    expect(find.text('PROJECT CODE'), findsOneWidget);

    // Mapped to Tender toggle exists
    expect(find.text('Mapped to Tender *'), findsOneWidget);

    // Sub Division, State, District, Area
    expect(find.text('Sub Division (Main / Sub)'), findsOneWidget);
    expect(find.text('State'), findsOneWidget);
    expect(find.text('District'), findsOneWidget);
    expect(find.text('Area'), findsOneWidget);

    // Actual Project Value kept as Project Value (Work Order / Contract) *
    expect(find.text('Project Value (Work Order / Contract) *'), findsOneWidget);

    // Approximate Project Value must be REMOVED
    expect(find.text('Approximate Project Value'), findsNothing);

    // Automatic Project Code display card exists with 'Auto' badge
    expect(find.text('Project Code (Auto-Generated)'), findsOneWidget);
    expect(find.text('Auto'), findsOneWidget);
  });

  testWidgets('C: When Mapped to Tender (Yes), displays read-only Won Tender info without Qualified field',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allEmployeesProvider.overrideWith((ref) => Future.value([testEmp1])),
          currentEmployeeProvider.overrideWithValue(testEmp1),
          activeCustomersProvider.overrideWith((ref) => Future.value([testCustomer])),
          tendersStreamProvider.overrideWith((ref) => Stream.value([wonTender])),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: NewProjectFormScreen(
              initialTabIndex: 1,
              initialTender: wonTender,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Section 3 is visible for mapped tender
    expect(find.text('SECTION 3'), findsOneWidget);
    expect(find.text('TENDER TYPE & DETAILS'), findsOneWidget);

    // Read-only indicator banner
    expect(find.textContaining('Auto-filled from Won Tender'), findsOneWidget);

    // Fetched read-only labels
    expect(find.text('Tender Reference No'), findsOneWidget);
    expect(find.text('REF-WON-99'), findsOneWidget);
    expect(find.text('Tender Type'), findsOneWidget);
    expect(find.text('Tender Awarded Value'), findsOneWidget);
    expect(find.text('2450000'), findsWidgets);

    // Qualified field must be REMOVED
    expect(find.text('Qualified'), findsNothing);
  });
}
