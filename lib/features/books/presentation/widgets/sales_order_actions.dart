import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/books_repository.dart';
import '../../providers/books_providers.dart';
import '../books_pages.dart' show money;

/// Overflow-menu actions shared by the Sales Order mobile and desktop list
/// views, so "Duplicate"/"Share"/stub behavior stays identical everywhere.
///
/// Duplicate/Share are genuinely functional and only call the existing,
/// already-public [BooksRepository.addTransaction] API. Edit/Delete have no
/// backing screen or repository method, so they surface an honest "coming
/// soon" message rather than pretending to do something they can't.
Future<void> handleSalesOrderAction(
  BuildContext context,
  WidgetRef ref,
  SalesTransaction row,
  String action,
) async {
  switch (action) {
    case 'duplicate':
      await _duplicate(context, ref, row);
    case 'share':
      await _share(context, row);
    case 'edit':
      _showComingSoon(context, 'Editing');
    case 'delete':
      _showComingSoon(context, 'Deleting');
  }
}

Future<void> _duplicate(BuildContext context, WidgetRef ref, SalesTransaction row) async {
  await ref
      .read(booksRepositoryProvider)
      .addTransaction(
        TransactionDraft(
          type: TransactionType.salesOrder,
          customer: row.customer,
          number: 'SO-${DateTime.now().millisecondsSinceEpoch}',
          date: DateTime.now(),
          amount: row.amount,
          referenceNumber: row.referenceNumber,
          dueDate: row.dueDate,
          notes: row.notes,
          terms: row.terms,
        ),
      );
  ref.invalidate(transactionsProvider(TransactionType.salesOrder));
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Sales order duplicated as a new draft')));
}

Future<void> _share(BuildContext context, SalesTransaction row) async {
  final summary =
      'Sales Order ${row.number}\n'
      'Customer: ${row.customer}\n'
      'Amount: ${money.format(row.amount)}\n'
      'Date: ${DateFormat('dd/MM/yyyy').format(row.date)}\n'
      'Status: ${row.status}';
  await Clipboard.setData(ClipboardData(text: summary));
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Sales order details copied to clipboard')));
}

void _showComingSoon(BuildContext context, String action) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$action is coming soon')));
}

/// Shared overflow menu items for a Sales Order row (Edit/Duplicate/Share/Delete).
List<PopupMenuEntry<String>> salesOrderMenuItems() => const [
  PopupMenuItem(value: 'edit', child: Text('Edit')),
  PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
  PopupMenuItem(value: 'share', child: Text('Share')),
  PopupMenuDivider(),
  PopupMenuItem(value: 'delete', child: Text('Delete')),
];

/// Color-by-status pattern shared by the Sales Order mobile card badge and
/// the desktop table status chip.
Color salesOrderStatusColor(BuildContext context, String status) => switch (status.toLowerCase()) {
  'accepted' || 'closed' || 'paid' => AppColors.primary,
  'confirmed' || 'pending' || 'sent' => AppColors.active,
  'rejected' || 'cancelled' => Theme.of(context).colorScheme.error,
  _ => AppColors.textSecondary,
};

/// Status filter options shared by the mobile and desktop Sales Order lists.
/// Purely presentational/client-side — 'Draft'/'Accepted' are the only
/// statuses the current backend actually produces, the rest are
/// forward-compatible.
const salesOrderStatusFilters = ['All', 'Draft', 'Confirmed', 'Accepted', 'Closed'];

/// Client-side sort options for the Sales Order lists — pure `List.sort()`
/// over the already-fetched rows, no repository/query changes.
enum SalesOrderSort {
  dateDesc('Date (Newest first)'),
  dateAsc('Date (Oldest first)'),
  amountDesc('Amount (High to low)'),
  amountAsc('Amount (Low to high)'),
  customerAz('Customer (A-Z)');

  const SalesOrderSort(this.label);
  final String label;
}

List<SalesTransaction> sortSalesOrders(List<SalesTransaction> rows, SalesOrderSort sort) {
  final sorted = [...rows];
  switch (sort) {
    case SalesOrderSort.dateDesc:
      sorted.sort((a, b) => b.date.compareTo(a.date));
    case SalesOrderSort.dateAsc:
      sorted.sort((a, b) => a.date.compareTo(b.date));
    case SalesOrderSort.amountDesc:
      sorted.sort((a, b) => b.amount.compareTo(a.amount));
    case SalesOrderSort.amountAsc:
      sorted.sort((a, b) => a.amount.compareTo(b.amount));
    case SalesOrderSort.customerAz:
      sorted.sort((a, b) => a.customer.toLowerCase().compareTo(b.customer.toLowerCase()));
  }
  return sorted;
}
