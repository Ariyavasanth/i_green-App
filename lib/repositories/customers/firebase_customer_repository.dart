import '../../models/customer.dart';
import 'customer_repository.dart';

/// Firestore stub — returns safe empty values until fully implemented.
class FirebaseCustomerRepository implements CustomerRepository {
  @override Future<int> createCustomer(Customer customer) async => 0;
  @override Future<void> deleteCustomer(int id) async {}
  @override Future<Customer?> getCustomer(int id) async => null;
  @override Future<List<Customer>> getCustomers({bool activeOnly = true}) async => [];
  @override Future<void> updateCustomer(Customer customer) async {}
}
