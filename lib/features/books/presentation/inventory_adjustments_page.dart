import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../domain/books_repository.dart';
import '../providers/books_providers.dart';
import 'books_pages.dart';

class InventoryAdjustmentDashboardPage extends ConsumerStatefulWidget {
  const InventoryAdjustmentDashboardPage({super.key});

  @override
  ConsumerState<InventoryAdjustmentDashboardPage> createState() =>
      _InventoryAdjustmentDashboardPageState();
}

class _InventoryAdjustmentDashboardPageState
    extends ConsumerState<InventoryAdjustmentDashboardPage> {
  final _searchController = TextEditingController();
  String _query = '';
  _InventoryCategory? _selectedCategory;

  static const _rawMaterialItems = <BookItem>[
    BookItem(
      id: -1,
      name: 'Mild Steel Sheet',
      sku: 'RM-001',
      unit: 'kg',
      type: 'Goods',
      trackInventory: true,
      stockOnHand: 240,
    ),
    BookItem(
      id: -2,
      name: 'Aluminium Round Bar',
      sku: 'RM-002',
      unit: 'kg',
      type: 'Goods',
      trackInventory: true,
      stockOnHand: 125,
    ),
    BookItem(
      id: -3,
      name: 'Stainless Steel Coil',
      sku: 'RM-003',
      unit: 'kg',
      type: 'Goods',
      trackInventory: true,
      stockOnHand: 86,
    ),
  ];

  static const _outsourceItems = <BookItem>[
    BookItem(
      id: -11,
      name: 'Powder Coating',
      sku: 'OS-001',
      unit: 'pcs',
      type: 'Service',
      stockOnHand: 48,
    ),
    BookItem(
      id: -12,
      name: 'CNC Machining',
      sku: 'OS-002',
      unit: 'pcs',
      type: 'Service',
      stockOnHand: 32,
    ),
    BookItem(
      id: -13,
      name: 'Heat Treatment',
      sku: 'OS-003',
      unit: 'lots',
      type: 'Service',
      stockOnHand: 12,
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsState = ref.watch(itemsProvider);
    final metricsState = ref.watch(dashboardMetricsProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Preserve the pre-existing tablet and desktop presentation.
        if (constraints.maxWidth >= AppBreakpoints.tablet) {
          return const InventoryAdjustmentsPage();
        }

        return Scaffold(
          backgroundColor: AppColors.canvas,
          body: SafeArea(
            top: false,
            child: _InventoryDashboardBody(
              itemsState: itemsState,
              dashboard: _buildDashboard(
                itemsState.valueOrNull ?? const <BookItem>[],
                metricsState.valueOrNull,
              ),
              onRetry: () => ref.invalidate(itemsProvider),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDashboard(List<BookItem> allItems, DashboardMetrics? metrics) {
    final normalizedQuery = _query.trim().toLowerCase();
    final categoryItems = switch (_selectedCategory) {
      _InventoryCategory.rawMaterial => _rawMaterialItems,
      _InventoryCategory.outsource => _outsourceItems,
      null => allItems,
    };
    final visibleItems = categoryItems
        .where((item) {
          final searchable = '${item.name} ${item.sku} ${item.type}'
              .toLowerCase();
          return searchable.contains(normalizedQuery);
        })
        .toList(growable: false);
    final inventoryValue = allItems.fold<double>(
      0,
      (sum, item) => sum + (item.costPrice * item.stockOnHand),
    );
    final purchaseAmount = metrics?.payables ?? inventoryValue;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(itemsProvider);
        ref.invalidate(dashboardMetricsProvider);
        await ref.read(itemsProvider.future);
      },
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            sliver: SliverList.list(
              children: [
                const _DashboardHeading(),
                const SizedBox(height: 16),
                _SummaryGrid(
                  purchaseAmount: purchaseAmount,
                  outstanding: inventoryValue,
                  items: allItems,
                  selectedCategory: _selectedCategory,
                  onCategorySelected: (category) => setState(() {
                    _selectedCategory = category;
                    _query = '';
                    _searchController.clear();
                  }),
                ),
                const SizedBox(height: 24),
                const _SectionHeader(
                  title: 'Quick create',
                  subtitle: 'Frequently used inventory actions',
                ),
                const SizedBox(height: 12),
                _QuickActions(
                  onAddStock: () => context.push('/inventory-adjustments/add-stock'),
                  onMoveStock: () => context.push('/inventory-adjustments/move-stock'),
                  onHistory: () => _showHistory(context),
                  onAddMaterial: () => context.push('/inventory-adjustments/add-material'),
                ),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: 'Inventory',
                  subtitle: switch (_selectedCategory) {
                    _InventoryCategory.rawMaterial =>
                      '${visibleItems.length} raw materials',
                    _InventoryCategory.outsource =>
                      '${visibleItems.length} outsource parts',
                    null => '${visibleItems.length} items',
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            sliver: SliverToBoxAdapter(
              child: SizedBox(
                height: 56,
                child: _InventorySearch(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  onClear: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
              ),
            ),
          ),
          if (visibleItems.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(
                isSearching: normalizedQuery.isNotEmpty,
                onAction: normalizedQuery.isNotEmpty
                    ? () {
                        _searchController.clear();
                        setState(() => _query = '');
                      }
                    : () => context.push('/items/new'),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
              sliver: SliverList.builder(
                itemCount: visibleItems.length,
                itemBuilder: (context, index) => _AnimatedInventoryCard(
                  key: ValueKey(visibleItems[index].id),
                  item: visibleItems[index],
                  index: index,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showHistory(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .62,
          child: Consumer(
            builder: (context, sheetRef, _) => sheetRef
                .watch(adjustmentsProvider)
                .when(
                  loading: () => const _HistoryShimmer(),
                  error: (error, _) => _ErrorState(
                    onRetry: () => sheetRef.invalidate(adjustmentsProvider),
                  ),
                  data: (rows) => rows.isEmpty
                      ? const _HistoryEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: rows.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, index) => Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: AppColors.canvas,
                                child: Icon(Icons.receipt_long_outlined),
                              ),
                              title: Text(rowTitle(rows[index])),
                              subtitle: Text(
                                '${rows[index].reason} · ${DateFormat('dd/MM/yyyy').format(rows[index].date)}',
                              ),
                              trailing: Text(rows[index].status),
                            ),
                          ),
                        ),
                ),
          ),
        ),
      ),
    );
  }

  String rowTitle(InventoryAdjustment row) => row.referenceNumber;
}

enum _InventoryCategory { rawMaterial, outsource }

class _InventoryDashboardBody extends StatelessWidget {
  const _InventoryDashboardBody({
    required this.itemsState,
    required this.dashboard,
    required this.onRetry,
  });

  final AsyncValue<List<BookItem>> itemsState;
  final Widget dashboard;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (itemsState.hasError && !itemsState.hasValue) {
      return _ErrorState(onRetry: onRetry);
    }

    return Stack(
      children: [
        Positioned.fill(child: dashboard),
        if (itemsState.isLoading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              minHeight: 3,
              color: AppColors.primary,
              backgroundColor: AppColors.shimmerBase,
            ),
          ),
      ],
    );
  }
}

class _DashboardHeading extends StatelessWidget {
  const _DashboardHeading();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Inventory overview', style: AppTextStyles.pageTitle),
      SizedBox(height: 4),
      Text(
        'Monitor stock, materials and purchasing at a glance',
        style: AppTextStyles.caption,
      ),
    ],
  );
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.purchaseAmount,
    required this.outstanding,
    required this.items,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  final double purchaseAmount;
  final double outstanding;
  final List<BookItem> items;
  final _InventoryCategory? selectedCategory;
  final ValueChanged<_InventoryCategory> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final rawMaterials = items.where((item) => item.type == 'Goods').length;
    final outsource = items.where((item) => item.type == 'Service').length;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        _StatCard(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Purchase amount',
          value: _money(purchaseAmount),
          subtitle: 'Total purchasing value',
        ),
        _StatCard(
          icon: Icons.pending_actions_outlined,
          title: 'Outstanding',
          value: _money(outstanding),
          subtitle: 'Current stock value',
        ),
        _StatCard(
          icon: Icons.precision_manufacturing_outlined,
          title: 'Raw material',
          value: '$rawMaterials Items',
          subtitle: 'Production inventory',
          backgroundColor: const Color(0xFFF4EFEB),
          borderColor: const Color(0xFFD1BC97),
          selected: selectedCategory == _InventoryCategory.rawMaterial,
          onTap: () => onCategorySelected(_InventoryCategory.rawMaterial),
        ),
        _StatCard(
          icon: Icons.handyman_outlined,
          title: 'Outsource',
          value: '$outsource Items',
          subtitle: 'External services',
          backgroundColor: const Color(0xFFE8F5FF),
          borderColor: const Color(0xFFC8DAE6),
          selected: selectedCategory == _InventoryCategory.outsource,
          onTap: () => onCategorySelected(_InventoryCategory.outsource),
        ),
      ],
    );
  }

  String _money(double value) => NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  ).format(value);
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    this.backgroundColor,
    this.borderColor,
    this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: onTap != null,
    label: '$title, $value, $subtitle',
    child: Card(
      elevation: 0,
      color: backgroundColor ??
          (selected
              ? AppColors.primary.withValues(alpha: .12)
              : AppColors.active.withValues(alpha: .045)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: borderColor ??
              (selected
                  ? AppColors.primary.withValues(alpha: .8)
                  : AppColors.active.withValues(alpha: .07)),
          width: selected ? 1.25 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 17, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: AppColors.active.withValues(alpha: .07),
                      ),
                    ),
                    child: Icon(icon, size: 17, color: AppColors.active),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.55,
                        height: 1,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: AppColors.active,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      const SizedBox(width: 8),
      Text(subtitle, style: AppTextStyles.caption),
    ],
  );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onAddStock,
    required this.onMoveStock,
    required this.onHistory,
    required this.onAddMaterial,
  });

  final VoidCallback onAddStock;
  final VoidCallback onMoveStock;
  final VoidCallback onHistory;
  final VoidCallback onAddMaterial;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _QuickAction(Icons.add_box_outlined, 'Add stock', onAddStock),
      const SizedBox(width: 8),
      _QuickAction(Icons.swap_horiz_rounded, 'Move stock', onMoveStock),
      const SizedBox(width: 8),
      _QuickAction(Icons.history_rounded, 'History', onHistory),
      const SizedBox(width: 8),
      _QuickAction(Icons.inventory_2_outlined, 'Material', onAddMaterial),
    ],
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      button: true,
      label: label,
      child: Card(
        elevation: 1,
        shadowColor: AppColors.active.withValues(alpha: .10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 76),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 24, color: AppColors.active),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _InventorySearch extends StatelessWidget {
  const _InventorySearch({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Semantics(
    textField: true,
    label: 'Search inventory',
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search items, SKU or category',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                tooltip: 'Clear search',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              )
            : const Icon(Icons.tune_rounded),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
      ),
    ),
  );
}

