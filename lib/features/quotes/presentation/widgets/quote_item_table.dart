import 'package:flutter/material.dart';

import '../../../../core/layout/responsive_layout.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../books/domain/books_repository.dart';
import 'searchable_field.dart';

/// Tax rate choices offered on each line item, matching [BookItem.taxRate]
/// conventions used elsewhere in the Books module (GST slabs).
const quoteTaxRateOptions = <double>[0, 5, 12, 18, 28];

String taxRateLabel(double rate) => rate == 0 ? 'Exempt' : 'GST${rate.toStringAsFixed(0)} (${rate.toStringAsFixed(0)}%)';

/// A single, mutable quote line item. Owns its own text controllers so rows
/// can be added/removed freely without the parent form re-wiring state.
class QuoteLineItem {
  QuoteLineItem({this.item, double quantity = 1, double rate = 0, this.taxPercent = 0})
    : itemController = TextEditingController(text: item?.name ?? ''),
      quantityController = TextEditingController(text: quantity.toStringAsFixed(0)),
      rateController = TextEditingController(text: rate == 0 ? '' : rate.toStringAsFixed(2));

  BookItem? item;
  double taxPercent;
  final TextEditingController itemController;
  final TextEditingController quantityController;
  final TextEditingController rateController;

  double get quantity => double.tryParse(quantityController.text) ?? 0;
  double get rate => double.tryParse(rateController.text) ?? 0;
  double get amount => quantity * rate;
  double get taxAmount => amount * taxPercent / 100;
  bool get isEmpty => item == null && itemController.text.trim().isEmpty;

  void dispose() {
    itemController.dispose();
    quantityController.dispose();
    rateController.dispose();
  }
}

/// The "Item Table" section: a responsive line-item editor that renders as a
/// desktop-style table above [AppBreakpoints.tablet] and stacks into
/// per-item cards on phones so quantity/rate/tax/amount stay reachable.
class QuoteItemTable extends StatelessWidget {
  const QuoteItemTable({
    required this.lines,
    required this.catalog,
    required this.onChanged,
    required this.onAddRow,
    required this.onAddRows,
    required this.onRemoveRow,
    required this.onClearAll,
    this.showInlineActionButtons = true,
    super.key,
  });

  final List<QuoteLineItem> lines;
  final List<BookItem> catalog;
  final VoidCallback onChanged;
  final VoidCallback onAddRow;
  final ValueChanged<List<BookItem>> onAddRows;
  final ValueChanged<int> onRemoveRow;
  final VoidCallback onClearAll;

  /// When false, hides the "Add New Row" / "Add Items in Bulk" buttons below
  /// the table so a caller can offer an equivalent action elsewhere (e.g. a
  /// mobile floating action button).
  final bool showInlineActionButtons;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Icon(Icons.check_box, color: AppColors.active, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Item Table', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ),
          PopupMenuButton<String>(
            tooltip: 'Bulk Actions',
            onSelected: (value) {
              if (value == 'clear') onClearAll();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'clear', child: Text('Clear all rows')),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Bulk Actions', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                  Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= AppBreakpoints.tablet;
          return DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.divider),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                if (desktop) const _TableHeader(),
                for (var i = 0; i < lines.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: desktop
                        ? _DesktopRow(
                            index: i,
                            line: lines[i],
                            catalog: catalog,
                            onChanged: onChanged,
                            onRemove: () => onRemoveRow(i),
                            showDivider: i > 0,
                          )
                        : _MobileCard(
                            key: ValueKey(lines[i]),
                            index: i,
                            line: lines[i],
                            catalog: catalog,
                            onChanged: onChanged,
                            onRemove: () => onRemoveRow(i),
                          ),
                  ),
                if (lines.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text('No items added yet.', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      if (showInlineActionButtons) ...[
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: onAddRow,
              icon: const Icon(Icons.add, size: 18),
              label: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text('Add New Row'), SizedBox(width: 4), Icon(Icons.keyboard_arrow_down, size: 16)],
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _showBulkAddDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Items in Bulk'),
            ),
          ],
        ),
      ],
    ],
  );

  Future<void> _showBulkAddDialog(BuildContext context) async {
    final result = await showBulkAddItemsDialog(context, catalog);
    if (result != null && result.isNotEmpty) onAddRows(result);
  }
}

