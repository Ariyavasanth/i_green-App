import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/books_repository.dart';

class ItemsDesktopView extends StatefulWidget {
  const ItemsDesktopView({
    required this.items,
    required this.onAdd,
    required this.onOpen,
    required this.onRequestMaterial,
    super.key,
  });

  final List<BookItem> items;
  final VoidCallback onAdd;
  final ValueChanged<BookItem> onOpen;
  final VoidCallback onRequestMaterial;

  @override
  State<ItemsDesktopView> createState() => _ItemsDesktopViewState();
}

class _ItemsDesktopViewState extends State<ItemsDesktopView> {
  static const _rowsPerPage = 7;
  final _searchController = TextEditingController();
  final Set<int> _selected = {};
  String _stockFilter = 'All stock';
  String _typeFilter = 'All types';
  int _page = 0;

  List<BookItem> get _filteredItems {
    final query = _searchController.text.trim().toLowerCase();
    return widget.items.where((item) {
      final matchesQuery = query.isEmpty ||
          '${item.sku} ${item.id} ${item.name} ${item.type}'
              .toLowerCase()
              .contains(query);
      final matchesType = _typeFilter == 'All types' || item.type == _typeFilter;
      final matchesStock = switch (_stockFilter) {
        'In stock' => item.stockOnHand > 0,
        'Low stock' => item.stockOnHand > 0 && item.stockOnHand < 5,
        'Out of stock' => item.stockOnHand <= 0,
        _ => true,
      };
      return matchesQuery && matchesType && matchesStock;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filtersChanged() => setState(() => _page = 0);

  void _showBulkMessage(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action ${_selected.length} selected items')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filteredItems;
    final pageCount = rows.isEmpty ? 1 : (rows.length / _rowsPerPage).ceil();
    if (_page >= pageCount) _page = pageCount - 1;
    final start = _page * _rowsPerPage;
    final visible = rows.skip(start).take(_rowsPerPage).toList();
    final allVisibleSelected = visible.isNotEmpty &&
        visible.every((item) => _selected.contains(item.id));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onAdd,
        icon: const Icon(Icons.add),
        label: const Text('New Item'),
      ),
      body: LayoutBuilder(
      builder: (context, constraints) {
        final gutter = AppLayout.gutter(constraints.maxWidth);
        return Padding(
          padding: EdgeInsets.fromLTRB(gutter, 18, gutter, gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Active Items',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 14),
                  ElevatedButton.icon(
                    onPressed: widget.onRequestMaterial,
                    icon: const Icon(Icons.inventory_2_outlined, size: 18),
                    label: const Text('Request Material'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => _filtersChanged(),
                        decoration: const InputDecoration(
                          hintText: 'Search by item name, SKU or item ID',
                          prefixIcon: Icon(Icons.search, size: 20),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _FilterDropdown(
                    value: _stockFilter,
                    values: const ['All stock', 'In stock', 'Low stock', 'Out of stock'],
                    onChanged: (value) {
                      _stockFilter = value;
                      _filtersChanged();
                    },
                  ),
                  const SizedBox(width: 12),
                  _FilterDropdown(
                    value: _typeFilter,
                    values: const ['All types', 'Goods', 'Service'],
                    onChanged: (value) {
                      _typeFilter = value;
                      _filtersChanged();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: _selected.isEmpty
                    ? const SizedBox(height: 36)
                    : SizedBox(
                        key: const ValueKey('bulk-actions'),
                        height: 36,
                        child: Row(
                          children: [
                            Text(
                              '${_selected.length} selected',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 12),
                            TextButton.icon(
                              onPressed: () => _showBulkMessage('Categorize'),
                              icon: const Icon(Icons.category_outlined, size: 18),
                              label: const Text('Categorize'),
                            ),
                            TextButton.icon(
                              onPressed: () => _showBulkMessage('Export'),
                              icon: const Icon(Icons.download_outlined, size: 18),
                              label: const Text('Export'),
                            ),
                            TextButton.icon(
                              onPressed: () => _showBulkMessage('Delete'),
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: const Text('Delete'),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.divider),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      _ItemsHeader(
                        checked: allVisibleSelected,
                        onChanged: visible.isEmpty
                            ? null
                            : (checked) => setState(() {
                                for (final item in visible) {
                                  checked
                                      ? _selected.add(item.id)
                                      : _selected.remove(item.id);
                                }
                              }),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: visible.isEmpty
                            ? const Center(child: Text('No items match these filters.'))
                            : ListView.separated(
                                itemCount: visible.length,
                                separatorBuilder: (_, _) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = visible[index];
                                  return _ItemRow(
                                    item: item,
                                    checked: _selected.contains(item.id),
                                    onChecked: (checked) => setState(() => checked
                                        ? _selected.add(item.id)
                                        : _selected.remove(item.id)),
                                    onOpen: () => widget.onOpen(item),
                                  );
                                },
                              ),
                      ),
                      const Divider(height: 1),
                      _Pagination(
                        start: rows.isEmpty ? 0 : start + 1,
                        end: (start + visible.length),
                        total: rows.length,
                        page: _page,
                        pageCount: pageCount,
                        onPrevious: _page == 0 ? null : () => setState(() => _page--),
                        onNext: _page + 1 >= pageCount
                            ? null
                            : () => setState(() => _page++),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({required this.value, required this.values, required this.onChanged});
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 42,
    width: 170,
    child: DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: values.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    ),
  );
}

class _ItemsHeader extends StatelessWidget {
  const _ItemsHeader({required this.checked, required this.onChanged});
  final bool checked;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 46,
    color: const Color(0xFFF6F7F8),
    child: _TableCells(
      checkbox: Checkbox(value: checked, onChanged: (value) => onChanged?.call(value ?? false)),
      sku: const _HeaderText('SKU / ITEM ID'),
      image: const _HeaderText('IMAGE'),
      name: const _HeaderText('ITEM NAME'),
      type: const _HeaderText('TYPE'),
      stock: const _HeaderText('STOCK LEVEL'),
      price: const _HeaderText('PRICE / VALUE', align: TextAlign.right),
    ),
  );
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.checked, required this.onChecked, required this.onOpen});
  final BookItem item;
  final bool checked;
  final ValueChanged<bool> onChecked;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onOpen,
    child: SizedBox(
      height: 62,
      child: _TableCells(
        checkbox: Checkbox(
          value: checked,
          onChanged: (value) => onChecked(value ?? false),
        ),
        sku: Text(item.sku.isEmpty ? '#${item.id}' : '${item.sku}\n#${item.id}', maxLines: 2),
        image: _ItemVisual(item: item),
        name: Text(
          item.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.active, fontWeight: FontWeight.w600),
        ),
        type: Text(item.type),
        stock: Text(
          item.trackInventory ? '${item.stockOnHand.toStringAsFixed(0)} ${item.unit}' : 'Not tracked',
          style: TextStyle(
            color: item.trackInventory && item.stockOnHand <= 0
                ? Colors.red.shade700
                : AppColors.textPrimary,
          ),
        ),
        price: Text(
          NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2).format(item.rate),
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    ),
  );
}

class _TableCells extends StatelessWidget {
  const _TableCells({required this.checkbox, required this.sku, required this.image, required this.name, required this.type, required this.stock, required this.price});
  final Widget checkbox, sku, image, name, type, stock, price;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 52, child: Center(child: checkbox)),
      Expanded(flex: 16, child: sku),
      SizedBox(width: 72, child: image),
      Expanded(flex: 28, child: name),
      Expanded(flex: 14, child: type),
      Expanded(flex: 16, child: stock),
      Expanded(flex: 16, child: Padding(padding: const EdgeInsets.only(right: 20), child: price)),
    ],
  );
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.text, {this.align = TextAlign.left});
  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: align,
    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.35),
  );
}

class _ItemVisual extends StatelessWidget {
  const _ItemVisual({required this.item});
  final BookItem item;

  @override
  Widget build(BuildContext context) {
    if (item.name == '3.5" Pulling Swivel') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Image.asset('assets/images/3_5_pulling_swivel.png', width: 42, height: 42, fit: BoxFit.cover),
      );
    }
    final colors = [const Color(0xFFE8F0E1), const Color(0xFFE5EDF3), const Color(0xFFF3E9DD), const Color(0xFFEDE6F3)];
    final color = colors[item.id.abs() % colors.length];
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Icon(item.type == 'Service' ? Icons.handyman_outlined : Icons.inventory_2_outlined, size: 21, color: AppColors.active),
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({required this.start, required this.end, required this.total, required this.page, required this.pageCount, required this.onPrevious, required this.onNext});
  final int start, end, total, page, pageCount;
  final VoidCallback? onPrevious, onNext;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: Row(
      children: [
        const SizedBox(width: 18),
        Text('Showing $start–$end of $total items', style: const TextStyle(color: AppColors.textSecondary)),
        const Spacer(),
        Text('Page ${page + 1} of $pageCount'),
        IconButton(tooltip: 'Previous page', onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
        IconButton(tooltip: 'Next page', onPressed: onNext, icon: const Icon(Icons.chevron_right)),
        const SizedBox(width: 8),
      ],
    ),
  );
}
