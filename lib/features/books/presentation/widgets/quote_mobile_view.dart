import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/visual_effects.dart';
import '../../domain/books_repository.dart';
import '../../providers/books_providers.dart';
import '../books_pages.dart' show error, money;

/// Mobile-only quote list experience. Reuses [transactionsProvider],
/// [booksSearchQueryProvider] and the existing convert/record-paid actions —
/// only presentation is new here, no business logic is duplicated.
class QuoteMobileView extends ConsumerStatefulWidget {
  const QuoteMobileView({
    required this.onAdd,
    required this.onAction,
    super.key,
  });

  final VoidCallback onAdd;
  final Future<void> Function(SalesTransaction row, String action) onAction;

  @override
  ConsumerState<QuoteMobileView> createState() => _QuoteMobileViewState();
}

const _statusFilters = ['All', 'Draft', 'Pending', 'Accepted', 'Rejected'];

class _QuoteMobileViewState extends ConsumerState<QuoteMobileView> {
  late final _searchController = TextEditingController(
    text: ref.read(booksSearchQueryProvider),
  );
  String _statusFilter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncRows = ref.watch(transactionsProvider(TransactionType.quote));
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onAdd,
        icon: const Icon(Icons.add),
        label: const Text('New Quote'),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _QuoteHeader(count: asyncRows.valueOrNull?.length),
              const SizedBox(height: 12),
              _QuoteSearchField(controller: _searchController),
              const SizedBox(height: 10),
              _QuoteFilterChips(
                selected: _statusFilter,
                onSelected: (v) => setState(() => _statusFilter = v),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: asyncRows.when(
                  loading: () => const ShimmerLoading(),
                  error: error,
                  data: (all) {
                    final q = ref.watch(booksSearchQueryProvider).toLowerCase();
                    final rows = all
                        .where(
                          (r) => '${r.number} ${r.customer} ${r.status}'
                              .toLowerCase()
                              .contains(q),
                        )
                        .toList();
                    final visible = _statusFilter == 'All'
                        ? rows
                        : rows
                              .where(
                                (r) =>
                                    r.status.toLowerCase() ==
                                    _statusFilter.toLowerCase(),
                              )
                              .toList();

                    if (all.isEmpty) {
                      return _QuoteEmptyState(onAdd: widget.onAdd);
                    }
                    if (visible.isEmpty) {
                      return const _QuoteNoResultsState();
                    }
                    return RefreshIndicator(
                      color: AppColors.active,
                      onRefresh: () => ref.refresh(
                        transactionsProvider(TransactionType.quote).future,
                      ),
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => FadeSlideIn(
                          child: _QuoteCard(
                            row: visible[i],
                            onAction: (action) =>
                                widget.onAction(visible[i], action),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuoteHeader extends StatelessWidget {
  const _QuoteHeader({required this.count});
  final int? count;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quotes', style: AppTextStyles.pageTitle),
            const SizedBox(height: 2),
            Text(
              count == null
                  ? 'Loading…'
                  : '$count quote${count == 1 ? '' : 's'} total',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    ],
  );
}

class _QuoteSearchField extends StatelessWidget {
  const _QuoteSearchField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Consumer(
    builder: (context, ref, _) => TextField(
      controller: controller,
      onChanged: (v) =>
          ref.read(booksSearchQueryProvider.notifier).state = v,
      decoration: InputDecoration(
        hintText: 'Search quotes',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  controller.clear();
                  ref.read(booksSearchQueryProvider.notifier).state = '';
                },
              ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.active, width: 1.5),
        ),
      ),
    ),
  );
}

class _QuoteFilterChips extends StatelessWidget {
  const _QuoteFilterChips({required this.selected, required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 36,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _statusFilters.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final label = _statusFilters[i];
        final isSelected = label == selected;
        return FilterChip(
          label: Text(label),
          selected: isSelected,
          showCheckmark: false,
          labelStyle: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
          backgroundColor: AppColors.surface,
          selectedColor: AppColors.active,
          side: BorderSide(
            color: isSelected ? AppColors.active : AppColors.divider,
          ),
          onSelected: (_) => onSelected(label),
        );
      },
    ),
  );
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.row, required this.onAction});
  final SalesTransaction row;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.divider),
      boxShadow: const [
        BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 4)),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.number,
                style: const TextStyle(
                  color: AppColors.active,
                  fontWeight: FontWeight.w700,
                  fontSize: 16.5,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.customer,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    money.format(row.amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15.5,
                      color: AppColors.active,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    DateFormat('dd/MM/yyyy').format(row.date),
                    style: AppTextStyles.caption,
                  ),
                  const Spacer(),
                  _StatusBadge(status: row.status),
                ],
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'More options',
          onSelected: onAction,
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'order', child: Text('Convert to Sales Order')),
            PopupMenuItem(value: 'invoice', child: Text('Convert to Invoice')),
          ],
        ),
      ],
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status.toLowerCase()) {
      'accepted' || 'paid' => AppColors.primary,
      'pending' || 'sent' => AppColors.active,
      'rejected' || 'cancelled' => Theme.of(context).colorScheme.error,
      _ => AppColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _QuoteEmptyState extends StatelessWidget {
  const _QuoteEmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.request_quote_outlined,
            size: 56,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          const Text('No Quotes Found', style: AppTextStyles.heading),
          const SizedBox(height: 6),
          const Text(
            'Create your first quote to start sending offers to customers.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create Quote'),
          ),
        ],
      ),
    ),
  );
}

class _QuoteNoResultsState extends StatelessWidget {
  const _QuoteNoResultsState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.filter_alt_off_outlined, size: 40, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Text('No quotes match your search or filter', style: AppTextStyles.caption),
        ],
      ),
    ),
  );
}
