import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/leave/domain/leave_request.dart';
import 'package:flutter_application_1/features/leave/domain/leave_overlap_validator.dart';

void main() {
  group('Step 5 — Leave Overlap Validation Test Suite', () {
    const empId = 1;

    LeaveRequest createSampleRequest({
      required int id,
      required String fromDate,
      required String toDate,
      required String status,
      bool isHalfDay = false,
      String? halfDayPeriod,
      String leaveType = 'Sick Leave',
    }) {
      return LeaveRequest(
        id: id,
        employeeId: empId,
        employeeName: 'Ariya Vasanth',
        employeeCustomId: 'EMP-001',
        leaveType: leaveType,
        fromDate: fromDate,
        toDate: toDate,
        numDays: isHalfDay ? 0.5 : 1.0,
        reason: 'Sample leave reason',
        status: status,
        createdAt: DateTime.now().toIso8601String(),
        isHalfDay: isHalfDay,
        halfDayPeriod: halfDayPeriod,
      );
    }

    test('Scenario 1 — Existing Full Day vs New Full Day (Same Date) -> ❌ Block', () {
      final existing = [
        createSampleRequest(
          id: 1,
          fromDate: '25-08-2026',
          toDate: '25-08-2026',
          status: 'Pending',
          isHalfDay: false,
        ),
      ];

      final result = LeaveOverlapValidator.checkOverlap(
        newFromDate: '25-08-2026',
        newToDate: '25-08-2026',
        isHalfDay: false,
        existingRequests: existing,
        employeeId: empId,
      );

      expect(result.hasOverlap, true);
      expect(result.message, contains('Leave already requested for 25 Aug 2026'));
    });

    test('Scenario 2 — Existing Full Day vs New First Half (Same Date) -> ❌ Block', () {
      final existing = [
        createSampleRequest(
          id: 1,
          fromDate: '25-08-2026',
          toDate: '25-08-2026',
          status: 'Approved',
          isHalfDay: false,
        ),
      ];

      final result = LeaveOverlapValidator.checkOverlap(
        newFromDate: '25-08-2026',
        newToDate: '25-08-2026',
        isHalfDay: true,
        halfDayPeriod: 'first_half',
        existingRequests: existing,
        employeeId: empId,
      );

      expect(result.hasOverlap, true);
    });

    test('Scenario 3 — Existing Full Day vs New Second Half (Same Date) -> ❌ Block', () {
      final existing = [
        createSampleRequest(
          id: 1,
          fromDate: '25-08-2026',
          toDate: '25-08-2026',
          status: 'Pending',
          isHalfDay: false,
        ),
      ];

      final result = LeaveOverlapValidator.checkOverlap(
        newFromDate: '25-08-2026',
        newToDate: '25-08-2026',
        isHalfDay: true,
        halfDayPeriod: 'second_half',
        existingRequests: existing,
        employeeId: empId,
      );

      expect(result.hasOverlap, true);
    });

    test('Scenario 4 — Existing First Half vs New First Half (Same Date) -> ❌ Block', () {
      final existing = [
        createSampleRequest(
          id: 1,
          fromDate: '25-08-2026',
          toDate: '25-08-2026',
          status: 'Pending',
          isHalfDay: true,
          halfDayPeriod: 'first_half',
        ),
      ];

      final result = LeaveOverlapValidator.checkOverlap(
        newFromDate: '25-08-2026',
        newToDate: '25-08-2026',
        isHalfDay: true,
        halfDayPeriod: 'first_half',
        existingRequests: existing,
        employeeId: empId,
      );

      expect(result.hasOverlap, true);
    });

    test('Scenario 5 — Existing Second Half vs New Second Half (Same Date) -> ❌ Block', () {
      final existing = [
        createSampleRequest(
          id: 1,
          fromDate: '25-08-2026',
          toDate: '25-08-2026',
          status: 'Approved',
          isHalfDay: true,
          halfDayPeriod: 'second_half',
        ),
      ];

      final result = LeaveOverlapValidator.checkOverlap(
        newFromDate: '25-08-2026',
        newToDate: '25-08-2026',
        isHalfDay: true,
        halfDayPeriod: 'second_half',
        existingRequests: existing,
        employeeId: empId,
      );

      expect(result.hasOverlap, true);
    });

    test('Scenario 6 — Existing First Half vs New Second Half (Same Date) -> ✅ Allow', () {
      final existing = [
        createSampleRequest(
          id: 1,
          fromDate: '25-08-2026',
          toDate: '25-08-2026',
          status: 'Pending',
          isHalfDay: true,
          halfDayPeriod: 'first_half',
        ),
      ];

      final result = LeaveOverlapValidator.checkOverlap(
        newFromDate: '25-08-2026',
        newToDate: '25-08-2026',
        isHalfDay: true,
        halfDayPeriod: 'second_half',
        existingRequests: existing,
        employeeId: empId,
      );

      expect(result.hasOverlap, false);
    });

    test('Scenario 7 — Existing Second Half vs New First Half (Same Date) -> ✅ Allow', () {
      final existing = [
        createSampleRequest(
          id: 1,
          fromDate: '25-08-2026',
          toDate: '25-08-2026',
          status: 'Approved',
          isHalfDay: true,
          halfDayPeriod: 'second_half',
        ),
      ];

      final result = LeaveOverlapValidator.checkOverlap(
        newFromDate: '25-08-2026',
        newToDate: '25-08-2026',
        isHalfDay: true,
        halfDayPeriod: 'first_half',
        existingRequests: existing,
        employeeId: empId,
      );

      expect(result.hasOverlap, false);
    });

    test('Scenario 8 — Date Range Overlap (25-27 Aug vs 26-28 Aug) -> ❌ Block', () {
      final existing = [
        createSampleRequest(
          id: 1,
          fromDate: '25-08-2026',
          toDate: '27-08-2026',
          status: 'Pending',
          leaveType: 'Casual Leave',
        ),
      ];

      final result = LeaveOverlapValidator.checkOverlap(
        newFromDate: '26-08-2026',
        newToDate: '28-08-2026',
        isHalfDay: false,
        existingRequests: existing,
        employeeId: empId,
      );

      expect(result.hasOverlap, true);
      expect(result.dateStatusMap['26 Aug 2026'], contains('Casual Leave'));
      expect(result.dateStatusMap['27 Aug 2026'], contains('Casual Leave'));
      expect(result.dateStatusMap['28 Aug 2026'], 'Available');
    });

    test('Scenario 9 — Cancelled or Rejected Existing Requests -> ✅ Allow', () {
      final existing = [
        createSampleRequest(
          id: 1,
          fromDate: '25-08-2026',
          toDate: '25-08-2026',
          status: 'Cancelled',
        ),
        createSampleRequest(
          id: 2,
          fromDate: '26-08-2026',
          toDate: '26-08-2026',
          status: 'Rejected',
        ),
        createSampleRequest(
          id: 3,
          fromDate: '27-08-2026',
          toDate: '27-08-2026',
          status: 'Denied',
        ),
      ];

      final result = LeaveOverlapValidator.checkOverlap(
        newFromDate: '25-08-2026',
        newToDate: '27-08-2026',
        isHalfDay: false,
        existingRequests: existing,
        employeeId: empId,
      );

      expect(result.hasOverlap, false);
    });
  });
}
