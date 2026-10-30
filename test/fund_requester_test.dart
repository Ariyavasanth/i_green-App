import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/fund_requester/domain/models/fund_category_constants.dart';
import 'package:flutter_application_1/features/fund_requester/domain/models/fund_request.dart';
import 'package:flutter_application_1/features/fund_requester/domain/models/fund_request_item.dart';
import 'package:flutter_application_1/features/fund_requester/data/repositories/firebase_fund_request_repository.dart';
import 'package:flutter_application_1/features/employee/domain/employee.dart';

void main() {
  group('Fund Requester Domain & Repository Tests', () {
    test('FundRequestItem serialization and copyWith', () {
      const item = FundRequestItem(
        id: 'item_1',
        category: 'Wages',
        subCategory: 'Betta',
        comments: 'Daily site allowance',
        amount: 250.0,
      );

      final map = item.toMap();
      expect(map['category'], equals('Wages'));
      expect(map['subCategory'], equals('Betta'));
      expect(map['amount'], equals(250.0));

      final fromMap = FundRequestItem.fromMap(map);
      expect(fromMap.category, equals('Wages'));
      expect(fromMap.subCategory, equals('Betta'));
      expect(fromMap.amount, equals(250.0));

      final updated = item.copyWith(amount: 300.0);
      expect(updated.amount, equals(300.0));
      expect(updated.category, equals('Wages'));
    });

    test('FundRequest model handles multiple items and totals correctly', () {
      final now = DateTime.now();
      final request = FundRequest(
        id: 'fr_101',
        requestNumber: 'REQ-2024-001',
        employeeId: 'emp_01',
        employeeName: 'Sathiya',
        employeeCustomId: 'EMP042',
        message: 'igig',
        projectCode: 'Corrtech-SUB-SEP/2023-1-TN-Coimbatore-Coimbatore',
        approvedAmount: 0.0,
        requestAmount: 25.0,
        items: const [
          FundRequestItem(
            id: 'it_1',
            category: 'Fuel',
            subCategory: 'CNG',
            comments: 'Zfsd',
            amount: 25.0,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      expect(request.employeeName, equals('Sathiya'));
      expect(request.projectCode, contains('Corrtech'));
      expect(request.items.length, equals(1));
      expect(request.requestAmount, equals(25.0));

      final map = request.toMap();
      expect(map['requestNumber'], equals('REQ-2024-001'));
      expect(map['items'].length, equals(1));

      final deserialized = FundRequest.fromMap(map, 'fr_101');
      expect(deserialized.id, equals('fr_101'));
      expect(deserialized.requestAmount, equals(25.0));
      expect(deserialized.items.first.subCategory, equals('CNG'));
    });

    test('FundRequest domain model copyWith and status checks', () {
      final newReq = FundRequest(
        id: 'req_test_1',
        requestNumber: 'REQ-2024-999',
        employeeId: 'emp_test',
        employeeName: 'Test Requester',
        message: 'Urgent materials',
        projectCode: 'Ajay Babu-SUB-FEB/2024-5-TN-Chennai-Tharamani',
        approvedAmount: 0.0,
        requestAmount: 1500.0,
        items: const [
          FundRequestItem(
            id: 'i1',
            category: 'Purchase',
            subCategory: 'Consumed',
            comments: 'PVC Pipes and elbows',
            amount: 1500.0,
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(newReq.id, equals('req_test_1'));
      expect(newReq.status, equals('Pending'));

      final approved = newReq.copyWith(
        status: 'Approved',
        approvedAmount: 1500.0,
        approvedBy: 'General Manager',
        approvalRemarks: 'Approved for field deployment',
      );
      expect(approved.status, equals('Approved'));
      expect(approved.approvedAmount, equals(1500.0));
      expect(approved.approvedBy, equals('General Manager'));

      final rejected = newReq.copyWith(
        status: 'Rejected',
        approvedBy: 'General Manager',
        approvalRemarks: 'Budget exceeded',
      );
      expect(rejected.status, equals('Rejected'));
      expect(rejected.approvalRemarks, equals('Budget exceeded'));
    });

    test('FundCategoryConstants returns correct subcategories', () {
      expect(FundCategoryConstants.categoryTitles, contains('Fuel'));
      expect(FundCategoryConstants.categoryTitles, contains('Rental'));
      expect(FundCategoryConstants.categoryTitles, contains('Travel'));
      expect(FundCategoryConstants.categoryTitles, contains('Transport'));
      expect(FundCategoryConstants.categoryTitles, contains('Accommodation'));
      expect(FundCategoryConstants.categoryTitles, contains('Food'));
      expect(FundCategoryConstants.categoryTitles, contains('Repairs'));
      expect(FundCategoryConstants.categoryTitles, contains('General'));
      expect(FundCategoryConstants.categoryTitles, contains('Wages'));
      expect(FundCategoryConstants.categoryTitles, contains('Purchase'));
      expect(FundCategoryConstants.categoryTitles, contains('Utilization'));
      expect(FundCategoryConstants.categoryTitles, contains('Others'));

      final fuelSubs = FundCategoryConstants.getSubCategoriesFor('Fuel');
      expect(fuelSubs, containsAll(['CNG', 'Petrol', 'Diesel', 'Electricity', 'Others']));

      final rentalSubs = FundCategoryConstants.getSubCategoriesFor('Rental');
      expect(rentalSubs, containsAll(['Truck', 'Hydra', 'Generator Set', 'Water Tanker', 'Jackhammer']));

      final foodSubs = FundCategoryConstants.getSubCategoriesFor('Food');
      expect(foodSubs, containsAll(['Tea', 'Breakfast', 'Lunch', 'Snacks', 'Dinner', 'Water Bottle']));

      final wageSubs = FundCategoryConstants.getSubCategoriesFor('Wages');
      expect(wageSubs, containsAll(['Betta', 'Wages', 'Others']));
    });

    test('Employee model recognizes Fund Requester permissions', () {
      final empWithPerm = Employee(
        id: 1,
        employeeId: 'EMP001',
        firstName: 'Test',
        lastName: 'User',
        emailAddress: 'test@example.com',
        phoneNumber: '9999999999',
        gender: 'MALE',
        dob: '1995-01-01',
        organizationName: 'iGreen',
        department: 'Operations',
        designation: 'Site Engineer',
        employmentType: 'FULL_TIME',
        status: 'ACTIVE',
        joiningDate: '2024-01-01',
        accessPermissions: ['Fund Requester'],
      );

      expect(empWithPerm.hasPermission('Fund Requester'), isTrue);
      expect(empWithPerm.hasPermission('fund requester'), isTrue);
      expect(empWithPerm.hasPermission('fund request'), isTrue);
      expect(empWithPerm.canAccessHrms, isTrue);
    });
  });
}
