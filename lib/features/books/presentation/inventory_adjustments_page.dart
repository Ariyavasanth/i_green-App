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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsState = ref.watch(itemsProvider);
    final materialsState = ref.watch(materialsProvider(null));
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
              materialsState: materialsState,
              dashboard: _buildDashboard(
                itemsState.valueOrNull ?? const <BookItem>[],
                materialsState.valueOrNull ?? const <MaterialItem>[],
                metricsState.valueOrNull,
              ),
              onRetry: () {
                ref.invalidate(itemsProvider);
                ref.invalidate(materialsProvider(null));
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildDashboard(
    List<BookItem> allItems,
    List<MaterialItem> allMaterials,
    DashboardMetrics? metrics,
  ) {
    final normalizedQuery = _query.trim().toLowerCase();

    final filteredMaterials = allMaterials.where((m) {
      if (_selectedCategory == _InventoryCategory.rawMaterial && !m.isRawMaterial) {
        return false;
      }
      if (_selectedCategory == _InventoryCategory.outsource && !m.isOutsource) {
        return false;
      }
      if (normalizedQuery.isEmpty) return true;
      final searchable = '${m.description} ${m.code} ${m.grade} ${m.supplier}'.toLowerCase();
      return searchable.contains(normalizedQuery);
    }).toList();

    final totalCount = filteredMaterials.length;

    final inventoryValue = allItems.fold<double>(
      0,
      (sum, item) => sum + (item.costPrice * item.stockOnHand),
    );
    final purchaseAmount = metrics?.payables ?? inventoryValue;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(itemsProvider);
        ref.invalidate(materialsProvider(null));
        ref.invalidate(materialsProvider('RAW'));
        ref.invalidate(materialsProvider('OUTSOURCE'));
        ref.invalidate(dashboardMetricsProvider);
        ref.invalidate(adjustmentsProvider);
        ref.invalidate(materialRequestsProvider);
        await Future.wait([
          ref.read(itemsProvider.future),
          ref.read(materialsProvider(null).future),
        ]);
      },
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            sliver: SliverList.list(
              children: [
                _SummaryGrid(
                  purchaseAmount: purchaseAmount,
                  outstanding: inventoryValue,
                  materials: allMaterials,
                  selectedCategory: _selectedCategory,
                  onCategorySelected: (category) => setState(() {
                    _selectedCategory = _selectedCategory == category ? null : category;
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
                  onRequestMaterial: () => context.push('/inventory-adjustments/requests'),
                ),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: 'Inventory',
                  subtitle: switch (_selectedCategory) {
                    _InventoryCategory.rawMaterial =>
                      '$totalCount raw materials',
                    _InventoryCategory.outsource =>
                      '$totalCount outsource parts',
                    null => '$totalCount items',
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
          if (totalCount == 0)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(
                isSearching: normalizedQuery.isNotEmpty,
                onAction: normalizedQuery.isNotEmpty
                    ? () {
                        _searchController.clear();
                        setState(() => _query = '');
                      }
                    : () => context.push('/inventory-adjustments/add-material'),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final mat = filteredMaterials[index];
                    return _AnimatedMaterialCard(
                      key: ValueKey('mat-${mat.id}'),
                      material: mat,
                      index: index,
                    );
                  },
                  childCount: totalCount,
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
          height: MediaQuery.sizeOf(context).height * .65,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent History',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.push('/inventory-adjustments/history');
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('View All'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
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
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: .12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        rows[index].status,
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                ),
              ),
            ],
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
    required this.materialsState,
    required this.dashboard,
    required this.onRetry,
    this.itemsState = const AsyncValue.data(<BookItem>[]),
  });

  final AsyncValue<List<MaterialItem>> materialsState;
  final AsyncValue<List<BookItem>> itemsState;
  final Widget dashboard;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (materialsState.hasError && !materialsState.hasValue) {
      return _ErrorState(onRetry: onRetry);
    }

    return Stack(
      children: [
        Positioned.fill(child: dashboard),
        if (materialsState.isLoading)
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

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.purchaseAmount,
    required this.outstanding,
    required this.materials,
    required this.selectedCategory,
    required this.onCategorySelected,
    this.items = const <BookItem>[],
  });

  final double purchaseAmount;
  final double outstanding;
  final List<MaterialItem> materials;
  final List<BookItem> items;
  final _InventoryCategory? selectedCategory;
  final ValueChanged<_InventoryCategory> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final rawCount = materials.where((m) => m.isRawMaterial).length;
    final outsourceCount = materials.where((m) => m.isOutsource).length;
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
          value: '$rawCount Items',
          subtitle: 'Production inventory',
          backgroundColor: const Color(0xFFF4EFEB),
          borderColor: const Color(0xFFD1BC97),
          selected: selectedCategory == _InventoryCategory.rawMaterial,
          onTap: () => onCategorySelected(_InventoryCategory.rawMaterial),
        ),
        _StatCard(
          icon: Icons.handyman_outlined,
          title: 'Outsource',
          value: '$outsourceCount Items',
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
    required this.onRequestMaterial,
  });

  final VoidCallback onAddStock;
  final VoidCallback onMoveStock;
  final VoidCallback onHistory;
  final VoidCallback onAddMaterial;
  final VoidCallback onRequestMaterial;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: _QuickAction(Icons.add_box_outlined, 'Add stock', onAddStock),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 90,
              child: _QuickAction(Icons.swap_horiz_rounded, 'Move stock', onMoveStock),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 90,
              child: _QuickAction(Icons.history_rounded, 'History', onHistory),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 90,
              child: _QuickAction(Icons.inventory_2_outlined, 'Material', onAddMaterial),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 90,
              child: _QuickAction(Icons.assignment_outlined, 'Requests', onRequestMaterial),
            ),
          ],
        ),
      );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
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

