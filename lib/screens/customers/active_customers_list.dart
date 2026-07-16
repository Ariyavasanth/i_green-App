import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/layout/responsive_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../models/customer.dart';
import '../../providers/customer_providers.dart';
import '../../widgets/customers/customer_list_item.dart';

class ActiveCustomersList extends ConsumerStatefulWidget {
  const ActiveCustomersList({super.key});
  @override ConsumerState<ActiveCustomersList> createState() => _ActiveCustomersListState();
}

class _ActiveCustomersListState extends ConsumerState<ActiveCustomersList> {
  String query = '', supplyFilter = 'All';
  int sortColumn = 0;
  bool ascending = true;
  final selected = <int>{};

  @override Widget build(BuildContext context) {
    final async = ref.watch(activeCustomersProvider);
    return ColoredBox(color: AppColors.canvas, child: Column(children: [
      AppBar(title: const Text('Active Customers'), actions: [
        Padding(padding: const EdgeInsets.all(8), child: FilledButton.icon(onPressed: () => context.go('/customers/new'), icon: const Icon(Icons.add), label: const Text('New'))),
      ]),
      Expanded(child: LayoutBuilder(builder: (context, box) {
        final gutter = AppLayout.gutter(box.maxWidth);
        return ResponsiveContent(child: Padding(padding: EdgeInsets.all(gutter), child: Column(children: [
          _toolbar(async.valueOrNull ?? const []), const SizedBox(height: 14),
          Expanded(child: async.when(loading: () => const Center(child: CircularProgressIndicator()), error: (e, _) => Center(child: Text('Unable to load customers: $e')), data: (all) => _content(all, box.maxWidth))),
        ])));
      })),
    ]));
  }

  Widget _toolbar(List<Customer> all) {
    final supplies = ['All', ...{for (final c in all) c.placeOfSupply}.where((e) => e.isNotEmpty)];
    return LayoutBuilder(builder: (_, c) => Wrap(spacing: 12, runSpacing: 10, alignment: WrapAlignment.spaceBetween, children: [
      SizedBox(width: c.maxWidth < 600 ? c.maxWidth : 360, child: TextField(onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search customers', border: OutlineInputBorder(), isDense: true))),
      DropdownButton<String>(value: supplies.contains(supplyFilter) ? supplyFilter : 'All', items: supplies.map((e) => DropdownMenuItem(value: e, child: Text(e == 'All' ? 'All places of supply' : e))).toList(), onChanged: (v) => setState(() => supplyFilter = v!)),
      if (selected.isNotEmpty) Text('${selected.length} selected', style: const TextStyle(fontWeight: FontWeight.w600)),
    ]));
  }

  List<Customer> _rows(List<Customer> all) {
    final q = query.toLowerCase();
    final rows = all.where((c) => (supplyFilter == 'All' || c.placeOfSupply == supplyFilter) && '${c.displayName} ${c.companyName} ${c.email} ${c.workPhone}'.toLowerCase().contains(q)).toList();
    int compare(Customer a, Customer b) => switch (sortColumn) { 1 => a.companyName.compareTo(b.companyName), 2 => a.email.compareTo(b.email), 3 => a.workPhone.compareTo(b.workPhone), 4 => a.placeOfSupply.compareTo(b.placeOfSupply), 5 => a.receivables.compareTo(b.receivables), 6 => a.unusedCredits.compareTo(b.unusedCredits), _ => a.displayName.compareTo(b.displayName) };
    rows.sort((a, b) => ascending ? compare(a, b) : compare(b, a));
    return rows;
  }

  Widget _content(List<Customer> all, double width) {
    final rows = _rows(all);
    if (rows.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.people_outline, size: 58, color: AppColors.textSecondary), const SizedBox(height: 12), Text(query.isEmpty ? 'No active customers yet' : 'No customers match your search'), const SizedBox(height: 12), FilledButton.icon(onPressed: () => context.go('/customers/new'), icon: const Icon(Icons.add), label: const Text('Create customer'))]));
    if (width < AppBreakpoints.tablet) return ListView(children: rows.map((c) => CustomerListCard(customer: c, selected: selected.contains(c.id), onSelected: (v) => setState(() => v! ? selected.add(c.id!) : selected.remove(c.id)))).toList());
    final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    DataColumn column(String text, int index) => DataColumn(label: Text(text), onSort: (_, asc) => setState(() { sortColumn = index; ascending = asc; }));
    return Card(child: SingleChildScrollView(child: PaginatedDataTable(
      showCheckboxColumn: true, rowsPerPage: rows.length < 10 ? rows.length : 10, sortColumnIndex: sortColumn, sortAscending: ascending,
      columns: [column('Name', 0), column('Company Name', 1), column('Email', 2), column('Work Phone', 3), column('Place of Supply', 4), column('Receivables', 5), column('Unused Credits', 6)],
      source: _CustomerSource(rows, selected, (id, value) => setState(() => value ? selected.add(id) : selected.remove(id)), money),
    )));
  }
}

class _CustomerSource extends DataTableSource {
  _CustomerSource(this.rows, this.selected, this.select, this.money);
  final List<Customer> rows; final Set<int> selected; final void Function(int, bool) select; final NumberFormat money;
  @override DataRow? getRow(int index) { if (index >= rows.length) return null; final c = rows[index]; return DataRow(selected: selected.contains(c.id), onSelectChanged: (v) => select(c.id!, v ?? false), cells: [DataCell(Text(c.displayName)), DataCell(Text(c.companyName)), DataCell(Text(c.email)), DataCell(Text(c.workPhone)), DataCell(Text(c.placeOfSupply)), DataCell(Text(money.format(c.receivables))), DataCell(Text(money.format(c.unusedCredits)))]); }
  @override bool get isRowCountApproximate => false;
  @override int get rowCount => rows.length;
  @override int get selectedRowCount => selected.length;
}
