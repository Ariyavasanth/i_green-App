import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
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

  static const destinations = <_Destination>[
    _Destination('Home', '/home', Icons.home_outlined),
    _Destination('Items', '/items', Icons.inventory_2_outlined),
    _Destination('Customers', '/customers', Icons.people_outline),
    _Destination('Quotes', '/quotes', Icons.request_quote_outlined),
    _Destination('Sales Orders', '/sales-orders', Icons.shopping_cart_outlined),
    _Destination('Invoices', '/invoices', Icons.receipt_long_outlined),
    _Destination('Inventory Adjustments', '/inventory-adjustments', Icons.tune),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(sidebarExpandedProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final sidebar = _Sidebar(
          currentLocation: currentLocation,
          expanded: compact || expanded,
          onSelected: (path) {
            context.go(path);
            if (compact) Navigator.of(context).pop();
          },
        );
        return Scaffold(
          drawer: compact ? Drawer(width: 250, child: sidebar) : null,
          body: Builder(
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
                              ? () => Scaffold.of(scaffoldContext).openDrawer()
                              : () =>
                                    ref
                                            .read(
                                              sidebarExpandedProvider.notifier,
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
  Widget build(BuildContext context) => Container(
    height: 58,
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(bottom: BorderSide(color: AppColors.divider)),
    ),
    child: Row(
      children: [
        IconButton(
          tooltip: compact ? 'Open navigation' : 'Toggle navigation',
          onPressed: onMenuPressed,
          icon: Icon(expanded && !compact ? Icons.menu_open : Icons.menu),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text('My Organization', style: AppTextStyles.heading),
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
            PopupMenuItem(value: '/invoices/new', child: Text('New Invoice')),
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
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.active,
            child: Text('A', style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    ),
  );
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.currentLocation,
    required this.expanded,
    required this.onSelected,
  });
  final String currentLocation;
  final bool expanded;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    width: expanded ? 250 : 72,
    color: AppColors.primary,
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 58,
            child: Row(
              mainAxisAlignment: expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                if (expanded) const SizedBox(width: 20),
                const Icon(Icons.auto_stories, color: Colors.white, size: 28),
                if (expanded) ...[
                  const SizedBox(width: 12),
                  const Text(
                    'BOOKS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0x33FFFFFF)),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final destination in AppShell.destinations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _SidebarItem(
                      destination: destination,
                      selected: currentLocation == destination.path,
                      expanded: expanded,
                      onTap: () => onSelected(destination.path),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });
  final _Destination destination;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: expanded ? '' : destination.label,
    child: Material(
      color: selected ? AppColors.active : Colors.transparent,
      borderRadius: BorderRadius.circular(3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: expanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              if (expanded) const SizedBox(width: 14),
              Icon(destination.icon, color: Colors.white, size: 21),
              if (expanded) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.navigation,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _Destination {
  const _Destination(this.label, this.path, this.icon);
  final String label;
  final String path;
  final IconData icon;
}
