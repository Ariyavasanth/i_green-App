import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/app_shell/presentation/app_shell.dart';
import '../../features/app_shell/presentation/section_page.dart';
import '../../features/books/domain/books_repository.dart';
import '../../features/books/presentation/books_forms.dart';
import '../../features/books/presentation/books_pages.dart';
import '../../features/quotes/presentation/quote_form_screen.dart';
import '../../features/vendors/presentation/vendors_page.dart';
import '../../features/expenses/presentation/expenses_page.dart';
import '../../screens/login_screen.dart';
import '../../screens/customers/active_customers_list.dart';
import '../../screens/customers/new_customer_form.dart';
import '../../screens/vendors/new_vendor_form.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
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
            builder: (_, _) => const ActiveCustomersList(),
            routes: [
              GoRoute(path: 'new', builder: (_, _) => const NewCustomerForm()),
            ],
          ),
          GoRoute(
            path: '/quotes',
            builder: (_, _) =>
                const TransactionsPage(type: TransactionType.quote),
            routes: [
              GoRoute(path: 'new', builder: (_, _) => const QuoteFormScreen()),
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
            path: '/delivery-challans',
            builder: (_, _) => const SectionPage(title: 'Delivery Challans'),
          ),
          GoRoute(
            path: '/payments-received',
            builder: (_, _) => const SectionPage(title: 'Payments Received'),
          ),
          GoRoute(
            path: '/credit-notes',
            builder: (_, _) => const SectionPage(title: 'Credit Notes'),
          ),
          GoRoute(
            path: '/e-way-bills',
            builder: (_, _) => const SectionPage(title: 'e-Way Bills'),
          ),
          GoRoute(
            path: '/vendors',
            builder: (_, _) => const VendorsPage(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, _) => const NewVendorForm(),
              ),
            ],
          ),
          GoRoute(
            path: '/expenses',
            builder: (_, _) => const ExpensesPage(),
          ),
          GoRoute(
            path: '/purchase-orders',
            builder: (_, _) => const SectionPage(title: 'Purchase Orders'),
          ),
          GoRoute(
            path: '/bills',
            builder: (_, _) => const SectionPage(title: 'Bills'),
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
