import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/customer.dart';
import '../repositories/customers/customer_repository.dart';
import '../repositories/customers/sqlite_customer_repository.dart';

// Change only this provider line when the Firebase implementation is ready.
final customerRepositoryProvider = Provider<CustomerRepository>((ref) => SqliteCustomerRepository());
final activeCustomersProvider = FutureProvider<List<Customer>>((ref) => ref.watch(customerRepositoryProvider).getCustomers());