class _AnimatedMaterialCard extends ConsumerStatefulWidget {
  const _AnimatedMaterialCard({
    required this.material,
    required this.index,
    super.key,
  });
  final MaterialItem material;
  final int index;

  @override
  ConsumerState<_AnimatedMaterialCard> createState() => _AnimatedMaterialCardState();
}

class _AnimatedMaterialCardState extends ConsumerState<_AnimatedMaterialCard> {
  bool _pressed = false;

  Future<void> _deleteMaterial() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Material'),
        content: Text(
          'Are you sure you want to delete "${widget.material.description}" (${widget.material.code})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(booksRepositoryProvider).deleteMaterial(widget.material.id);
      ref.invalidate(materialsProvider(null));
      ref.invalidate(materialsProvider('RAW'));
      ref.invalidate(materialsProvider('OUTSOURCE'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.material.description} deleted successfully'),
          ),
        );
      }
    }
  }

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
          label: '${widget.material.description}, ${widget.material.code}',
          child: Card(
            elevation: _pressed ? 0 : 1.5,
            shadowColor: AppColors.active.withValues(alpha: .11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                context.push(
                  '/inventory-adjustments/add-material',
                  extra: {
                    'material': widget.material,
                    'readOnly': true,
                  },
                );
              },
              onHighlightChanged: (value) => setState(() => _pressed = value),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        widget.material.isOutsource
                            ? Icons.handyman_outlined
                            : Icons.precision_manufacturing_outlined,
                        color: AppColors.active,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.material.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.material.code.isEmpty
                                ? 'Code not assigned'
                                : widget.material.supplier.isNotEmpty
                                    ? '${widget.material.code} · ${widget.material.supplier}'
                                    : widget.material.code,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption,
                          ),
                          const SizedBox(height: 6),
                          _CategoryChip(
                            label: widget.material.displayType,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          widget.material.stockOnHand.toStringAsFixed(0),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          widget.material.unit.isNotEmpty ? widget.material.unit : 'pcs',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 20),
                      padding: EdgeInsets.zero,
                      onSelected: (val) {
                        if (val == 'view') {
                          context.push(
                            '/inventory-adjustments/add-material',
                            extra: {
                              'material': widget.material,
                              'readOnly': true,
                            },
                          );
                        } else if (val == 'delete') {
                          _deleteMaterial();
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'view',
                          child: Row(
                            children: [
                              Icon(Icons.visibility_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('View Details'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 18, color: Theme.of(ctx).colorScheme.error),
                              const SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                            ],
                          ),
                        ),
                      ],
                    ),
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

class FullInventoryHistoryPage extends ConsumerStatefulWidget {
  const FullInventoryHistoryPage({super.key});

  @override
  ConsumerState<FullInventoryHistoryPage> createState() =>
      _FullInventoryHistoryPageState();
}

