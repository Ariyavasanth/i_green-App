import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/customer.dart';
import '../repositories/customers/customer_repository.dart';
import '../repositories/customers/firebase_customer_repository.dart';

// Firestore implementation active.
final customerRepositoryProvider = Provider<CustomerRepository>((ref) => FirebaseCustomerRepository());
final activeCustomersProvider = FutureProvider<List<Customer>>((ref) => ref.watch(customerRepositoryProvider).getCustomers());