class _AnimatedInventoryCard extends StatefulWidget {
  const _AnimatedInventoryCard({
    required this.item,
    required this.index,
    super.key,
  });
  final BookItem item;
  final int index;

  @override
  State<_AnimatedInventoryCard> createState() => _AnimatedInventoryCardState();
}

class _AnimatedInventoryCardState extends State<_AnimatedInventoryCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    duration: Duration(milliseconds: 220 + (widget.index.clamp(0, 5) * 35)),
    curve: Curves.easeOutCubic,
    tween: Tween(begin: 0, end: 1),
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 10 * (1 - value)),
        child: child,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? .985 : 1,
        child: Semantics(
          button: true,
          label:
              '${widget.item.name}, ${widget.item.type}, ${widget.item.stockOnHand.toStringAsFixed(0)} ${widget.item.unit}',
          child: Card(
            elevation: _pressed ? 0 : 1.5,
            shadowColor: AppColors.active.withValues(alpha: .11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {},
              onLongPress: () {},
              onHighlightChanged: (value) => setState(() => _pressed = value),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Hero(
                      tag: 'inventory-item-${widget.item.id}',
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          widget.item.type == 'Service'
                              ? Icons.handyman_outlined
                              : Icons.precision_manufacturing_outlined,
                          color: AppColors.active,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.item.sku.isEmpty
                                ? 'SKU not assigned'
                                : widget.item.sku,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption,
                          ),
                          const SizedBox(height: 6),
                          _CategoryChip(label: widget.item.type),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          widget.item.stockOnHand.toStringAsFixed(0),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(widget.item.unit, style: AppTextStyles.caption),
                      ],
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 22),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.active.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label, style: AppTextStyles.caption),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isSearching, required this.onAction});
  final bool isSearching;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 104),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSearching
                  ? Icons.search_off_rounded
                  : Icons.inventory_2_outlined,
              size: 42,
              color: AppColors.active,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isSearching ? 'No matching items' : 'Your inventory is empty',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            isSearching
                ? 'Try another item name, SKU or category.'
                : 'Add your first material to start tracking stock.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAction,
            icon: Icon(isSearching ? Icons.close : Icons.add),
            label: Text(isSearching ? 'Clear search' : 'Add Item'),
          ),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48),
          const SizedBox(height: 16),
          Text(
            'Unable to load inventory',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Check your connection and try again.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.history_rounded, size: 48),
        SizedBox(height: 12),
        Text('No adjustment history'),
      ],
    ),
  );
}

class _HistoryShimmer extends StatelessWidget {
  const _HistoryShimmer();

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.all(16),
    itemCount: 5,
    separatorBuilder: (_, _) => const SizedBox(height: 8),
    itemBuilder: (_, _) => const _ShimmerBlock(height: 72),
  );
}

class _ShimmerBlock extends StatefulWidget {
  const _ShimmerBlock({required this.height});
  final double height;

  @override
  State<_ShimmerBlock> createState() => _ShimmerBlockState();
}

class _ShimmerBlockState extends State<_ShimmerBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Opacity(
      opacity:
          .48 +
          (_controller.value < .5 ? _controller.value : 1 - _controller.value) *
              .62,
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.active.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
  );
}
