import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../domain/purchase_order.dart';
import '../domain/purchase_order_repository.dart';

/// Firebase Firestore implementation for PurchaseOrderRepository.
class FirebasePurchaseOrderRepository implements PurchaseOrderRepository {
  final FirebaseFirestore? _customFirestore;

  FirebasePurchaseOrderRepository({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _poRef =>
      _firestore.collection('purchase_orders');

  static final List<PurchaseOrder> _seedOrders = [
    PurchaseOrder(
      id: 1,
      number: 'PO-00225',
      vendorName: 'Shahnaz Bright Steel Industries Pvt Ltd.',
      date: DateTime.parse('2026-07-14'),
      amount: 18150.76,
      subTotal: 15382.00,
      taxAmount: 2768.76,
      status: 'DRAFT',
      billedStatus: 'YET TO BE BILLED',
      paymentTerms: 'Due on Receipt',
    ),
    PurchaseOrder(
      id: 2,
      number: 'PO-00224',
      vendorName: 'Shahnaz Bright Steel Industries Pvt Ltd.',
      date: DateTime.parse('2026-06-20'),
      amount: 17452.20,
      subTotal: 14790.00,
      taxAmount: 2662.20,
      status: 'DRAFT',
      billedStatus: 'YET TO BE BILLED',
      paymentTerms: 'Net 30',
    ),
  ];

  static final List<PurchaseOrder> _localStore = List<PurchaseOrder>.from(_seedOrders);

  @override
  Future<String> generateNextPoNumber() async {
    try {
      final snap = await _poRef.get();
      if (snap.docs.isNotEmpty) {
        int maxNum = 0;
        for (final doc in snap.docs) {
          final code = (doc.data()['number'] as String?) ?? '';
          final numStr = code.replaceAll(RegExp(r'[^0-9]'), '');
          final n = int.tryParse(numStr) ?? 0;
          if (n > maxNum) maxNum = n;
        }
        return 'PO-${(maxNum + 1).toString().padLeft(5, '0')}';
      }
    } catch (e) {
      debugPrint('Firestore generateNextPoNumber error: $e');
    }

    int maxNum = 0;
    for (final po in _localStore) {
      final numStr = po.number.replaceAll(RegExp(r'[^0-9]'), '');
      final n = int.tryParse(numStr) ?? 0;
      if (n > maxNum) maxNum = n;
    }
    return 'PO-${(maxNum + 1).toString().padLeft(5, '0')}';
  }

  @override
  Future<List<PurchaseOrder>> getPurchaseOrders() async {
    try {
      final snap = await _poRef.get();
      if (snap.docs.isNotEmpty) {
        final list = snap.docs.map((doc) => _mapDocToPo(doc)).toList();
        list.sort((a, b) => b.date.compareTo(a.date));
        return list;
      } else {
        for (final po in _seedOrders) {
          await _poRef.doc(po.id.toString()).set(_mapPoToData(po));
        }
      }
    } catch (e) {
      debugPrint('Firestore getPurchaseOrders error: $e');
    }

    return List.unmodifiable(_localStore);
  }

  @override
  Future<PurchaseOrder?> getPurchaseOrderById(int id) async {
    try {
      final doc = await _poRef.doc(id.toString()).get();
      if (doc.exists) {
        return _mapDocToPo(doc);
      }
    } catch (e) {
      debugPrint('Firestore getPurchaseOrderById error: $e');
    }
    final index = _localStore.indexWhere((p) => p.id == id);
    return index != -1 ? _localStore[index] : null;
  }

  @override
  Future<void> addPurchaseOrder(PurchaseOrderDraft draft) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    final now = DateTime.now();
    final po = PurchaseOrder(
      id: id,
      number: draft.number,
      vendorId: draft.vendorId,
      vendorName: draft.vendorName,
      reference: draft.reference,
      date: draft.date,
      amount: draft.amount,
      status: draft.status,
      billedStatus: 'YET TO BE BILLED',
      deliveryDate: draft.deliveryDate,
      deliveryAddressType: draft.deliveryAddressType,
      deliveryAddress: draft.deliveryAddress,
      customerId: draft.customerId,
      customerName: draft.customerName,
      shipmentPreference: draft.shipmentPreference,
      paymentTerms: draft.paymentTerms,
      reverseCharge: draft.reverseCharge,
      notes: draft.notes,
      terms: draft.terms,
      subTotal: draft.subTotal,
      discountType: draft.discountType,
      discountValue: draft.discountValue,
      discountAmount: draft.discountAmount,
      taxAmount: draft.taxAmount,
      tdsRate: draft.tdsRate,
      tdsAmount: draft.tdsAmount,
      tcsRate: draft.tcsRate,
      tcsAmount: draft.tcsAmount,
      roundOff: draft.roundOff,
      attachments: draft.attachments,
      createdAt: now,
      updatedAt: now,
      items: draft.items
          .map((i) => PurchaseOrderItem(
                itemId: i.itemId,
                itemName: i.itemName,
                account: i.account,
                quantity: i.quantity,
                unit: i.unit,
                rate: i.rate,
                tax: i.tax,
                taxRate: i.taxRate,
                amount: i.amount,
              ))
          .toList(),
    );

    _localStore.insert(0, po);

    try {
      await _poRef.doc(id.toString()).set(_mapPoToData(po));
    } catch (e) {
      debugPrint('Firestore addPurchaseOrder error: $e');
    }
  }

  @override
  Future<void> updatePurchaseOrder(int id, PurchaseOrderDraft draft) async {
    final existing = await getPurchaseOrderById(id);
    if (existing != null && existing.isReadOnly) {
      throw StateError('Purchase Order #${existing.number} is in status "${existing.status}" and cannot be modified.');
    }

    final now = DateTime.now();
    final po = PurchaseOrder(
      id: id,
      number: draft.number,
      vendorId: draft.vendorId,
      vendorName: draft.vendorName,
      reference: draft.reference,
      date: draft.date,
      amount: draft.amount,
      status: draft.status,
      billedStatus: existing?.billedStatus ?? 'YET TO BE BILLED',
      deliveryDate: draft.deliveryDate,
      deliveryAddressType: draft.deliveryAddressType,
      deliveryAddress: draft.deliveryAddress,
      customerId: draft.customerId,
      customerName: draft.customerName,
      shipmentPreference: draft.shipmentPreference,
      paymentTerms: draft.paymentTerms,
      reverseCharge: draft.reverseCharge,
      notes: draft.notes,
      terms: draft.terms,
      subTotal: draft.subTotal,
      discountType: draft.discountType,
      discountValue: draft.discountValue,
      discountAmount: draft.discountAmount,
      taxAmount: draft.taxAmount,
      tdsRate: draft.tdsRate,
      tdsAmount: draft.tdsAmount,
      tcsRate: draft.tcsRate,
      tcsAmount: draft.tcsAmount,
      roundOff: draft.roundOff,
      attachments: draft.attachments,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      items: draft.items
          .map((i) => PurchaseOrderItem(
                itemId: i.itemId,
                itemName: i.itemName,
                account: i.account,
                quantity: i.quantity,
                unit: i.unit,
                rate: i.rate,
                tax: i.tax,
                taxRate: i.taxRate,
                amount: i.amount,
              ))
          .toList(),
    );

    final idx = _localStore.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _localStore[idx] = po;
    } else {
      _localStore.insert(0, po);
    }

    try {
      await _poRef.doc(id.toString()).set(_mapPoToData(po), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore updatePurchaseOrder error: $e');
    }
  }

  @override
  Future<void> updatePoStatus(int id, String newStatus) async {
    final idx = _localStore.indexWhere((p) => p.id == id);
    if (idx != -1) {
      final old = _localStore[idx];
      _localStore[idx] = PurchaseOrder(
        id: old.id,
        number: old.number,
        vendorId: old.vendorId,
        vendorName: old.vendorName,
        reference: old.reference,
        status: newStatus,
        billedStatus: newStatus == 'BILLED' ? 'BILLED' : old.billedStatus,
        date: old.date,
        deliveryDate: old.deliveryDate,
        deliveryAddressType: old.deliveryAddressType,
        deliveryAddress: old.deliveryAddress,
        customerId: old.customerId,
        customerName: old.customerName,
        shipmentPreference: old.shipmentPreference,
        paymentTerms: old.paymentTerms,
        reverseCharge: old.reverseCharge,
        notes: old.notes,
        terms: old.terms,
        subTotal: old.subTotal,
        discountType: old.discountType,
        discountValue: old.discountValue,
        discountAmount: old.discountAmount,
        taxAmount: old.taxAmount,
        tdsRate: old.tdsRate,
        tdsAmount: old.tdsAmount,
        tcsRate: old.tcsRate,
        tcsAmount: old.tcsAmount,
        roundOff: old.roundOff,
        amount: old.amount,
        attachments: old.attachments,
        items: old.items,
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
      );
    }

    try {
      await _poRef.doc(id.toString()).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Firestore updatePoStatus error: $e');
    }
  }

  @override
  Future<void> deletePurchaseOrder(int id) async {
    final existing = await getPurchaseOrderById(id);
    if (existing != null && (existing.isBilled || existing.status == 'RECEIVED')) {
      throw StateError('Cannot delete Purchase Order #${existing.number} because it is already ${existing.status}.');
    }
    _localStore.removeWhere((p) => p.id == id);
    try {
      await _poRef.doc(id.toString()).delete();
    } catch (e) {
      debugPrint('Firestore deletePurchaseOrder error: $e');
    }
  }

  Map<String, dynamic> _mapPoToData(PurchaseOrder po) {
    return {
      'id': po.id,
      'number': po.number,
      'vendorId': po.vendorId,
      'vendorName': po.vendorName,
      'reference': po.reference,
      'status': po.status,
      'billedStatus': po.billedStatus,
      'date': Timestamp.fromDate(po.date),
      'deliveryDate': po.deliveryDate != null ? Timestamp.fromDate(po.deliveryDate!) : null,
      'deliveryAddressType': po.deliveryAddressType,
      'deliveryAddress': po.deliveryAddress,
      'customerId': po.customerId,
      'customerName': po.customerName,
      'shipmentPreference': po.shipmentPreference,
      'paymentTerms': po.paymentTerms,
      'reverseCharge': po.reverseCharge,
      'notes': po.notes,
      'terms': po.terms,
      'subTotal': po.subTotal,
      'discountType': po.discountType,
      'discountValue': po.discountValue,
      'discountAmount': po.discountAmount,
      'taxAmount': po.taxAmount,
      'tdsRate': po.tdsRate,
      'tdsAmount': po.tdsAmount,
      'tcsRate': po.tcsRate,
      'tcsAmount': po.tcsAmount,
      'roundOff': po.roundOff,
      'amount': po.amount,
      'attachments': po.attachments,
      'createdAt': po.createdAt != null ? Timestamp.fromDate(po.createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'items': po.items
          .map((i) => {
                'itemId': i.itemId,
                'itemName': i.itemName,
                'account': i.account,
                'quantity': i.quantity,
                'unit': i.unit,
                'rate': i.rate,
                'tax': i.tax,
                'taxRate': i.taxRate,
                'amount': i.amount,
                'taxAmount': i.taxAmount,
              })
          .toList(),
    };
  }

  PurchaseOrder _mapDocToPo(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final id = (d['id'] as num?)?.toInt() ?? doc.id.hashCode;

    final itemList = <PurchaseOrderItem>[];
    if (d['items'] != null && d['items'] is List) {
      for (final item in d['items'] as List) {
        if (item is Map) {
          itemList.add(PurchaseOrderItem(
            itemId: (item['itemId'] as num?)?.toInt(),
            itemName: item['itemName'] as String? ?? '',
            account: item['account'] as String? ?? 'Cost of Goods Sold',
            quantity: (item['quantity'] as num?)?.toDouble() ?? 1.0,
            unit: item['unit'] as String? ?? 'pcs',
            rate: (item['rate'] as num?)?.toDouble() ?? 0.0,
            tax: item['tax'] as String? ?? 'GST 18%',
            taxRate: (item['taxRate'] as num?)?.toDouble() ?? 18.0,
            amount: (item['amount'] as num?)?.toDouble() ?? 0.0,
          ));
        }
      }
    }

    final attachList = <String>[];
    if (d['attachments'] != null && d['attachments'] is List) {
      for (final a in d['attachments'] as List) {
        if (a is String) attachList.add(a);
      }
    }

    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final computedGstTax = itemList.fold<double>(0, (acc, i) => acc + i.taxAmount);

    return PurchaseOrder(
      id: id,
      number: d['number'] as String? ?? '',
      vendorId: (d['vendorId'] as num?)?.toInt(),
      vendorName: d['vendorName'] as String? ?? '',
      reference: d['reference'] as String? ?? '',
      status: d['status'] as String? ?? 'DRAFT',
      billedStatus: d['billedStatus'] as String? ?? 'YET TO BE BILLED',
      date: parseDate(d['date']),
      deliveryDate: parseNullableDate(d['deliveryDate']),
      deliveryAddressType: d['deliveryAddressType'] as String? ?? 'Organization',
      deliveryAddress: d['deliveryAddress'] as String? ?? '',
      customerId: (d['customerId'] as num?)?.toInt(),
      customerName: d['customerName'] as String? ?? '',
      shipmentPreference: d['shipmentPreference'] as String? ?? '',
      paymentTerms: d['paymentTerms'] as String? ?? 'Due on Receipt',
      reverseCharge: d['reverseCharge'] as bool? ?? false,
      notes: d['notes'] as String? ?? '',
      terms: d['terms'] as String? ?? '',
      subTotal: (d['subTotal'] as num?)?.toDouble() ?? 0.0,
      discountType: d['discountType'] as String? ?? '%',
      discountValue: (d['discountValue'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (d['discountAmount'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (d['taxAmount'] as num?)?.toDouble() ?? computedGstTax,
      tdsRate: (d['tdsRate'] as num?)?.toDouble() ?? 0.0,
      tdsAmount: (d['tdsAmount'] as num?)?.toDouble() ?? 0.0,
      tcsRate: (d['tcsRate'] as num?)?.toDouble() ?? 0.0,
      tcsAmount: (d['tcsAmount'] as num?)?.toDouble() ?? 0.0,
      roundOff: (d['roundOff'] as num?)?.toDouble() ?? 0.0,
      amount: (d['amount'] as num?)?.toDouble() ?? 0.0,
      attachments: attachList,
      createdAt: parseNullableDate(d['createdAt']),
      updatedAt: parseNullableDate(d['updatedAt']),
      items: itemList,
    );
  }
}
