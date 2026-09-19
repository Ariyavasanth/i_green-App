import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_record.dart';
import 'package:flutter_application_1/features/attendance_management/presentation/widgets/monthly_attendance_result_view.dart';
import 'package:flutter_application_1/features/employee/domain/employee.dart';
import 'package:flutter_application_1/features/leave/domain/leave_request.dart';
import 'package:flutter_application_1/features/on_duty/domain/on_duty_assignment.dart';

void main() {
  group('Phase 2C — Monthly Attendance Result UI Tests', () {
    const testEmployee1 = Employee(
      id: 101,
      employeeId: 'EMP-101',
      firstName: 'Vikram',
      lastName: 'Sharma',
      emailAddress: 'vikram@example.com',
      phoneNumber: '9876543210',
      gender: 'Male',
      dob: '01-01-1995',
      organizationName: 'IGreen',
      department: 'Engineering',
      designation: 'Engineer',
      employmentType: 'Full-Time',
      joiningDate: '01-01-2025',
      status: 'Active',
      inTime: '09:00 AM',
      outTime: '06:00 PM',
      requiredWorkingHours: 9.0,
      workScheduleType: 'Fixed',
      weeklyOffDay: 'Sunday',
    );

    const testEmployee2 = Employee(
      id: 102,
      employeeId: 'EMP-102',
      firstName: 'Priya',
      lastName: 'Patel',
      emailAddress: 'priya@example.com',
      phoneNumber: '9876543211',
      gender: 'Female',
      dob: '01-01-1996',
      organizationName: 'IGreen',
      department: 'Finance',
      designation: 'Accountant',
      employmentType: 'Full-Time',
      joiningDate: '01-01-2025',
      status: 'Active',
      inTime: '09:30 AM',
      outTime: '06:30 PM',
      requiredWorkingHours: 8.0,
      workScheduleType: 'Fixed',
      weeklyOffDay: 'Sunday',
    );

    // Records for Vikram (EMP-101) in September 2026:
    // Day 1 to 5: Present (9 hrs each = 45 hrs)
    // Day 6: Sunday (Weekly Off)
    // Day 11: Late (8.5 hrs)
    // Day 12: Missing Check-Out (0 hrs)
    // Day 18: Insufficient Hours (4.0 hrs)
    final records = <AttendanceRecord>[];
    for (int d = 1; d <= 5; d++) {
      records.add(AttendanceRecord(
        id: d,
        employeeId: 101,
        employeeCode: 'EMP-101',
        employeeName: 'Vikram Sharma',
        date: '${d.toString().padLeft(2, '0')}-09-2026',
        time: '09:00 AM',
        checkInTime: '09:00 AM',
        checkOutTime: '06:00 PM',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        totalHours: 9.0,
      ));
    }

    records.add(const AttendanceRecord(
      id: 11,
      employeeId: 101,
      employeeCode: 'EMP-101',
      employeeName: 'Vikram Sharma',
      date: '11-09-2026',
      time: '09:30 AM',
      checkInTime: '09:30 AM',
      checkOutTime: '06:00 PM',
      status: 'Late',
      verificationStatus: 'Verified',
      similarityScore: 1.0,
      totalHours: 8.5,
    ));

    records.add(const AttendanceRecord(
      id: 12,
      employeeId: 101,
      employeeCode: 'EMP-101',
      employeeName: 'Vikram Sharma',
      date: '12-09-2026',
      time: '09:00 AM',
      checkInTime: '09:00 AM',
      checkOutTime: '',
      status: 'Missing Check-Out',
      verificationStatus: 'Verified',
      similarityScore: 1.0,
      totalHours: 0.0,
    ));

    records.add(const AttendanceRecord(
      id: 18,
      employeeId: 101,
      employeeCode: 'EMP-101',
      employeeName: 'Vikram Sharma',
      date: '18-09-2026',
      time: '09:00 AM',
      checkInTime: '09:00 AM',
      checkOutTime: '01:00 PM',
      status: 'Insufficient Hours',
      verificationStatus: 'Verified',
      similarityScore: 1.0,
      totalHours: 4.0,
    ));

    const leave = LeaveRequest(
      id: 1,
      employeeId: 101,
      employeeName: 'Vikram Sharma',
      employeeCustomId: 'EMP-101',
      leaveType: 'Casual Leave',
      fromDate: '14-09-2026',
      toDate: '15-09-2026',
      reason: 'Personal leave',
      status: 'Approved',
      numDays: 2.0,
      createdAt: '2026-09-10T10:00:00.000',
    );

    const od = OnDutyAssignment(
      id: 1,
      employeeId: 101,
      employeeName: 'Vikram Sharma',
      odType: 'Client Visit',
      purpose: 'Site Inspection',
      destination: 'Project Alpha',
      date: '16-09-2026',
      status: 'APPROVED',
      assignedBy: 'Manager',
      createdAt: '2026-09-10T10:00:00.000',
    );

    final holidays = ['17-09-2026'];

    testWidgets('1. Monthly summary renders all 8 KPI cards and employee profile details',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyAttendanceResultView(
                focusedMonth: DateTime(2026, 9, 1),
                employees: const [testEmployee1, testEmployee2],
                selectedEmployeeId: 101,
                records: records,
                leaves: const [leave],
                onDutyAssignments: const [od],
                holidays: holidays,
                isMobile: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Employee Profile Card
      expect(find.text('Vikram Sharma'), findsWidgets);
      expect(find.text('EMP-101'), findsWidgets);
      expect(find.text('Engineering'), findsWidgets);
      expect(find.text('Engineer'), findsWidgets);

      // Check 8 Status Summary KPI Cards
      expect(find.text('Present'), findsWidgets);
      expect(find.text('Late'), findsWidgets);
      expect(find.text('Absent'), findsWidgets);
      expect(find.text('On Leave'), findsWidgets);
      expect(find.text('Weekly Off'), findsWidgets);
      expect(find.text('Holiday'), findsWidgets);
      expect(find.text('Missing Check-Out'), findsWidgets);
      expect(find.text('Insufficient Hours'), findsWidgets);

      // Check Specific Counts for Vikram Sharma
      expect(find.text('5'), findsWidgets); // 5 Present
      expect(find.text('1'), findsWidgets); // 1 Late, 1 MC, 1 IH, 1 Holiday, 1 OD
      expect(find.text('4'), findsWidgets); // 4 Weekly Offs (Sundays)
      expect(find.text('2'), findsWidgets); // 2 On Leave (Sept 14 & 15)
    });

    testWidgets('2. Monthly Hours Summary Banner renders required, working, and shortfall hours',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyAttendanceResultView(
                focusedMonth: DateTime(2026, 9, 1),
                employees: const [testEmployee1],
                selectedEmployeeId: 101,
                records: records,
                leaves: const [leave],
                onDutyAssignments: const [od],
                holidays: holidays,
                isMobile: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Monthly Hours Summary'), findsOneWidget);
      expect(find.text('Total Required Hours'), findsOneWidget);
      expect(find.text('Total Working Hours'), findsOneWidget);
      expect(find.text('Total Shortfall'), findsOneWidget);

      // 25 working days * 9.0 = 225.0 hrs
      expect(find.text('225hr'), findsOneWidget);
      // Working: 5*9.0 + 8.5 + 4.0 = 57.5 hrs -> '57hr 30min'
      expect(find.text('57hr 30min'), findsOneWidget);
      expect(find.text('57.5 hrs logged'), findsOneWidget);
    });

    testWidgets('3. Daily breakdown table renders dates, status badges, in/out, and working hours',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyAttendanceResultView(
                focusedMonth: DateTime(2026, 9, 1),
                employees: const [testEmployee1],
                selectedEmployeeId: 101,
                records: records,
                leaves: const [leave],
                onDutyAssignments: const [od],
                holidays: holidays,
                isMobile: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Table Header
      expect(find.text('Daily Attendance — September 2026'), findsOneWidget);
      expect(find.text('30 Days'), findsOneWidget);

      // Check specific day rows
      expect(find.text('01-09-2026'), findsOneWidget);
      expect(find.text('11-09-2026'), findsOneWidget);
      expect(find.text('14-09-2026'), findsOneWidget);
      expect(find.text('16-09-2026'), findsOneWidget);
      expect(find.text('17-09-2026'), findsOneWidget);

      // Status Badges
      expect(find.text('P - Present'), findsWidgets);
      expect(find.text('L - Late'), findsWidgets);
      expect(find.text('OL - On Leave'), findsWidgets);
      expect(find.text('OD - On Duty'), findsWidgets);
      expect(find.text('H - Holiday'), findsWidgets);
      expect(find.text('WO - Weekly Off'), findsWidgets);
    });

    testWidgets('4. Employee selection filter updates the displayed monthly result',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      int? selectedEmp = 101;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (ctx, setState) {
                return SingleChildScrollView(
                  child: MonthlyAttendanceResultView(
                    focusedMonth: DateTime(2026, 9, 1),
                    employees: const [testEmployee1, testEmployee2],
                    selectedEmployeeId: selectedEmp,
                    onEmployeeChanged: (id) => setState(() => selectedEmp = id),
                    records: records,
                    isMobile: false,
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vikram Sharma (EMP-101)'), findsOneWidget);

      // Tap to open Employee Selection Dialog
      await tester.tap(find.text('Vikram Sharma (EMP-101)'));
      await tester.pumpAndSettle();

      // Select Priya Patel
      expect(find.text('Select Employee'), findsOneWidget);
      expect(find.text('Priya Patel'), findsOneWidget);
      await tester.tap(find.text('Priya Patel'));
      await tester.pumpAndSettle();

      // Selected employee updated to Priya Patel
      expect(selectedEmp, equals(102));
      expect(find.text('Priya Patel (EMP-102)'), findsOneWidget);
      expect(find.text('Finance'), findsWidgets);
      expect(find.text('Accountant'), findsWidgets);
    });

    testWidgets('5. Month navigation chevrons update the focused month',
        (WidgetTester tester) async {
      DateTime currentMonth = DateTime(2026, 9, 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (ctx, setState) {
                return SingleChildScrollView(
                  child: MonthlyAttendanceResultView(
                    focusedMonth: currentMonth,
                    onMonthChanged: (m) => setState(() => currentMonth = m),
                    employees: const [testEmployee1],
                    selectedEmployeeId: 101,
                    records: records,
                    isMobile: false,
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('September 2026'), findsWidgets);

      // Tap Next Month
      await tester.tap(find.byTooltip('Next Month'));
      await tester.pumpAndSettle();

      expect(currentMonth.month, equals(10));
      expect(find.text('October 2026'), findsWidgets);

      // Tap Previous Month twice -> August 2026
      await tester.tap(find.byTooltip('Previous Month'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Previous Month'));
      await tester.pumpAndSettle();

      expect(currentMonth.month, equals(8));
      expect(find.text('August 2026'), findsWidgets);
    });

    testWidgets('6. Department and Designation dropdown filters accurately constrain employee list',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyAttendanceResultView(
                focusedMonth: DateTime(2026, 9, 1),
                employees: const [testEmployee1, testEmployee2],
                selectedEmployeeId: 101,
                records: records,
                isMobile: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find department dropdown
      final deptFinder = find.byKey(const ValueKey('department_dropdown'));
      expect(deptFinder, findsOneWidget);

      // Select Finance department
      await tester.tap(deptFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finance').last);
      await tester.pumpAndSettle();

      // Now active employee should be Priya Patel (Finance)
      expect(find.text('Priya Patel (EMP-102)'), findsOneWidget);
    });

    testWidgets('7. Mobile view renders responsive daily cards list without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyAttendanceResultView(
                focusedMonth: DateTime(2026, 9, 1),
                employees: const [testEmployee1],
                selectedEmployeeId: 101,
                records: records,
                leaves: const [leave],
                onDutyAssignments: const [od],
                holidays: holidays,
                isMobile: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Mobile cards rendered cleanly without RenderFlex overflow
      expect(find.text('01-09-2026'), findsOneWidget);
      expect(find.text('In: 09:00 AM'), findsWidgets);
      expect(find.text('Out: 06:00 PM'), findsWidgets);
      expect(find.text('Work: 9hr  |  Req: 9hr'), findsWidgets);
      expect(find.text('Shortfall: 0hr'), findsWidgets);
    });
  });
}
