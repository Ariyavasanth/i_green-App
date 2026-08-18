import 'package:cloud_firestore/cloud_firestore.dart';
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
    const BookItem(id: 1, name: 'Joint Kit', trackInventory: true, stockOnHand: 10),
    const BookItem(id: 2, name: 'Tool Holder', trackInventory: true, stockOnHand: 10),
    const BookItem(id: 3, name: 'End Mill', trackInventory: true, stockOnHand: 10),
    const BookItem(id: 4, name: 'Fixture', trackInventory: true, stockOnHand: 10),
    const BookItem(id: 5, name: 'Bore plug Gauge', trackInventory: true, stockOnHand: 10),
    const BookItem(id: 6, name: '3 Jaw Chuck', trackInventory: true, stockOnHand: 10),
    const BookItem(id: 7, name: '3.5" Pulling Swivel', trackInventory: true, stockOnHand: 10),
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
          return BookItem(
            id: doc.id.hashCode,
            name: data['name'] ?? '',
            sku: data['sku'] ?? '',
            rate: (data['rate'] as num?)?.toDouble() ?? 0,
            type: data['type'] ?? 'Goods',
            unit: data['unit'] ?? 'pcs',
            hsnCode: data['hsnCode'] ?? '',
            taxPreference: data['taxPreference'] ?? 'Taxable',
            taxRate: (data['taxRate'] as num?)?.toDouble() ?? 18,
            costPrice: (data['costPrice'] as num?)?.toDouble() ?? 0,
            salesAccount: data['salesAccount'] ?? 'Sales',
            cogsAccount: data['cogsAccount'] ?? 'Cost of Goods Sold',
            preferredVendor: data['preferredVendor'] ?? '',
            trackInventory: data['trackInventory'] ?? false,
            stockOnHand: (data['stockOnHand'] as num?)?.toDouble() ?? 0,
          );
        }).toList();
      } else {
        // Auto-create 'items' collection in Firestore with default items
        for (final item in _itemsStore) {
          await _itemsRef.add({
            'name': item.name,
            'sku': item.sku,
            'rate': item.rate,
            'type': item.type,
            'unit': item.unit,
            'hsnCode': item.hsnCode,
            'taxPreference': item.taxPreference,
            'taxRate': item.taxRate,
            'costPrice': item.costPrice,
            'salesAccount': item.salesAccount,
            'cogsAccount': item.cogsAccount,
            'preferredVendor': item.preferredVendor,
            'trackInventory': item.trackInventory,
            'stockOnHand': item.stockOnHand,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      debugPrint('Firestore getItems error: $e');
    }
    return List.unmodifiable(_itemsStore);
  }

  @override
  Future<void> addItem({
    required String name,
    String sku = '',
    double rate = 0,
    String type = 'Goods',
    String unit = 'pcs',
    String hsnCode = '',
    String taxPreference = 'Taxable',
    double taxRate = 18,
    double costPrice = 0,
    String salesAccount = 'Sales',
    String cogsAccount = 'Cost of Goods Sold',
    String preferredVendor = '',
  }) async {
    final newItem = BookItem(
      id: DateTime.now().millisecondsSinceEpoch,
      name: name,
      sku: sku,
      rate: rate,
      type: type,
      unit: unit,
      hsnCode: hsnCode,
      taxPreference: taxPreference,
      taxRate: taxRate,
      costPrice: costPrice,
      salesAccount: salesAccount,
      cogsAccount: cogsAccount,
      preferredVendor: preferredVendor,
      trackInventory: true,
      stockOnHand: 0,
    );
    _itemsStore.add(newItem);

    try {
      await _itemsRef.add({
        'name': name,
        'sku': sku,
        'rate': rate,
        'type': type,
        'unit': unit,
        'hsnCode': hsnCode,
        'taxPreference': taxPreference,
        'taxRate': taxRate,
        'costPrice': costPrice,
        'salesAccount': salesAccount,
        'cogsAccount': cogsAccount,
        'preferredVendor': preferredVendor,
        'trackInventory': true,
        'stockOnHand': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Firestore addItem error: $e');
    }
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
  @override Future<List<ItemHistoryEntry>> getItemHistory(int itemId) async => [];
  @override Future<List<SalesTransaction>> getTransactions(TransactionType type) async => [];
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
}
