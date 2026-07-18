import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../screens/bom/bom_details_screen.dart';
import '../domain/books_repository.dart';
import 'books_pages.dart' show money;

/// Overview tab: image upload first, followed by the item details.
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (constraints.maxWidth < AppBreakpoints.laptop)
                image
              else
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(width: 260, child: image),
                ),
              const SizedBox(height: 16),
              details,
              const SizedBox(height: 16),
              const ItemProductDetailsCard(),
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
  static const _pullingSwivelImage = AssetImage(_pullingSwivelAsset);

  void _openPullingSwivel(BuildContext context) {
    precacheImage(_pullingSwivelImage, context);
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const _PullingSwivelViewer(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: .96, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: DottedImageDropZone(
        imageAsset: item.name == '3.5" Pulling Swivel'
            ? _pullingSwivelAsset
            : null,
        onImageTap: item.name == '3.5" Pulling Swivel'
            ? () => _openPullingSwivel(context)
            : null,
        onBrowse: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image upload is not available yet')),
        ),
      ),
    ),
  );
}

class DottedImageDropZone extends StatelessWidget {
  const DottedImageDropZone({
    this.imageAsset,
    this.onBrowse,
    this.onImageTap,
    super.key,
  });
  final String? imageAsset;
  final VoidCallback? onBrowse;
  final VoidCallback? onImageTap;

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
                   Semantics(
                     button: onImageTap != null,
                     label: 'Open exploded pulling swivel inspection',
                     child: InkWell(
                       onTap: onImageTap,
                       child: Hero(
                         tag: 'pulling-swivel-exploded-image',
                         child: Padding(
                           padding: const EdgeInsets.all(12),
                           child: Image.asset(imageAsset!, fit: BoxFit.contain),
                         ),
                       ),
                     ),
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
  const _SwivelPart(this.name, this.anchor, this.label, {this.curve = 0});

  final String name;
  final Offset anchor;
  final Offset label;
  final double curve;
}

const _swivelParts = <_SwivelPart>[
  _SwivelPart('Shaft', Offset(.189, .250), Offset(.09, .40), curve: -.08),
  _SwivelPart('Bearing Housing', Offset(.378, .196), Offset(.32, .08)),
  _SwivelPart('Oil Seal', Offset(.294, .610), Offset(.10, .76), curve: .08),
  _SwivelPart('Bearing', Offset(.467, .626), Offset(.40, .90), curve: -.06),
  _SwivelPart('Lock Nut', Offset(.504, .357), Offset(.53, .21), curve: .05),
  _SwivelPart('Depth Screw R15', Offset(.626, .191), Offset(.76, .08), curve: .08),
  _SwivelPart('Housing Lock Nut', Offset(.701, .650), Offset(.80, .80), curve: -.08),
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

  void _select(int index) => _selection.value = {index};

  @override
  Widget build(BuildContext context) {
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
                    padding: const EdgeInsets.fromLTRB(28, 64, 28, 28),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 1200,
                        maxHeight: 760,
                      ),
                      child: _SwivelInspectionCanvas(
                        selection: _selection,
                        onSelect: _select,
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
      final geometry = _SwivelGeometry(size);
      return RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fromRect(
              rect: geometry.imageRect,
              child: Hero(
                tag: 'pulling-swivel-exploded-image',
                child: Image.asset(
                  ItemImagePanel._pullingSwivelAsset,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            ListenableBuilder(
              listenable: selection,
              builder: (context, child) => CustomPaint(
                painter: _CalloutPainter(selection.value, geometry),
              ),
            ),
            for (var index = 0; index < _swivelParts.length; index++) ...[
              _ComponentTarget(
                part: _swivelParts[index],
                geometry: geometry,
                onTap: () => onSelect(index),
              ),
              _PartCallout(
                index: index,
                part: _swivelParts[index],
                geometry: geometry,
                selection: selection,
                onTap: () {
                  onSelect(index);
                  // Pass only the selected diagram part into its BOM view.
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BomDetailsScreen(
                        partIdentifier: _swivelParts[index].name,
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      );
    },
  );
}
class _SwivelGeometry {
  const _SwivelGeometry(this.size);

  final Size size;

  Rect get imageRect {
    const imageRatio = 1974 / 797;
    // Keep open canvas around the assembly so labels can occupy independent
    // zones instead of competing with the mechanical detail.
    final maxWidth = size.width * (size.width < 600 ? .86 : .78);
    final maxHeight = size.height * (size.width < 600 ? .34 : .52);
    final width = maxWidth.clamp(0.0, maxHeight * imageRatio).toDouble();
    final height = width / imageRatio;
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: width,
      height: height,
    );
  }

  Offset anchorFor(_SwivelPart part) => Offset(
    imageRect.left + (part.anchor.dx * imageRect.width),
    imageRect.top + (part.anchor.dy * imageRect.height),
  );

  Rect labelRectFor(_SwivelPart part) {
    final width = (size.width * .30).clamp(110.0, 150.0).toDouble();
    const height = 48.0;
    final center = Offset(
      (part.label.dx * size.width)
          .clamp(width / 2, size.width - width / 2)
          .toDouble(),
      (part.label.dy * size.height)
          .clamp(height / 2, size.height - height / 2)
          .toDouble(),
    );
    return Rect.fromCenter(center: center, width: width, height: height);
  }
}

class _ComponentTarget extends StatelessWidget {
  const _ComponentTarget({
    required this.part,
    required this.geometry,
    required this.onTap,
  });

  final _SwivelPart part;
  final _SwivelGeometry geometry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Positioned.fromRect(
    rect: Rect.fromCircle(center: geometry.anchorFor(part), radius: 24),
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
    required this.geometry,
    required this.selection,
    required this.onTap,
  });

  final int index;
  final _SwivelPart part;
  final _SwivelGeometry geometry;
  final ValueListenable<Set<int>> selection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Positioned.fromRect(
    rect: geometry.labelRectFor(part),
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
              color: selected
                  ? colors.primary.withValues(alpha: .88)
                  : colors.surface.withValues(alpha: .78),
              shape: StadiumBorder(
                side: BorderSide(
                  color: selected ? colors.primary : colors.outline,
                ),
              ),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
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
  const _CalloutPainter(this.selection, this.geometry);

  final Set<int> selection;
  final _SwivelGeometry geometry;

  @override
  void paint(Canvas canvas, Size size) {
    for (var index = 0; index < _swivelParts.length; index++) {
      final part = _swivelParts[index];
      final active = selection.contains(index);
      final anchor = geometry.anchorFor(part);
      final label = geometry.labelRectFor(part).center;
      final color = active ? AppColors.primary : AppColors.active;
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = active ? 1.5 : 1
        ..style = PaintingStyle.stroke;
      final delta = label - anchor;
      final midpoint = Offset(
        (anchor.dx + label.dx) / 2,
        (anchor.dy + label.dy) / 2,
      );
      final control = midpoint + Offset(-delta.dy, delta.dx) * part.curve;
      final connector = Path()
        ..moveTo(anchor.dx, anchor.dy)
        ..quadraticBezierTo(control.dx, control.dy, label.dx, label.dy);
      canvas.drawPath(connector, linePaint);
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
      oldDelegate.selection != selection || oldDelegate.geometry.size != geometry.size;
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

/// Read-only product information displayed within the Overview tab.
class ItemProductDetailsCard extends StatelessWidget {
  const ItemProductDetailsCard({super.key});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DetailRow('Product', 'Gear Shaft Assembly'),
          const DetailRow('Drawing', 'GS-1001.pdf'),
          const DetailRow('Product Name', 'Industrial Gear Shaft'),
          const DetailRow('Master Serial No.', 'MSN-GS-001'),
          const DetailRow('Part No.', 'GS-1001'),
        ],
      ),
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