/// Shows the "Add Items in Bulk" catalog picker and resolves to the selected
/// items (or null/empty if cancelled). Shared by [QuoteItemTable]'s own
/// "Add Items in Bulk" button and by callers that supply their own trigger
/// (e.g. a mobile floating action button) when [QuoteItemTable
/// .showInlineActionButtons] is false.
Future<List<BookItem>?> showBulkAddItemsDialog(BuildContext context, List<BookItem> catalog) {
  final selected = <BookItem>{};
  return showDialog<List<BookItem>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Add Items in Bulk'),
        content: SizedBox(
          width: 380,
          child: catalog.isEmpty
              ? const Text('No catalog items available.')
              : ListView(
                  shrinkWrap: true,
                  children: catalog
                      .map(
                        (item) => CheckboxListTile(
                          dense: true,
                          value: selected.contains(item),
                          title: Text(item.name),
                          subtitle: Text('₹${item.rate.toStringAsFixed(2)}'),
                          onChanged: (checked) => setDialogState(() {
                            if (checked ?? false) {
                              selected.add(item);
                            } else {
                              selected.remove(item);
                            }
                          }),
                        ),
                      )
                      .toList(),
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, selected.toList()),
            child: const Text('Add Selected'),
          ),
        ],
      ),
    ),
  );
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();
  static const _style = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.3);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: const BoxDecoration(
      color: AppColors.canvas,
      border: Border(bottom: BorderSide(color: AppColors.divider)),
    ),
    child: const Row(
      children: [
        SizedBox(width: 24),
        SizedBox(width: 40),
        Expanded(flex: 4, child: Text('ITEM DETAILS', style: _style)),
        SizedBox(width: 12),
        Expanded(flex: 2, child: Text('QUANTITY', style: _style)),
        SizedBox(width: 12),
        Expanded(flex: 2, child: Text('RATE', style: _style)),
        SizedBox(width: 12),
        Expanded(flex: 2, child: Text('TAX', style: _style)),
        SizedBox(width: 12),
        Expanded(flex: 2, child: Text('AMOUNT', textAlign: TextAlign.right, style: _style)),
        SizedBox(width: 36),
      ],
    ),
  );
}

class _DesktopRow extends StatelessWidget {
  const _DesktopRow({
    required this.index,
    required this.line,
    required this.catalog,
    required this.onChanged,
    required this.onRemove,
    required this.showDivider,
  });

  final int index;
  final QuoteLineItem line;
  final List<BookItem> catalog;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final bool showDivider;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (showDivider) const Padding(padding: EdgeInsets.only(bottom: 10), child: Divider(height: 1)),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Icon(Icons.drag_indicator, size: 18, color: AppColors.textSecondary),
            ),
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(top: 6, right: 8),
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.divider),
              ),
              child: const Icon(Icons.image_outlined, size: 16, color: AppColors.textSecondary),
            ),
            Expanded(
              flex: 4,
              child: SearchableField<BookItem>(
                label: '',
                hintText: 'Type or click to select an item.',
                controller: line.itemController,
                options: catalog,
                displayStringForOption: (item) => item.name,
                optionSubtitle: (item) => '₹${item.rate.toStringAsFixed(2)} · ${item.unit}',
                onSelected: (item) {
                  line.item = item;
                  line.rateController.text = item.rate.toStringAsFixed(2);
                  line.taxPercent = item.taxRate;
                  onChanged();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: _numberField(line.quantityController, onChanged)),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: _numberField(line.rateController, onChanged, prefix: '₹')),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: _TaxDropdown(line: line, onChanged: onChanged)),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  '₹${line.amount.toStringAsFixed(2)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            SizedBox(
              width: 36,
              child: IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Remove row',
                onPressed: onRemove,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Compact, collapsible line-item card used on mobile widths. Collapsed, it
