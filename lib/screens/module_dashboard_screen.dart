import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../features/authentication/providers/authentication_providers.dart';
import '../features/employee/domain/employee.dart';
import '../features/employee/providers/employee_providers.dart';
import '../widgets/brand_logo.dart';
import '../widgets/module_card.dart';

class ModuleDashboardScreen extends ConsumerWidget {
  const ModuleDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeeStream = ref.watch(currentEmployeeStreamProvider);
    final employeesAsync = ref.watch(employeesProvider);
    final employee = ref.watch(currentEmployeeProvider);
    final authEmail = ref.watch(currentUserEmailProvider);

    final isLoading = (employeeStream.isLoading || employeesAsync.isLoading) && employee == null;
    final hasError = (employeeStream.hasError || employeesAsync.hasError) && employee == null;
    final employeeCount = employeesAsync.asData?.value.length ?? 0;

    void refreshProfile() {
      ref.invalidate(currentEmployeeStreamProvider);
      ref.invalidate(currentEmployeeProvider);
      ref.invalidate(employeesProvider);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F6),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Header ──
            _DashboardTopBar(
              employee: employee,
              authEmail: authEmail,
              isLoading: isLoading,
              hasError: hasError,
            ),
            // ── Main Content Area ──
            Expanded(
              child: RefreshIndicator(
                color: AppColors.active,
                onRefresh: () async {
                  refreshProfile();
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child: SingleChildScrollView(
                  key: const PageStorageKey<String>('module_dashboard_scroll'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isSmall = constraints.maxWidth < 600;
                          return Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmall ? 16 : 28,
                              vertical: isSmall ? 18 : 28,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Greeting & Hero Section ──
                                _GreetingHero(
                                  employee: employee,
                                  authEmail: authEmail,
                                  isLoading: isLoading,
                                  hasError: hasError,
                                  onRetry: refreshProfile,
                                ),
                                SizedBox(height: isSmall ? 20 : 28),
                                // ── Workspace Modules Section ──
                                _WorkspaceSection(
                                  employee: employee,
                                  employeeCount: employeeCount,
                                ),
                                SizedBox(height: isSmall ? 24 : 32),
                                // ── Brand Footer Card ──
                                const _BrandFooterCard(),
                                const SizedBox(height: 16),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardTopBar extends StatelessWidget {
  const _DashboardTopBar({
    this.employee,
    this.authEmail,
    required this.isLoading,
    required this.hasError,
  });

  final Employee? employee;
  final String? authEmail;
  final bool isLoading;
  final bool hasError;

  String get _displayName {
    if (isLoading) return 'Loading profile...';
    if (hasError) return authEmail?.isNotEmpty == true ? authEmail! : 'Sync Error';
    if (employee != null) {
      if (employee!.fullName.isNotEmpty) return employee!.fullName;
      if (employee!.firstName.isNotEmpty) return employee!.firstName;
      if (employee!.employeeId.isNotEmpty) return employee!.employeeId;
    }
    return authEmail?.isNotEmpty == true ? authEmail! : 'Account';
  }

  String get _designationText {
    if (isLoading) return 'Please wait...';
    if (hasError) return 'Error loading profile';
    if (employee != null) {
      if (employee!.designation.isNotEmpty) return employee!.designation;
      if (employee!.isSuperAdmin) return 'Super Administrator';
      return 'Staff Member';
    }
    return 'Setup Required';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 560;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 16 : 24,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(
              bottom: BorderSide(
                color: Color(0xFFE5E8E2),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Logo (Enlarged and cleaned without subtext)
              BrandLogo(
                height: isNarrow ? 44 : 54,
              ),
              const Spacer(),
              // Notification Button
              _TopBarIconButton(
                icon: Icons.notifications_none_rounded,
                tooltip: 'Notifications',
                hasBadge: true,
                onTap: () {},
              ),
              if (!isNarrow) ...[
                const SizedBox(width: 8),
                _TopBarIconButton(
                  icon: Icons.help_outline_rounded,
                  tooltip: 'Help & Documentation',
                  onTap: () {},
                ),
                const SizedBox(width: 14),
                Container(
                  height: 28,
                  width: 1,
                  color: const Color(0xFFE5E8E2),
                ),
                const SizedBox(width: 14),
              ] else ...[
                const SizedBox(width: 10),
              ],
              // User Profile Chip / Compact Avatar
              InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () => context.go('/my-profile'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildAvatar(),
                      if (!isNarrow) ...[
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _displayName,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.2,
                              ),
                            ),
                            Text(
                              _designationText,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatar() {
    if (isLoading) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary.withValues(alpha: 0.15),
        ),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          ),
        ),
      );
    }

    if (hasError) {
      return Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFEF4444),
        ),
        child: const Center(
          child: Icon(Icons.error_outline, size: 18, color: Colors.white),
        ),
      );
    }

    final cleanUrl = employee?.profileImageUrl.trim() ?? '';
    if (cleanUrl.isNotEmpty) {
      if (cleanUrl.startsWith('data:')) {
        try {
          final commaIdx = cleanUrl.indexOf(',');
          final bytes = base64Decode(
            commaIdx != -1 ? cleanUrl.substring(commaIdx + 1) : cleanUrl,
          );
          return CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary,
            backgroundImage: MemoryImage(bytes),
          );
        } catch (_) {}
      } else if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
        return CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primary,
          backgroundImage: NetworkImage(cleanUrl),
        );
      }
    }

