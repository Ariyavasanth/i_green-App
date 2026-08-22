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

  @override Future<void> addTransaction(TransactionDraft draft) async {}
  @override Future<void> addAdjustment(AdjustmentDraft draft) async {}
  @override Future<void> addStock(StockEntryDraft draft) async {}
  @override Future<void> addMaterial(MaterialDraft draft) async {}
  @override Future<void> moveStock(MoveStockDraft draft) async {}
  @override Future<void> requestMaterial(MaterialRequestDraft draft) async {}
  @override Future<void> returnMaterial(MaterialReturnDraft draft) async {}
  @override Future<void> convertQuote(int quoteId, TransactionType targetType) async {}
  @override Future<List<InventoryAdjustment>> getAdjustments() async => [];
  @override Future<DashboardMetrics> getDashboardMetrics() async => const DashboardMetrics(receivables: 0, payables: 0, revenue: 0, netProfit: 0, inventoryAtRisk: 0);
  @override Future<void> recordInvoicePaid(int invoiceId) async {}
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
