import 'package:flutter/material.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
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
      final image = const ItemImagePanel();
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
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
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
  const ItemImagePanel({super.key});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: DottedImageDropZone(
        onBrowse: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image upload is not available yet')),
        ),
      ),
    ),
  );
}

class DottedImageDropZone extends StatelessWidget {
  const DottedImageDropZone({this.onBrowse, super.key});
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
      child: Center(
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
            style: AppTextStyles.caption.copyWith(fontSize: 14),
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
/// existing Overview tab.
class ItemProductDetailsTab extends StatelessWidget {
  const ItemProductDetailsTab({required this.item, super.key});

  final BookItem item;

  @override
  Widget build(BuildContext context) => _ItemFieldsTab(
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
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: const InputDecoration(isDense: true),
        );

        // Stack on narrow screens so labels and editable fields remain usable.
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
