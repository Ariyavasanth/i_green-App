import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../screens/bom/bom_details_screen.dart';
import '../domain/books_repository.dart';
import 'books_pages.dart' show money;

/// Overview tab: item fields on the left, image panel on the right (desktop),
/// stacked vertically on mobile — matching the reference layout.
class ItemOverviewTab extends StatelessWidget {
  const ItemOverviewTab({required this.item, super.key});
  final BookItem item;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final gutter = AppLayout.gutter(constraints.maxWidth);
      final details = ItemDetailsCard(item: item);
      final image = ItemImagePanel(item: item);
      return SingleChildScrollView(
        padding: EdgeInsets.all(gutter),
        child: ResponsiveContent(
          child: constraints.maxWidth < AppBreakpoints.laptop
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [details, const SizedBox(height: 16), image],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: details),
                    const SizedBox(width: 20),
                    SizedBox(width: 260, child: image),
                  ],
                ),
        ),
      );
    },
  );
}

class ItemDetailsCard extends StatelessWidget {
  const ItemDetailsCard({required this.item, super.key});
  final BookItem item;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DetailRow('Item Type', item.type == 'Service' ? 'Sales and Purchase Services' : 'Sales and Purchase Items'),
          if (item.name == '3.5" Pulling Swivel')
            const DetailRow('Category', 'Pulling Accessories'),
          DetailRow('HSN Code', item.hsnCode.isEmpty ? '-' : item.hsnCode),
          const DetailRow('Created Source', 'User'),
          const DetailRow('Tax Preference', 'Taxable'),
          DetailRow(
            'Intra State Tax Rate',
            'GST${item.taxRate.toStringAsFixed(0)} (${item.taxRate.toStringAsFixed(0)} %)',
          ),
          DetailRow(
            'Inter State Tax Rate',
            'IGST${item.taxRate.toStringAsFixed(0)} (${item.taxRate.toStringAsFixed(0)} %)',
          ),
          const DetailSectionTitle('Purchase Information'),
          DetailRow('Cost Price', money.format(item.costPrice)),
          const DetailRow('Purchase Account', 'Cost of Goods Sold'),
          const DetailSectionTitle('Sales Information'),
          DetailRow('Selling Price', money.format(item.rate)),
          const DetailRow('Sales Account', 'Sales'),
          const DetailSectionTitle('Reporting Tags'),
          const Text(
            'No reporting tag has been associated with this item.',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    ),
  );
}
class DetailSectionTitle extends StatelessWidget {
  const DetailSectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(text, style: AppTextStyles.heading),
        const SizedBox(height: 12),
        const Divider(height: 1),
      ],
    ),
  );
}

class DetailRow extends StatelessWidget {
  const DetailRow(this.label, this.value, {super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 170, child: Text(label, style: AppTextStyles.caption)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

/// Non-functional image placeholder/upload affordance, matching the reference
/// design. No image picking dependency exists in this project, so "Browse
/// images" surfaces a lightweight acknowledgement rather than a real picker.
class ItemImagePanel extends StatelessWidget {
  const ItemImagePanel({required this.item, super.key});

  final BookItem item;

  static const _pullingSwivelAsset =
      'assets/images/3_5_pulling_swivel.png';

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: DottedImageDropZone(
        imageAsset: item.name == '3.5" Pulling Swivel'
            ? _pullingSwivelAsset
            : null,
        onBrowse: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image upload is not available yet')),
        ),
      ),
    ),
  );
}

