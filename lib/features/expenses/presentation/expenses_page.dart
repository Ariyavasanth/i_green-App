import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/expense.dart';
import '../providers/expense_providers.dart';

class ExpensesPage extends ConsumerStatefulWidget {
  const ExpensesPage({super.key});

  @override
  ConsumerState<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends ConsumerState<ExpensesPage> {
  final Set<int> _selected = {};
  final _date = DateFormat('dd/MM/yyyy');
  final _money = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '\u20B9',
    decimalDigits: 2,
  );

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(expensesProvider);
    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          _toolbar(context),
          const Divider(height: 1),
          Expanded(
            child: result.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text('Unable to load expenses: $error'),
              ),
              data: (expenses) => LayoutBuilder(
                builder: (context, constraints) => constraints.maxWidth < 720
                    ? _mobileList(expenses)
                    : _desktopTable(expenses, constraints.maxWidth),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
    child: Row(
      children: [
        if (MediaQuery.sizeOf(context).width >= 600) ...[
          const Text(
            'Receipts Inbox',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
          const SizedBox(width: 24),
        ],
        const Text(
          'All Expenses',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.active),
        const Spacer(),
        if (MediaQuery.sizeOf(context).width >= 780)
          OutlinedButton.icon(
            onPressed: () => _showNotice('Expense upload'),
            icon: const Icon(Icons.upload_outlined, size: 17),
            label: const Text('Upload Expense'),
          ),
        const SizedBox(width: 8),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.active),
          onPressed: _showNewExpenseDialog,
          icon: const Icon(Icons.add, size: 18),
          label: Text(MediaQuery.sizeOf(context).width < 500 ? 'New' : 'New Expense'),
        ),
        const SizedBox(width: 6),
        IconButton.outlined(
          tooltip: 'More actions',
          onPressed: () => _showNotice('More actions'),
          icon: const Icon(Icons.more_horiz, size: 18),
        ),
      ],
    ),
  );

  Widget _desktopTable(List<Expense> expenses, double width) =>
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width < 1120 ? 1120 : width,
          child: SingleChildScrollView(
            child: DataTable(
              headingRowHeight: 42,
              dataRowMinHeight: 58,
              dataRowMaxHeight: 68,
              horizontalMargin: 16,
              columnSpacing: 24,
              showCheckboxColumn: true,
              headingTextStyle: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              columns: const [
                DataColumn(label: Text('DATE')),
                DataColumn(label: Text('EXPENSE ACCOUNT')),
                DataColumn(label: Text('REFERENCE#')),
                DataColumn(label: Text('VENDOR NAME')),
                DataColumn(label: Text('PAID THROUGH')),
                DataColumn(label: Text('CUSTOMER NAME')),
                DataColumn(label: Text('STATUS')),
                DataColumn(label: Text('AMOUNT'), numeric: true),
              ],
              rows: expenses.map((expense) => _row(expense)).toList(),
            ),
          ),
        ),
      );

  DataRow _row(Expense expense) => DataRow(
    selected: _selected.contains(expense.id),
    onSelectChanged: (selected) => setState(() {
      selected == true
          ? _selected.add(expense.id)
          : _selected.remove(expense.id);
    }),
    cells: [
      DataCell(Text(_date.format(expense.date))),
      DataCell(
        SizedBox(
          width: 130,
          child: Text(
            expense.account,
            style: const TextStyle(
              color: AppColors.active,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      DataCell(Text(expense.reference)),
      DataCell(Text(expense.vendor)),
      DataCell(Text(expense.paidThrough)),
      DataCell(SizedBox(width: 170, child: Text(expense.customer))),
      DataCell(Text(expense.status, style: const TextStyle(fontSize: 11))),
      DataCell(Text(_money.format(expense.amount))),
    ],
  );

  Widget _mobileList(List<Expense> expenses) => ListView.separated(
    padding: const EdgeInsets.all(12),
    itemCount: expenses.length,
    separatorBuilder: (_, _) => const SizedBox(height: 8),
    itemBuilder: (context, index) {
      final expense = expenses[index];
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      expense.account,
                      style: const TextStyle(
                        color: AppColors.active,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    _money.format(expense.amount),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('${_date.format(expense.date)}  \u00b7  ${expense.paidThrough}'),
              const SizedBox(height: 4),
              Text(expense.customer, style: const TextStyle(color: AppColors.textSecondary)),
              if (expense.vendor.isNotEmpty || expense.reference.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  [expense.vendor, expense.reference].where((v) => v.isNotEmpty).join('  \u00b7  '),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 8),
              Text(expense.status, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      );
    },
  );

  void _showNotice(String feature) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$feature is ready to be connected.')),
  );

  Future<void> _showNewExpenseDialog() async {
    final account = TextEditingController();
    final vendor = TextEditingController();
    final customer = TextEditingController(text: 'iGreentec Engineering India Pvt Ltd');
    final amount = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New Expense'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: account, decoration: const InputDecoration(labelText: 'Expense Account')),
              TextField(controller: vendor, decoration: const InputDecoration(labelText: 'Vendor Name')),
              TextField(controller: customer, decoration: const InputDecoration(labelText: 'Customer Name')),
              TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true || account.text.trim().isEmpty) return;
    await ref.read(expenseRepositoryProvider).addExpense(
      date: DateTime.now(),
      account: account.text.trim(),
      reference: '',
      vendor: vendor.text.trim(),
      paidThrough: 'Petty Cash',
      customer: customer.text.trim(),
      status: 'NON-BILLABLE',
      amount: double.tryParse(amount.text.trim()) ?? 0,
    );
    ref.invalidate(expensesProvider);
  }
}

