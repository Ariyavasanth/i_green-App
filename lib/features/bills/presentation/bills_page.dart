import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../domain/bill.dart';
import '../providers/bill_providers.dart';

final _money = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);

class BillsPage extends ConsumerStatefulWidget {
  const BillsPage({super.key});
  @override
  ConsumerState<BillsPage> createState() => _BillsPageState();
}

class _BillsPageState extends ConsumerState<BillsPage> {
  final _search = TextEditingController();
  String _query = '', _filter = 'All Bills';
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(billsProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/bills/new'),
        icon: const Icon(Icons.add),
        label: const Text('New Bill'),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('All Bills', style: AppTextStyles.pageTitle),
                        Text(
                          '${state.valueOrNull?.length ?? 0} bills total',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => ref.invalidate(billsProvider),
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search bill number or vendor',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _Summary(bills: state.valueOrNull ?? const []),
              const SizedBox(height: 10),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 3,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final value = ['All Bills', 'Draft', 'Overdue'][i];
                    return FilterChip(
                      label: Text(value),
                      selected: _filter == value,
                      showCheckmark: false,
                      selectedColor: AppColors.active,
                      labelStyle: TextStyle(
                        color: _filter == value
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => setState(() => _filter = value),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: state.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text(
                      'Unable to load bills\n$e',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  data: (all) {
                    final now = DateTime.now();
                    final rows = all
                        .where(
                          (b) =>
                              '${b.number} ${b.vendorName} ${b.reference}'
                                  .toLowerCase()
                                  .contains(_query) &&
                              (_filter == 'All Bills' ||
                                  _filter == 'Draft' && b.status == 'DRAFT' ||
                                  _filter == 'Overdue' &&
                                      b.dueDate.isBefore(now)),
                        )
                        .toList();
                    if (rows.isEmpty)
                      return const Center(child: Text('No bills found'));
                    return RefreshIndicator(
                      onRefresh: () => ref.refresh(billsProvider.future),
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 92),
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _BillCard(
                          bill: rows[i],
                          onDelete: () => _delete(rows[i]),
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

  Future<void> _delete(Bill bill) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete bill?'),
        content: Text('${bill.number} will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(billRepositoryProvider).deleteBill(bill.id);
      ref.invalidate(billsProvider);
    }
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.bills});
  final List<Bill> bills;
  @override
  Widget build(BuildContext context) {
    final total = bills.fold<double>(0, (s, b) => s + b.amount);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFFFFE7B3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.north_east, color: AppColors.active),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Outstanding Payables',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 3),
              Text(
                _money.format(total),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({required this.bill, required this.onDelete});
  final Bill bill;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                bill.number,
                style: const TextStyle(
                  color: AppColors.active,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.active.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                bill.status,
                style: const TextStyle(
                  color: AppColors.active,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (_) => onDelete(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
        Text(
          bill.vendorName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Detail(
                'Bill date',
                DateFormat('dd/MM/yyyy').format(bill.date),
              ),
            ),
            Expanded(
              child: _Detail(
                'Due date',
                DateFormat('dd/MM/yyyy').format(bill.dueDate),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _Detail(
                'Amount',
                _money.format(bill.amount),
                strong: true,
              ),
            ),
            Expanded(
              child: _Detail(
                'Balance due',
                _money.format(bill.amount),
                strong: true,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value, {this.strong = false});
  final String label, value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTextStyles.caption),
      const SizedBox(height: 3),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    ],
  );
}
