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

/// Shared empty state for the Transactions/History tabs — no per-item
/// transaction linkage exists in the data model yet.
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
