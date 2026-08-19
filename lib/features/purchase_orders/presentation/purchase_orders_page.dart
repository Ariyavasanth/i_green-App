import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/visual_effects.dart';
import '../domain/purchase_order.dart';
import '../providers/purchase_order_providers.dart';
import 'new_purchase_order_page.dart';
import 'widgets/purchase_order_pdf_dialog.dart';
import 'widgets/send_purchase_order_dialog.dart';

final _poMoney = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

class PurchaseOrdersPage extends ConsumerStatefulWidget {
  const PurchaseOrdersPage({super.key});
  @override
  ConsumerState<PurchaseOrdersPage> createState() => _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends ConsumerState<PurchaseOrdersPage> {
  final search = TextEditingController();
  String query = '', filter = 'All';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(purchaseOrdersProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/purchase-orders/new'),
        icon: const Icon(Icons.add),
        label: const Text('New Purchase Order'),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: search,
                      onChanged: (v) => setState(() => query = v.toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Search PO number or vendor',
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  search.clear();
                                  setState(() => query = '');
                                },
                              ),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.divider)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () => ref.invalidate(purchaseOrdersProvider),
                    icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 6),
                child: Text(
                  '${data.valueOrNull?.length ?? 0} purchase orders total',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 6,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final value = ['All', 'Draft', 'Sent', 'Accepted', 'Received', 'Billed'][i];
                    final isSelected = filter == value;
                    return FilterChip(
                      label: Text(value),
                      selected: isSelected,
                      showCheckmark: false,
                      selectedColor: AppColors.active,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => setState(() => filter = value),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: data.when(
                  loading: () => const ShimmerLoading(),
                  error: (e, _) => Center(child: Text('Unable to load purchase orders\n$e', textAlign: TextAlign.center)),
                  data: (all) {
                    final rows = all.where((r) {
                      final matchesSearch = '${r.number} ${r.vendorName} ${r.reference}'.toLowerCase().contains(query);
                      final matchesFilter = (filter == 'All') ||
                          (filter == 'Draft' && r.status.toUpperCase() == 'DRAFT') ||
                          (filter == 'Sent' && r.status.toUpperCase() == 'SENT') ||
                          (filter == 'Accepted' && r.status.toUpperCase() == 'ACCEPTED') ||
                          (filter == 'Received' && r.status.toUpperCase() == 'RECEIVED') ||
                          (filter == 'Billed' && (r.status.toUpperCase() == 'BILLED' || r.billedStatus != 'YET TO BE BILLED'));
                      return matchesSearch && matchesFilter;
                    }).toList();

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
                            onTap: () => _openPoScreen(rows[i]),
                            onDelete: () => _delete(rows[i]),
                            onStatusChange: (status) => _changeStatus(rows[i], status),
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

  void _openPoScreen(PurchaseOrder order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewPurchaseOrderPage(existingPo: order),
      ),
    );
  }

  Future<void> _changeStatus(PurchaseOrder order, String newStatus) async {
    try {
      await ref.read(purchaseOrderRepositoryProvider).updatePoStatus(order.id, newStatus);
      ref.invalidate(purchaseOrdersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${order.number} status updated to $newStatus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  Future<void> _delete(PurchaseOrder order) async {
    if (order.isBilled || order.status == 'RECEIVED') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${order.number} is ${order.status} and cannot be deleted.')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete purchase order?'),
        content: Text('${order.number} will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (ok == true) {
      try {
        await ref.read(purchaseOrderRepositoryProvider).deletePurchaseOrder(order.id);
        ref.invalidate(purchaseOrdersProvider);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e')),
          );
        }
      }
    }
  }
}

class _PurchaseOrderCard extends StatelessWidget {
  const _PurchaseOrderCard({
    required this.order,
    required this.onTap,
    required this.onDelete,
    required this.onStatusChange,
  });

  final PurchaseOrder order;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<String> onStatusChange;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
          boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.number,
                    style: const TextStyle(color: AppColors.active, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                _PoBadge(order.status),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'delete') {
                      onDelete();
                    } else if (val == 'edit' || val == 'view') {
                      onTap();
                    } else if (val == 'send_mail') {
                      showDialog(
                        context: context,
                        builder: (_) => SendPurchaseOrderDialog(order: order),
                      );
                    } else if (val == 'preview_pdf') {
                      showDialog(
                        context: context,
                        builder: (_) => PurchaseOrderPdfDialog(order: order),
                      );
                    } else {
                      onStatusChange(val);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'preview_pdf',
                      child: Row(children: [Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 18), SizedBox(width: 10), Text('Preview & Print PDF')]),
                    ),
                    const PopupMenuItem(
                      value: 'send_mail',
                      child: Row(children: [Icon(Icons.send_rounded, color: AppColors.active, size: 18), SizedBox(width: 10), Text('Send to Vendor')]),
                    ),
                    const PopupMenuDivider(),
                    if (order.isEditable) ...[
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 10), Text('Edit PO')]),
                      ),
                      const PopupMenuItem(
                        value: 'SENT',
                        child: Row(children: [Icon(Icons.send, size: 18), SizedBox(width: 10), Text('Mark as Sent')]),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [Icon(Icons.delete_outline, color: Colors.redAccent, size: 18), SizedBox(width: 10), Text('Delete', style: TextStyle(color: Colors.redAccent))]),
                      ),
                    ] else ...[
                      PopupMenuItem(
                        value: 'view',
                        child: Row(children: const [Icon(Icons.visibility, size: 18), SizedBox(width: 10), Text('View Details')]),
                      ),
                      if (order.status == 'SENT') ...[
                        const PopupMenuItem(
                          value: 'ACCEPTED',
                          child: Row(children: [Icon(Icons.check_circle_outline, size: 18), SizedBox(width: 10), Text('Mark Accepted')]),
                        ),
                        const PopupMenuItem(
                          value: 'CANCELLED',
                          child: Row(children: [Icon(Icons.cancel_outlined, size: 18), SizedBox(width: 10), Text('Mark Cancelled')]),
                        ),
                      ] else if (order.status == 'ACCEPTED') ...[
                        const PopupMenuItem(
                          value: 'RECEIVED',
                          child: Row(children: [Icon(Icons.inventory, size: 18), SizedBox(width: 10), Text('Mark Received')]),
                        ),
                      ] else if (order.status == 'RECEIVED') ...[
                        const PopupMenuItem(
                          value: 'BILLED',
                          child: Row(children: [Icon(Icons.receipt_long, size: 18), SizedBox(width: 10), Text('Create Bill')]),
                        ),
                      ],
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(order.vendorName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _PoDetail('Order date', DateFormat('dd/MM/yyyy').format(order.date))),
                Expanded(child: _PoDetail('Amount', _poMoney.format(order.amount), strong: true)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _PoDetail('Billed status', order.billedStatus)),
                Expanded(child: _PoDetail('Delivery date', order.deliveryDate == null ? 'Not set' : DateFormat('dd/MM/yyyy').format(order.deliveryDate!))),
              ],
            ),
            if (order.reference.isNotEmpty) ...[
              const SizedBox(height: 10),
              _PoDetail('Reference', order.reference),
            ],
          ],
        ),
      ),
    );
  }
}

class _PoDetail extends StatelessWidget {
  const _PoDetail(this.label, this.value, {this.strong = false});
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
            style: TextStyle(fontWeight: strong ? FontWeight.w700 : FontWeight.w500),
          ),
        ],
      );
}

class _PoBadge extends StatelessWidget {
  const _PoBadge(this.text);
  final String text;

  Color _getBadgeColor() {
    switch (text.toUpperCase()) {
      case 'DRAFT':
        return Colors.orange;
      case 'SENT':
        return Colors.blue;
      case 'ACCEPTED':
        return Colors.teal;
      case 'RECEIVED':
        return AppColors.active;
      case 'BILLED':
        return Colors.purple;
      case 'CANCELLED':
        return Colors.red;
      default:
        return AppColors.active;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getBadgeColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _EmptyPurchaseOrders extends StatelessWidget {
  const _EmptyPurchaseOrders();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 52, color: AppColors.textSecondary),
            SizedBox(height: 12),
            Text('No purchase orders found', style: AppTextStyles.heading),
            SizedBox(height: 5),
            Text('Try changing your search or filter.', style: AppTextStyles.caption),
          ],
        ),
      );
}
