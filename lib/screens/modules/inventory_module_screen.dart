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

class InventoryModuleScreen extends ConsumerWidget {
  const InventoryModuleScreen({super.key});

  static const _sections = <String, List<_SubModule>>{
    'STOCK': [
      _SubModule(
          'Items', Icons.inventory_2_outlined, '/items', Color(0xFF2196F3)),
      _SubModule('Inventory\nAdjustments', Icons.tune_outlined,
          '/inventory-adjustments', Color(0xFF00B894)),
    ],
    'SALES': [
      _SubModule(
          'Customers', Icons.people_outline, '/customers', Color(0xFF6C5CE7)),
      _SubModule(
          'Quotes', Icons.request_quote_outlined, '/quotes', Color(0xFFE17055)),
      _SubModule('Sales\nOrders', Icons.shopping_cart_outlined, '/sales-orders',
          Color(0xFF0984E3)),
      _SubModule(
          'Invoices', Icons.receipt_long_outlined, '/invoices', Color(0xFF00CEC9)),
      _SubModule('Delivery\nChallans', Icons.local_shipping_outlined,
          '/delivery-challans', Color(0xFFFDAA5D)),
      _SubModule('Payments\nReceived', Icons.payments_outlined,
          '/payments-received', Color(0xFFE84393)),
      _SubModule('Credit\nNotes', Icons.assignment_return_outlined,
          '/credit-notes', Color(0xFF636E72)),
      _SubModule('e-Way\nBills', Icons.qr_code_outlined, '/e-way-bills',
          Color(0xFF6C5CE7)),
    ],
    'PURCHASE': [
      _SubModule(
          'Vendors', Icons.storefront_outlined, '/vendors', Color(0xFF0984E3)),
      _SubModule('Expenses', Icons.account_balance_wallet_outlined, '/expenses',
          Color(0xFF00B894)),
      _SubModule('Purchase\nOrders', Icons.shopping_bag_outlined,
          '/purchase-orders', Color(0xFFE17055)),
      _SubModule(
          'Bills', Icons.receipt_outlined, '/bills', Color(0xFF636E72)),
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
            title: 'INVENTORY',
            icon: Icons.inventory_2_outlined,
            color: const Color(0xFF2196F3),
            onBack: () => context.go('/module-dashboard'),
            employeeName: employeeName,
            onProfile: () => context.go('/my-profile'),
          ),
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF2196F3),
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
                              'No Accessible Inventory Modules',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'You do not have permission to access any sub-modules in Inventory.',
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
                                color: Color(0xFF2196F3),
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
