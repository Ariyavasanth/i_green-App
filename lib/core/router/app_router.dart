import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/app_shell/presentation/app_shell.dart';
import '../../features/app_shell/presentation/section_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(
          currentLocation: state.uri.path,
          child: child,
        ),
        routes: [
          for (final route in _routes)
            GoRoute(
              path: route.path,
              builder: (context, state) => SectionPage(title: route.title),
            ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

const _routes = [
  (path: '/home', title: 'Home'),
  (path: '/items', title: 'Items'),
  (path: '/customers', title: 'Customers'),
  (path: '/quotes', title: 'Quotes'),
  (path: '/sales-orders', title: 'Sales Orders'),
  (path: '/invoices', title: 'Invoices'),
  (path: '/inventory-adjustments', title: 'Inventory Adjustments'),
];