    String initial = 'U';
    if (employee != null) {
      if (employee!.firstName.isNotEmpty) {
        initial = employee!.firstName[0].toUpperCase();
      } else if (employee!.fullName.isNotEmpty) {
        initial = employee!.fullName[0].toUpperCase();
      } else if (employee!.employeeId.isNotEmpty) {
        initial = employee!.employeeId[0].toUpperCase();
      }
    } else if (authEmail?.isNotEmpty == true) {
      initial = authEmail![0].toUpperCase();
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _TopBarIconButton extends StatelessWidget {
  const _TopBarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.hasBadge = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool hasBadge;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE5E8E2),
              width: 1,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                icon,
                size: 19,
                color: AppColors.textPrimary,
              ),
              if (hasBadge)
                Positioned(
                  top: 7,
                  right: 7,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFE53935),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GreetingHero extends StatelessWidget {
  const _GreetingHero({
    this.employee,
    this.authEmail,
    required this.isLoading,
    required this.hasError,
    this.onRetry,
  });

  final Employee? employee;
  final String? authEmail;
  final bool isLoading;
  final bool hasError;
  final VoidCallback? onRetry;

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  String get _greetingHeadline {
    final greeting = _getTimeBasedGreeting();
    if (isLoading) return '$greeting 👋';
    if (hasError) return '$greeting 👋';
    if (employee != null) {
      final name = employee!.firstName.isNotEmpty
          ? employee!.firstName
          : (employee!.fullName.isNotEmpty ? employee!.fullName : employee!.employeeId);
      return '$greeting, $name 👋';
    }
    final fallbackIdentifier = authEmail?.isNotEmpty == true ? authEmail! : '';
    if (fallbackIdentifier.isNotEmpty) {
      return '$greeting, $fallbackIdentifier 👋';
    }
    return '$greeting 👋';
  }

  String get _greetingSubtitle {
    if (isLoading) return 'Loading your profile and workspace...';
    if (hasError) return 'Could not load your employee profile from the server.';
    if (employee == null) return 'No employee profile is currently linked to this account.';
    return 'What would you like to manage today?';
  }

  Widget? _buildStatusOrAlertNotice() {
    if (hasError) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Could not load employee profile from server.',
                style: TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w500),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Retry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      );
    }

    if (!isLoading && employee == null) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFFE082)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFFF57C00), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Profile Setup Required: No employee record found matching "${authEmail ?? 'your account'}". Contact an administrator to link your profile.',
                style: const TextStyle(fontSize: 12, color: Color(0xFFE65100), fontWeight: FontWeight.w500),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFE65100),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Refresh', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final alertNotice = _buildStatusOrAlertNotice();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 580;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 18 : 24,
            vertical: isNarrow ? 18 : 22,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFE5E8E2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isNarrow) ...[
                Text(
                  _greetingHeadline,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _greetingSubtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 14),
                _SystemStatusBadge(),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greetingHeadline,
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _greetingSubtitle,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    _SystemStatusBadge(),
                  ],
                ),
              ],
              ?alertNotice,
            ],
          ),
        );
      },
    );
  }
}

