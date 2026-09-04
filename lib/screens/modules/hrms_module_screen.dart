import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../features/employee/providers/employee_providers.dart';
import '../../widgets/module_card.dart';

/// Data model for a sub-module item.
class _SubModule {
  const _SubModule(this.label, this.icon, this.route, this.color);
  final String label;
  final IconData icon;
  final String route;
  final Color color;
}

class HrmsModuleScreen extends ConsumerWidget {
  const HrmsModuleScreen({super.key});

  static const _sections = <String, List<_SubModule>>{
    'ORGANIZATION': [
      _SubModule('Organization\nManagement', Icons.corporate_fare_outlined,
          '/organization-management', Color(0xFF6C5CE7)),
      _SubModule('Organization\nStructure', Icons.account_tree_outlined,
          '/organization-structure', Color(0xFF00B894)),
    ],
    'EMPLOYEE': [
      _SubModule('Employee\nManagement', Icons.badge_outlined,
          '/employee-management', Color(0xFF0984E3)),
      _SubModule(
          'Responses', Icons.rate_review_outlined, '/responses', Color(0xFFE17055)),
    ],
    'ATTENDANCE': [
      _SubModule(
          'Attendance', Icons.calendar_month_outlined, '/attendance', Color(0xFF9CC70A)),
      _SubModule('Attendance\nManagement', Icons.co_present_outlined,
          '/attendance-management', Color(0xFF00CEC9)),
      _SubModule('Attendance\nSettings', Icons.tune_outlined,
          '/attendance-settings', Color(0xFF636E72)),
      _SubModule(
          'On-Duty', Icons.business_center_outlined, '/on-duty', Color(0xFFFDAA5D)),
      _SubModule('On-Duty\nManagement', Icons.business_center,
          '/on-duty-management', Color(0xFFE84393)),
    ],
    'TASKS & CLOCKING': [
      _SubModule(
          'My Tasks', Icons.task_alt_outlined, '/my-tasks', Color(0xFF6C5CE7)),
      _SubModule('Time\nClocking', Icons.timer_outlined, '/time-clocking',
          Color(0xFF0984E3)),
      _SubModule('Tasks & Clocking\nManagement', Icons.assignment_outlined,
          '/tasks-and-timesheets', Color(0xFF00B894)),
    ],
    'SITE VISIT': [
      _SubModule('Site Visit\nAttendance', Icons.add_location_alt_outlined,
          '/site-visit-attendance', Color(0xFFE17055)),
      _SubModule('Site Visit\nAttendance Mgmt', Icons.pin_drop_outlined,
          '/site-visit-attendance-management', Color(0xFF636E72)),
    ],
    'LEAVE & PERMISSION': [
      _SubModule('Leave\nManagement', Icons.event_note, '/leave-management',
          Color(0xFF00CEC9)),
      _SubModule(
          'Permission', Icons.access_time_filled_outlined, '/permission', Color(0xFFFDAA5D)),
      _SubModule('Permission\nManagement', Icons.more_time_outlined,
          '/permission-management', Color(0xFFE84393)),
    ],
    'SALARY & ASSETS': [
      _SubModule('Salary\nSettings', Icons.request_quote_outlined,
          '/salary-settings', Color(0xFF6C5CE7)),
      _SubModule('Asset\nSettings', Icons.settings_suggest_outlined,
          '/asset-settings', Color(0xFF0984E3)),
      _SubModule('Asset\nManagement', Icons.devices_other_outlined,
          '/asset-management', Color(0xFF00B894)),
      _SubModule(
          'My Asset', Icons.devices_outlined, '/my-asset', Color(0xFFE17055)),
    ],
    'LOAN': [
      _SubModule(
          'Loan', Icons.account_balance_outlined, '/loan', Color(0xFF636E72)),
      _SubModule('Loan\nManagement', Icons.account_balance,
          '/loan-management', Color(0xFFFDAA5D)),
    ],
    'EXIT & INCENTIVE': [
      _SubModule(
          'My Exit', Icons.exit_to_app_outlined, '/my-exit', Color(0xFFE84393)),
      _SubModule('Exit\nManagement', Icons.assignment_return_outlined,
          '/exit-management', Color(0xFF00CEC9)),
      _SubModule('Incentive\nRequest', Icons.request_quote_outlined,
          '/incentive', Color(0xFF6C5CE7)),
      _SubModule('Incentive\nManagement', Icons.price_check_outlined,
          '/incentive-management', Color(0xFF0984E3)),
    ],
    'PAYROLL': [
      _SubModule(
          'My Payslips', Icons.receipt_long_outlined, '/my-payslips', Color(0xFF00B894)),
      _SubModule(
          'Payroll', Icons.payments_outlined, '/payroll', Color(0xFFE17055)),
      _SubModule('Payroll\nHistory', Icons.history_outlined, '/payroll-history',
          Color(0xFF636E72)),
      _SubModule('Payroll\nSettings', Icons.settings_outlined,
          '/payroll-settings', Color(0xFFFDAA5D)),
    ],
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employee = ref.watch(currentEmployeeProvider);
    final employeeName = employee?.firstName ?? '';

    final isSuper = employee == null || employee.isSuperAdmin;
    final permittedSections = <String, List<_SubModule>>{};

    for (final entry in _sections.entries) {
      final allowedItems = entry.value.where((m) {
        if (isSuper) return true;
        final cleanLabel = m.label.replaceAll('\n', ' ');
        return employee.hasPermission(cleanLabel);
      }).toList();

      if (allowedItems.isNotEmpty) {
        permittedSections[entry.key] = allowedItems;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F3),
      body: Column(
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
                        for (final entry in permittedSections.entries) ...[
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
                              return GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: crossAxisCount,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.85,
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
    );

  }
}
