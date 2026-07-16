import '../domain/books_repository.dart';

// Firebase placeholder: implement these methods, then change only the provider line.
class FirebaseBooksRepository implements BooksRepository {
  Never _pending() =>
      throw UnimplementedError('Firebase repository is not configured yet.');
  @override
  Future<void> addCustomer({
    required String name,
    String company = '',
    String phone = '',
  }) async => _pending();
  @override
  Future<void> addItem({
    required String name,
    String sku = '',
    double rate = 0,
    String type = 'Goods',
  }) async => _pending();
  @override
  Future<void> addTransaction(TransactionDraft draft) async => _pending();
  @override
  Future<List<Customer>> getCustomers() async => _pending();
  @override
  Future<List<BookItem>> getItems() async => _pending();
  @override
  Future<List<ItemHistoryEntry>> getItemHistory(int itemId) async =>
      _pending();
  @override
  Future<List<SalesTransaction>> getTransactions(TransactionType type) async =>
      _pending();
  @override
  Future<void> addAdjustment(AdjustmentDraft draft) async => _pending();
  @override
  Future<void> convertQuote(int quoteId, TransactionType targetType) async =>
      _pending();
  @override
  Future<List<InventoryAdjustment>> getAdjustments() async => _pending();
  @override
  Future<DashboardMetrics> getDashboardMetrics() async => _pending();
  @override
  Future<void> recordInvoicePaid(int invoiceId) async => _pending();
}