class _FullInventoryHistoryPageState
    extends ConsumerState<FullInventoryHistoryPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adjustmentsState = ref.watch(adjustmentsProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: adjustmentsState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Failed to load history'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(adjustmentsProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (allRows) {
                  final queryNorm = _query.trim().toLowerCase();
                  final rows = allRows.where((r) {
                    if (queryNorm.isEmpty) return true;
                    final text =
                        '${r.referenceNumber} ${r.reason} ${r.type} ${r.status} ${r.description}'
                            .toLowerCase();
                    return text.contains(queryNorm);
                  }).toList();

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _query = val),
                          decoration: InputDecoration(
                            hintText: 'Search history by reference, reason, type...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _query.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _query = '');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () async {
                            ref.invalidate(adjustmentsProvider);
                            await ref.read(adjustmentsProvider.future);
                          },
                          child: rows.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.history_toggle_off_rounded,
                                          size: 64, color: AppColors.textSecondary),
                                      const SizedBox(height: 12),
                                      Text(
                                        _query.isNotEmpty
                                            ? 'No matching history entries'
                                            : 'No history entries found',
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                  itemCount: rows.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final item = rows[index];
                                    return Card(
                                      elevation: 1,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.all(8),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.primary
                                                            .withValues(alpha: .12),
                                                        borderRadius:
                                                            BorderRadius.circular(10),
                                                      ),
                                                      child: const Icon(
                                                          Icons.receipt_long_outlined,
                                                          size: 20,
                                                          color: AppColors.active),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      item.referenceNumber,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleMedium
                                                          ?.copyWith(
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 10, vertical: 5),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary
                                                        .withValues(alpha: .12),
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    item.status,
                                                    style: TextStyle(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .primary,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              item.reason,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                            if (item.description.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                item.description,
                                                style: AppTextStyles.caption.copyWith(
                                                    color: AppColors.textSecondary),
                                              ),
                                            ],
                                            const SizedBox(height: 10),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceBetween,
                                              children: [
                                                Chip(
                                                  label: Text(item.type,
                                                      style: const TextStyle(fontSize: 11)),
                                                  visualDensity: VisualDensity.compact,
                                                  padding: EdgeInsets.zero,
                                                ),
                                                Text(
                                                  DateFormat('dd/MM/yyyy · hh:mm a')
                                                      .format(item.date),
                                                  style: AppTextStyles.caption.copyWith(
                                                      color: AppColors.textSecondary),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class MaterialRequestsPage extends ConsumerStatefulWidget {
  const MaterialRequestsPage({super.key});

  @override
  ConsumerState<MaterialRequestsPage> createState() => _MaterialRequestsPageState();
}

class _MaterialRequestsPageState extends ConsumerState<MaterialRequestsPage> {
  int? _processingId;

  String _getMaterialClassification(String materialName, List<MaterialItem> allMaterials) {
    final nameLower = materialName.trim().toLowerCase();
    for (final m in allMaterials) {
      final d = m.description.trim().toLowerCase();
      final c = m.code.trim().toLowerCase();
      if (d == nameLower ||
          c == nameLower ||
          nameLower.contains(d) ||
          (d.isNotEmpty && nameLower.startsWith(d))) {
        return m.displayType;
      }
    }
    if (nameLower.contains('outsource') || nameLower.contains('cnc') || nameLower.contains('service')) {
      return 'Outsource';
    }
    return 'Raw Material';
  }

  double _getMaterialStock(String materialName, List<MaterialItem> allMaterials) {
    final nameLower = materialName.trim().toLowerCase();
    for (final m in allMaterials) {
      final d = m.description.trim().toLowerCase();
      final c = m.code.trim().toLowerCase();
      if (d == nameLower ||
          c == nameLower ||
          nameLower.contains(d) ||
          (d.isNotEmpty && nameLower.startsWith(d))) {
        return m.stockOnHand;
      }
    }
    return 0.0;
  }

  void _showDetailsModal(MaterialRequest req, List<MaterialItem> allMaterials) {
    final category = _getMaterialClassification(req.material, allMaterials);
    final isOutsource = category == 'Outsource';
    final currentStock = _getMaterialStock(req.material, allMaterials);
    final isPending = req.status.toLowerCase() == 'pending';
    final isApproved = req.status.toLowerCase() == 'approved';
    final isRejected = req.status.toLowerCase() == 'rejected';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Material Request Details',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isApproved
                          ? Colors.green.withValues(alpha: .12)
                          : isRejected
                              ? Colors.red.withValues(alpha: .12)
                              : Colors.amber.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      req.status,
                      style: TextStyle(
                        color: isApproved
                            ? Colors.green[800]
                            : isRejected
                                ? Colors.red[800]
                                : Colors.amber[900],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _detailRow('Work Order', req.workOrder),
              _detailRow('Date', DateFormat('dd MMM yyyy').format(req.date)),
              _detailRow('Material', req.material),
              _detailRow(
                'Type',
                category,
                valueWidget: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isOutsource
                        ? const Color(0xFFE8F5FF)
                        : const Color(0xFFEFF5D8),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isOutsource
                          ? const Color(0xFFB8DCFE)
                          : const Color(0xFFDCEB9F),
                    ),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isOutsource ? const Color(0xFF0066CC) : AppColors.active,
                    ),
                  ),
                ),
              ),
              _detailRow(
                'Current Stock',
                '${currentStock.toStringAsFixed(0)} pcs',
                valueColor: currentStock > 0 ? Colors.green[700] : Colors.red[700],
              ),
              _detailRow('Machine', req.machine),
              _detailRow('Operator', req.operatorName),
              _detailRow('Quantity Requested', '${req.quantityIssued.toStringAsFixed(0)} pcs'),
              _detailRow('Weight Requested', '${req.weightIssued.toStringAsFixed(1)} kg'),
              if (isPending) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _handleReject(req);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red[700],
                          side: BorderSide(color: Colors.red[300]!),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Reject Request'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _handleApprove(req, allMaterials);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Approve Request', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {Widget? valueWidget, Color? valueColor}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(width: 16),
            valueWidget ??
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: valueColor ?? AppColors.textPrimary,
                    ),
                  ),
                ),
          ],
        ),
      );

  Future<void> _handleApprove(MaterialRequest req, List<MaterialItem> allMaterials) async {
    final currentStock = _getMaterialStock(req.material, allMaterials);

    if (currentStock <= 0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          icon: const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
          title: const Text('No Stock Available', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                req.material,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Current stock: 0 pcs',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text('Please add stock before approving this request.'),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (currentStock < req.quantityIssued) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          icon: const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
          title: const Text('Insufficient Stock', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                req.material,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Insufficient stock. Only ${currentStock.toStringAsFixed(0)} pcs are available, but ${req.quantityIssued.toStringAsFixed(0)} pcs were requested.',
                style: const TextStyle(height: 1.4),
              ),
              const SizedBox(height: 8),
              Text(
                'Available stock: ${currentStock.toStringAsFixed(0)} pcs',
                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final remainingStock = currentStock - req.quantityIssued;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.verified_outlined, color: AppColors.active, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Approve Request',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              req.material,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'WO: ${req.workOrder} · ${req.operatorName}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAEE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDCEB9F)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Current Stock:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      Text('${currentStock.toStringAsFixed(0)} pcs', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Requested / Deduct:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      Text('- ${req.quantityIssued.toStringAsFixed(0)} pcs', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Remaining Stock:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(
                        '${remainingStock.toStringAsFixed(0)} pcs',
                        style: const TextStyle(
                          color: Color(0xFF4A7300),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm Approval', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      if (_processingId != null) return;
      setState(() => _processingId = req.id);

      try {
        await ref.read(booksRepositoryProvider).approveMaterialRequest(req.id);
        ref.invalidate(materialRequestsProvider);
        ref.invalidate(materialsProvider(null));
        ref.invalidate(materialsProvider('RAW'));
        ref.invalidate(materialsProvider('OUTSOURCE'));
        ref.invalidate(adjustmentsProvider);
        ref.invalidate(itemsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Request for ${req.material} approved. Stock updated to ${remainingStock.toStringAsFixed(0)} pcs.'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error approving request: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _processingId = null);
      }
    }
  }

  Future<void> _handleReject(MaterialRequest req) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Reject Material Request'),
        content: Text(
          'Are you sure you want to reject this request for "${req.material}" (WO: ${req.workOrder})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _processingId = req.id);
      try {
        await ref.read(booksRepositoryProvider).rejectMaterialRequest(req.id);
        ref.invalidate(materialRequestsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Request for ${req.material} marked as Rejected.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error rejecting request: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _processingId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestsState = ref.watch(materialRequestsProvider);
    final materialsState = ref.watch(materialsProvider(null));
    final allMaterials = materialsState.valueOrNull ?? <MaterialItem>[];

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: requestsState.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (error, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Failed to load material requests'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => ref.invalidate(materialRequestsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (requests) => RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(materialRequestsProvider);
              ref.invalidate(materialsProvider(null));
              await Future.wait([
                ref.read(materialRequestsProvider.future),
                ref.read(materialsProvider(null).future),
              ]);
            },
            child: requests.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.assignment_late_outlined,
                              size: 64, color: AppColors.textSecondary),
                          const SizedBox(height: 16),
                          Text(
                            'No Material Requests Created Yet',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Create a new request to issue materials to machines and operators.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () =>
                                context.push('/inventory-adjustments/request-material'),
                            icon: const Icon(Icons.add),
                            label: const Text('Create Material Request'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    itemCount: requests.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final req = requests[index];
                      final isPending = req.status.toLowerCase() == 'pending';
                      final isApproved = req.status.toLowerCase() == 'approved';
                      final isCurrentProcessing = _processingId == req.id;
                      final category = _getMaterialClassification(req.material, allMaterials);
                      final isOutsource = category == 'Outsource';

                      return Card(
                        elevation: 1.5,
                        shadowColor: AppColors.active.withValues(alpha: .08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isApproved
                                ? AppColors.primary.withValues(alpha: .5)
                                : AppColors.active.withValues(alpha: .06),
                            width: 1,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _showDetailsModal(req, allMaterials),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF5D8),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(
                                            Icons.assignment_outlined,
                                            color: AppColors.active,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'WO: ${req.workOrder}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          DateFormat('dd MMM yyyy').format(req.date),
                                          style: AppTextStyles.caption
                                              .copyWith(color: AppColors.textSecondary),
                                        ),
                                        const SizedBox(width: 6),
                                        IconButton(
                                          icon: const Icon(Icons.visibility_outlined, size: 20, color: AppColors.active),
                                          tooltip: 'View Details',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                          onPressed: () => _showDetailsModal(req, allMaterials),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        req.material,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isOutsource
                                            ? const Color(0xFFE8F5FF)
                                            : const Color(0xFFEFF5D8),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isOutsource
                                              ? const Color(0xFFB8DCFE)
                                              : const Color(0xFFDCEB9F),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isOutsource
                                                ? Icons.handyman_outlined
                                                : Icons.precision_manufacturing_outlined,
                                            size: 13,
                                            color: isOutsource
                                                ? const Color(0xFF0066CC)
                                                : AppColors.active,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            category,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isOutsource
                                                  ? const Color(0xFF0066CC)
                                                  : AppColors.active,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.precision_manufacturing_outlined,
                                            size: 16,
                                            color: AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Machine: ${req.machine}',
                                              style: AppTextStyles.caption,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.person_outline_rounded,
                                            size: 16,
                                            color: AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Operator: ${req.operatorName}',
                                              style: AppTextStyles.caption,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF7FAEE),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFDCEB9F)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.tag_rounded,
                                              size: 15, color: Color(0xFF7FA800)),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Qty: ${req.quantityIssued.toStringAsFixed(0)} pcs',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.active,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF7FAEE),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFDCEB9F)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.scale_outlined,
                                              size: 15, color: Color(0xFF7FA800)),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Weight: ${req.weightIssued.toStringAsFixed(1)} kg',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.active,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    if (!isPending)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isApproved
                                              ? Colors.green.withValues(alpha: .12)
                                              : Colors.red.withValues(alpha: .12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          req.status,
                                          style: TextStyle(
                                            color: isApproved ? Colors.green[800] : Colors.red[800],
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (isPending) ...[
                                  const Divider(height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton(
                                        onPressed: isCurrentProcessing
                                            ? null
                                            : () => _handleReject(req),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red[700],
                                          side: BorderSide(color: Colors.red[300]!),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 8),
                                        ),
                                        child: const Text('Reject'),
                                      ),
                                      const SizedBox(width: 12),
                                      FilledButton(
                                        onPressed: isCurrentProcessing
                                            ? null
                                            : () => _handleApprove(req, allMaterials),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 8),
                                        ),
                                        child: isCurrentProcessing
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Text(
                                                'Approve',
                                                style: TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
