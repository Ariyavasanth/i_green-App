import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/firebase_books_repository.dart';
import '../domain/books_repository.dart';

// Firebase implementation active.
final booksRepositoryProvider = Provider<BooksRepository>(
  (ref) => FirebaseBooksRepository(),
);
final itemsProvider = FutureProvider<List<BookItem>>(
  (ref) => ref.watch(booksRepositoryProvider).getItems(),
);
final itemHistoryProvider =
    FutureProvider.family<List<ItemHistoryEntry>, int>(
      (ref, itemId) =>
          ref.watch(booksRepositoryProvider).getItemHistory(itemId),
    );
final customersProvider = FutureProvider<List<Customer>>(
  (ref) => ref.watch(booksRepositoryProvider).getCustomers(),
);
final transactionsProvider =
    FutureProvider.family<List<SalesTransaction>, TransactionType>(
      (ref, type) => ref.watch(booksRepositoryProvider).getTransactions(type),
    );
final adjustmentsProvider = FutureProvider<List<InventoryAdjustment>>(
  (ref) => ref.watch(booksRepositoryProvider).getAdjustments(),
);
final materialsProvider =
    FutureProvider.family<List<MaterialItem>, String?>(
      (ref, sourceType) =>
          ref.watch(booksRepositoryProvider).getMaterials(sourceType: sourceType),
    );
final stockEntriesProvider = FutureProvider<List<StockEntry>>(
  (ref) => ref.watch(booksRepositoryProvider).getStockEntries(),
);
final materialRequestsProvider = FutureProvider<List<MaterialRequest>>(
  (ref) => ref.watch(booksRepositoryProvider).getMaterialRequests(),
);
final materialReturnsProvider = FutureProvider<List<MaterialReturn>>(
  (ref) => ref.watch(booksRepositoryProvider).getMaterialReturns(),
);
final dashboardMetricsProvider = FutureProvider<DashboardMetrics>(
  (ref) => ref.watch(booksRepositoryProvider).getDashboardMetrics(),
);
final booksSearchQueryProvider = StateProvider<String>((ref) => '');
