import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../domain/bill.dart';
import '../domain/bill_repository.dart';

class FirebaseBillRepository implements BillRepository {
  final FirebaseFirestore _firestore;

  FirebaseBillRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _billsRef =>
      _firestore.collection('bills');

  @override
  Future<List<Bill>> getBills() async {
    try {
      final snap = await _billsRef.get();
      final list = snap.docs.map((doc) {
        final data = doc.data();
        DateTime parseDate(dynamic val) {
          if (val is Timestamp) return val.toDate();
          if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
          return DateTime.now();
        }

        return Bill(
          id: (data['id'] as num?)?.toInt() ?? int.tryParse(doc.id) ?? doc.id.hashCode,
          number: (data['number'] ?? '').toString(),
          vendorName: (data['vendor_name'] ?? data['vendorName'] ?? '').toString(),
          reference: (data['reference'] ?? '').toString(),
          status: (data['status'] ?? 'DRAFT').toString(),
          date: parseDate(data['date']),
          dueDate: parseDate(data['due_date'] ?? data['dueDate']),
          amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    } catch (e) {
      debugPrint('Firestore getBills error: $e');
      return [];
    }
  }

  @override
  Future<void> addBill(BillDraft bill) async {
    try {
      final id = DateTime.now().millisecondsSinceEpoch;
      await _billsRef.doc('$id').set({
        'id': id,
        'number': bill.number,
        'vendor_name': bill.vendorName,
        'reference': bill.reference,
        'status': 'DRAFT',
        'date': Timestamp.fromDate(bill.date),
        'due_date': Timestamp.fromDate(bill.dueDate),
        'amount': bill.amount,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Firestore addBill error: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteBill(int id) async {
    try {
      final snap = await _billsRef.where('id', isEqualTo: id).limit(1).get();
      if (snap.docs.isNotEmpty) {
        await snap.docs.first.reference.delete();
        return;
      }
      await _billsRef.doc('$id').delete();
    } catch (e) {
      debugPrint('Firestore deleteBill error: $e');
      rethrow;
    }
  }
}