class _SystemStatusBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 7),
          const Text(
            'System Operational',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceSection extends StatelessWidget {
  const _WorkspaceSection({this.employee, this.employeeCount = 0});
  final dynamic employee;
  final int employeeCount;

  @override
  Widget build(BuildContext context) {
    final emp = employee;
    final List<Widget> moduleCards = [];

    final isSuper = emp == null || (emp.isSuperAdmin == true);

    if (isSuper || emp.canAccessHrms == true) {
      moduleCards.add(
        ModuleCard(
          label: 'HRMS',
          icon: Icons.people_alt_rounded,
          color: const Color(0xFF9CC70A),
          description: 'Human Resource\nManagement',
          meta: employeeCount > 0
              ? '$employeeCount ${employeeCount == 1 ? "Employee" : "Employees"}'
              : 'Employees',
          metaIcon: Icons.people_outline_rounded,
          onTap: () => context.go('/module/hrms'),
        ),
      );
    }

    if (isSuper || emp.canAccessInventory == true) {
      moduleCards.add(
        ModuleCard(
          label: 'INVENTORY',
          icon: Icons.inventory_2_rounded,
          color: const Color(0xFF2196F3),
          description: 'Manage stock,\nproducts & assets',
          meta: '248 Items',
          metaIcon: Icons.inventory_2_outlined,
          onTap: () => context.go('/module/inventory'),
        ),
      );
    }

    if (isSuper || emp.canAccessAccounts == true) {
      moduleCards.add(
        ModuleCard(
          label: 'ACCOUNTS',
          icon: Icons.account_balance_rounded,
          color: const Color(0xFFFF9800),
          description: 'Manage finance,\nexpenses & reports',
          meta: '₹12.4L Total',
          metaIcon: Icons.account_balance_wallet_outlined,
          onTap: () => context.go('/module/accounts'),
        ),
      );
    }

    if (isSuper || emp.canAccessProjects == true) {
      moduleCards.add(
        ModuleCard(
          label: 'PROJECTS',
          icon: Icons.rocket_launch_rounded,
          color: const Color(0xFF9C27B0),
          description: 'Project tracking\n& milestones',
          comingSoon: false,
          onTap: () => context.go('/module/project'),
        ),
      );
    }

    if (isSuper || emp.canAccessFactory == true) {
      moduleCards.add(
        ModuleCard(
          label: 'FACILITY',
          icon: Icons.factory_rounded,
          color: const Color(0xFF607D8B),
          description: 'Facility &\nequipment operations',
          comingSoon: true,
          onTap: () => context.go('/module/factory'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'YOUR WORKSPACE',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Access and manage your business operations',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEBEFE7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${moduleCards.length} ${moduleCards.length == 1 ? 'Module' : 'Modules'}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Responsive Modules Grid
        if (moduleCards.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: const [
                Icon(Icons.lock_outline, size: 40, color: Color(0xFF9E9E9E)),
                SizedBox(height: 12),
                Text(
                  'No Accessible Modules',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Your account does not have permission to access any modules. Please contact your administrator.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width > 950
                  ? 3
                  : width > 550
                      ? 2
                      : 1;

              final childAspectRatio = width > 950
                  ? 1.45
                  : width > 550
                      ? 1.35
                      : width < 360
                          ? 1.65
                          : 1.85;

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: childAspectRatio,
                children: moduleCards,
              );
            },
          ),
      ],
    );
  }
}

class _BrandFooterCard extends StatelessWidget {
  const _BrandFooterCard();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 500;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 16 : 22,
            vertical: isNarrow ? 16 : 18,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF232A2F),
                Color(0xFF38434B),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF232A2F).withValues(alpha: 0.15),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.eco_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'igreen',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Enterprise Resource Planning • Smart solutions',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isNarrow) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    'v1.0.0',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