class DottedImageDropZone extends StatelessWidget {
  const DottedImageDropZone({this.imageAsset, this.onBrowse, super.key});
  final String? imageAsset;
  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: imageAsset != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Image.asset(imageAsset!, fit: BoxFit.contain),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: TextButton(
                      onPressed: onBrowse,
                      child: const Text('Browse images'),
                    ),
                  ),
                ],
              ),
            )
          : Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.image_outlined,
                size: 32,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              const Text(
                'Drag image(s) here or',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
              TextButton(
                onPressed: onBrowse,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Browse images'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SwivelPart {
  const _SwivelPart(this.name, this.anchor, this.label);

  final String name;
  final Offset anchor;
  final Offset label;
}

const _swivelParts = <_SwivelPart>[
  _SwivelPart('Shaft', Offset(.29, .39), Offset(.10, .20)),
  _SwivelPart('Bearing Shaft', Offset(.53, .48), Offset(.42, .72)),
  _SwivelPart('Bearing Housing', Offset(.43, .34), Offset(.36, .08)),
  _SwivelPart('Oil Seal', Offset(.34, .68), Offset(.12, .84)),
  _SwivelPart('Bearing', Offset(.47, .58), Offset(.47, .86)),
  _SwivelPart('Lock Nut', Offset(.56, .43), Offset(.57, .15)),
  _SwivelPart('Depth Screw R15', Offset(.62, .31), Offset(.73, .10)),
  _SwivelPart('Housing Lock Nut', Offset(.70, .67), Offset(.84, .84)),
];

class _PullingSwivelViewer extends StatefulWidget {
  const _PullingSwivelViewer();

  @override
  State<_PullingSwivelViewer> createState() => _PullingSwivelViewerState();
}

class _PullingSwivelViewerState extends State<_PullingSwivelViewer> {
  final ValueNotifier<Set<int>> _selection = ValueNotifier(
    Set<int>.from(List<int>.generate(_swivelParts.length, (index) => index)),
  );

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  void _select(int index) {
    _selection.value = {index};
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BomDetailsScreen(
          partIdentifier: _swivelParts[index].name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: ColoredBox(
          color: Colors.black.withValues(alpha: .58),
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 52, 12, 16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Material(
                        elevation: 18,
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        child: AspectRatio(
                          aspectRatio: 1974 / 797,
                          child: _SwivelInspectionCanvas(
                            selection: _selection,
                            onSelect: _select,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 12,
                  child: Semantics(
                    button: true,
                    label: 'Close exploded view',
                    child: IconButton.filled(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SwivelInspectionCanvas extends StatelessWidget {
  const _SwivelInspectionCanvas({
    required this.selection,
    required this.onSelect,
  });

  final ValueListenable<Set<int>> selection;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      return RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'pulling-swivel-exploded-image',
              child: Image.asset(
                ItemImagePanel._pullingSwivelAsset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
            ListenableBuilder(
              listenable: selection,
              builder: (context, child) => CustomPaint(
                painter: _CalloutPainter(selection.value),
              ),
            ),
            for (var index = 0; index < _swivelParts.length; index++) ...[
              _ComponentTarget(
                part: _swivelParts[index],
                canvasSize: size,
                onTap: () => onSelect(index),
              ),
              _PartCallout(
                index: index,
                part: _swivelParts[index],
                canvasSize: size,
                selection: selection,
                onTap: () => onSelect(index),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _ComponentTarget extends StatelessWidget {
  const _ComponentTarget({
    required this.part,
    required this.canvasSize,
    required this.onTap,
  });

  final _SwivelPart part;
  final Size canvasSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Positioned(
    left: part.anchor.dx * canvasSize.width - 24,
    top: part.anchor.dy * canvasSize.height - 24,
    width: 48,
    height: 48,
    child: Semantics(
      button: true,
      label: '${part.name} component',
      child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: onTap),
    ),
  );
}

class _PartCallout extends StatelessWidget {
  const _PartCallout({
    required this.index,
    required this.part,
    required this.canvasSize,
    required this.selection,
    required this.onTap,
  });

  final int index;
  final _SwivelPart part;
  final Size canvasSize;
  final ValueListenable<Set<int>> selection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Positioned(
    left: part.label.dx * canvasSize.width - 70,
    top: part.label.dy * canvasSize.height - 24,
    width: 140,
    height: 48,
    child: Center(
      child: ListenableBuilder(
        listenable: selection,
        builder: (context, child) {
          final selected = selection.value.contains(index);
          final colors = Theme.of(context).colorScheme;
          return Semantics(
            button: true,
            selected: selected,
            label: part.name,
            child: Material(
              animationDuration: const Duration(milliseconds: 180),
              color: selected ? colors.primary : colors.surface,
              shape: StadiumBorder(
                side: BorderSide(
                  color: selected ? colors.primary : colors.outline,
                ),
              ),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  child: Text(
                    part.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? colors.onPrimary
                          : colors.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _CalloutPainter extends CustomPainter {
  const _CalloutPainter(this.selection);

  final Set<int> selection;

  @override
  void paint(Canvas canvas, Size size) {
    for (var index = 0; index < _swivelParts.length; index++) {
      final part = _swivelParts[index];
      final active = selection.contains(index);
      final anchor = Offset(
        part.anchor.dx * size.width,
        part.anchor.dy * size.height,
      );
      final label = Offset(
        part.label.dx * size.width,
        part.label.dy * size.height,
      );
      final color = active ? AppColors.primary : AppColors.active;
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = active ? 1.5 : 1
        ..style = PaintingStyle.stroke;
      canvas.drawLine(anchor, label, linePaint);
      canvas.drawCircle(anchor, 3, Paint()..color = color);
      if (active) {
        canvas.drawCircle(
          anchor,
          13,
          Paint()
            ..color = AppColors.primary.withValues(alpha: .24)
            ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CalloutPainter oldDelegate) =>
      oldDelegate.selection != selection;
}

/// Original product image for the Product Details tab.
class LabeledSwivelDiagram extends StatelessWidget {
  const LabeledSwivelDiagram({super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.canvas,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.divider),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 1974 / 797,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Image.asset(
            ItemImagePanel._pullingSwivelAsset,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    ),
  );
}

/// Responsive transaction filters and empty state. Transaction linkage is not
/// added here so the existing data and business behavior remain unchanged.
class ItemTransactionsTab extends StatefulWidget {
  const ItemTransactionsTab({super.key});

  @override
  State<ItemTransactionsTab> createState() => _ItemTransactionsTabState();
}

class _ItemTransactionsTabState extends State<ItemTransactionsTab> {
  static const _transactionTypes = [
    'Quotes',
    'Sales Orders',
    'Invoices',
    'Delivery Challans',
    'Credit Notes',
    'Recurring Invoices',
    'Purchase Orders',
    'Bills',
    'Vendor Credits',
  ];

  String _selectedType = _transactionTypes.first;
  String _selectedStatus = 'All';

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final isDesktop = constraints.maxWidth >= AppBreakpoints.laptop;
      final gutter = AppLayout.gutter(constraints.maxWidth);

      return ResponsiveContent(
        child: Padding(
          padding: EdgeInsets.all(gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFilters(constraints.maxWidth - (gutter * 2), isDesktop),
              Expanded(
                child: _TransactionEmptyState(
                  transactionType: _selectedType,
                  // The desktop reference uses a restrained text-only state.
                  showIcon: !isDesktop,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _buildFilters(double availableWidth, bool isDesktop) {
    final typeFilter = TransactionFilterDropdown(
      label: 'Filter By',
      value: _selectedType,
      items: _transactionTypes,
      onChanged: (value) => setState(() => _selectedType = value),
    );
    final statusFilter = TransactionFilterDropdown(
      label: 'Status',
      value: _selectedStatus,
      items: const ['All'],
      onChanged: (value) => setState(() => _selectedStatus = value),
    );

    if (isDesktop) {
      return Row(
        children: [
          SizedBox(width: 190, child: typeFilter),
          const SizedBox(width: 10),
          SizedBox(width: 130, child: statusFilter),
        ],
      );
    }

    // Keep both controls aligned on phones; stack only when the viewport is
    // too narrow to retain comfortable touch targets.
    if (availableWidth >= 280) {
      return Row(
        children: [
          Expanded(flex: 3, child: typeFilter),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: statusFilter),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [typeFilter, const SizedBox(height: 10), statusFilter],
    );
  }
}

class TransactionFilterDropdown extends StatelessWidget {
  const TransactionFilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    super.key,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
    ),
    // Build the closed field as one row so its label and value cannot overlap.
    selectedItemBuilder: (context) => items
        .map(
          (item) => Row(
            children: [
              Text('$label: ', style: AppTextStyles.caption),
              Expanded(
                child: Text(
                  item,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        )
        .toList(),
    items: items
        .map(
          (item) => DropdownMenuItem(
            value: item,
            child: Text(
              item,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body,
            ),
          ),
        )
        .toList(),
    onChanged: (selection) {
      if (selection != null) onChanged(selection);
    },
  );
}

class _TransactionEmptyState extends StatelessWidget {
  const _TransactionEmptyState({
    required this.transactionType,
    required this.showIcon,
  });

  final String transactionType;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final type = transactionType.toLowerCase();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...const [
            Icon(
              Icons.receipt_long_outlined,
              size: 52,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 16),
          ],
          Text(
            showIcon ? 'No transactions to display' : 'There are no $type',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Shared empty state for tabs that do not require additional controls.
class ItemEmptyTab extends StatelessWidget {
  const ItemEmptyTab({required this.message, super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.receipt_long_outlined,
          size: 46,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: 12),
        Text(message, style: AppTextStyles.caption),
      ],
    ),
  );
}

/// Read-only product information using the same card and row treatment as the
/// existing Overview tab, with the image panel shown above the fields.
class ItemProductDetailsTab extends StatefulWidget {
  const ItemProductDetailsTab({required this.item, super.key});

  final BookItem item;

  @override
  State<ItemProductDetailsTab> createState() => _ItemProductDetailsTabState();
}

class _ItemProductDetailsTabState extends State<ItemProductDetailsTab> {
  bool _arePartsVisible = false;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final gutter = AppLayout.gutter(constraints.maxWidth);
      final image = Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const LabeledSwivelDiagram(),
              const SizedBox(height: 16),
              _PartsDropdown(
                isExpanded: _arePartsVisible,
                onPressed: () => setState(
                  () => _arePartsVisible = !_arePartsVisible,
                ),
                onPartSelected: (partIdentifier) => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BomDetailsScreen(
                      partIdentifier: partIdentifier,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      final fields = Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              DetailRow('Product', 'Gear Shaft Assembly'),
              DetailRow('Drawing', 'GS-1001.pdf'),
              DetailRow('Product Name', 'Industrial Gear Shaft'),
              DetailRow('Master Serial No.', 'MSN-GS-001'),
              DetailRow('Part No.', 'GS-1001'),
            ],
          ),
        ),
      );

      return SingleChildScrollView(
        padding: EdgeInsets.all(gutter),
        child: ResponsiveContent(
          child: constraints.maxWidth < AppBreakpoints.laptop
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [image, const SizedBox(height: 16), fields],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 260, child: image),
                    const SizedBox(width: 20),
                    Expanded(flex: 3, child: fields),
                  ],
                ),
        ),
      );
    },
  );
}

class _PartsDropdown extends StatelessWidget {
  const _PartsDropdown({
    required this.isExpanded,
    required this.onPressed,
    required this.onPartSelected,
  });

  final bool isExpanded;
  final VoidCallback onPressed;
  final ValueChanged<String> onPartSelected;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.divider),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: const Key('view-parts-toggle'),
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'View Parts',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: isExpanded ? .5 : 0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: const Icon(Icons.keyboard_arrow_down, size: 22),
                ),
              ],
            ),
          ),
        ),
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Column(
                    key: const Key('parts-list'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Divider(height: 1),
                      for (final part in _swivelParts)
                        InkWell(
                          onTap: () => onPartSelected(part.name),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            child: Text(
                              part.name,
                              style: AppTextStyles.body,
                            ),
                          ),
                        ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ),
      ],
    ),
  );
}

/// BOM information. Size and Quantity are intentionally the only editable
/// fields; the remaining values stay read-only.
class ItemBomTab extends StatefulWidget {
  const ItemBomTab({required this.item, super.key});

  final BookItem item;

  @override
  State<ItemBomTab> createState() => _ItemBomTabState();
}

class _ItemBomTabState extends State<ItemBomTab> {
  @override
  Widget build(BuildContext context) => _ItemFieldsTab(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DetailRow('Part Name', 'Gear Shaft'),
        const DetailRow('Drawing', 'Gear Shaft Drawing'),
        const DetailRow('Drawing No.', 'DRW-GS-1001'),
        const DetailRow('Part No.', 'GS-1001-P01'),
        const DetailRow('Raw Material (RM)', 'Alloy Steel Round Bar'),
        const DetailRow('Material Grade', 'EN19'),
        const _EditableDetailRow(label: 'Size', initialValue: '50 x 300 mm'),
        const _EditableDetailRow(
          label: 'Quantity',
          initialValue: '2',
          keyboardType: TextInputType.numberWithOptions(decimal: true),
        ),
        const DetailRow('Child Part / Outsourcing', 'Outsourcing'),
        const DetailRow('Vendor (if outsourced)', 'Precision Heat Treaters'),
      ],
    ),
  );
}

/// Read-only process information, ready for repository-backed values when the
/// item model exposes them.
class ItemProcessFlowTab extends StatelessWidget {
  const ItemProcessFlowTab({super.key});

  @override
  Widget build(BuildContext context) => const _ItemFieldsTab(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailRow('Operation No.', '10'),
        DetailRow('Operation Name', 'Turning'),
        DetailRow('Machine', 'CNC Lathe'),
        DetailRow('Standard Duration (min)', '45'),
        DetailRow('Vendor Job', 'No'),
        DetailRow('Vendor Name', '-'),
      ],
    ),
  );
}

class _ItemFieldsTab extends StatelessWidget {
  const _ItemFieldsTab({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: EdgeInsets.all(AppLayout.gutter(constraints.maxWidth)),
      child: ResponsiveContent(
        child: Card(
          child: Padding(padding: const EdgeInsets.all(20), child: child),
        ),
      ),
    ),
  );
}

class _EditableDetailRow extends StatelessWidget {
  const _EditableDetailRow({
    required this.label,
    this.initialValue,
    this.keyboardType,
  });

  final String label;
  final String? initialValue;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final field = TextFormField(
          initialValue: initialValue,
          keyboardType: keyboardType,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          decoration: const InputDecoration(isDense: true),
        );

        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: AppTextStyles.caption),
              const SizedBox(height: 8),
              field,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 170,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(label, style: AppTextStyles.caption),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: field),
          ],
        );
      },
    ),
  );
}

