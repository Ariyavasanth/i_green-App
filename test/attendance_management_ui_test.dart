import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_record.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_session.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_status_helper.dart';
import 'package:flutter_application_1/features/attendance/presentation/widgets/attendance_details_dialog.dart';
import 'package:flutter_application_1/features/attendance_management/presentation/widgets/attendance_correction_dialog.dart';
import 'package:flutter_application_1/features/attendance_management/presentation/widgets/attendance_matrix_view.dart';
import 'package:flutter_application_1/features/attendance_management/presentation/widgets/attendance_table_view.dart';
import 'package:flutter_application_1/features/employee/domain/employee.dart';

void main() {
  group('Phase 2B — Admin Attendance Management UI & Data Integration Tests', () {
    const sampleEmployee = Employee(
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

    final multiSessionRecord = AttendanceRecord(
      id: 1,
      employeeId: 101,
      employeeCode: 'EMP-101',
      employeeName: 'Vikram Sharma',
      date: '15-09-2026',
      time: '09:00 AM',
      status: 'Present',
      verificationStatus: 'Geofence Verified',
      similarityScore: 1.0,
      checkInTime: '09:00 AM',
      checkOutTime: '06:00 PM',
      totalHours: 9.0,
      sessions: [
        const AttendanceSession(
          id: 's1',
          type: 'Office',
          checkInTime: '09:00 AM',
          checkOutTime: '01:00 PM',
          durationMinutes: 240,
          durationHours: 4.0,
        ),
        const AttendanceSession(
          id: 's2',
          type: 'Lunch Break',
          checkInTime: '01:00 PM',
          checkOutTime: '01:45 PM',
          durationMinutes: 45,
          durationHours: 0.75,
        ),
        const AttendanceSession(
          id: 's3',
          type: 'OD',
          checkInTime: '01:45 PM',
          checkOutTime: '04:45 PM',
          durationMinutes: 180,
          durationHours: 3.0,
        ),
        const AttendanceSession(
          id: 's4',
          type: 'Tea Break',
          checkInTime: '04:45 PM',
          checkOutTime: '05:00 PM',
          durationMinutes: 15,
          durationHours: 0.25,
        ),
        const AttendanceSession(
          id: 's5',
          type: 'Client Meeting',
          checkInTime: '05:00 PM',
          checkOutTime: '06:00 PM',
          durationMinutes: 60,
          durationHours: 1.0,
        ),
      ],
    );

    testWidgets('1. AttendanceTableView displays all 13 required columns and accurate session values',
        (WidgetTester tester) async {
      AttendanceRecord? tappedRecord;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceTableView(
              records: [multiSessionRecord],
              employees: const [sampleEmployee],
              onEdit: (_) {},
              onDelete: (_) {},
              onRowTap: (rec, emp) {
                tappedRecord = rec;
              },
            ),
          ),
        ),
      );

      // Verify Column headers
      expect(find.text('Date'), findsOneWidget);
      expect(find.text('Employee'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Check In'), findsOneWidget);
      expect(find.text('Check Out'), findsOneWidget);
      expect(find.text('Office Hrs'), findsOneWidget);
      expect(find.text('OD Hrs'), findsOneWidget);
      expect(find.text('Lunch Hrs'), findsOneWidget);
      expect(find.text('Tea Hrs'), findsOneWidget);
      expect(find.text('Meeting/Other'), findsOneWidget);
      expect(find.text('Total Hrs'), findsOneWidget);
      expect(find.text('Req. Hrs'), findsOneWidget);
      expect(find.text('Shortfall'), findsOneWidget);
      expect(find.text('Actions'), findsOneWidget);

      // Verify Row Values
      expect(find.text('15-09-2026'), findsOneWidget);
      expect(find.text('Vikram Sharma'), findsOneWidget);
      expect(find.text('EMP-101'), findsOneWidget);
      expect(find.text('4hr'), findsOneWidget); // Office
      expect(find.text('3hr'), findsOneWidget); // OD
      expect(find.text('45min'), findsOneWidget); // Lunch
      expect(find.text('15min'), findsOneWidget); // Tea
      expect(find.text('1hr'), findsOneWidget); // Meeting
      expect(find.text('9hr'), findsOneWidget); // Total Hrs
      expect(find.text('9.0hr'), findsOneWidget); // Req. Hrs
      expect(find.text('0hr'), findsOneWidget); // Shortfall

      // Tap on employee name to trigger row tap
      await tester.tap(find.text('Vikram Sharma'));
      await tester.pump();
      expect(tappedRecord, equals(multiSessionRecord));
    });

    testWidgets('2. AttendanceMatrixView renders employee, days, and tooltip contains all session metrics',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceMatrixView(
              focusedMonth: DateTime(2026, 9, 1),
              employees: const [sampleEmployee],
              records: [multiSessionRecord],
              onCellTap: (emp, date, rec, status) {},
            ),
          ),
        ),
      );

      expect(find.text('Employee'), findsOneWidget);
      expect(find.text('Vikram Sharma'), findsOneWidget);
      expect(find.text('EMP-101'), findsOneWidget);

      // Verify day 15 cell is present
      final tooltipFinder = find.byType(Tooltip);
      expect(tooltipFinder, findsWidgets);

      // Find tooltip on day 15
      bool foundDay15Tooltip = false;
      for (final widget in tester.widgetList<Tooltip>(tooltipFinder)) {
        if (widget.message?.contains('Date: 15-09-2026') == true) {
          foundDay15Tooltip = true;
          expect(widget.message, contains('Status: Present'));
          expect(widget.message, contains('Office: 4hr'));
          expect(widget.message, contains('OD: 3hr'));
          expect(widget.message, contains('Lunch: 45min'));
          expect(widget.message, contains('Tea: 15min'));
          expect(widget.message, contains('Meeting/Other: 1hr'));
          expect(widget.message, contains('Total Hours: 9hr'));
          expect(widget.message, contains('Req Hours: 9.0hr'));
          expect(widget.message, contains('Shortfall: 0hr'));
          break;
        }
      }
      expect(foundDay15Tooltip, isTrue);
    });

    testWidgets('3. AttendanceDetailsDialog displays complete employee, status, breakdown and shortfall cards',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceDetailsDialog(
              employee: sampleEmployee,
              date: DateTime(2026, 9, 15),
              record: multiSessionRecord,
              statusInfo: AttendanceStatusInfo.present,
            ),
          ),
        ),
      );

      // Header & Employee card
      expect(find.text('Attendance Details'), findsOneWidget);
      expect(find.text('Vikram Sharma'), findsOneWidget);
      expect(find.text('EMP-101 • Engineering'), findsOneWidget);
      expect(find.text('P - Present'), findsOneWidget);

      // Check-in / Check-out
      expect(find.text('Check-in'), findsOneWidget);
      expect(find.text('Check-out'), findsOneWidget);

      // Session Hours Breakdown Card
      expect(find.text('SESSION HOURS BREAKDOWN'), findsOneWidget);
      expect(find.text('Office'), findsOneWidget);
      expect(find.text('4hr'), findsOneWidget);
      expect(find.text('OD'), findsOneWidget);
      expect(find.text('3hr'), findsOneWidget);
      expect(find.text('Lunch (Paid)'), findsOneWidget);
      expect(find.text('45min'), findsOneWidget);
      expect(find.text('Tea Break (Paid)'), findsOneWidget);
      expect(find.text('15min'), findsOneWidget);
      expect(find.text('Meeting / Other'), findsOneWidget);
      expect(find.text('1hr'), findsOneWidget);

      // Hours & Shortfall Card
      expect(find.text('HOURS & SHORTFALL CALCULATION'), findsOneWidget);
      expect(find.text('Total Working Hours'), findsOneWidget);
      expect(find.text('Required Hours'), findsOneWidget);
      expect(find.text('Shortfall'), findsOneWidget);
      expect(find.text('9.0hr'), findsOneWidget);
      expect(find.text('0hr'), findsOneWidget);
    });

    testWidgets('4. AttendanceDetailsDialog for unrecorded absent day shows 0hr working hours & full shortfall',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceDetailsDialog(
              employee: sampleEmployee,
              date: DateTime(2026, 9, 10),
              record: null,
              statusInfo: AttendanceStatusInfo.absent,
            ),
          ),
        ),
      );

      expect(find.text('A - Absent'), findsOneWidget);
      expect(find.text('0hr'), findsOneWidget); // Total Working Hours
      expect(find.text('9.0hr'), findsNWidgets(2)); // Required Hours and Shortfall
      expect(find.text('System Auto-Resolved (Absent)'), findsOneWidget);
    });

    testWidgets('5. AttendanceCorrectionDialog validates mandatory reason and supports all statuses',
        (WidgetTester tester) async {
      String? submittedCheckIn;
      String? submittedCheckOut;
      String? submittedStatus;
      String? submittedReason;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceCorrectionDialog(
              employee: sampleEmployee,
              date: DateTime(2026, 9, 15),
              record: multiSessionRecord,
              statusInfo: AttendanceStatusInfo.present,
              onSubmitted: ({
                required String correctedCheckIn,
                required String correctedCheckOut,
                required String correctedStatus,
                required String reason,
              }) {
                submittedCheckIn = correctedCheckIn;
                submittedCheckOut = correctedCheckOut;
                submittedStatus = correctedStatus;
                submittedReason = reason;
              },
            ),
          ),
        ),
      );

      expect(find.text('Attendance Correction'), findsOneWidget);
      expect(find.text('Submit Correction'), findsOneWidget);

      // Attempt to submit without reason -> should trigger validation
      await tester.tap(find.text('Submit Correction'));
      await tester.pump();
      expect(find.text('Mandatory correction reason required for audit tracking'), findsOneWidget);

      // Enter valid reason and submit
      final reasonField = find.byType(TextFormField).last;
      await tester.enterText(reasonField, 'Admin verified physical presence at client meeting');
      await tester.pump();

      await tester.tap(find.text('Submit Correction'));
      await tester.pump();

      expect(submittedStatus, equals('Present'));
      expect(submittedReason, equals('Admin verified physical presence at client meeting'));
      expect(submittedCheckIn, isNotEmpty);
      expect(submittedCheckOut, isNotEmpty);
    });
  });
}
