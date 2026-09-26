import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../features/employee/providers/employee_providers.dart';
import '../../widgets/app_background_wrapper.dart';
import '../../widgets/module_card.dart';

class _SubModule {
  const _SubModule(this.label, this.icon, this.route, this.color);
  final String label;
  final IconData icon;
  final String route;
  final Color color;
}

class AccountsModuleScreen extends ConsumerStatefulWidget {
  const AccountsModuleScreen({super.key});

  static const _sections = <String, List<_SubModule>>{
    'RECEIVABLES': [
      _SubModule(
          'Invoices', Icons.receipt_long_outlined, '/invoices', Color(0xFF06B6D4)),
      _SubModule('Payments\nReceived', Icons.payments_outlined,
          '/payments-received', Color(0xFFEC4899)),
      _SubModule('Credit\nNotes', Icons.assignment_return_outlined,
          '/credit-notes', Color(0xFF8B5CF6)),
      _SubModule(
          'Customers', Icons.people_outline, '/customers', Color(0xFF2563EB)),
    ],
    'PAYABLES': [
      _SubModule(
          'Expenses', Icons.account_balance_wallet_outlined, '/expenses',
          Color(0xFFEF4444)),
      _SubModule(
          'Bills', Icons.receipt_outlined, '/bills', Color(0xFF4F46E5)),
      _SubModule(
          'Vendors', Icons.storefront_outlined, '/vendors', Color(0xFF0D9488)),
      _SubModule('Purchase\nOrders', Icons.shopping_bag_outlined,
          '/purchase-orders', Color(0xFFF59E0B)),
    ],
  };

  @override
  ConsumerState<AccountsModuleScreen> createState() => _AccountsModuleScreenState();
}

class _AccountsModuleScreenState extends ConsumerState<AccountsModuleScreen> {
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

  static IconData _getSectionIcon(String sectionName) {
    switch (sectionName) {
      case 'RECEIVABLES':
        return Icons.call_received_rounded;
      case 'PAYABLES':
        return Icons.call_made_rounded;
      default:
        return Icons.folder_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final employee = ref.watch(currentEmployeeProvider);
    final isSuper = employee == null || employee.isSuperAdmin;
    final permittedSections = <String, List<_SubModule>>{};

    for (final entry in AccountsModuleScreen._sections.entries) {
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

    final employeeName = employee?.firstName ?? '';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        if (isDesktop) {
          return _buildDesktopLayout(
            context,
            employee: employee,
            employeeName: employeeName,
            isSuper: isSuper,
            permittedSections: permittedSections,
            filteredSections: filteredSections,
            constraints: constraints,
          );
        }

        return _buildMobileLayout(
          context,
          employee: employee,
          employeeName: employeeName,
          permittedSections: permittedSections,
          filteredSections: filteredSections,
        );
      },
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context, {
    required dynamic employee,
    required String employeeName,
    required bool isSuper,
    required Map<String, List<_SubModule>> permittedSections,
    required Map<String, List<_SubModule>> filteredSections,
    required BoxConstraints constraints,
  }) {
    final horizontalPadding = constraints.maxWidth > 1200 ? 32.0 : 20.0;
    final gridColumns = constraints.maxWidth >= 1180
        ? 4
        : constraints.maxWidth >= 860
            ? 3
            : 2;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackgroundWrapper(
        child: Column(
          children: [
            DesktopModuleScreenHeader(
              title: 'ACCOUNTS',
              icon: Icons.account_balance_outlined,
              color: const Color(0xFFFF9800),
              onBack: () => context.go('/module-dashboard'),
              employeeName: employeeName,
              photoUrl: employee?.profileImageUrl,
              isSuperAdmin: isSuper,
              onProfile: () => context.go('/my-profile'),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search modules...',
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFFFF9800),
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
                  fillColor: Colors.white.withOpacity(0.95),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E8E2), width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E8E2), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFF9800), width: 1.5),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: false,
                child: ListView(
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(horizontalPadding, 4, horizontalPadding, 32),
                  children: [
                    if (permittedSections.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(48),
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
                    else if (filteredSections.isEmpty && _searchQuery.isNotEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFFF9800).withOpacity(0.1),
                                ),
                                child: const Icon(
                                  Icons.search_off_rounded,
                                  size: 40,
                                  color: Color(0xFFFF9800),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No modules found for "$_searchQuery"',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Try searching with a different keyword like "Invoices", "Bills", or "Vendors".',
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
                                  foregroundColor: const Color(0xFFFF9800),
                                  side: const BorderSide(color: Color(0xFFFF9800)),
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
                        DesktopSectionHeader(
                          title: entry.key,
                          icon: _getSectionIcon(entry.key),
                          color: const Color(0xFFFF9800),
                          count: entry.value.length,
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: gridColumns,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            mainAxisExtent: 80,
                          ),
                          itemCount: entry.value.length,
                          itemBuilder: (context, index) {
                            final m = entry.value[index];
                            return DesktopSubModuleCard(
                              label: m.label,
                              icon: m.icon,
                              color: m.color,
                              onTap: () => context.go(m.route),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
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

  Widget _buildMobileLayout(
    BuildContext context, {
    required dynamic employee,
    required String employeeName,
    required Map<String, List<_SubModule>> permittedSections,
    required Map<String, List<_SubModule>> filteredSections,
  }) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackgroundWrapper(
        child: Column(
          children: [
            ModuleScreenHeader(
              title: 'ACCOUNTS',
              icon: Icons.account_balance_outlined,
              color: const Color(0xFFFF9800),
              onBack: () => context.go('/module-dashboard'),
              employeeName: employeeName,
              photoUrl: employee?.profileImageUrl,
              onProfile: () => context.go('/my-profile'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search icons (e.g. Invoices, Bills, Expenses...)',
                  hintStyle: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFFFF9800),
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
                  fillColor: Colors.white.withOpacity(0.95),
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
                    borderSide: const BorderSide(color: Color(0xFFFF9800), width: 1.5),
                  ),
                ),
              ),
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
                        key: const PageStorageKey<String>('accounts_module_scroll_list'),
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
                                        color: const Color(0xFFFF9800).withOpacity(0.1),
                                      ),
                                      child: const Icon(
                                        Icons.search_off_rounded,
                                        size: 40,
                                        color: Color(0xFFFF9800),
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
                                      'Try searching with a different keyword like "Invoices", "Expenses", or "Vendors".',
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
                                        foregroundColor: const Color(0xFFFF9800),
                                        side: const BorderSide(color: Color(0xFFFF9800)),
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
