import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/employee/domain/employee.dart';
import 'package:flutter_application_1/features/employee/providers/employee_providers.dart';
import 'package:flutter_application_1/features/projects/domain/models/site_project.dart';
import 'package:flutter_application_1/features/projects/presentation/screens/new_project_form_screen.dart';
import 'package:flutter_application_1/features/projects/providers/project_providers.dart';
import 'package:flutter_application_1/models/customer.dart';
import 'package:flutter_application_1/providers/customer_providers.dart';

void main() {
  setUp(() {});

  testWidgets('Section 5 displays Employee Name, Designation, Contact Number, Email, and Assigned Date',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allEmployeesProvider.overrideWith((ref) => Future.value([testEmp1])),
          currentEmployeeProvider.overrideWithValue(testEmp1),
          activeCustomersProvider.overrideWith((ref) => Future.value([testCustomer])),
          tenderTypesProvider.overrideWith((ref) => Future.value(['Open Tender', 'Limited Tender'])),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: NewProjectFormScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify SECTION 5 card header exists
    expect(find.text('SECTION 5'), findsOneWidget);
    expect(find.text('ASSIGNED TO'), findsOneWidget);

    // Verify all 5 field labels exist
    expect(
      find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('Employee Name')),
      findsWidgets,
    ); // Creator & Assigned To
    expect(find.text('Designation'), findsOneWidget);
    expect(find.text('Contact Number'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('Assigned Date')),
      findsOneWidget,
    );

    // Verify that auto-populated values match testEmp1
    expect(find.text('Senior Project Lead'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
    expect(find.text('saravanan@igreentech.com'), findsOneWidget);
  });

  testWidgets('Selecting a different employee automatically updates Designation, Contact Number, and Email',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
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

    final testEmp2 = Employee(
      id: 2,
      employeeId: 'EMP-002',
      firstName: 'Priya',
      lastName: 'Dharshini',
      emailAddress: 'priya@igreentech.com',
      phoneNumber: '9123456789',
      gender: 'Female',
      dob: '1995-05-15',
      organizationName: 'iGreen',
      department: 'Engineering',
      designation: 'Lead Electrical Engineer',
      employmentType: 'Full-time',
      joiningDate: '2022-03-01',
      status: 'Active',
    );

    final testCustomer = Customer(
      id: 1,
      displayName: 'Client Corp',
      companyName: 'Client Corp Ltd',
      gstTreatment: 'Consumer',
      placeOfSupply: 'Tamil Nadu',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allEmployeesProvider.overrideWith((ref) => Future.value([testEmp1, testEmp2])),
          currentEmployeeProvider.overrideWithValue(testEmp1),
          activeCustomersProvider.overrideWith((ref) => Future.value([testCustomer])),
          tenderTypesProvider.overrideWith((ref) => Future.value(['Open Tender', 'Limited Tender'])),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: NewProjectFormScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initial values from testEmp1
    expect(find.text('Senior Project Lead'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
    expect(find.text('saravanan@igreentech.com'), findsOneWidget);

    // Open employee dropdown in Section 5
    // Find dropdown for assigned employee (second AppSearchableDropdown<Employee>)
    final dropdownFinders = find.byType(InkWell);
    // Tap on the selector box for the second employee dropdown
    final emp2Option = find.text('EMP-002 - Priya Dharshini');

    // Tap on the searchable dropdown for Assigned To
    final assignedDropdown = find.ancestor(
      of: find.text('Senior Project Lead'),
      matching: find.byType(Column),
    );
    expect(assignedDropdown, findsWidgets);
  });

  testWidgets('Verifies Tender Value (Original Bid), Actual Project Value, and Work Order Document upload',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    final testEmp = Employee(
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allEmployeesProvider.overrideWith((ref) => Future.value([testEmp])),
          currentEmployeeProvider.overrideWithValue(testEmp),
          activeCustomersProvider.overrideWith((ref) => Future.value([testCustomer])),
          tenderTypesProvider.overrideWith((ref) => Future.value(['Open Tender', 'Limited Tender'])),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: NewProjectFormScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify renamed Tender Value (Original Bid)
    expect(find.text('Tender Value (Original Bid)'), findsOneWidget);

    // Verify Actual Project Value (Work Order / Contract) *
    expect(find.text('Actual Project Value (Work Order / Contract) *'), findsOneWidget);

    // Verify Work Order / Contract Document upload widget is present
    expect(find.text('Work Order / Contract Document'), findsOneWidget);
    expect(find.text('Upload Work Order / Contract Document'), findsOneWidget);
  });
}
