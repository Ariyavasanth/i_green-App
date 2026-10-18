import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../domain/expense.dart';
import '../domain/expense_repository.dart';

class FirebaseExpenseRepository implements ExpenseRepository {
  final FirebaseFirestore _firestore;

  FirebaseExpenseRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _expensesRef =>
      _firestore.collection('expenses');

  @override
  Future<List<Expense>> getExpenses() async {
    try {
      final snap = await _expensesRef.get();
      final list = snap.docs.map((doc) {
        final data = doc.data();
        DateTime parseDate(dynamic val) {
          if (val is Timestamp) return val.toDate();
          if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
          return DateTime.now();
        }

        return Expense(
          id: (data['id'] as num?)?.toInt() ?? int.tryParse(doc.id) ?? doc.id.hashCode,
          date: parseDate(data['date']),
          account: (data['account'] ?? '').toString(),
          reference: (data['reference'] ?? '').toString(),
          vendor: (data['vendor'] ?? '').toString(),
          paidThrough: (data['paid_through'] ?? data['paidThrough'] ?? '').toString(),
          customer: (data['customer'] ?? '').toString(),
          status: (data['status'] ?? 'NON-BILLABLE').toString(),
          amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    } catch (e) {
      debugPrint('Firestore getExpenses error: $e');
      return [];
    }
  }

  @override
  Future<void> addExpense({
    required DateTime date,
    required String account,
    required String reference,
    required String vendor,
    required String paidThrough,
    required String customer,
    required String status,
    required double amount,
  }) async {
    try {
      final id = DateTime.now().millisecondsSinceEpoch;
      await _expensesRef.doc('$id').set({
        'id': id,
        'date': Timestamp.fromDate(date),
        'account': account,
        'reference': reference,
        'vendor': vendor,
        'paid_through': paidThrough,
        'customer': customer,
        'status': status,
        'amount': amount,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Firestore addExpense error: $e');
      rethrow;
    }
  }
}
