import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/visual_effects.dart';
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

  static const destinations = <_Destination>[
    _Destination('Home', '/home', Icons.home_outlined, 'Overview'),
    _Destination('Items', '/items', Icons.inventory_2_outlined, 'Stock'),
    _Destination(
      'Inventory Adjustments',
      '/inventory-adjustments',
      Icons.tune,
      'Stock',
    ),
    _Destination('Customers', '/customers', Icons.people_outline, 'Sales'),
    _Destination('Quotes', '/quotes', Icons.request_quote_outlined, 'Sales'),
    _Destination(
      'Sales Orders',
      '/sales-orders',
      Icons.shopping_cart_outlined,
      'Sales',
    ),
    _Destination('Invoices', '/invoices', Icons.receipt_long_outlined, 'Sales'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(sidebarExpandedProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < AppBreakpoints.laptop;
        final sidebar = _Sidebar(
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
            const Expanded(
              child: Text(
                'My Organization',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.heading,
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

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.currentLocation,
    required this.expanded,
    required this.onSelected,
    required this.onLogout,
  });
  final String currentLocation;
  final bool expanded;
  final ValueChanged<String> onSelected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    curve: Curves.easeInOutCubic,
    width: expanded ? 250 : 72,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.active, Color(0xFF252C31)],
      ),
    ),
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Row(
              mainAxisAlignment: expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                if (expanded) const SizedBox(width: 18),
                const Icon(Icons.auto_stories, color: Colors.white, size: 26),
                if (expanded) ...[
                  const SizedBox(width: 11),
                  const Text(
                    'BOOKS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0x33FFFFFF)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 20),
              children: [
                for (
                  var index = 0;
                  index < AppShell.destinations.length;
                  index++
                ) ...[
                  // A header is rendered only when the destination's section changes.
                  if (index == 0 ||
                      AppShell.destinations[index - 1].section !=
                          AppShell.destinations[index].section)
                    _SidebarSectionHeader(
                      label: AppShell.destinations[index].section,
                      expanded: expanded,
                    ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: _SidebarItem(
                      destination: AppShell.destinations[index],
                      selected:
                          currentLocation == AppShell.destinations[index].path,
                      expanded: expanded,
                      onTap: () => onSelected(AppShell.destinations[index].path),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0x33FFFFFF)),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
            child: _SidebarItem(
              destination: const _Destination(
                'Logout',
                '/login',
                Icons.logout,
                'Account',
              ),
              selected: false,
              expanded: expanded,
              onTap: onLogout,
            ),
          ),
        ],
      ),
    ),
  );
}

class _SidebarSectionHeader extends StatelessWidget {
  const _SidebarSectionHeader({required this.label, required this.expanded});

  final String label;
  final bool expanded;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    curve: Curves.easeInOutCubic,
    height: expanded ? 38 : 16,
    padding: EdgeInsets.only(left: expanded ? 12 : 0, top: expanded ? 14 : 0),
    alignment: Alignment.centerLeft,
    child: AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: expanded ? 1 : 0,
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.7,
        ),
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
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 46),
            child: Row(
              mainAxisAlignment: expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                if (expanded) const SizedBox(width: 13),
                Icon(destination.icon, color: Colors.white, size: 20),
                if (expanded) ...[
                  const SizedBox(width: 13),
                  Expanded(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      style: CupertinoTheme.of(context).textTheme.textStyle
                          .copyWith(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            letterSpacing: -0.2,
                          ),
                      child: Text(
                        destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Destination {
  const _Destination(this.label, this.path, this.icon, this.section);
  final String label;
  final String path;
  final IconData icon;
  final String section;
}
