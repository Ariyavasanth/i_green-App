import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/projects/domain/models/project_breakdown_item.dart';
import 'package:flutter_application_1/features/projects/domain/models/site_project.dart';

void main() {
  group('ProjectBreakdownItem Model Tests', () {
    test('creates item with auto-calculated amount (qty * rate)', () {
      final item = ProjectBreakdownItem.create(
        description: 'PLB HDPE Duct 40/33mm',
        unit: 'm',
        quantity: 2500.0,
        rate: 45.50,
        type: BreakdownItemType.material,
        remarks: 'ISI Marked',
      );

      expect(item.description, 'PLB HDPE Duct 40/33mm');
      expect(item.unit, 'm');
      expect(item.quantity, 2500.0);
      expect(item.rate, 45.50);
      expect(item.amount, 113750.0);
      expect(item.type, BreakdownItemType.material);
      expect(item.remarks, 'ISI Marked');
    });

    test('toJson and fromJson preserves all fields', () {
      final original = ProjectBreakdownItem.create(
        id: 'item_101',
        description: 'Horizontal Directional Drilling (HDD)',
        unit: 'm',
        quantity: 1200.0,
        rate: 180.0,
        type: BreakdownItemType.service,
        remarks: 'Normal soil conditions',
      );

      final json = original.toJson();
      expect(json['id'], 'item_101');
      expect(json['description'], 'Horizontal Directional Drilling (HDD)');
      expect(json['unit'], 'm');
      expect(json['quantity'], 1200.0);
      expect(json['rate'], 180.0);
      expect(json['amount'], 216000.0);
      expect(json['type'], 'service');
      expect(json['remarks'], 'Normal soil conditions');

      final reconstructed = ProjectBreakdownItem.fromJson(json);
      expect(reconstructed.id, original.id);
      expect(reconstructed.description, original.description);
      expect(reconstructed.unit, original.unit);
      expect(reconstructed.quantity, original.quantity);
      expect(reconstructed.rate, original.rate);
      expect(reconstructed.amount, original.amount);
      expect(reconstructed.type, original.type);
      expect(reconstructed.remarks, original.remarks);
    });

    test('copyWith updates fields and recalculates amount if quantity or rate changes', () {
      final original = ProjectBreakdownItem.create(
        description: 'OFC Cable 24F',
        unit: 'm',
        quantity: 1000.0,
        rate: 50.0,
      );
      expect(original.amount, 50000.0);

      final updatedQty = original.copyWith(quantity: 1500.0);
      expect(updatedQty.quantity, 1500.0);
      expect(updatedQty.amount, 75000.0);

      final updatedRate = original.copyWith(rate: 60.0);
      expect(updatedRate.rate, 60.0);
      expect(updatedRate.amount, 60000.0);
    });
  });

  group('SiteProject Breakdown Aggregations', () {
    test('calculates totalMaterialsValue, totalServicesValue and totalBreakdownValue accurately', () {
      final mat1 = ProjectBreakdownItem.create(
        description: 'HDPE Pipe 40mm',
        unit: 'm',
        quantity: 1000.0,
        rate: 50.0,
        type: BreakdownItemType.material,
      );
      final mat2 = ProjectBreakdownItem.create(
        description: 'OFC 48F Armored Cable',
        unit: 'm',
        quantity: 500.0,
        rate: 80.0,
        type: BreakdownItemType.material,
      );

      final ser1 = ProjectBreakdownItem.create(
        description: 'HDD Boring',
        unit: 'm',
        quantity: 1000.0,
        rate: 200.0,
        type: BreakdownItemType.service,
      );
      final ser2 = ProjectBreakdownItem.create(
        description: 'Cable Blowing & Splicing',
        unit: 'joints',
        quantity: 10.0,
        rate: 1500.0,
        type: BreakdownItemType.service,
      );

      final project = SiteProject(
        id: 'PRJ-001',
        projectCode: 'PRJ-001',
        employeeName: 'Ravi Kumar',
        clientName: 'BSNL',
        generalCode: 'GC-001',
        actualProjectValue: 350000.0,
        breakdownMaterials: [mat1, mat2],
        breakdownServices: [ser1, ser2],
      );

      // mat1: 50,000, mat2: 40,000 -> Total Materials = 90,000
      expect(project.totalMaterialsValue, 90000.0);

      // ser1: 200,000, ser2: 15,000 -> Total Services = 215,000
      expect(project.totalServicesValue, 215000.0);

      // Total Breakdown = 90,000 + 215,000 = 305,000
      expect(project.totalBreakdownValue, 305000.0);

      // Variance against actualProjectValue (350,000 - 305,000 = 45,000)
      final variance = project.actualProjectValue - project.totalBreakdownValue;
      expect(variance, 45000.0);
    });

    test('SiteProject serializes and deserializes breakdown items in toJson and fromJson', () {
      final mat = ProjectBreakdownItem.create(
        id: 'mat_1',
        description: 'Chamber Pit Cover',
        unit: 'nos',
        quantity: 20.0,
        rate: 2500.0,
        type: BreakdownItemType.material,
      );
      final ser = ProjectBreakdownItem.create(
        id: 'ser_1',
        description: 'Chamber Installation',
        unit: 'nos',
        quantity: 20.0,
        rate: 1200.0,
        type: BreakdownItemType.service,
      );

      final original = SiteProject(
        id: 'PRJ-102',
        projectCode: 'PRJ-102',
        employeeName: 'Anita Sharma',
        clientName: 'RailTel',
        generalCode: 'GC-102',
        breakdownMaterials: [mat],
        breakdownServices: [ser],
      );

      final json = original.toJson();
      expect(json['total_materials_value'], 50000.0);
      expect(json['total_services_value'], 24000.0);
      expect(json['total_breakdown_value'], 74000.0);

      final reconstructed = SiteProject.fromJson(json, docId: original.id);
      expect(reconstructed.breakdownMaterials.length, 1);
      expect(reconstructed.breakdownMaterials.first.description, 'Chamber Pit Cover');
      expect(reconstructed.breakdownMaterials.first.amount, 50000.0);

      expect(reconstructed.breakdownServices.length, 1);
      expect(reconstructed.breakdownServices.first.description, 'Chamber Installation');
      expect(reconstructed.breakdownServices.first.amount, 24000.0);

      expect(reconstructed.totalBreakdownValue, 74000.0);
    });
  });
}
