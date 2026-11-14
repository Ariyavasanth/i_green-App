import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/projects/domain/models/project_inventory_item.dart';

void main() {
  test('Kumar receives 100 cement bags, uses 60, returns 10 => balance is 30, Unsettled', () {
    final item = ProjectInventoryItem(
      id: '1',
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
    );

    expect(item.balanceQty, 30.0);
    expect(item.isSettled, isFalse);
    expect(100 - (60 + 10), 30);
  });

  test('When balance is zero => Settled', () {
    final item = ProjectInventoryItem(
      id: '2',
      projectCode: 'PRJ-001',
      supervisorId: 'kumar',
      supervisorName: 'Kumar',
      itemId: 'cement_bags',
      itemName: 'cement bags',
      unit: 'bags',
      issuedQty: 100,
      usedQty: 60,
      returnedQty: 40,
      updatedAt: DateTime.now(),
    );

    expect(item.balanceQty, 0.0);
    expect(item.isSettled, isTrue);
  });
}

