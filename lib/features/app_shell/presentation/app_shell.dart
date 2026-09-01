import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/storage/sidebar_state_storage.dart';
import '../../../core/storage/sidebar_state_storage_factory.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/visual_effects.dart';
import '../../../widgets/navigation/sidebar_drawer.dart';
import '../../authentication/providers/authentication_providers.dart';
import '../../books/providers/books_providers.dart';
import '../../employee/providers/employee_providers.dart';
import '../../permission/providers/permission_providers.dart';

final sidebarStateStorageProvider = Provider<SidebarStateStorage>(
  (_) => createSidebarStateStorage(),
);

final sidebarExpandedProvider = StateProvider<bool>((ref) {
  return ref.read(sidebarStateStorageProvider).readExpanded() ?? true;
});

final attendanceActiveTabProvider = StateProvider<int>((ref) => 0);

final userDestinationsProvider = Provider<List<SidebarDestination>>((ref) {
  final userEmail = ref.watch(currentUserEmailProvider);
  if (userEmail == null || userEmail.trim().isEmpty) {
    return AppShell.destinations;
  }

  final employeesAsync = ref.watch(employeesProvider);
  return employeesAsync.maybeWhen(
    data: (employees) {
      final matchingEmp = employees.where(
        (e) =>
            e.emailAddress.trim().toLowerCase() == userEmail.trim().toLowerCase() ||
            e.employeeId.trim().toLowerCase() == userEmail.trim().toLowerCase(),
      ).toList();

      if (matchingEmp.isEmpty) return AppShell.destinations;

      final emp = matchingEmp.first;
      final role = emp.userType.trim().toUpperCase();

      // ── SUPER_ADMIN / ADMIN: unrestricted full access ──────────────────────────────
      if (role == 'SUPER_ADMIN' || role == 'SUPER ADMIN' || role == 'ADMIN') {
        return AppShell.destinations;
      }

      // ── EMPLOYEE / standard roles:
      final allowed = emp.accessPermissions.map((p) => p.trim()).toSet();

      // Default basic employee modules when no explicit permissions are specified
      const defaultEmployeeModules = {
        'Home',
        'Attendance',
        'My Tasks',
        'Site Visit Attendance',
        'Permission',
        'Loan',
        'My Asset',
        'My Exit',
        'Incentive Request',
        'My Payslips',
      };

      if (allowed.isEmpty) {
        return AppShell.destinations
            .where((d) => defaultEmployeeModules.contains(d.label))
            .toList();
      }

      return AppShell.destinations
          .where((d) =>
              d.label == 'Home' ||
              d.label == 'My Payslips' ||
              allowed.contains(d.label) ||
              (d.label == 'Leave Management' && allowed.contains('Leave')))
          .toList();
    },
    orElse: () => AppShell.destinations,
  );
});

