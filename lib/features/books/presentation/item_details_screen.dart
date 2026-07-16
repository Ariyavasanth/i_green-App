import 'package:flutter/material.dart';

import '../domain/books_repository.dart';
import 'item_details_widgets.dart';

/// Item Details screen — reached by tapping a row on the Items list.
/// Renders the [BookItem] passed in via navigation; no separate fetch is
/// needed since the list already holds the full, up-to-date record.
class ItemDetailsScreen extends StatelessWidget {
  const ItemDetailsScreen({required this.item, super.key});
  final BookItem item;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: Text(item.name),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Overview'),
            Tab(text: 'Transactions'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          ItemOverviewTab(item: item),
          const ItemEmptyTab(message: 'No transactions to display'),
          const ItemEmptyTab(message: 'No history to display'),
        ],
      ),
    ),
  );
}
