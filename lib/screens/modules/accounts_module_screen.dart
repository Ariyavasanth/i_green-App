import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../features/employee/providers/employee_providers.dart';
import '../../widgets/module_card.dart';

class _SubModule {
  const _SubModule(this.label, this.icon, this.route, this.color);
  final String label;
  final IconData icon;
  final String route;
  final Color color;
}

class AccountsModuleScreen extends ConsumerWidget {
  const AccountsModuleScreen({super.key});

  static const _sections = <String, List<_SubModule>>{
    'RECEIVABLES': [
      _SubModule(
          'Invoices', Icons.receipt_long_outlined, '/invoices', Color(0xFFFF9800)),
      _SubModule('Payments\nReceived', Icons.payments_outlined,
          '/payments-received', Color(0xFF00B894)),
      _SubModule('Credit\nNotes', Icons.assignment_return_outlined,
          '/credit-notes', Color(0xFF6C5CE7)),
      _SubModule(
          'Customers', Icons.people_outline, '/customers', Color(0xFF0984E3)),
    ],
    'PAYABLES': [
      _SubModule(
          'Expenses', Icons.account_balance_wallet_outlined, '/expenses',
          Color(0xFFE17055)),
      _SubModule(
          'Bills', Icons.receipt_outlined, '/bills', Color(0xFF636E72)),
      _SubModule(
          'Vendors', Icons.storefront_outlined, '/vendors', Color(0xFFFDAA5D)),
      _SubModule('Purchase\nOrders', Icons.shopping_bag_outlined,
          '/purchase-orders', Color(0xFFE84393)),
    ],
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employee = ref.watch(currentEmployeeProvider);
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

    final employeeName = employee?.firstName ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F3),
      body: Column(
        children: [
          ModuleScreenHeader(
            title: 'ACCOUNTS',
            icon: Icons.account_balance_outlined,
            color: const Color(0xFFFF9800),
            onBack: () => context.go('/module-dashboard'),
            employeeName: employeeName,
            onProfile: () => context.go('/my-profile'),
          ),
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFFFF9800),
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
                              'No Accessible Accounts Modules',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'You do not have permission to access any sub-modules in Accounts.',
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
                                color: Color(0xFFFF9800),
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
