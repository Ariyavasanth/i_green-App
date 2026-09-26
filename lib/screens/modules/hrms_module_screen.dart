import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_background_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../features/employee/providers/employee_providers.dart';
import '../../widgets/app_background_wrapper.dart';
import '../../widgets/module_card.dart';
import '../../widgets/organization_chart_icon.dart';

/// Data model for a sub-module item.
class _SubModule {
  const _SubModule(
    this.label,
    this.icon,
    this.route,
    this.color, {
    this.customIcon,
    this.containerColor,
  });
  final String label;
  final IconData? icon;
  final String route;
  final Color color;
  final Widget? customIcon;
  final Color? containerColor;
}

Widget _icon(String fileName, {double size = 52}) => Image.asset(
  'assets/icones/$fileName',
  width: size,
  height: size,
  fit: BoxFit.contain,
);

class HrmsModuleScreen extends ConsumerStatefulWidget {
  const HrmsModuleScreen({super.key});

  static final _sections = <String, List<_SubModule>>{
    'ORGANIZATION': [
      _SubModule(
        'Organization\nManagement',
        null,
        '/organization-management',
        const Color(0xFFF59E0B),
        customIcon: const OrganizationChartIcon(size: 52),
        containerColor: const Color(0xFFFEF3D6),
      ),
      _SubModule(
        'Organization\nStructure',
        null,
        '/organization-structure',
        const Color(0xFF00CEC9),
        customIcon: _icon('Organisation_structure.png'),
        containerColor: const Color(0xFFE0F9F8),
      ),
    ],
    'EMPLOYEE': [
      _SubModule(
        'Employee\nManagement',
        null,
        '/employee-management',
        const Color(0xFF0984E3),
        customIcon: _icon('employee management.png'),
        containerColor: const Color(0xFFE1EFFF),
      ),
      _SubModule(
        'Responses',
        null,
        '/responses',
        const Color(0xFFFF7675),
        customIcon: _icon('Response.png'),
        containerColor: const Color(0xFFFFECEB),
      ),
    ],
    'ATTENDANCE': [
      _SubModule(
        'Attendance',
        Icons.calendar_month_outlined,
        '/attendance',
        const Color(0xFF10B981),
        containerColor: const Color(0xFFE1F8ED),
      ),
      _SubModule(
        'Attendance\nManagement',
        Icons.co_present_outlined,
        '/attendance-management',
        const Color(0xFF06B6D4),
        containerColor: const Color(0xFFE0F7FA),
      ),
      _SubModule(
        'Attendance\nSettings',
        null,
        '/attendance-settings',
        const Color(0xFF8B5CF6),
        customIcon: _icon('attendace_settings.png'),
        containerColor: const Color(0xFFF1EAFF),
      ),
      _SubModule(
        'My On Duty',
        null,
        '/on-duty',
        const Color(0xFFF59E0B),
        customIcon: _icon('On_duty.png'),
        containerColor: const Color(0xFFFEF3D6),
      ),
      _SubModule(
        'On Duty\nManagement',
        null,
        '/on-duty-management',
        const Color(0xFFEF4444),
        customIcon: _icon('Od_management.png'),
        containerColor: const Color(0xFFFEE8E8),
      ),
    ],
    'TASKS & CLOCKING': [
      _SubModule(
        'My Tasks',
        null,
        '/my-tasks',
        const Color(0xFF3B82F6),
        customIcon: _icon('My_Task.png'),
        containerColor: const Color(0xFFE6F0FD),
      ),
      _SubModule(
        'Time\nClocking',
        null,
        '/time-clocking',
        const Color(0xFFEC4899),
        customIcon: _icon('clockinng.png'),
        containerColor: const Color(0xFFFDF0F6),
      ),
      _SubModule(
        'Tasks & Clocking\nManagement',
        null,
        '/tasks-and-timesheets',
        const Color(0xFF14B8A6),
        customIcon: _icon('task_and_clocking management.png'),
        containerColor: const Color(0xFFE0F7F4),
      ),
    ],
    'SITE VISIT': [
      _SubModule(
        'Site Visit\nAttendance',
        Icons.add_location_alt_outlined,
        '/site-visit-attendance',
        const Color(0xFFF97316),
        containerColor: const Color(0xFFFFEEDB),
      ),
      _SubModule(
        'Site Visit\nAttendance Mgmt',
        null,
        '/site-visit-attendance-management',
        const Color(0xFF6366F1),
        customIcon: _icon('site_attendace_management.png'),
        containerColor: const Color(0xFFEEF0FD),
      ),
    ],
    'LEAVE': [
      _SubModule(
        'Leave\nManagement',
        null,
        '/leave-management',
        const Color(0xFFE11D48),
        customIcon: _icon('Leave Management.png'),
        containerColor: const Color(0xFFFEE7EB),
      ),
    ],
    'SALARY & ASSETS': [
      _SubModule(
        'Salary\nSettings',
        Icons.request_quote_outlined,
        '/salary-settings',
        const Color(0xFF059669),
        containerColor: const Color(0xFFE1F7EF),
      ),
      _SubModule(
        'Asset\nSettings',
        null,
        '/asset-settings',
        const Color(0xFF0284C7),
        customIcon: _icon('asset_settings.png'),
        containerColor: const Color(0xFFE0F2FE),
      ),
      _SubModule(
        'Asset\nManagement',
        null,
        '/asset-management',
        const Color(0xFF7C3AED),
        customIcon: _icon('asset_management.png'),
        containerColor: const Color(0xFFF2EAFE),
      ),
      _SubModule(
        'My Asset',
        null,
        '/my-asset',
        const Color(0xFFEA580C),
        customIcon: _icon('My_asset.png'),
        containerColor: const Color(0xFFFDEDE5),
      ),
    ],
    'LOAN': [
      _SubModule(
        'Loan',
        null,
        '/loan',
        const Color(0xFF10B981),
        customIcon: _icon('loan.png'),
        containerColor: const Color(0xFFE1F8ED),
      ),
      _SubModule(
        'Loan\nManagement',
        null,
        '/loan-management',
        const Color(0xFFD97706),
        customIcon: _icon('Loan_management.png'),
        containerColor: const Color(0xFFFEF3D8),
      ),
    ],
    'EXIT & INCENTIVE': [
      _SubModule(
        'My Exit',
        null,
        '/my-exit',
        const Color(0xFFDC2626),
        customIcon: _icon('My_exit.png'),
        containerColor: const Color(0xFFFEE7E7),
      ),
      _SubModule(
        'Exit\nManagement',
        null,
        '/exit-management',
        const Color(0xFF9333EA),
        customIcon: _icon('Exit_management.png'),
        containerColor: const Color(0xFFF5E8FD),
      ),
      _SubModule(
        'Incentive\nRequest',
        null,
        '/incentive',
        const Color(0xFF16A34A),
        customIcon: _icon('incentive_requestion.png'),
        containerColor: const Color(0xFFE5F8EC),
      ),
      _SubModule(
        'Incentive\nManagement',
        null,
        '/incentive-management',
        const Color(0xFF0891B2),
        customIcon: _icon('incentive_management.png'),
        containerColor: const Color(0xFFE1F7FB),
      ),
    ],
    'PAYROLL': [
      _SubModule(
        'My Payslips',
        null,
        '/my-payslips',
        const Color(0xFF2563EB),
        customIcon: _icon('my_payslips.png'),
        containerColor: const Color(0xFFE6EFFF),
      ),
      _SubModule(
        'Payroll',
        null,
        '/payroll',
        const Color(0xFF4F46E5),
        customIcon: _icon('payroll.png'),
        containerColor: const Color(0xFFECEEFE),
      ),
      _SubModule(
        'Payroll\nHistory',
        null,
        '/payroll-history',
        const Color(0xFFC026D3),
        customIcon: _icon('Payroll_historty.png'),
        containerColor: const Color(0xFFFCEBFD),
      ),
      _SubModule(
        'Payroll\nSettings',
        null,
        '/payroll-settings',
        const Color(0xFF0D9488),
        customIcon: _icon('payroll_Settings.png'),
        containerColor: const Color(0xFFE0F6F4),
      ),
    ],
  };

