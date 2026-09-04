import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/employee/domain/employee.dart';

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

class SidebarDrawer extends StatefulWidget {
  const SidebarDrawer({
    required this.destinations,
    required this.currentLocation,
    required this.expanded,
    required this.onSelected,
    required this.onLogout,
    this.employee,
    super.key,
  });

  final List<SidebarDestination> destinations;
  final String currentLocation;
  final bool expanded;
  final ValueChanged<String> onSelected;
  final VoidCallback onLogout;
  final Employee? employee;

  @override
  State<SidebarDrawer> createState() => _SidebarDrawerState();
}

class _SidebarDrawerState extends State<SidebarDrawer> {
  final GlobalKey _selectedKey = GlobalKey();
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset: _calculateInitialOffset(),
    );
    _scrollToSelectedItem();
  }

  @override
  void didUpdateWidget(covariant SidebarDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentLocation != widget.currentLocation) {
      _scrollToSelectedItem();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double _calculateInitialOffset() {
    final selectedIndex = _findSelectedIndex();
    if (selectedIndex <= 0) return 0.0;

    double offset = 0.0;
    for (int i = 0; i < selectedIndex; i++) {
      if (i == 0 || widget.destinations[i - 1].section != widget.destinations[i].section) {
        offset += (i == 0) ? 26.0 : 33.0;
      }
      offset += 36.0;
    }
    return (offset - 100.0).clamp(0.0, 5000.0);
  }

  void _scrollToSelectedItem() {
    void performScroll() {
      if (!mounted) return;
      final currentCtx = _selectedKey.currentContext;
      if (currentCtx != null) {
        Scrollable.ensureVisible(
          currentCtx,
          duration: Duration.zero,
          alignment: 0.3,
        );
      } else if (_scrollController.hasClients) {
        final calcOffset = _calculateInitialOffset();
        _scrollController.jumpTo(calcOffset);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => performScroll());
    Future.delayed(const Duration(milliseconds: 50), () => performScroll());
    Future.delayed(const Duration(milliseconds: 150), () => performScroll());
  }

  int _findSelectedIndex() {
    final cur = widget.currentLocation.trim();
    for (int i = 0; i < widget.destinations.length; i++) {
      if (cur == widget.destinations[i].path.trim()) {
        return i;
      }
    }
    for (int i = 0; i < widget.destinations.length; i++) {
      final path = widget.destinations[i].path.trim();
      if (path != '/' && path.isNotEmpty && cur.startsWith(path)) {
        return i;
      }
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _findSelectedIndex();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOutCubic,
      width: widget.expanded ? 250 : 72,
      decoration: const BoxDecoration(color: Colors.white),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 46),
              child: Row(
                mainAxisAlignment: widget.expanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  if (widget.expanded) const SizedBox(width: 16),
                  const Icon(Icons.auto_stories, color: Colors.black, size: 20),
                  if (widget.expanded) ...[
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
            if (widget.expanded && widget.employee != null) ...[
              _DrawerProfileCard(
                employee: widget.employee!,
                onTap: () => widget.onSelected('/my-profile'),
              ),
              const Divider(height: 1, color: Color(0x1F000000)),
            ],
            const SizedBox(height: 4),
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                children: [
                  for (var index = 0; index < widget.destinations.length; index++) ...[
                    // Group labels keep the longer navigation list easy to scan.
                    if (index == 0 ||
                        widget.destinations[index - 1].section !=
                            widget.destinations[index].section) ...[
                      if (index != 0)
                        Padding(
                          padding: EdgeInsets.only(
                            top: 6,
                            left: widget.expanded ? 4 : 0,
                            right: widget.expanded ? 4 : 0,
                          ),
                          child: const Divider(
                            height: 1,
                            color: Color(0x1A000000),
                          ),
                        ),
                      _SectionHeader(
                        label: widget.destinations[index].section,
                        expanded: widget.expanded,
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: _SidebarItem(
                        key: index == selectedIndex ? _selectedKey : null,
                        destination: widget.destinations[index],
                        selected: index == selectedIndex,
                        expanded: widget.expanded,
                        onTap: () => widget.onSelected(widget.destinations[index].path),
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
                expanded: widget.expanded,
                onTap: widget.onLogout,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
    super.key,
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

class _DrawerProfileCard extends StatelessWidget {
  const _DrawerProfileCard({
    required this.employee,
    this.onTap,
  });

  final Employee employee;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final name = employee.fullName.isNotEmpty
        ? employee.fullName
        : (employee.firstName.isNotEmpty ? employee.firstName : (employee.employeeId.isNotEmpty ? employee.employeeId : 'Employee'));
    final role = employee.designation.isNotEmpty
        ? employee.designation
        : (employee.userType.isNotEmpty ? employee.userType : 'Administrator');
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'E';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                _buildAvatar(employee, initial),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        role,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(Employee employee, String initial) {
    final photoUrl = employee.profileImageUrl.trim();
    if (photoUrl.isNotEmpty) {
      if (photoUrl.startsWith('data:')) {
        try {
          final commaIdx = photoUrl.indexOf(',');
          final bytes = base64Decode(commaIdx != -1 ? photoUrl.substring(commaIdx + 1) : photoUrl);
          return CircleAvatar(
            radius: 17,
            backgroundColor: AppColors.active,
            backgroundImage: MemoryImage(bytes),
          );
        } catch (_) {}
      } else if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
        return CircleAvatar(
          radius: 17,
          backgroundColor: AppColors.active,
          backgroundImage: NetworkImage(photoUrl),
        );
      }
    }
    return CircleAvatar(
      radius: 17,
      backgroundColor: AppColors.active,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}

