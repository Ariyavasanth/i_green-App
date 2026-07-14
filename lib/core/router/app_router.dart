import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/app_shell/presentation/app_shell.dart';
import '../../features/books/domain/books_repository.dart';
import '../../features/books/presentation/books_forms.dart';
import '../../features/books/presentation/books_pages.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(currentLocation: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const HomePage()),
          GoRoute(
            path: '/items',
            builder: (_, _) => const ItemsPage(),
            routes: [
              GoRoute(path: 'new', builder: (_, _) => const NewItemPage()),
            ],
          ),
          GoRoute(
            path: '/customers',
            builder: (_, _) => const CustomersPage(),
          ),
          GoRoute(
            path: '/quotes',
            builder: (_, _) =>
                const TransactionsPage(type: TransactionType.quote),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, _) =>
                    const NewTransactionPage(type: TransactionType.quote),
              ),
            ],
          ),
          GoRoute(
            path: '/sales-orders',
            builder: (_, _) =>
                const TransactionsPage(type: TransactionType.salesOrder),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, _) =>
                    const NewTransactionPage(type: TransactionType.salesOrder),
              ),
            ],
          ),
          GoRoute(
            path: '/invoices',
            builder: (_, _) =>
                const TransactionsPage(type: TransactionType.invoice),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, _) =>
                    const NewTransactionPage(type: TransactionType.invoice),
              ),
            ],
          ),
          GoRoute(
            path: '/inventory-adjustments',
            builder: (_, _) => const InventoryAdjustmentsPage(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, _) => const NewAdjustmentPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
