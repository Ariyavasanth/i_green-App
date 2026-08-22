import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/books_repository.dart';
import '../providers/books_providers.dart';
import 'books_forms.dart';
import 'item_details_widgets.dart';

/// Item Details screen — reached by tapping a row on the Items list.
/// Renders the [BookItem] passed in via navigation; no separate fetch is
/// needed since the list already holds the full, up-to-date record.
class ItemDetailsScreen extends ConsumerWidget {
  const ItemDetailsScreen({required this.item, super.key});
  final BookItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          item.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Item',
            onPressed: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                builder: (_) => NewItemPage(initialItem: item),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
        bottom: const TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'Overview'),
            Tab(text: 'Transactions'),
            Tab(text: 'History'),
            Tab(text: 'Product Details'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(itemsProvider);
          await ref.read(itemsProvider.future);
        },
        child: TabBarView(
          children: [
            ItemOverviewTab(item: item),
            const ItemTransactionsTab(),
            _ItemHistoryTab(itemId: item.id),
            ItemProductDetailsTab(item: item),
          ],
        ),
      ),
    ),
  );
}

class _ItemHistoryTab extends ConsumerWidget {
  const _ItemHistoryTab({required this.itemId});

  final int itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(itemHistoryProvider(itemId))
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (history) {
          if (history.isEmpty) {
            return const SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: 300,
                child: ItemEmptyTab(message: 'No history to display'),
              ),
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              final gutter = AppLayout.gutter(constraints.maxWidth);

              if (isMobile) {
                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(gutter),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final entry = history[index];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Color(0xFFE2E5EA)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.details,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('dd/MM/yyyy hh:mm a').format(entry.date),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(gutter),
                child: Table(
                  columnWidths: const {
                    0: FixedColumnWidth(210),
                    1: FlexColumnWidth(),
                  },
                  border: const TableBorder(
                    horizontalInside: BorderSide(color: Color(0xFFE2E5EA)),
                    bottom: BorderSide(color: Color(0xFFE2E5EA)),
                  ),
                  children: [
                    const TableRow(
                      children: [
                        _HistoryCell(text: 'DATE', isHeader: true),
                        _HistoryCell(text: 'DETAILS', isHeader: true),
                      ],
                    ),
                    for (final entry in history)
                      TableRow(
                        children: [
                          _HistoryCell(
                            text: DateFormat(
                              'dd/MM/yyyy hh:mm a',
                            ).format(entry.date),
                          ),
                          _HistoryCell(text: entry.details),
                        ],
                      ),
                  ],
                ),
              );
            },
          );
        },
      );
}

class _HistoryCell extends StatelessWidget {
  const _HistoryCell({required this.text, this.isHeader = false});

  final String text;
  final bool isHeader;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    child: Text(
      text,
      style: TextStyle(
        fontSize: isHeader ? 12 : 14,
        fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
      ),
    ),
  );
}
