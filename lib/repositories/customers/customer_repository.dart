import '../../models/customer.dart';

abstract interface class CustomerRepository {
  Future<List<Customer>> getCustomers({bool activeOnly = true});
  Future<Customer?> getCustomer(int id);
  Future<int> createCustomer(Customer customer);
  Future<void> updateCustomer(Customer customer);
  Future<void> deleteCustomer(int id);
}