/// shows just the item name / quantity / rate / amount summary requested by
/// the mobile UX spec; tapping it (or the chevron) expands it into the full
/// editable row so multiple items don't turn the page into a long scroll.
class _MobileCard extends StatefulWidget {
  const _MobileCard({
    super.key,
    required this.index,
    required this.line,
    required this.catalog,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final QuoteLineItem line;
  final List<BookItem> catalog;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  State<_MobileCard> createState() => _MobileCardState();
}

class _MobileCardState extends State<_MobileCard> {
  // New/empty rows start expanded since the user is actively filling them
  // in; rows that already carry data collapse to their compact summary.
  late bool _expanded = widget.line.isEmpty;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    final title = line.itemController.text.trim().isEmpty ? 'Item ${widget.index + 1}' : line.itemController.text.trim();
    return Container(
      padding: const EdgeInsets.all(12),
      margin: EdgeInsets.only(bottom: widget.index == 0 ? 0 : 4),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                const Icon(Icons.drag_indicator, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                if (!_expanded) ...[
                  Text('₹${line.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(width: 2),
                ],
                IconButton(
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  tooltip: _expanded ? 'Collapse item' : 'Expand item',
                  onPressed: _toggle,
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Remove row',
                  onPressed: widget.onRemove,
                ),
              ],
            ),
          ),
          if (!_expanded)
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 2),
              child: Text(
                'Qty ${line.quantity.toStringAsFixed(line.quantity == line.quantity.roundToDouble() ? 0 : 2)}  ·  Rate ₹${line.rate.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            SearchableField<BookItem>(
              label: 'Item details',
              hintText: 'Type or click to select an item.',
              controller: line.itemController,
              options: widget.catalog,
              displayStringForOption: (item) => item.name,
              optionSubtitle: (item) => '₹${item.rate.toStringAsFixed(2)} · ${item.unit}',
              onSelected: (item) {
                line.item = item;
                line.rateController.text = item.rate.toStringAsFixed(2);
                line.taxPercent = item.taxRate;
                widget.onChanged();
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _numberField(line.quantityController, widget.onChanged, label: 'Quantity')),
                const SizedBox(width: 10),
                Expanded(child: _numberField(line.rateController, widget.onChanged, label: 'Rate', prefix: '₹')),
              ],
            ),
            const SizedBox(height: 10),
            _TaxDropdown(line: line, onChanged: widget.onChanged, label: 'Tax'),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Amount: ₹${line.amount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Widget _numberField(TextEditingController controller, VoidCallback onChanged, {String? label, String? prefix}) => TextFormField(
  controller: controller,
  keyboardType: const TextInputType.numberWithOptions(decimal: true),
  onChanged: (_) => onChanged(),
  decoration: InputDecoration(
    labelText: label,
    isDense: true,
    prefixText: prefix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
  ),
);

class _TaxDropdown extends StatelessWidget {
  const _TaxDropdown({required this.line, required this.onChanged, this.label});
  final QuoteLineItem line;
  final VoidCallback onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<double>(
    initialValue: quoteTaxRateOptions.contains(line.taxPercent) ? line.taxPercent : 0,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      suffixIcon: const Padding(
        padding: EdgeInsets.only(right: 4),
        child: Tooltip(message: 'Tax rate applied to this line item', child: Icon(Icons.info_outline, size: 16)),
      ),
    ),
    items: quoteTaxRateOptions
        .map((rate) => DropdownMenuItem(value: rate, child: Text(taxRateLabel(rate), overflow: TextOverflow.ellipsis)))
        .toList(),
    onChanged: (value) {
      line.taxPercent = value ?? 0;
      onChanged();
    },
  );
}
