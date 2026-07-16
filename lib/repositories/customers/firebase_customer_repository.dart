import '../../models/customer.dart';
import 'customer_repository.dart';

/// Firebase placeholder. Implement these methods before switching the provider.
class FirebaseCustomerRepository implements CustomerRepository {
  @override Future<int> createCustomer(Customer customer) => throw UnimplementedError();
  @override Future<void> deleteCustomer(int id) => throw UnimplementedError();
  @override Future<Customer?> getCustomer(int id) => throw UnimplementedError();
  @override Future<List<Customer>> getCustomers({bool activeOnly = true}) => throw UnimplementedError();
  @override Future<void> updateCustomer(Customer customer) => throw UnimplementedError();
}
