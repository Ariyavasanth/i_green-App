import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../domain/books_repository.dart';

/// Firebase Firestore repository implementation for Books and Items.
class FirebaseBooksRepository implements BooksRepository {
  final FirebaseFirestore? _customFirestore;

  FirebaseBooksRepository({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _itemsRef =>
      _firestore.collection('items');
  CollectionReference<Map<String, dynamic>> get _materialsRef =>
      _firestore.collection('materials');
  CollectionReference<Map<String, dynamic>> get _adjustmentsRef =>
      _firestore.collection('inventory_adjustments');
  CollectionReference<Map<String, dynamic>> get _stockEntriesRef =>
      _firestore.collection('stock_entries');
  CollectionReference<Map<String, dynamic>> get _requestsRef =>
      _firestore.collection('material_requests');
  CollectionReference<Map<String, dynamic>> get _returnsRef =>
      _firestore.collection('material_returns');
  CollectionReference<Map<String, dynamic>> get _transactionsRef =>
      _firestore.collection('transactions');
  CollectionReference<Map<String, dynamic>> get _customersRef =>
      _firestore.collection('customers');

  static final List<BookItem> _itemsStore = [
    const BookItem(
      id: 1,
      name: 'Joint Kit',
      type: 'Goods',
      unit: 'pcs',
      hsnCode: '8483',
      taxPreference: 'Taxable',
      intraStateTaxRate: 'GST18 (18 %)',
      interStateTaxRate: 'IGST18 (18 %)',
      costPrice: 500,
      purchaseAccount: 'Cost of Goods Sold',
      rate: 750,
      salesAccount: 'Sales',
      reportingTags: 'Hardware',
      product: 'Joint Assembly',
      productName: 'Industrial Joint Kit',
      masterSerialNo: 'MSN-JK-001',
      partNo: 'JK-1001',
      drawingFileName: 'JK-1001.pdf',
      trackInventory: true,
      stockOnHand: 10,
    ),
    const BookItem(
      id: 2,
      name: 'Tool Holder',
      type: 'Goods',
      unit: 'pcs',
      hsnCode: '8466',
      taxPreference: 'Taxable',
      intraStateTaxRate: 'GST18 (18 %)',
      interStateTaxRate: 'IGST18 (18 %)',
      costPrice: 1200,
      purchaseAccount: 'Cost of Goods Sold',
      rate: 1800,
      salesAccount: 'Sales',
      reportingTags: 'Tools',
      product: 'Holder Assembly',
      productName: 'CNC Tool Holder',
      masterSerialNo: 'MSN-TH-001',
      partNo: 'TH-2001',
      drawingFileName: 'TH-2001.pdf',
      trackInventory: true,
      stockOnHand: 10,
    ),
    const BookItem(
      id: 7,
      name: '3.5" Pulling Swivel',
      type: 'Goods',
      unit: 'pcs',
      hsnCode: '8479',
      taxPreference: 'Taxable',
      intraStateTaxRate: 'GST18 (18 %)',
      interStateTaxRate: 'IGST18 (18 %)',
      costPrice: 0,
      purchaseAccount: 'Cost of Goods Sold',
      rate: 0,
      salesAccount: 'Sales',
      reportingTags: 'Swivel Accessories',
      product: 'Gear Shaft Assembly',
      productName: 'Industrial Gear Shaft',
      masterSerialNo: 'MSN-GS-001',
      partNo: 'GS-1001',
      drawingFileName: 'GS-1001.pdf',
      assemblyImagePath: 'assets/images/3_5_pulling_swivel.png',
      trackInventory: true,
      stockOnHand: 10,
    ),
  ];

  static final List<MaterialItem> _materialsStore = [
    MaterialItem(
      id: 101,
      sourceType: 'RAW',
      code: 'MAT-101',
      description: 'Mild Steel Plate 12mm',
      materialType: 'Steel',
      grade: 'MS-350',
      make: 'Tata Steel',
      model: 'Plate-12',
      size: '2500x1250mm',
      unit: 'pcs',
      density: '7.85',
      supplier: 'Standard Steel Suppliers',
      heatNumber: 'HT-99201',
      batchNumber: 'BATCH-2026A',
      warehouseLocation: 'Warehouse A',
      rackLocation: 'Rack R-01',
      minimumStock: '10',
      maximumStock: '100',
      reorderLevel: '20',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    MaterialItem(
      id: 201,
      sourceType: 'OUTSOURCE',
      code: 'OUT-201',
      description: 'CNC Milling & Shaft Turning Service',
      materialType: 'Machining',
      grade: 'N/A',
      make: 'Precision Works',
      model: 'PW-MILL-01',
      size: 'Standard',
      unit: 'pcs',
      density: '0',
      supplier: 'Precision Turning Vendors',
      heatNumber: 'N/A',
      batchNumber: 'OUT-BATCH-01',
      warehouseLocation: 'Shelf S-01',
      rackLocation: 'Rack Out-1',
      minimumStock: '5',
      maximumStock: '50',
      reorderLevel: '10',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  static final List<InventoryAdjustment> _adjustmentsStore = [
    InventoryAdjustment(
      id: 1,
      date: DateTime.now().subtract(const Duration(days: 2)),
      reason: 'Physical Count Verification',
      referenceNumber: 'ADJ-0001',
      type: 'Quantity Adjustment',
      status: 'Approved',
      description: 'Annual stock audit adjustment',
    ),
    InventoryAdjustment(
      id: 2,
      date: DateTime.now().subtract(const Duration(days: 1)),
      reason: 'GRN Stock Inward',
      referenceNumber: 'GRN-1001',
      type: 'Add Stock',
      status: 'Completed',
      description: 'Received initial inventory batch',
    ),
  ];

  static final List<StockEntry> _stockEntriesStore = [
    StockEntry(
      id: 1,
      grnNumber: 'GRN-1001',
      supplier: 'Standard Steel Suppliers',
      poNumber: 'PO-2026-001',
      poDate: DateTime.now().subtract(const Duration(days: 10)),
      invoiceNumber: 'INV-ST-8890',
      invoiceDate: DateTime.now().subtract(const Duration(days: 5)),
      materialCode: 'MAT-101',
      description: 'Mild Steel Plate 12mm - 50 pcs',
      heatNumber: 'HT-99201',
      batchNumber: 'BATCH-2026A',
      quantity: 50,
      weight: 392.5,
      inspectionStatus: 'Passed',
      storeLocation: 'Warehouse A - Rack R-01',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  static final List<MaterialRequest> _materialRequestsStore = [
    MaterialRequest(
      id: 1,
      date: DateTime.now().subtract(const Duration(days: 1)),
      machine: 'CNC Lathe 01',
      operatorName: 'Ramesh Kumar',
      workOrder: 'WO-2026-050',
      material: 'Mild Steel Plate 12mm',
      quantityIssued: 10,
      weightIssued: 78.5,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  static final List<MaterialReturn> _materialReturnsStore = [
    MaterialReturn(
      id: 1,
      workOrder: 'WO-2026-050',
      material: 'Mild Steel Plate 12mm',
      quantityReturned: 2,
      weight: 15.7,
      reason: 'Excess Issued Material',
      createdAt: DateTime.now(),
    ),
  ];

  static final List<ItemHistoryEntry> _historyStore = [
    ItemHistoryEntry(
      date: DateTime.now(),
      details: 'created by - iGreenTec Engineering india Pvt.Ltd.',
    ),
  ];

  static final List<SalesTransaction> _transactionsStore = [
    SalesTransaction(
      id: 1,
      type: TransactionType.invoice,
      number: 'INV-000001',
      customer: 'NEXORA INFRATECH',
      date: DateTime.now(),
      status: 'Draft',
      amount: 0,
    ),
  ];

  static final List<Customer> _customersStore = [
    const Customer(id: 1, name: 'NEXORA INFRATECH', company: 'NEXORA INFRATECH'),
    const Customer(id: 2, name: 'Poomari Engineering', company: 'Poomari Engineering'),
    const Customer(id: 3, name: 'Sark Telecom', company: 'Sark Telecom'),
    const Customer(id: 4, name: 'Indwel Precision Gears Pvt Ltd', company: 'Indwel Precision Gears Pvt Ltd'),
  ];

  @override
  Future<List<BookItem>> getItems() async {
    try {
      final snap = await _itemsRef.get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.map((doc) {
          final data = doc.data();
          final partsRaw = data['parts'] as List<dynamic>? ?? [];
          final List<ItemPart> parts = partsRaw.map((pData) {
            final opsRaw = pData['operations'] as List<dynamic>? ?? [];
            final List<ItemPartOperation> ops = opsRaw.map((opData) => ItemPartOperation(
              operationNumber: (opData['operationNumber'] as num?)?.toInt() ?? 1,
              operationName: opData['operationName'] ?? '',
              machine: opData['machine'] ?? '',
              duration: opData['duration'] ?? '',
              remarks: opData['remarks'] ?? 'Inhouse',
              vendor: opData['vendor'],
            )).toList();

            return ItemPart(
              slNo: (pData['slNo'] as num?)?.toInt() ?? 1,
              partName: pData['partName'] ?? '',
              partNo: pData['partNo'] ?? '',
              partImage: pData['partImage'] ?? '',
              partPdf: pData['partPdf'] ?? '',
              rmGrade: pData['rmGrade'] ?? '',
              rmSize: pData['rmSize'] ?? '',
              rmWeight: (pData['rmWeight'] as num?)?.toDouble() ?? 0,
              fgWeight: (pData['fgWeight'] as num?)?.toDouble() ?? 0,
              quantity: (pData['quantity'] as num?)?.toDouble() ?? 1,
              hasProcessFlow: pData['hasProcessFlow'] ?? false,
              operations: ops,
            );
          }).toList();

          return BookItem(
            id: (data['id'] as num?)?.toInt() ?? doc.id.hashCode,
            name: data['name'] ?? '',
            sku: data['sku'] ?? '',
            rate: (data['rate'] as num?)?.toDouble() ?? 0,
            type: data['type'] ?? 'Sales and Purchase Items',
            unit: data['unit'] ?? 'pcs',
            hsnCode: data['hsnCode'] ?? '',
            taxPreference: data['taxPreference'] ?? 'Taxable',
            taxRate: (data['taxRate'] as num?)?.toDouble() ?? 18,
            intraStateTaxRate: data['intraStateTaxRate'] ?? 'GST18 (18 %)',
            interStateTaxRate: data['interStateTaxRate'] ?? 'IGST18 (18 %)',
            costPrice: (data['costPrice'] as num?)?.toDouble() ?? 0,
            purchaseAccount: data['purchaseAccount'] ?? 'Cost of Goods Sold',
            salesAccount: data['salesAccount'] ?? 'Sales',
            cogsAccount: data['cogsAccount'] ?? 'Cost of Goods Sold',
            reportingTags: data['reportingTags'] ?? '',
            preferredVendor: data['preferredVendor'] ?? '',
            product: data['product'] ?? '',
            productName: data['productName'] ?? '',
            masterSerialNo: data['masterSerialNo'] ?? '',
            partNo: data['partNo'] ?? '',
            drawingFileName: data['drawingFileName'] ?? '',
            assemblyImagePath: data['assemblyImagePath'] ?? '',
            parts: parts,
            trackInventory: data['trackInventory'] ?? true,
            stockOnHand: (data['stockOnHand'] as num?)?.toDouble() ?? 0,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Firestore getItems error: $e');
    }
    return List.unmodifiable(_itemsStore);
  }

  @override
  Future<BookItem> addItem({
    required String name,
    String sku = '',
    double rate = 0,
    String type = 'Sales and Purchase Items',
    String unit = 'pcs',
    String hsnCode = '',
    String taxPreference = 'Taxable',
    double taxRate = 18,
    String intraStateTaxRate = 'GST18 (18 %)',
    String interStateTaxRate = 'IGST18 (18 %)',
    double costPrice = 0,
    String purchaseAccount = 'Cost of Goods Sold',
    String salesAccount = 'Sales',
    String cogsAccount = 'Cost of Goods Sold',
    String reportingTags = '',
    String preferredVendor = '',
    String product = '',
    String productName = '',
    String masterSerialNo = '',
    String partNo = '',
    String drawingFileName = '',
    String assemblyImagePath = '',
    List<ItemPart> parts = const [],
  }) async {
    final itemId = DateTime.now().millisecondsSinceEpoch;
    final newItem = BookItem(
      id: itemId,
      name: name,
      sku: sku,
      rate: rate,
      type: type,
      unit: unit,
      hsnCode: hsnCode,
      taxPreference: taxPreference,
      taxRate: taxRate,
      intraStateTaxRate: intraStateTaxRate,
      interStateTaxRate: interStateTaxRate,
      costPrice: costPrice,
      purchaseAccount: purchaseAccount,
      salesAccount: salesAccount,
      cogsAccount: cogsAccount,
      reportingTags: reportingTags,
      preferredVendor: preferredVendor,
      product: product,
      productName: productName,
      masterSerialNo: masterSerialNo,
      partNo: partNo,
      drawingFileName: drawingFileName,
      assemblyImagePath: assemblyImagePath,
      parts: parts,
      trackInventory: true,
      stockOnHand: 0,
    );
    _itemsStore.add(newItem);

    // Initial history audit entry
    final historyEntry = ItemHistoryEntry(
      date: DateTime.now(),
      details: 'created by - iGreenTec Engineering india Pvt.Ltd.',
    );
    _historyStore.add(historyEntry);

    // Initial transaction entry
    final transactionEntry = SalesTransaction(
      id: DateTime.now().millisecondsSinceEpoch + 1,
      type: TransactionType.invoice,
      number: 'INV-${itemId.toString().substring(itemId.toString().length - 6)}',
      customer: 'NEXORA INFRATECH',
      date: DateTime.now(),
      status: 'Draft',
      amount: rate,
    );
    _transactionsStore.add(transactionEntry);

    try {
      final partsMapList = parts.map((p) => {
        'slNo': p.slNo,
        'partName': p.partName,
        'partNo': p.partNo,
        'partImage': p.partImage,
        'partPdf': p.partPdf,
        'rmGrade': p.rmGrade,
        'rmSize': p.rmSize,
        'rmWeight': p.rmWeight,
        'fgWeight': p.fgWeight,
        'quantity': p.quantity,
        'hasProcessFlow': p.hasProcessFlow,
        'operations': p.operations.map((op) => {
          'operationNumber': op.operationNumber,
          'operationName': op.operationName,
          'machine': op.machine,
          'duration': op.duration,
          'remarks': op.remarks,
          'vendor': op.vendor,
        }).toList(),
      }).toList();

      await _itemsRef.doc('$itemId').set({
        'id': itemId,
        'name': name,
        'sku': sku,
        'rate': rate,
        'type': type,
        'unit': unit,
        'hsnCode': hsnCode,
        'taxPreference': taxPreference,
        'taxRate': taxRate,
        'intraStateTaxRate': intraStateTaxRate,
        'interStateTaxRate': interStateTaxRate,
        'costPrice': costPrice,
        'purchaseAccount': purchaseAccount,
        'salesAccount': salesAccount,
        'cogsAccount': cogsAccount,
        'reportingTags': reportingTags,
        'preferredVendor': preferredVendor,
        'product': product,
        'productName': productName,
        'masterSerialNo': masterSerialNo,
        'partNo': partNo,
        'drawingFileName': drawingFileName,
        'assemblyImagePath': assemblyImagePath,
        'parts': partsMapList,
        'trackInventory': true,
        'stockOnHand': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Save initial History document
      await _firestore.collection('items').doc('$itemId').collection('history').add({
        'itemId': itemId,
        'date': Timestamp.fromDate(historyEntry.date),
        'details': historyEntry.details,
      });

      // Save initial Transaction document
      await _firestore.collection('transactions').add({
        'itemId': itemId,
        'type': 'invoice',
        'number': transactionEntry.number,
        'customerName': transactionEntry.customer,
        'date': Timestamp.fromDate(transactionEntry.date),
        'status': transactionEntry.status,
        'amount': transactionEntry.amount,
      });
    } catch (e) {
      debugPrint('Firestore addItem error: $e');
    }
    return newItem;
  }

  @override
  Future<List<ItemHistoryEntry>> getItemHistory(int itemId) async {
    try {
      final snap = await _firestore.collection('items').doc('$itemId').collection('history').get();
      if (snap.docs.isNotEmpty) {
        final List<ItemHistoryEntry> list = snap.docs.map((doc) {
          final data = doc.data();
          final dateVal = data['date'];
          DateTime date = DateTime.now();
          if (dateVal is Timestamp) {
            date = dateVal.toDate();
          }
          return ItemHistoryEntry(
            date: date,
            details: data['details'] ?? '',
          );
        }).toList();
        return list;
      }
    } catch (e) {
      debugPrint('Firestore getItemHistory error: $e');
    }
    return List.unmodifiable(_historyStore);
  }

  @override
  Future<List<SalesTransaction>> getTransactions(TransactionType type) async {
    try {
      final typeStr = type == TransactionType.invoice ? 'invoice' : 'salesOrder';
      final snap = await _firestore.collection('transactions').where('type', isEqualTo: typeStr).get();
      if (snap.docs.isNotEmpty) {
        final List<SalesTransaction> list = snap.docs.map((doc) {
          final data = doc.data();
          final dateVal = data['date'];
          DateTime date = DateTime.now();
          if (dateVal is Timestamp) {
            date = dateVal.toDate();
          }
          return SalesTransaction(
            id: doc.id.hashCode,
            type: type,
            number: data['number'] ?? '',
            customer: data['customerName'] ?? data['customer'] ?? '',
            date: date,
            status: data['status'] ?? 'Draft',
            amount: (data['amount'] as num?)?.toDouble() ?? 0,
          );
        }).toList();
        return list;
      }
    } catch (e) {
      debugPrint('Firestore getTransactions error: $e');
    }
    return _transactionsStore.where((t) => t.type == type).toList();
  }

  @override
  Future<List<Customer>> getCustomers() async {
    try {
      final snap = await _firestore.collection('customers').get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.map((doc) {
          final data = doc.data();
          return Customer(
            id: doc.id.hashCode,
            name: data['name'] ?? '',
            company: data['company'] ?? '',
            email: data['email'] ?? '',
            phone: data['phone'] ?? '',
            gstTreatment: data['gstTreatment'] ?? 'Registered Business - Regular',
            receivables: (data['receivables'] as num?)?.toDouble() ?? 0,
          );
        }).toList();
      }
    } catch (_) {}
    return List.unmodifiable(_customersStore);
  }

  @override
  Future<void> addCustomer({required String name, String company = '', String phone = ''}) async {
    final c = Customer(id: DateTime.now().millisecondsSinceEpoch, name: name, company: company, phone: phone);
    _customersStore.add(c);
    try {
      await _firestore.collection('customers').add({'name': name, 'company': company, 'phone': phone});
    } catch (_) {}
  }

  @override
  Future<List<MaterialItem>> getMaterials({String? sourceType}) async {
    try {
      final snap = await _materialsRef.get();
      if (snap.docs.isNotEmpty) {
        final list = snap.docs.map((doc) {
          final data = doc.data();
          final createdVal = data['createdAt'];
          DateTime createdAt = DateTime.now();
          if (createdVal is Timestamp) {
            createdAt = createdVal.toDate();
          } else if (createdVal is String) {
            createdAt = DateTime.tryParse(createdVal) ?? DateTime.now();
          }
          return MaterialItem(
            id: (data['id'] as num?)?.toInt() ?? doc.id.hashCode,
            sourceType: data['sourceType'] ?? 'RAW',
            code: data['code'] ?? '',
            description: data['description'] ?? '',
            materialType: data['materialType'] ?? '',
            grade: data['grade'] ?? '',
            make: data['make'] ?? '',
            model: data['model'] ?? '',
            size: data['size'] ?? '',
            unit: data['unit'] ?? 'pcs',
            density: data['density'] ?? '',
            supplier: data['supplier'] ?? '',
            heatNumber: data['heatNumber'] ?? '',
            batchNumber: data['batchNumber'] ?? '',
            warehouseLocation: data['warehouseLocation'] ?? '',
            rackLocation: data['rackLocation'] ?? '',
            minimumStock: data['minimumStock'] ?? '0',
            maximumStock: data['maximumStock'] ?? '0',
            reorderLevel: data['reorderLevel'] ?? '0',
            createdAt: createdAt,
            stockOnHand: (data['stockOnHand'] as num?)?.toDouble() ?? 0,
          );
        }).toList();

        if (sourceType != null && sourceType.isNotEmpty) {
          return list
              .where((m) =>
                  m.sourceType.toUpperCase() == sourceType.toUpperCase())
              .toList();
        }
        return list;
      }
    } catch (e) {
      debugPrint('Firestore getMaterials error: $e');
    }

    if (sourceType != null && sourceType.isNotEmpty) {
      return _materialsStore
          .where(
              (m) => m.sourceType.toUpperCase() == sourceType.toUpperCase())
          .toList();
    }
    return List.unmodifiable(_materialsStore);
  }

  @override
  Future<void> addMaterial(MaterialDraft draft) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    final item = MaterialItem(
      id: id,
      sourceType: draft.sourceType,
      code: draft.code,
      description: draft.description,
      materialType: draft.materialType,
      grade: draft.grade,
      make: draft.make,
      model: draft.model,
      size: draft.size,
      unit: draft.unit,
      density: draft.density,
      supplier: draft.supplier,
      heatNumber: draft.heatNumber,
      batchNumber: draft.batchNumber,
      warehouseLocation: draft.warehouseLocation,
      rackLocation: draft.rackLocation,
      minimumStock: draft.minimumStock,
      maximumStock: draft.maximumStock,
      reorderLevel: draft.reorderLevel,
      createdAt: DateTime.now(),
    );
    _materialsStore.insert(0, item);

    try {
      await _materialsRef.doc('$id').set({
        'id': id,
        'sourceType': draft.sourceType,
        'code': draft.code,
        'description': draft.description,
        'materialType': draft.materialType,
        'grade': draft.grade,
        'make': draft.make,
        'model': draft.model,
        'size': draft.size,
        'unit': draft.unit,
        'density': draft.density,
        'supplier': draft.supplier,
        'heatNumber': draft.heatNumber,
        'batchNumber': draft.batchNumber,
        'warehouseLocation': draft.warehouseLocation,
        'rackLocation': draft.rackLocation,
        'minimumStock': draft.minimumStock,
        'maximumStock': draft.maximumStock,
        'reorderLevel': draft.reorderLevel,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Firestore addMaterial error: $e');
    }
  }

  @override
  Future<List<InventoryAdjustment>> getAdjustments() async {
    try {
      final snap = await _adjustmentsRef.get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.map((doc) {
          final data = doc.data();
          final dateVal = data['date'];
          DateTime date = DateTime.now();
          if (dateVal is Timestamp) {
            date = dateVal.toDate();
          } else if (dateVal is String) {
            date = DateTime.tryParse(dateVal) ?? DateTime.now();
          }
          return InventoryAdjustment(
            id: (data['id'] as num?)?.toInt() ?? doc.id.hashCode,
            date: date,
            reason: data['reason'] ?? '',
            referenceNumber: data['referenceNumber'] ?? '',
            type: data['type'] ?? 'Quantity Adjustment',
            status: data['status'] ?? 'Completed',
            description: data['description'] ?? '',
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Firestore getAdjustments error: $e');
    }
    return List.unmodifiable(_adjustmentsStore);
  }

  @override
  Future<void> addAdjustment(AdjustmentDraft draft) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    final adj = InventoryAdjustment(
      id: id,
      date: DateTime.now(),
      reason: draft.reason,
      referenceNumber: draft.referenceNumber,
      type: draft.quantityAdjusted >= 0
          ? 'Quantity Increase'
          : 'Quantity Decrease',
      status: 'Approved',
      description: draft.description,
    );
    _adjustmentsStore.insert(0, adj);

    try {
      await _adjustmentsRef.doc('$id').set({
        'id': id,
        'itemId': draft.itemId,
        'quantityAdjusted': draft.quantityAdjusted,
        'reason': draft.reason,
        'referenceNumber': draft.referenceNumber,
        'type': adj.type,
        'status': adj.status,
        'description': draft.description,
        'applyNow': draft.applyNow,
        'date': FieldValue.serverTimestamp(),
      });

      if (draft.applyNow) {
        final itemDoc = await _itemsRef.doc('${draft.itemId}').get();
        if (itemDoc.exists && itemDoc.data() != null) {
          final currentStock =
              (itemDoc.data()!['stockOnHand'] as num?)?.toDouble() ?? 0;
          final newStock =
              (currentStock + draft.quantityAdjusted).clamp(0, 999999).toDouble();
          await _itemsRef
              .doc('${draft.itemId}')
              .update({'stockOnHand': newStock});
        }
      }
    } catch (e) {
      debugPrint('Firestore addAdjustment error: $e');
    }
  }

  @override
  Future<List<StockEntry>> getStockEntries() async {
    try {
      final snap = await _stockEntriesRef.get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.map((doc) {
          final data = doc.data();
          final poVal = data['poDate'];
          final invVal = data['invoiceDate'];
          final crVal = data['createdAt'];

          DateTime parseDate(dynamic val) {
            if (val is Timestamp) return val.toDate();
            if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
            return DateTime.now();
          }

          return StockEntry(
            id: (data['id'] as num?)?.toInt() ?? doc.id.hashCode,
            grnNumber: data['grnNumber'] ?? '',
            supplier: data['supplier'] ?? '',
            poNumber: data['poNumber'] ?? '',
            poDate: parseDate(poVal),
            invoiceNumber: data['invoiceNumber'] ?? '',
            invoiceDate: parseDate(invVal),
            materialCode: data['materialCode'] ?? '',
            description: data['description'] ?? '',
            heatNumber: data['heatNumber'] ?? '',
            batchNumber: data['batchNumber'] ?? '',
            quantity: (data['quantity'] as num?)?.toDouble() ?? 0,
            weight: (data['weight'] as num?)?.toDouble() ?? 0,
            inspectionStatus: data['inspectionStatus'] ?? 'Passed',
            storeLocation: data['storeLocation'] ?? '',
            createdAt: parseDate(crVal),
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Firestore getStockEntries error: $e');
    }
    return List.unmodifiable(_stockEntriesStore);
  }

  @override
  Future<void> addStock(StockEntryDraft draft) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    final entry = StockEntry(
      id: id,
      grnNumber: draft.grnNumber,
      supplier: draft.supplier,
      poNumber: draft.poNumber,
      poDate: draft.poDate,
      invoiceNumber: draft.invoiceNumber,
      invoiceDate: draft.invoiceDate,
      materialCode: draft.materialCode,
      description: draft.description,
      heatNumber: draft.heatNumber,
      batchNumber: draft.batchNumber,
      quantity: draft.quantity,
      weight: draft.weight,
      inspectionStatus: draft.inspectionStatus,
      storeLocation: draft.storeLocation,
      createdAt: DateTime.now(),
    );
    _stockEntriesStore.insert(0, entry);

    final adj = InventoryAdjustment(
      id: id + 1,
      date: DateTime.now(),
      reason: 'Stock Inward (${draft.supplier})',
      referenceNumber: draft.grnNumber,
      type: 'Add Stock',
      status: draft.inspectionStatus,
      description: draft.description,
    );
    _adjustmentsStore.insert(0, adj);

    try {
      await _stockEntriesRef.doc('$id').set({
        'id': id,
        'grnNumber': draft.grnNumber,
        'supplier': draft.supplier,
        'poNumber': draft.poNumber,
        'poDate': Timestamp.fromDate(draft.poDate),
        'invoiceNumber': draft.invoiceNumber,
        'invoiceDate': Timestamp.fromDate(draft.invoiceDate),
        'materialCode': draft.materialCode,
        'description': draft.description,
        'heatNumber': draft.heatNumber,
        'batchNumber': draft.batchNumber,
        'quantity': draft.quantity,
        'weight': draft.weight,
        'inspectionStatus': draft.inspectionStatus,
        'storeLocation': draft.storeLocation,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _adjustmentsRef.doc('${id + 1}').set({
        'id': id + 1,
        'date': FieldValue.serverTimestamp(),
        'reason': adj.reason,
        'referenceNumber': adj.referenceNumber,
        'type': adj.type,
        'status': adj.status,
        'description': adj.description,
      });

      bool matchMat(String code, String desc) {
        final mc = code.trim().toLowerCase();
        final md = desc.trim().toLowerCase();
        final dc = draft.materialCode.trim().toLowerCase();
        final dd = draft.description.trim().toLowerCase();

        if (mc.isNotEmpty && dc.isNotEmpty && (mc == dc || mc.contains(dc) || dc.contains(mc))) {
          return true;
        }
        if (md.isNotEmpty && dd.isNotEmpty && (md == dd || md.contains(dd) || dd.contains(md))) {
          return true;
        }
        final mdWords = md.split(RegExp(r'\s+')).where((w) => w.length > 2).toSet();
        final ddWords = dd.split(RegExp(r'\s+')).where((w) => w.length > 2).toSet();
        if (mdWords.isNotEmpty && ddWords.isNotEmpty) {
          final intersection = mdWords.intersection(ddWords);
          if (intersection.length >= 2 || intersection.length == mdWords.length) {
            return true;
          }
        }
        return false;
      }

      // 1. Update in-memory materials store
      for (var i = 0; i < _materialsStore.length; i++) {
        final m = _materialsStore[i];
        if (matchMat(m.code, m.description)) {
          _materialsStore[i] = MaterialItem(
            id: m.id,
            sourceType: m.sourceType,
            code: m.code,
            description: m.description,
            materialType: m.materialType,
            grade: m.grade,
            make: m.make,
            model: m.model,
            size: m.size,
            unit: m.unit,
            density: m.density,
            supplier: m.supplier,
            heatNumber: m.heatNumber,
            batchNumber: m.batchNumber,
            warehouseLocation: m.warehouseLocation,
            rackLocation: m.rackLocation,
            minimumStock: m.minimumStock,
            maximumStock: m.maximumStock,
            reorderLevel: m.reorderLevel,
            createdAt: m.createdAt,
            stockOnHand: m.stockOnHand + draft.quantity,
          );
        }
      }

      // 2. Update Firestore materials collection
      final matQuery = await _materialsRef.get();
      for (final doc in matQuery.docs) {
        final data = doc.data();
        final code = data['code'] ?? '';
        final desc = data['description'] ?? '';
        if (matchMat(code.toString(), desc.toString())) {
          final current = (data['stockOnHand'] as num?)?.toDouble() ?? 0;
          await doc.reference.update({'stockOnHand': current + draft.quantity});
        }
      }

      // 3. Update in-memory items store if matched
      for (var i = 0; i < _itemsStore.length; i++) {
        final item = _itemsStore[i];
        if (matchMat(item.sku, item.name)) {
          _itemsStore[i] = BookItem(
            id: item.id,
            name: item.name,
            sku: item.sku,
            rate: item.rate,
            type: item.type,
            unit: item.unit,
            hsnCode: item.hsnCode,
            taxPreference: item.taxPreference,
            taxRate: item.taxRate,
            intraStateTaxRate: item.intraStateTaxRate,
            interStateTaxRate: item.interStateTaxRate,
            costPrice: item.costPrice,
            purchaseAccount: item.purchaseAccount,
            salesAccount: item.salesAccount,
            cogsAccount: item.cogsAccount,
            reportingTags: item.reportingTags,
            preferredVendor: item.preferredVendor,
            product: item.product,
            productName: item.productName,
            masterSerialNo: item.masterSerialNo,
            partNo: item.partNo,
            drawingFileName: item.drawingFileName,
            assemblyImagePath: item.assemblyImagePath,
            parts: item.parts,
            trackInventory: item.trackInventory,
            stockOnHand: item.stockOnHand + draft.quantity,
          );
        }
      }

      // 4. Update Firestore items collection if matched
      final itemQuery = await _itemsRef.get();
      for (final doc in itemQuery.docs) {
        final data = doc.data();
        final sku = data['sku'] ?? '';
        final name = data['name'] ?? '';
        if (matchMat(sku.toString(), name.toString())) {
          final current = (data['stockOnHand'] as num?)?.toDouble() ?? 0;
          await doc.reference.update({'stockOnHand': current + draft.quantity});
        }
      }
    } catch (e) {
      debugPrint('Firestore addStock error: $e');
    }
  }

  @override
  Future<void> moveStock(MoveStockDraft draft) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    final adj = InventoryAdjustment(
      id: id,
      date: draft.date,
      reason: 'Stock Transfer to Machine ${draft.machine}',
      referenceNumber: draft.workOrder,
      type: 'Move Stock',
      status: 'Completed',
      description:
          'Issued by ${draft.issuedBy}, Received by ${draft.receivedBy}',
    );
    _adjustmentsStore.insert(0, adj);

    try {
      await _firestore.collection('stock_movements').doc('$id').set({
        'id': id,
        'workOrder': draft.workOrder,
        'productionOrder': draft.productionOrder,
        'jobCard': draft.jobCard,
        'date': Timestamp.fromDate(draft.date),
        'machine': draft.machine,
        'operatorName': draft.operatorName,
        'captureWorkOrder': draft.captureWorkOrder,
        'materialId': draft.materialId,
        'quantityIssued': draft.quantityIssued,
        'weightIssued': draft.weightIssued,
        'issuedBy': draft.issuedBy,
        'receivedBy': draft.receivedBy,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _adjustmentsRef.doc('$id').set({
        'id': id,
        'date': Timestamp.fromDate(draft.date),
        'reason': adj.reason,
        'referenceNumber': adj.referenceNumber,
        'type': adj.type,
        'status': adj.status,
        'description': adj.description,
      });
    } catch (e) {
      debugPrint('Firestore moveStock error: $e');
    }
  }

  @override
  Future<List<MaterialRequest>> getMaterialRequests() async {
    try {
      final snap = await _requestsRef.get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.map((doc) {
          final data = doc.data();
          final dateVal = data['date'];
          final crVal = data['createdAt'];

          DateTime parseDate(dynamic val) {
            if (val is Timestamp) return val.toDate();
            if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
            return DateTime.now();
          }

          return MaterialRequest(
            id: (data['id'] as num?)?.toInt() ?? doc.id.hashCode,
            date: parseDate(dateVal),
            machine: data['machine'] ?? '',
            operatorName: data['operatorName'] ?? '',
            workOrder: data['workOrder'] ?? '',
            material: data['material'] ?? '',
            quantityIssued: (data['quantityIssued'] as num?)?.toDouble() ?? 0,
            weightIssued: (data['weightIssued'] as num?)?.toDouble() ?? 0,
            createdAt: parseDate(crVal),
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Firestore getMaterialRequests error: $e');
    }
    return List.unmodifiable(_materialRequestsStore);
  }

  @override
  Future<void> requestMaterial(MaterialRequestDraft draft) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    final req = MaterialRequest(
      id: id,
      date: draft.date,
      machine: draft.machine,
      operatorName: draft.operatorName,
      workOrder: draft.workOrder,
      material: draft.material,
      quantityIssued: draft.quantityIssued,
      weightIssued: draft.weightIssued,
      createdAt: DateTime.now(),
    );
    _materialRequestsStore.insert(0, req);

    try {
      await _requestsRef.doc('$id').set({
        'id': id,
        'date': Timestamp.fromDate(draft.date),
        'machine': draft.machine,
        'operatorName': draft.operatorName,
        'workOrder': draft.workOrder,
        'material': draft.material,
        'quantityIssued': draft.quantityIssued,
        'weightIssued': draft.weightIssued,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Firestore requestMaterial error: $e');
    }
  }

  @override
  Future<List<MaterialReturn>> getMaterialReturns() async {
    try {
      final snap = await _returnsRef.get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.map((doc) {
          final data = doc.data();
          final crVal = data['createdAt'];

          DateTime parseDate(dynamic val) {
            if (val is Timestamp) return val.toDate();
            if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
            return DateTime.now();
          }

          return MaterialReturn(
            id: (data['id'] as num?)?.toInt() ?? doc.id.hashCode,
            workOrder: data['workOrder'] ?? '',
            material: data['material'] ?? '',
            quantityReturned:
                (data['quantityReturned'] as num?)?.toDouble() ?? 0,
            weight: (data['weight'] as num?)?.toDouble() ?? 0,
            reason: data['reason'] ?? '',
            createdAt: parseDate(crVal),
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Firestore getMaterialReturns error: $e');
    }
    return List.unmodifiable(_materialReturnsStore);
  }

  @override
  Future<void> returnMaterial(MaterialReturnDraft draft) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    final ret = MaterialReturn(
      id: id,
      workOrder: draft.workOrder,
      material: draft.material,
      quantityReturned: draft.quantityReturned,
      weight: draft.weight,
      reason: draft.reason,
      createdAt: DateTime.now(),
    );
    _materialReturnsStore.insert(0, ret);

    try {
      await _returnsRef.doc('$id').set({
        'id': id,
        'workOrder': draft.workOrder,
        'material': draft.material,
        'quantityReturned': draft.quantityReturned,
        'weight': draft.weight,
        'reason': draft.reason,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Firestore returnMaterial error: $e');
    }
  }

  @override
  Future<void> addTransaction(TransactionDraft draft) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    final tx = SalesTransaction(
      id: id,
      type: draft.type,
      number: draft.number,
      customer: draft.customer,
      date: draft.date,
      amount: draft.amount,
      status: 'Draft',
      referenceNumber: draft.referenceNumber,
      dueDate: draft.dueDate,
      notes: draft.notes,
      terms: draft.terms,
    );
    _transactionsStore.insert(0, tx);

    try {
      await _transactionsRef.doc('$id').set({
        'id': id,
        'type': draft.type == TransactionType.quote
            ? 'quote'
            : (draft.type == TransactionType.invoice ? 'invoice' : 'salesOrder'),
        'number': draft.number,
        'customerName': draft.customer,
        'date': Timestamp.fromDate(draft.date),
        'dueDate':
            draft.dueDate != null ? Timestamp.fromDate(draft.dueDate!) : null,
        'amount': draft.amount,
        'status': 'Draft',
        'referenceNumber': draft.referenceNumber,
        'notes': draft.notes,
        'terms': draft.terms,
        'discount': draft.discount,
        'taxAmount': draft.taxAmount,
        'amountPaid': draft.amountPaid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Firestore addTransaction error: $e');
    }
  }

  @override
  Future<void> convertQuote(int quoteId, TransactionType targetType) async {
    final targetStr =
        targetType == TransactionType.invoice ? 'invoice' : 'salesOrder';
    final index = _transactionsStore.indexWhere((t) => t.id == quoteId);
    if (index != -1) {
      _transactionsStore[index] = SalesTransaction(
        id: _transactionsStore[index].id,
        type: targetType,
        number: _transactionsStore[index].number,
        customer: _transactionsStore[index].customer,
        date: _transactionsStore[index].date,
        amount: _transactionsStore[index].amount,
        status: 'Converted',
      );
    }
    try {
      await _transactionsRef.doc('$quoteId').update({
        'type': targetStr,
        'status': 'Converted',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Firestore convertQuote error: $e');
    }
  }

  @override
  Future<void> recordInvoicePaid(int invoiceId) async {
    final index = _transactionsStore.indexWhere((t) => t.id == invoiceId);
    if (index != -1) {
      _transactionsStore[index] = SalesTransaction(
        id: _transactionsStore[index].id,
        type: _transactionsStore[index].type,
        number: _transactionsStore[index].number,
        customer: _transactionsStore[index].customer,
        date: _transactionsStore[index].date,
        amount: _transactionsStore[index].amount,
        status: 'Paid',
      );
    }
    try {
      await _transactionsRef.doc('$invoiceId').update({
        'status': 'Paid',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Firestore recordInvoicePaid error: $e');
    }
  }

  @override
  Future<DashboardMetrics> getDashboardMetrics() async {
    try {
      final items = await getItems();
      final materials = await getMaterials();
      final txs = await getTransactions(TransactionType.invoice);

      final totalInventoryValue = items.fold<double>(
        0,
        (sum, item) => sum + (item.costPrice * item.stockOnHand),
      );

      final totalReceivables = txs.fold<double>(
        0,
        (sum, tx) => sum + tx.amount,
      );

      final atRiskCount = items.where((i) => i.stockOnHand <= 2).length +
          materials
              .where((m) => (double.tryParse(m.minimumStock) ?? 0) > 10)
              .length;

      return DashboardMetrics(
        receivables: totalReceivables > 0 ? totalReceivables : 15500.0,
        payables: totalInventoryValue > 0 ? totalInventoryValue : 17000.0,
        revenue: totalReceivables > 0 ? totalReceivables * 1.2 : 28500.0,
        netProfit: 11500.0,
        inventoryAtRisk: atRiskCount,
      );
    } catch (e) {
      debugPrint('Firestore getDashboardMetrics error: $e');
    }
    return const DashboardMetrics(
      receivables: 15500.0,
      payables: 17000.0,
      revenue: 28500.0,
      netProfit: 11500.0,
      inventoryAtRisk: 1,
    );
  }

  @override
  Future<void> updateItem({
    required int id,
    required String name,
    String sku = '',
    double rate = 0,
    String type = 'Goods',
    String unit = 'pcs',
    String hsnCode = '',
    String taxPreference = 'Taxable',
    double taxRate = 18,
    String intraStateTaxRate = '',
    String interStateTaxRate = '',
    double costPrice = 0,
    String purchaseAccount = 'Cost of Goods Sold',
    String salesAccount = 'Sales',
    String cogsAccount = 'Cost of Goods Sold',
    String reportingTags = '',
    String preferredVendor = '',
    String product = '',
    String productName = '',
    String masterSerialNo = '',
    String partNo = '',
    String drawingFileName = '',
    String assemblyImagePath = '',
    List<ItemPart> parts = const [],
  }) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('items').doc('$id');
      await docRef.set({
        'id': id,
        'name': name,
        'sku': sku,
        'rate': rate,
        'type': type,
        'unit': unit,
        'hsnCode': hsnCode,
        'taxPreference': taxPreference,
        'taxRate': taxRate,
        'intraStateTaxRate': intraStateTaxRate,
        'interStateTaxRate': interStateTaxRate,
        'costPrice': costPrice,
        'purchaseAccount': purchaseAccount,
        'salesAccount': salesAccount,
        'cogsAccount': cogsAccount,
        'reportingTags': reportingTags,
        'preferredVendor': preferredVendor,
        'product': product,
        'productName': productName,
        'masterSerialNo': masterSerialNo,
        'partNo': partNo,
        'drawingFileName': drawingFileName,
        'assemblyImagePath': assemblyImagePath,
        'parts': parts.map((p) => {
          'slNo': p.slNo,
          'partName': p.partName,
          'partNo': p.partNo,
          'partImage': p.partImage,
          'partPdf': p.partPdf,
          'rmGrade': p.rmGrade,
          'rmSize': p.rmSize,
          'rmWeight': p.rmWeight,
          'fgWeight': p.fgWeight,
          'quantity': p.quantity,
          'hasProcessFlow': p.hasProcessFlow,
          'operations': p.operations.map((op) => {
            'operationNumber': op.operationNumber,
            'operationName': op.operationName,
            'machine': op.machine,
            'duration': op.duration,
            'remarks': op.remarks,
            'vendor': op.vendor,
          }).toList(),
        }).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firebase updateItem error: $e');
    }
  }

  @override
  Future<String> uploadItemImage({
    required Uint8List bytes,
    required String fileName,
    String folderName = 'Item Images',
  }) async {
    try {
      final sanitizedName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path = '$folderName/${DateTime.now().millisecondsSinceEpoch}_$sanitizedName';
      final storageRef = FirebaseStorage.instance.ref().child(path);
      
      String contentType = 'image/jpeg';
      final lower = fileName.toLowerCase();
      if (lower.endsWith('.pdf')) {
        contentType = 'application/pdf';
      } else if (lower.endsWith('.png')) {
        contentType = 'image/png';
      } else if (lower.endsWith('.webp')) {
        contentType = 'image/webp';
      } else if (lower.endsWith('.svg')) {
        contentType = 'image/svg+xml';
      }

      final uploadTask = await storageRef.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      if (kIsWeb && !lower.endsWith('.pdf') && bytes.lengthInBytes < 3 * 1024 * 1024) {
        final mimeType = lower.endsWith('.png') ? 'image/png' : 'image/jpeg';
        final base64Str = base64Encode(bytes);
        return 'data:$mimeType;base64,$base64Str';
      }
      return downloadUrl;
    } catch (e) {
      debugPrint('Firebase Storage uploadItemImage error: $e');
      final lower = fileName.toLowerCase();
      final mimeType = lower.endsWith('.png') ? 'image/png' : (lower.endsWith('.pdf') ? 'application/pdf' : 'image/jpeg');
      final base64Str = base64Encode(bytes);
      return 'data:$mimeType;base64,$base64Str';
    }
  }
}
