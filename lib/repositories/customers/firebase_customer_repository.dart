import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/customer.dart';
import 'customer_repository.dart';

class FirebaseCustomerRepository implements CustomerRepository {
  FirebaseCustomerRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _customersRef =>
      _firestore.collection('customers');

  @override
  Future<int> createCustomer(Customer customer) async {
    try {
      final snap = await _customersRef.get();
      int nextId = 1;
      for (final doc in snap.docs) {
        final rawId = doc.data()['id'];
        final currentId = rawId is num
            ? rawId.toInt()
            : int.tryParse(rawId?.toString() ?? '') ?? 0;
        if (currentId >= nextId) {
          nextId = currentId + 1;
        }
      }

      final newCustomer = customer.copyWith(id: nextId);
      await _customersRef.doc('$nextId').set(newCustomer.toJson());
      return nextId;
    } catch (e, stack) {
      developer.log('Error creating customer: $e',
          name: 'FirebaseCustomerRepository', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<void> deleteCustomer(int id) async {
    try {
      await _customersRef.doc('$id').delete();
    } catch (e, stack) {
      developer.log('Error deleting customer $id: $e',
          name: 'FirebaseCustomerRepository', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<Customer?> getCustomer(int id) async {
    try {
      final doc = await _customersRef.doc('$id').get();
      if (!doc.exists || doc.data() == null) return null;
      return Customer.fromJson(doc.data()!, id: id);
    } catch (e, stack) {
      developer.log('Error getting customer $id: $e',
          name: 'FirebaseCustomerRepository', error: e, stackTrace: stack);
      return null;
    }
  }

  @override
  Future<List<Customer>> getCustomers({bool activeOnly = true}) async {
    try {
      final snap = await _customersRef.get();
      final customers = <Customer>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final id = int.tryParse(doc.id) ??
            (data['id'] is num
                ? (data['id'] as num).toInt()
                : int.tryParse(data['id']?.toString() ?? ''));
        final c = Customer.fromJson(data, id: id);
        if (!activeOnly || c.isActive) {
          customers.add(c);
        }
      }
      customers.sort((a, b) => a.displayName.compareTo(b.displayName));
      return customers;
    } catch (e, stack) {
      developer.log('Error getting customers: $e',
          name: 'FirebaseCustomerRepository', error: e, stackTrace: stack);
      return [];
    }
  }

  @override
  Future<void> updateCustomer(Customer customer) async {
    if (customer.id == null) return;
    try {
      await _customersRef.doc('${customer.id}').update(customer.toJson());
    } catch (e, stack) {
      developer.log('Error updating customer ${customer.id}: $e',
          name: 'FirebaseCustomerRepository', error: e, stackTrace: stack);
      rethrow;
    }
  }
}
