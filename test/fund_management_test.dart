import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/fund_requester/domain/models/fund_request.dart';
import 'package:flutter_application_1/features/fund_management/data/repositories/firebase_fund_management_repository.dart';

void main() {
  group('Fund Management Repository & Logic Tests', () {
    test('Initial fallback pending requests match screenshot data points', () async {
      final repo = FirebaseFundManagementRepository();
      final pending = await repo.getPendingFundRequests();

      expect(pending.isNotEmpty, isTrue);
      expect(pending.length, greaterThanOrEqualTo(3));

      // Test row 1 from screenshot
      final row1 = pending.firstWhere((r) => r.employeeId == '65');
      expect(row1.employeeName, equals('K Paramasivam'));
      expect(row1.requestAmount, equals(10550.00));
      expect(row1.message, equals('street light erection work'));
      expect(row1.projectCode, contains('TNEB-OWN-DEC/2025-107'));
      expect(row1.status, equals('Pending'));

      // Test row 2 from screenshot
      final row2 = pending.firstWhere((r) => r.requestAmount == 2000.00);
      expect(row2.employeeId, equals('84'));
      expect(row2.employeeName, equals('Deepak R'));
      expect(row2.message, equals('Police others'));

      // Test row 3 from screenshot
      final row3 = pending.firstWhere((r) => r.requestAmount == 27000.00);
      expect(row3.employeeId, equals('84'));
      expect(row3.employeeName, equals('Deepak R'));
      expect(row3.message, equals('Night shift Machine advance and hydra'));
    });

    test('Full approval sets status to Approved and updates approved amount', () async {
      final repo = FirebaseFundManagementRepository();
      final pending = await repo.getPendingFundRequests();
      final target = pending.first;

      await repo.approveOrPartiallyApproveRequest(
        requestId: target.id,
        projectCode: target.projectCode,
        approvedAmount: target.requestAmount,
        approvedBy: 'Managing Director',
        remarks: 'Approved in full',
      );

      final all = await repo.getAllFundRequests();
      final updated = all.firstWhere((r) => r.id == target.id);

      expect(updated.status, equals('Approved'));
      expect(updated.approvedAmount, equals(target.requestAmount));
      expect(updated.approvedBy, equals('Managing Director'));
      expect(updated.approvalRemarks, equals('Approved in full'));
    });

    test('Partial approval sets status to Partially Approved', () async {
      final repo = FirebaseFundManagementRepository();
      final pending = await repo.getPendingFundRequests();
      final target = pending.firstWhere((r) => r.requestAmount == 27000.00);

      // Approve 20,000 out of 27,000
      await repo.approveOrPartiallyApproveRequest(
        requestId: target.id,
        projectCode: target.projectCode,
        approvedAmount: 20000.00,
        approvedBy: 'Admin Approver',
        remarks: 'Partially approved 20k for advance',
      );

      final all = await repo.getAllFundRequests();
      final updated = all.firstWhere((r) => r.id == target.id);

      expect(updated.status, equals('Partially Approved'));
      expect(updated.approvedAmount, equals(20000.00));
      expect(updated.approvedBy, equals('Admin Approver'));
      expect(updated.approvalRemarks, equals('Partially approved 20k for advance'));
    });

    test('Reject request updates status to Rejected with reason', () async {
      final repo = FirebaseFundManagementRepository();
      final pending = await repo.getPendingFundRequests();
      final target = pending.firstWhere((r) => r.requestAmount == 2000.00);

      await repo.rejectRequest(
        requestId: target.id,
        rejectedBy: 'Super Admin',
        reason: 'Quotation receipt missing or invalid project code',
      );

      final all = await repo.getAllFundRequests();
      final updated = all.firstWhere((r) => r.id == target.id);

      expect(updated.status, equals('Rejected'));
      expect(updated.approvedBy, equals('Super Admin'));
      expect(updated.approvalRemarks, equals('Quotation receipt missing or invalid project code'));
    });
  });
}

