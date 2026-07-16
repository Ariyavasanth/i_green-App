import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class SidebarDestination {
  const SidebarDestination(this.label, this.path, this.icon, this.section);

  final String label;
  final String path;
  final IconData icon;
  final String section;
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
                for (var index = 0; index < destinations.length; index++) ...[
                  // Group labels keep the longer navigation list easy to scan.
                  if (index == 0 ||
                      destinations[index - 1].section !=
                          destinations[index].section)
                    _SectionHeader(
                      label: destinations[index].section,
                      expanded: expanded,
                    ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
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
          const Divider(height: 1, color: Color(0x33FFFFFF)),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
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
                    child: Text(
                      destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CupertinoTheme.of(context).textTheme.textStyle
                          .copyWith(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            letterSpacing: -0.2,
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
