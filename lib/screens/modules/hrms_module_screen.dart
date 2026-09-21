import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_background_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../features/employee/providers/employee_providers.dart';
import '../../widgets/app_background_wrapper.dart';
import '../../widgets/module_card.dart';

/// Data model for a sub-module item.
class _SubModule {
  const _SubModule(this.label, this.icon, this.route, this.color);
  final String label;
  final IconData icon;
  final String route;
  final Color color;
}

class HrmsModuleScreen extends ConsumerStatefulWidget {
  const HrmsModuleScreen({super.key});

  static const _sections = <String, List<_SubModule>>{
    'ORGANIZATION': [
      _SubModule('Organization\nManagement', Icons.corporate_fare_outlined,
          '/organization-management', Color(0xFF6C5CE7)),
      _SubModule('Organization\nStructure', Icons.account_tree_outlined,
          '/organization-structure', Color(0xFF00CEC9)),
    ],
    'EMPLOYEE': [
      _SubModule('Employee\nManagement', Icons.badge_outlined,
          '/employee-management', Color(0xFF0984E3)),
      _SubModule(
          'Responses', Icons.rate_review_outlined, '/responses', Color(0xFFFF7675)),
    ],
    'ATTENDANCE': [
      _SubModule(
          'Attendance', Icons.calendar_month_outlined, '/attendance', Color(0xFF10B981)),
      _SubModule('Attendance\nManagement', Icons.co_present_outlined,
          '/attendance-management', Color(0xFF06B6D4)),
      _SubModule('Attendance\nSettings', Icons.tune_outlined,
          '/attendance-settings', Color(0xFF8B5CF6)),
      _SubModule(
          'My On Duty', Icons.business_center_outlined, '/on-duty', Color(0xFFF59E0B)),
      _SubModule('On Duty\nManagement', Icons.business_center,
          '/on-duty-management', Color(0xFFEF4444)),
    ],
    'TASKS & CLOCKING': [
      _SubModule(
          'My Tasks', Icons.task_alt_outlined, '/my-tasks', Color(0xFF3B82F6)),
      _SubModule('Time\nClocking', Icons.timer_outlined, '/time-clocking',
          Color(0xFFEC4899)),
      _SubModule('Tasks & Clocking\nManagement', Icons.assignment_outlined,
          '/tasks-and-timesheets', Color(0xFF14B8A6)),
    ],
    'SITE VISIT': [
      _SubModule('Site Visit\nAttendance', Icons.add_location_alt_outlined,
          '/site-visit-attendance', Color(0xFFF97316)),
      _SubModule('Site Visit\nAttendance Mgmt', Icons.pin_drop_outlined,
          '/site-visit-attendance-management', Color(0xFF6366F1)),
    ],
    'LEAVE': [
      _SubModule('Leave\nManagement', Icons.event_note, '/leave-management',
          Color(0xFFE11D48)),
    ],
    'SALARY & ASSETS': [
      _SubModule('Salary\nSettings', Icons.request_quote_outlined,
          '/salary-settings', Color(0xFF059669)),
      _SubModule('Asset\nSettings', Icons.settings_suggest_outlined,
          '/asset-settings', Color(0xFF0284C7)),
      _SubModule('Asset\nManagement', Icons.devices_other_outlined,
          '/asset-management', Color(0xFF7C3AED)),
      _SubModule(
          'My Asset', Icons.devices_outlined, '/my-asset', Color(0xFFEA580C)),
    ],
    'LOAN': [
      _SubModule(
          'Loan', Icons.account_balance_outlined, '/loan', Color(0xFF10B981)),
      _SubModule('Loan\nManagement', Icons.account_balance,
          '/loan-management', Color(0xFFD97706)),
    ],
    'EXIT & INCENTIVE': [
      _SubModule(
          'My Exit', Icons.exit_to_app_outlined, '/my-exit', Color(0xFFDC2626)),
      _SubModule('Exit\nManagement', Icons.assignment_return_outlined,
          '/exit-management', Color(0xFF9333EA)),
      _SubModule('Incentive\nRequest', Icons.request_quote_outlined,
          '/incentive', Color(0xFF16A34A)),
      _SubModule('Incentive\nManagement', Icons.price_check_outlined,
          '/incentive-management', Color(0xFF0891B2)),
    ],
    'PAYROLL': [
      _SubModule(
          'My Payslips', Icons.receipt_long_outlined, '/my-payslips', Color(0xFF2563EB)),
      _SubModule(
          'Payroll', Icons.payments_outlined, '/payroll', Color(0xFF4F46E5)),
      _SubModule('Payroll\nHistory', Icons.history_outlined, '/payroll-history',
          Color(0xFFC026D3)),
      _SubModule('Payroll\nSettings', Icons.settings_outlined,
          '/payroll-settings', Color(0xFF0D9488)),
    ],
  };

  @override
  ConsumerState<HrmsModuleScreen> createState() => _HrmsModuleScreenState();
}

class _HrmsModuleScreenState extends ConsumerState<HrmsModuleScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
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
              onProfile: () => context.go('/my-profile'),
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
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        children: [
                          // ── Clean Full-width Search Bar ──
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
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
                                  final childAspectRatio = constraints.maxWidth > 800
                                      ? 0.95
                                      : constraints.maxWidth > 500
                                          ? 0.82
                                          : 0.72;
                                  return GridView.count(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    crossAxisCount: crossAxisCount,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: childAspectRatio,
                                    children: entry.value
                                        .map((m) => SubModuleCard(
                                              label: m.label,
                                              icon: m.icon,
                                              color: m.color,
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
