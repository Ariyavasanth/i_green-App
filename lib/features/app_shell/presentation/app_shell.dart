import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/visual_effects.dart';
import '../../../widgets/navigation/sidebar_drawer.dart';
import '../../authentication/providers/authentication_providers.dart';
import '../../books/providers/books_providers.dart';

final sidebarExpandedProvider = StateProvider<bool>((ref) => true);

class AppShell extends ConsumerWidget {
  const AppShell({
    required this.currentLocation,
    required this.child,
    super.key,
  });

  final String currentLocation;
  final Widget child;

  static const destinations = <SidebarDestination>[
    SidebarDestination('Home', '/home', Icons.home_outlined, 'Overview'),
    SidebarDestination('Items', '/items', Icons.inventory_2_outlined, 'Stock'),
    SidebarDestination(
      'Inventory Adjustments',
      '/inventory-adjustments',
      Icons.tune,
      'Stock',
    ),
    SidebarDestination(
      'Customers',
      '/customers',
      Icons.people_outline,
      'Sales',
    ),
    SidebarDestination(
      'Quotes',
      '/quotes',
      Icons.request_quote_outlined,
      'Sales',
    ),
    SidebarDestination(
      'Sales Orders',
      '/sales-orders',
      Icons.shopping_cart_outlined,
      'Sales',
    ),
    SidebarDestination(
      'Invoices',
      '/invoices',
      Icons.receipt_long_outlined,
      'Sales',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(sidebarExpandedProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < AppBreakpoints.laptop;
        final sidebar = SidebarDrawer(
          destinations: destinations,
          currentLocation: currentLocation,
          expanded: compact || expanded,
          onSelected: (path) {
            context.go(path);
            if (compact) Navigator.of(context).pop();
          },
          onLogout: () async {
            await ref.read(authenticationRepositoryProvider).signOut();
            if (context.mounted) context.go('/login');
          },
        );
        return Scaffold(
          drawer: compact ? Drawer(width: 250, child: sidebar) : null,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFECF2FC), Color(0xFFECF2FC)],
              ),
            ),
            child: Builder(
              builder: (scaffoldContext) {
                return Row(
                  children: [
                    if (!compact) sidebar,
                    Expanded(
                      child: Column(
                        children: [
                          _TopBar(
                            compact: compact,
                            expanded: expanded,
                            onMenuPressed: compact
                                ? () =>
                                      Scaffold.of(scaffoldContext).openDrawer()
                                : () =>
                                      ref
                                              .read(
                                                sidebarExpandedProvider
                                                    .notifier,
                                              )
                                              .state =
                                          !expanded,
                          ),
                          Expanded(child: child),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.compact,
    required this.expanded,
    required this.onMenuPressed,
  });
  final bool compact;
  final bool expanded;
  final VoidCallback onMenuPressed;

  @override
  Widget build(BuildContext context) => GlassPanel(
    radius: 0,
    child: SafeArea(
      bottom: false,
      child: ConstrainedBox(
        // A minimum height preserves the design while allowing large text to grow.
        constraints: const BoxConstraints(minHeight: 64),
        child: Row(
          children: [
            IconButton(
              tooltip: compact ? 'Open navigation' : 'Toggle navigation',
              onPressed: onMenuPressed,
              icon: Icon(expanded && !compact ? Icons.menu_open : Icons.menu),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: onMenuPressed,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'My Organization',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.heading,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Search current section',
              onPressed: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Search'),
                  content: TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search records',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => ProviderScope.containerOf(
                      context,
                    ).read(booksSearchQueryProvider.notifier).state = value,
                    onSubmitted: (_) => Navigator.pop(dialogContext),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        ProviderScope.containerOf(
                          context,
                        ).read(booksSearchQueryProvider.notifier).state = '';
                        Navigator.pop(dialogContext);
                      },
                      child: const Text('Clear'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              icon: const Icon(Icons.search),
            ),
            PopupMenuButton<String>(
              tooltip: 'Quick create',
              icon: const Icon(Icons.add_box_outlined, color: AppColors.active),
              onSelected: (path) => context.push(path),
              itemBuilder: (_) => const [
                PopupMenuItem(value: '/items/new', child: Text('New Item')),
                PopupMenuItem(value: '/quotes/new', child: Text('New Quote')),
                PopupMenuItem(
                  value: '/sales-orders/new',
                  child: Text('New Sales Order'),
                ),
                PopupMenuItem(
                  value: '/invoices/new',
                  child: Text('New Invoice'),
                ),
                PopupMenuItem(
                  value: '/inventory-adjustments/new',
                  child: Text('New Adjustment'),
                ),
              ],
            ),
            IconButton(
              tooltip: 'Notifications',
              onPressed: () {},
              icon: const Icon(Icons.notifications_none),
            ),
            if (MediaQuery.sizeOf(context).width >= 520)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.active,
                  child: Text('A', style: TextStyle(color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
