import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../domain/books_repository.dart';
import '../providers/books_providers.dart';
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
        title: Text(item.name),
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'Overview'),
            Tab(text: 'Transactions'),
            Tab(text: 'History'),
            Tab(text: 'Product Details'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          ItemOverviewTab(item: item),
          const ItemTransactionsTab(),
          _ItemHistoryTab(itemId: item.id),
          ItemProductDetailsTab(item: item),
        ],
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
            return const ItemEmptyTab(message: 'No history to display');
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
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
