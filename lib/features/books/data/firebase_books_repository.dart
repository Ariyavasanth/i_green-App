import '../domain/books_repository.dart';

/// Firestore stub — returns safe empty values until fully implemented.
class FirebaseBooksRepository implements BooksRepository {
  @override Future<void> addCustomer({required String name, String company = '', String phone = ''}) async {}
  @override Future<void> addItem({required String name, String sku = '', double rate = 0, String type = 'Goods'}) async {}
  @override Future<void> addTransaction(TransactionDraft draft) async {}
  @override Future<List<Customer>> getCustomers() async => [];
  @override Future<List<BookItem>> getItems() async => [];
  @override Future<List<ItemHistoryEntry>> getItemHistory(int itemId) async => [];
  @override Future<List<SalesTransaction>> getTransactions(TransactionType type) async => [];
  @override Future<void> addAdjustment(AdjustmentDraft draft) async {}
  @override Future<void> addStock(StockEntryDraft draft) async {}
  @override Future<void> addMaterial(MaterialDraft draft) async {}
  @override Future<void> moveStock(MoveStockDraft draft) async {}
  @override Future<void> requestMaterial(MaterialRequestDraft draft) async {}
  @override Future<void> returnMaterial(MaterialReturnDraft draft) async {}
  @override Future<void> convertQuote(int quoteId, TransactionType targetType) async {}
  @override Future<List<InventoryAdjustment>> getAdjustments() async => [];
  @override Future<DashboardMetrics> getDashboardMetrics() async => const DashboardMetrics(receivables: 0, payables: 0, revenue: 0, netProfit: 0, inventoryAtRisk: 0);
  @override Future<void> recordInvoicePaid(int invoiceId) async {}
}
