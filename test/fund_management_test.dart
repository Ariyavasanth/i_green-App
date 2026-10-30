import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/fund_requester/domain/models/fund_request.dart';
import 'package:flutter_application_1/features/fund_requester/domain/models/fund_request_item.dart';

void main() {
  group('Fund Management Domain & Logic Tests', () {
    test('FundRequest serialization and deserialization works correctly', () {
      final req = FundRequest(
        id: 'test_req_1',
        requestNumber: 'REQ-2026-001',
        employeeId: 'emp_101',
        employeeName: 'Ramesh K',
        employeeCustomId: 'EMP101',
        department: 'Operations',
        message: 'Cable laying advance',
        projectCode: 'PRJ-TNEB-001',
        projectName: 'TNEB Phase 1',
        requestAmount: 15000.0,
        approvedAmount: 0.0,
        status: 'Pending',
        items: const [
          FundRequestItem(
            id: 'item_1',
            category: 'Fuel',
            subCategory: 'Diesel',
            comments: 'Site generator',
            amount: 5000.0,
          ),
          FundRequestItem(
            id: 'item_2',
            category: 'Rental',
            subCategory: 'Truck',
            comments: 'Material shifting',
            amount: 10000.0,
          ),
        ],
        billUrls: const ['https://example.com/bill1.jpg'],
        audioNoteUrl: 'https://example.com/audio1.mp4',
        createdAt: DateTime.parse('2026-10-31 10:00:00'),
        updatedAt: DateTime.parse('2026-10-31 10:00:00'),
      );

      final map = req.toMap();
      expect(map['requestNumber'], equals('REQ-2026-001'));
      expect(map['requestAmount'], equals(15000.0));
      expect(map['status'], equals('Pending'));

      final restored = FundRequest.fromMap(map, 'test_req_1');
      expect(restored.id, equals('test_req_1'));
      expect(restored.employeeName, equals('Ramesh K'));
      expect(restored.items.length, equals(2));
      expect(restored.billUrls.first, equals('https://example.com/bill1.jpg'));
    });

    test('Fund request copyWith updates approval and rejection fields', () {
      final req = FundRequest(
        id: 'test_req_2',
        requestNumber: 'REQ-2026-002',
        employeeId: 'emp_102',
        employeeName: 'Suresh M',
        message: 'Vehicle maintenance',
        projectCode: 'PRJ-L&T-002',
        requestAmount: 8000.0,
        status: 'Pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Full approval
      final approved = req.copyWith(
        status: 'Approved',
        approvedAmount: 8000.0,
        approvedBy: 'Admin Approver',
        approvalRemarks: 'Fully approved',
      );
      expect(approved.status, equals('Approved'));
      expect(approved.approvedAmount, equals(8000.0));

      // Partial approval
      final partial = req.copyWith(
        status: 'Partially Approved',
        approvedAmount: 5000.0,
        approvedBy: 'Admin Approver',
        approvalRemarks: 'Partial approval of 5k',
      );
      expect(partial.status, equals('Partially Approved'));
      expect(partial.approvedAmount, equals(5000.0));

      // Rejection
      final rejected = req.copyWith(
        status: 'Rejected',
        approvedBy: 'Admin Approver',
        approvalRemarks: 'Quotation receipt missing',
      );
      expect(rejected.status, equals('Rejected'));
      expect(rejected.approvalRemarks, equals('Quotation receipt missing'));
    });
  });
}