  @override
  ConsumerState<HrmsModuleScreen> createState() => _HrmsModuleScreenState();
}

class _HrmsModuleScreenState extends ConsumerState<HrmsModuleScreen> {
  static double _savedScrollOffset = 0.0;
  late final ScrollController _scrollController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(initialScrollOffset: _savedScrollOffset);
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        _savedScrollOffset = _scrollController.offset;
      }
    });
  }

  @override
  void dispose() {
    if (_scrollController.hasClients) {
      _savedScrollOffset = _scrollController.offset;
    }
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final employee = ref.watch(currentEmployeeProvider);
    final employeeName = employee?.firstName ?? '';

    if (employee != null) {
      final bgState = ref.watch(appBackgroundProvider);
      if (bgState.currentEmployeeId != employee.id.toString()) {
        Future.microtask(() {
          ref.read(appBackgroundProvider.notifier).loadSettingsForEmployee(employee.id.toString());
        });
      }
    }

    final isSuper = employee == null || employee.isSuperAdmin;
    final permittedSections = <String, List<_SubModule>>{};

    for (final entry in HrmsModuleScreen._sections.entries) {
      final allowedItems = entry.value.where((m) {
        if (isSuper) return true;
        final cleanLabel = m.label.replaceAll('\n', ' ');
        return employee.hasPermission(cleanLabel);
      }).toList();

      if (allowedItems.isNotEmpty) {
        permittedSections[entry.key] = allowedItems;
      }
    }

    final filteredSections = <String, List<_SubModule>>{};
    final query = _searchQuery.trim().toLowerCase();

    for (final entry in permittedSections.entries) {
      final matches = entry.value.where((m) {
        if (query.isEmpty) return true;
        final cleanLabel = m.label.replaceAll('\n', ' ').toLowerCase();
        final sectionName = entry.key.toLowerCase();
        return cleanLabel.contains(query) || sectionName.contains(query);
      }).toList();

      if (matches.isNotEmpty) {
        filteredSections[entry.key] = matches;
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackgroundWrapper(
        child: Column(
          children: [
            ModuleScreenHeader(
              title: 'HRMS',
              icon: Icons.people_alt_outlined,
              color: const Color(0xFF9CC70A),
              onBack: () => context.go('/module-dashboard'),
              employeeName: employeeName,
              photoUrl: employee?.profileImageUrl,
              onProfile: () => context.go('/my-profile'),
            ),
            // ── Fixed Full-width Search Bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search icons (e.g. Attendance, Leave, Employee...)',
                  hintStyle: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF9CC70A),
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.95),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE5E8E2), width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE5E8E2), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF9CC70A), width: 1.5),
                  ),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF9CC70A),
                onRefresh: () async {
                  ref.invalidate(currentEmployeeProvider);
                  ref.invalidate(employeesProvider);
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child: permittedSections.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.lock_outline, size: 48, color: Color(0xFF9E9E9E)),
                              SizedBox(height: 16),
                              Text(
                                'No Accessible HRMS Modules',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'You do not have permission to access any sub-modules in HRMS.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView(
                        key: const PageStorageKey<String>('hrms_module_scroll_list'),
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        children: [

                          if (filteredSections.isEmpty && _searchQuery.isNotEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFF9CC70A).withValues(alpha: 0.1),
                                      ),
                                      child: const Icon(
                                        Icons.search_off_rounded,
                                        size: 40,
                                        color: Color(0xFF9CC70A),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No icons found for "$_searchQuery"',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Try searching with a different keyword like "Attendance", "Employee", or "Leave".',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                      icon: const Icon(Icons.refresh_rounded, size: 16),
                                      label: const Text('Clear Search'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF9CC70A),
                                        side: const BorderSide(color: Color(0xFF9CC70A)),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            for (final entry in filteredSections.entries) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8, top: 8),
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final crossAxisCount = constraints.maxWidth > 800
                                      ? 6
                                      : constraints.maxWidth > 500
                                          ? 4
                                          : 3;
                                  const childAspectRatio = 0.80;
                                  return GridView.count(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    padding: EdgeInsets.zero,
                                    crossAxisCount: crossAxisCount,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: childAspectRatio,
                                    children: entry.value
                                        .map((m) => SubModuleCard(
                                              label: m.label,
                                              icon: m.icon,
                                              customIcon: m.customIcon,
                                              color: m.color,
                                              containerColor: m.containerColor,
                                              onTap: () => context.go(m.route),
                                            ))
                                        .toList(),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                            ],
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
