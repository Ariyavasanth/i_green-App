import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/visual_effects.dart';
import '../domain/purchase_order.dart';
import '../providers/purchase_order_providers.dart';

final _poMoney = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

class PurchaseOrdersPage extends ConsumerStatefulWidget {
  const PurchaseOrdersPage({super.key});
  @override ConsumerState<PurchaseOrdersPage> createState() => _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends ConsumerState<PurchaseOrdersPage> {
  final search = TextEditingController();
  String query = '', filter = 'All';
  @override void dispose() { search.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    final data = ref.watch(purchaseOrdersProvider);
    return Scaffold(backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(onPressed: () => context.push('/purchase-orders/new'), icon: const Icon(Icons.add), label: const Text('New Purchase Order')),
      body: SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Purchase Orders', style: AppTextStyles.pageTitle), Text('${data.valueOrNull?.length ?? 0} purchase orders total', style: AppTextStyles.caption)])), IconButton(tooltip: 'Refresh', onPressed: () => ref.invalidate(purchaseOrdersProvider), icon: const Icon(Icons.refresh))]),
        const SizedBox(height: 12),
        TextField(controller: search, onChanged: (v) => setState(() => query = v.toLowerCase()), decoration: InputDecoration(hintText: 'Search PO number or vendor', prefixIcon: const Icon(Icons.search), suffixIcon: query.isEmpty ? null : IconButton(icon: const Icon(Icons.close), onPressed: () { search.clear(); setState(() => query = ''); }), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.divider)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
        const SizedBox(height: 10),
        SizedBox(height: 36, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: 3, separatorBuilder: (_, _) => const SizedBox(width: 8), itemBuilder: (_, i) { final value = ['All', 'Draft', 'Billed'][i]; return FilterChip(label: Text(value), selected: filter == value, showCheckmark: false, selectedColor: AppColors.active, labelStyle: TextStyle(color: filter == value ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w600), onSelected: (_) => setState(() => filter = value)); })),
        const SizedBox(height: 10),
        Expanded(child: data.when(loading: () => const ShimmerLoading(), error: (e, _) => Center(child: Text('Unable to load purchase orders\n$e', textAlign: TextAlign.center)), data: (all) {
          final rows = all.where((r) => '${r.number} ${r.vendorName} ${r.reference}'.toLowerCase().contains(query) && (filter == 'All' || filter == 'Draft' && r.status == 'DRAFT' || filter == 'Billed' && r.billedStatus != 'YET TO BE BILLED')).toList();
          if (rows.isEmpty) return const _EmptyPurchaseOrders();
          return RefreshIndicator(
            color: AppColors.active,
            onRefresh: () => ref.refresh(purchaseOrdersProvider.future),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 92),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => FadeSlideIn(
                child: _PurchaseOrderCard(
                  order: rows[i],
                  onDelete: () => _delete(rows[i]),
                ),
              ),
            ),
          );
        })),
      ]))));
  }

  Future<void> _delete(PurchaseOrder order) async {
    final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Delete purchase order?'), content: Text('${order.number} will be permanently removed.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))]));
    if (ok == true) { await ref.read(purchaseOrderRepositoryProvider).deletePurchaseOrder(order.id); ref.invalidate(purchaseOrdersProvider); }
  }
}

class _PurchaseOrderCard extends StatelessWidget {
  const _PurchaseOrderCard({required this.order, required this.onDelete});
  final PurchaseOrder order; final VoidCallback onDelete;
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.divider), boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 4))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Expanded(child: Text(order.number, style: const TextStyle(color: AppColors.active, fontSize: 16, fontWeight: FontWeight.w700))), _PoBadge(order.status), PopupMenuButton<String>(onSelected: (_) => onDelete(), itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline), SizedBox(width: 10), Text('Delete')]))])]),
    Text(order.vendorName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 12),
    Row(children: [Expanded(child: _PoDetail('Order date', DateFormat('dd/MM/yyyy').format(order.date))), Expanded(child: _PoDetail('Amount', _poMoney.format(order.amount), strong: true))]), const SizedBox(height: 10),
    Row(children: [Expanded(child: _PoDetail('Billed status', order.billedStatus)), Expanded(child: _PoDetail('Delivery date', order.deliveryDate == null ? 'Not set' : DateFormat('dd/MM/yyyy').format(order.deliveryDate!)))]),
    if (order.reference.isNotEmpty) ...[const SizedBox(height: 10), _PoDetail('Reference', order.reference)],
  ]));
}

class _PoDetail extends StatelessWidget { const _PoDetail(this.label, this.value, {this.strong = false}); final String label, value; final bool strong; @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: AppTextStyles.caption), const SizedBox(height: 3), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: strong ? FontWeight.w700 : FontWeight.w500))]); }
class _PoBadge extends StatelessWidget { const _PoBadge(this.text); final String text; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(color: AppColors.active.withValues(alpha: .1), borderRadius: BorderRadius.circular(20)), child: Text(text, style: const TextStyle(color: AppColors.active, fontSize: 11, fontWeight: FontWeight.w700))); }
class _EmptyPurchaseOrders extends StatelessWidget { const _EmptyPurchaseOrders(); @override Widget build(BuildContext context) => const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.shopping_cart_outlined, size: 52, color: AppColors.textSecondary), SizedBox(height: 12), Text('No purchase orders found', style: AppTextStyles.heading), SizedBox(height: 5), Text('Try changing your search or filter.', style: AppTextStyles.caption)])); }
