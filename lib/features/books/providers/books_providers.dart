import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/sqlite_books_repository.dart';
import '../domain/books_repository.dart';

// Change only this line when the Firebase implementation is ready.
final booksRepositoryProvider = Provider<BooksRepository>(
  (ref) => SqliteBooksRepository(),
);
final itemsProvider = FutureProvider<List<BookItem>>(
  (ref) => ref.watch(booksRepositoryProvider).getItems(),
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
final dashboardMetricsProvider = FutureProvider<DashboardMetrics>(
  (ref) => ref.watch(booksRepositoryProvider).getDashboardMetrics(),
);
final booksSearchQueryProvider = StateProvider<String>((ref) => '');
