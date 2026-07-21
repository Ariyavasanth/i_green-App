import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class SidebarDestination {
  const SidebarDestination(
    this.label,
    this.path,
    this.icon,
    this.section, {
    this.badgeCount,
  });

  final String label;
  final String path;
  final IconData icon;
  final String section;
  final int? badgeCount;
}

class SidebarDrawer extends StatelessWidget {
  const SidebarDrawer({
    required this.destinations,
    required this.currentLocation,
    required this.expanded,
    required this.onSelected,
    required this.onLogout,
    super.key,
  });

  final List<SidebarDestination> destinations;
  final String currentLocation;
  final bool expanded;
  final ValueChanged<String> onSelected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    curve: Curves.easeInOutCubic,
    width: expanded ? 250 : 72,
    decoration: const BoxDecoration(color: Colors.white),
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 46),
            child: Row(
              mainAxisAlignment: expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                if (expanded) const SizedBox(width: 16),
                const Icon(Icons.auto_stories, color: Colors.black, size: 20),
                if (expanded) ...[
                  const SizedBox(width: 9),
                  const Text(
                    'BOOKS',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0x1F000000)),
          const SizedBox(height: 4),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              children: [
                for (var index = 0; index < destinations.length; index++) ...[
                  // Group labels keep the longer navigation list easy to scan.
                  if (index == 0 ||
                      destinations[index - 1].section !=
                          destinations[index].section) ...[
                    if (index != 0)
                      Padding(
                        padding: EdgeInsets.only(
                          top: 6,
                          left: expanded ? 4 : 0,
                          right: expanded ? 4 : 0,
                        ),
                        child: const Divider(
                          height: 1,
                          color: Color(0x1A000000),
                        ),
                      ),
                    _SectionHeader(
                      label: destinations[index].section,
                      expanded: expanded,
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: _SidebarItem(
                      destination: destinations[index],
                      selected: currentLocation == destinations[index].path,
                      expanded: expanded,
                      onTap: () => onSelected(destinations[index].path),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0x1F000000)),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: _SidebarItem(
              destination: const SidebarDestination(
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.expanded});

  final String label;
  final bool expanded;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    curve: Curves.easeInOutCubic,
    height: expanded ? 26 : 12,
    padding: EdgeInsets.only(left: expanded ? 8 : 0, top: expanded ? 10 : 0),
    alignment: Alignment.centerLeft,
    child: AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: expanded ? 1 : 0,
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          color: Colors.black54,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
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

  final SidebarDestination destination;
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
        color: selected ? AppColors.active : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 34),
            child: Row(
              mainAxisAlignment: expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                if (expanded) const SizedBox(width: 10),
                Icon(
                  destination.icon,
                  color: selected ? Colors.white : Colors.black,
                  size: 18,
                ),
                if (expanded) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.navigation.copyWith(
                        color: selected ? Colors.white : Colors.black,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (destination.badgeCount != null) ...[
                    const SizedBox(width: 6),
                    _BadgeCount(count: destination.badgeCount!),
                  ],
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

class _BadgeCount extends StatelessWidget {
  const _BadgeCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      count > 99 ? '99+' : '$count',
      style: const TextStyle(
        color: Colors.black,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
    ),
  );
}