void _toggleSidebarExpanded(WidgetRef ref, bool expanded) {
  ref.read(sidebarExpandedProvider.notifier).state = expanded;
  ref.read(sidebarStateStorageProvider).writeExpanded(expanded);
}


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
    SidebarDestination(
      'Organization Management',
      '/organization-management',
      Icons.corporate_fare_outlined,
      'Organization',
    ),
    SidebarDestination(
      'Organization Structure',
      '/organization-structure',
      Icons.account_tree_outlined,
      'Organization',
    ),
    SidebarDestination(
      'Responses',
      '/responses',
      Icons.rate_review_outlined,
      'Employee',
    ),
    SidebarDestination(
      'Employee Management',
      '/employee-management',
      Icons.badge_outlined,
      'Employee',
    ),
    SidebarDestination(
      'Attendance',
      '/attendance',
      Icons.calendar_month_outlined,
      'Employee',
    ),
    SidebarDestination(
      'Attendance Management',
      '/attendance-management',
      Icons.co_present_outlined,
      'Employee',
    ),
    SidebarDestination(
      'Attendance Settings',
      '/attendance-settings',
      Icons.tune_outlined,
      'Employee',
    ),
    SidebarDestination(
      'On-Duty Management',
      '/on-duty-management',
      Icons.business_center_outlined,
      'Employee',
    ),
    SidebarDestination(
      'My Tasks',
      '/my-tasks',
      Icons.task_alt_outlined,
      'Employee',
    ),
    SidebarDestination(
      'Tasks and Clocking Management',
      '/tasks-and-timesheets',
      Icons.assignment_outlined,
      'Employee',
    ),
    SidebarDestination(
      'Site Visit Attendance',
      '/site-visit-attendance',
      Icons.add_location_alt_outlined,
      'Employee',
    ),
    SidebarDestination(
      'Site Visit Attendance Management',
      '/site-visit-attendance-management',
      Icons.pin_drop_outlined,
      'Employee',
    ),
    SidebarDestination(
      'Leave Management',
      '/leave-management',
      Icons.event_note,
      'Employee',
    ),
    SidebarDestination(
      'Permission',
      '/permission',
      Icons.access_time_filled_outlined,
      'Employee',
    ),
    SidebarDestination(
      'Permission Management',
      '/permission-management',
      Icons.more_time_outlined,
      'Employee',
    ),
    SidebarDestination(
      'Salary Settings',
      '/salary-settings',
      Icons.request_quote_outlined,
      'Employee',
    ),
    SidebarDestination(
      'Asset Settings',
      '/asset-settings',
      Icons.settings_suggest_outlined,
      'Employee',
    ),
    SidebarDestination(
      'Asset Management',
      '/asset-management',
      Icons.devices_other_outlined,
      'Employee',
    ),
    SidebarDestination(
      'My Asset',
      '/my-asset',
      Icons.devices_outlined,
      'Employee',
    ),
    SidebarDestination(
      'Loan',
      '/loan',
      Icons.account_balance_outlined,
      'Employee',
    ),
    SidebarDestination(
      'My Exit',
      '/my-exit',
      Icons.exit_to_app_outlined,
      'Employee',
    ),
    SidebarDestination(
      'Exit Management',
      '/exit-management',
      Icons.assignment_return_outlined,
      'Employee',
    ),
    SidebarDestination(
      'Incentive Request',
      '/incentive',
      Icons.request_quote_outlined,
      'Employee',
    ),
    SidebarDestination(
      'Incentive Management',
      '/incentive-management',
      Icons.price_check_outlined,
      'Employee',
    ),
    SidebarDestination(
      'My Payslips',
      '/my-payslips',
      Icons.receipt_long_outlined,
      'Employee',
    ),
    SidebarDestination(
      'Payroll',
      '/payroll',
      Icons.payments_outlined,
      'Payroll Management',
    ),
    SidebarDestination(
      'Payroll History',
      '/payroll-history',
      Icons.history_outlined,
      'Payroll Management',
    ),
    SidebarDestination(
      'Payroll Settings',
      '/payroll-settings',
      Icons.settings_outlined,
      'Payroll Management',
    ),
    SidebarDestination(
      'Loan Management',
      '/loan-management',
      Icons.account_balance,
      'Loan Management',
    ),
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
    SidebarDestination(
      'Delivery Challans',
      '/delivery-challans',
      Icons.local_shipping_outlined,
      'Sales',
    ),
    SidebarDestination(
      'Payments Received',
      '/payments-received',
      Icons.payments_outlined,
      'Sales',
    ),
    SidebarDestination(
      'Credit Notes',
      '/credit-notes',
      Icons.assignment_return_outlined,
      'Sales',
    ),
    SidebarDestination(
      'e-Way Bills',
      '/e-way-bills',
      Icons.qr_code_outlined,
      'Sales',
    ),
    SidebarDestination(
      'Vendors',
      '/vendors',
      Icons.storefront_outlined,
      'Purchase',
    ),
    SidebarDestination(
      'Expenses',
      '/expenses',
      Icons.account_balance_wallet_outlined,
      'Purchase',
    ),
    SidebarDestination(
      'Purchase Orders',
      '/purchase-orders',
      Icons.shopping_bag_outlined,
      'Purchase',
    ),
    SidebarDestination('Bills', '/bills', Icons.receipt_outlined, 'Purchase'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(sidebarExpandedProvider);
    final activeDestinations = ref.watch(userDestinationsProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < AppBreakpoints.laptop;
        final sidebar = SidebarDrawer(
          destinations: activeDestinations,
          currentLocation: currentLocation,
          expanded: compact || expanded,
          onSelected: (path) {
            context.go(path);
            if (compact) Navigator.of(context).pop();
          },
          onLogout: () async {
            ref.read(currentUserEmailProvider.notifier).state = null;
            await ref.read(authSessionStorageProvider).writeUserEmail(null);
            await ref.read(authenticationRepositoryProvider).signOut();
            if (context.mounted) context.go('/login');
          },
        );
        return Scaffold(
          drawer: compact ? Drawer(width: 250, child: sidebar) : null,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
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
                            currentLocation: currentLocation,
                            onMenuPressed: compact
                                ? () =>
                                      Scaffold.of(scaffoldContext).openDrawer()
                                : () =>
                                      _toggleSidebarExpanded(ref, !expanded),
                          ),
                          Expanded(
                            child: SafeArea(
                              top: false,
                              bottom: true,
                              child: child,
                            ),
                          ),
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

class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.compact,
    required this.expanded,
    required this.currentLocation,
    required this.onMenuPressed,
  });
  final bool compact;
  final bool expanded;
  final String currentLocation;
  final VoidCallback onMenuPressed;

  String _getHeading(String location) {
    final cleanLoc = location.split('?').first;
    if (cleanLoc == '/inventory-adjustments/add-stock') return 'Add Stock';
    if (cleanLoc == '/inventory-adjustments/add-material') return 'Add Material';
    if (cleanLoc == '/inventory-adjustments/move-stock') return 'Move Stock';
    if (cleanLoc == '/inventory-adjustments/history') return 'Adjustment History';
    if (cleanLoc == '/inventory-adjustments/requests') return 'Material Requests';
    if (cleanLoc == '/inventory-adjustments/request-material') return 'Request Material';
    if (cleanLoc == '/items/request-material') return 'Request Material';
    if (cleanLoc == '/items/new') return 'New Item';
    if (cleanLoc == '/customers/new') return 'New Customer';
    if (cleanLoc == '/quotes/new') return 'New Quote';
    if (cleanLoc == '/sales-orders/new') return 'New Sales Order';
    if (cleanLoc == '/invoices/new') return 'New Invoice';
    if (cleanLoc == '/bills/new') return 'New Bill';
    if (cleanLoc == '/purchase-orders/new') return 'New Purchase Order';
    if (cleanLoc == '/vendors/new') return 'New Vendors';
    if (cleanLoc == '/expenses/new') return 'New Expense';
    if (cleanLoc == '/inventory-adjustments/new') return 'New Inventory Adjustment';
    if (cleanLoc == '/permission/apply') return 'Apply Permission';
    if (cleanLoc == '/permission/emergency') return 'Emergency Exception Permission';
    if (cleanLoc == '/permission/details') return 'Permission Details';
    for (final dest in AppShell.destinations) {
      if (dest.path == cleanLoc || (dest.path != '/home' && cleanLoc.startsWith(dest.path))) {
        return dest.label;
      }
    }
    if (cleanLoc == '/employee' || cleanLoc == '/employee-management') return 'Employee Management';
    if (cleanLoc.startsWith('/employee/register')) return 'Employee Registration';
    return 'Green Technology';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String headingText;
    final isAttendanceManagement = currentLocation.startsWith('/attendance-management');

    if (isAttendanceManagement) {
      headingText = 'Attendance Management';
    } else if (currentLocation == '/attendance' || currentLocation.startsWith('/attendance/')) {
      final tabIndex = ref.watch(attendanceActiveTabProvider);
      switch (tabIndex) {
        case 1:
          headingText = 'Calendar';
          break;
        case 2:
          headingText = 'Leave';
          break;
        case 3:
          headingText = 'Salary & Loss of Pay Calculation';
          break;
        default:
          headingText = 'Attendance';
      }
    } else if (currentLocation == '/permission' || currentLocation == '/permission-management') {
      final permTab = ref.watch(adminPermissionActiveTabProvider);
      if (permTab == 2) {
        headingText = 'Usage Tracker';
      } else {
        headingText = 'Permission';
      }
    } else {
      headingText = _getHeading(currentLocation);
    }

    final isFormPage = currentLocation.endsWith('/new') ||
        currentLocation.contains('/edit') ||
        currentLocation.startsWith('/permission/') ||
        currentLocation.startsWith('/inventory-adjustments/');

    final content = SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            if (isFormPage)
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
                tooltip: 'Back',
                onPressed: () {
                  if (currentLocation.startsWith('/inventory-adjustments/')) {
                    context.go('/inventory-adjustments');
                  } else if (currentLocation.startsWith('/permission/')) {
                    context.go('/permission');
                  } else if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    context.go('/home');
                  }
                },
              )
            else
              _AnimatedMenuButton(
                tooltip: compact ? 'Open navigation' : 'Toggle navigation',
                onPressed: onMenuPressed,
              ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: isFormPage ? null : onMenuPressed,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isAttendanceManagement) ...[
                              const Text(
                                'Attendance',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                  height: 1.1,
                                ),
                              ),
                              const Text(
                                'Management',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                  height: 1.1,
                                ),
                              ),
                            ] else
                              Text(
                                headingText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            if (currentLocation.startsWith('/responses'))
                              Consumer(
                                builder: (context, ref, _) {
                                  final linksAsync = ref.watch(registrationLinksProvider);
                                  final count = linksAsync.maybeWhen(
                                    data: (links) => links.where((l) {
                                      final s = l.linkStatus.trim().toLowerCase();
                                      return s != 'registered' && s != 'converted';
                                    }).length,
                                    orElse: () => 0,
                                  );
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF2E7D32),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$count total responses',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                        if (isAttendanceManagement) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF81C784)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, size: 6, color: Color(0xFF2E7D32)),
                              SizedBox(width: 4),
                              Text(
                                'Live Sync',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            if (currentLocation == '/inventory-adjustments/requests')
              IconButton(
                tooltip: 'Create Material Request',
                icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.active, size: 24),
                onPressed: () => context.push('/inventory-adjustments/request-material'),
              ),

            if (compact) ...[
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.notifications_outlined, color: Color(0xFF414A51), size: 20),
                      onPressed: () {},
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFC62828),
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        '1',
                        style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (!compact) ...[
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
                icon: const Icon(
                  Icons.add_box_outlined,
                  color: AppColors.active,
                ),
                onSelected: (path) => context.push(path),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: '/tasks-and-timesheets?action=create_task', child: Text('+ Create Task')),
                  PopupMenuItem(value: '/tasks-and-timesheets?action=clock_activity', child: Text('⏱️ Start / Clock Activity')),
                  PopupMenuItem(value: '/tasks-and-timesheets?action=log_break', child: Text('☕ Log Break (Lunch / Tea)')),
                  PopupMenuDivider(),
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
            ],
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
    );

    if (compact) {
      return Container(
        color: const Color(0xFFF8FAFC),
        child: content,
      );
    }
    return GlassPanel(radius: 0, child: content);
  }
}

class _AnimatedMenuButton extends StatefulWidget {
  const _AnimatedMenuButton({
    required this.tooltip,
    required this.onPressed,
  });

  final String tooltip;
  final VoidCallback onPressed;

  @override
  State<_AnimatedMenuButton> createState() => _AnimatedMenuButtonState();
}

class _AnimatedMenuButtonState extends State<_AnimatedMenuButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final Animation<double> _turn = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0, end: 0.125), weight: 50),
    TweenSequenceItem(tween: Tween(begin: 0.125, end: 0), weight: 50),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: 0.88), weight: 35),
    TweenSequenceItem(tween: Tween(begin: 0.88, end: 1), weight: 65),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePressed() {
    _controller.forward(from: 0);
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: widget.tooltip,
    onPressed: _handlePressed,
    icon: AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => RotationTransition(
        turns: _turn,
        child: ScaleTransition(scale: _scale, child: child),
      ),
      child: const _FourTileMenuIcon(),
    ),
  );
}

class _FourTileMenuIcon extends StatelessWidget {
  const _FourTileMenuIcon();

  @override
  Widget build(BuildContext context) => const Icon(
        Icons.menu,
        size: 24,
        color: Color(0xFF1E293B),
      );
}
