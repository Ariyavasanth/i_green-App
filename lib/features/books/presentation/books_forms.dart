import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/layout/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/visual_effects.dart';
import '../domain/books_repository.dart';
import '../providers/books_providers.dart';

class NewItemPage extends ConsumerStatefulWidget {
  const NewItemPage({super.key});
  @override
  ConsumerState<NewItemPage> createState() => _NewItemState();
}

class _NewItemState extends ConsumerState<NewItemPage> {
  final name = TextEditingController(),
      sku = TextEditingController(),
      rate = TextEditingController(),
      hsnCode = TextEditingController(),
      salesDescription = TextEditingController(),
      costPrice = TextEditingController(),
      purchaseDescription = TextEditingController();
  bool saving = false;
  bool trackInventory = false;
  String itemType = 'Goods';
  @override
  void dispose() {
    name.dispose();
    sku.dispose();
    rate.dispose();
    hsnCode.dispose();
    salesDescription.dispose();
    costPrice.dispose();
    purchaseDescription.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormPage(
    title: 'New Item',
    saving: saving,
    onSave: save,
    maxWidth: 1120,
    children: [
      const SectionTitle('Basic Information'),
      LayoutBuilder(
        builder: (context, constraints) {
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              field(name, 'Name*'),
              const SizedBox(height: 14),
              const Text('Type'),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Goods', label: Text('Goods')),
                  ButtonSegment(value: 'Service', label: Text('Service')),
                ],
                selected: {itemType},
                onSelectionChanged: (values) =>
                    setState(() => itemType = values.first),
              ),
              const SizedBox(height: 14),
              field(sku, 'SKU'),
              const SizedBox(height: 14),
              const StaticSelect('Unit', 'pcs'),
              const SizedBox(height: 14),
              field(hsnCode, 'HSN Code'),
              const SizedBox(height: 14),
              const StaticSelect('Tax Preference*', 'Taxable'),
            ],
          );
          // The reference moves the image beside basic fields on wide screens.
          if (constraints.maxWidth < AppBreakpoints.laptop) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                details,
                const SizedBox(height: 18),
                const ItemImageUpload(),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: details),
              const SizedBox(width: 32),
              const Expanded(flex: 2, child: ItemImageUpload()),
            ],
          );
        },
      ),
      const SizedBox(height: 28),
      LayoutBuilder(
        builder: (context, constraints) {
          final sales = _ItemInfoSection(
            title: 'Sales Information',
            children: [
              field(rate, 'Selling Price*', prefix: 'INR', number: true),
              const SizedBox(height: 14),
              field(salesDescription, 'Description', lines: 3),
              const SizedBox(height: 14),
              const StaticSelect('Account*', 'Sales'),
            ],
          );
          final purchase = _ItemInfoSection(
            title: 'Purchase Information',
            children: [
              field(costPrice, 'Cost Price', prefix: 'INR', number: true),
              const SizedBox(height: 14),
              field(purchaseDescription, 'Description', lines: 3),
              const SizedBox(height: 14),
              const StaticSelect('Account*', 'Cost of Goods Sold'),
              const SizedBox(height: 14),
              const StaticSelect('Preferred Vendor', 'Select a vendor'),
            ],
          );
          if (constraints.maxWidth < AppBreakpoints.tablet) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [sales, const SizedBox(height: 28), purchase],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: sales),
              const SizedBox(width: 28),
              Expanded(child: purchase),
            ],
          );
        },
      ),
      const SizedBox(height: 28),
      const SectionTitle('Default Tax Rates'),
      const ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Intra State Tax Rate'),
        trailing: Text('GST18 (18 %)'),
      ),
      const ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Inter State Tax Rate'),
        trailing: Text('IGST18 (18 %)'),
      ),
      const SizedBox(height: 18),
      const SectionTitle('Inventory'),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: trackInventory,
        onChanged: (value) => setState(() => trackInventory = value ?? false),
        title: const Text('Track Inventory for this item'),
        subtitle: const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'You cannot enable/disable inventory tracking once you\'ve created transactions for this item.',
          ),
        ),
      ),
    ],
  );
  Future<void> save() async {
    if (name.text.trim().isEmpty) return;
    setState(() => saving = true);
    await ref
        .read(booksRepositoryProvider)
        .addItem(
          name: name.text.trim(),
          sku: sku.text.trim(),
          rate: double.tryParse(rate.text) ?? 0,
          type: itemType,
        );
    ref.invalidate(itemsProvider);
    if (mounted) context.pop();
  }
}

class NewTransactionPage extends ConsumerStatefulWidget {
  const NewTransactionPage({required this.type, super.key});
  final TransactionType type;
  @override
  ConsumerState<NewTransactionPage> createState() => _NewTransactionState();
}

class _NewTransactionState extends ConsumerState<NewTransactionPage> {
  final customer = TextEditingController(),
      number = TextEditingController(),
      item = TextEditingController(),
      quantity = TextEditingController(text: '1'),
      rate = TextEditingController(text: '0'),
      notes = TextEditingController(),
      terms = TextEditingController();
  bool saving = false;
  String get label => switch (widget.type) {
    TransactionType.quote => 'Quote',
    TransactionType.salesOrder => 'Sales Order',
    TransactionType.invoice => 'Invoice',
  };
  @override
  void initState() {
    super.initState();
    number.text = widget.type == TransactionType.quote
        ? 'IGT-EST-1252'
        : widget.type == TransactionType.salesOrder
        ? 'IGT PI1451'
        : 'IGT-1113';
  }

  @override
  Widget build(BuildContext context) {
    final total =
        (double.tryParse(quantity.text) ?? 0) *
        (double.tryParse(rate.text) ?? 0);
    return FormPage(
      title: 'New $label',
      saving: saving,
      onSave: () => save(total),
      children: [
        field(customer, 'Customer Name*'),
        const SizedBox(height: 14),
        field(number, '$label#*'),
        const SizedBox(height: 14),
        TextFormField(
          initialValue: DateFormat('dd/MM/yyyy').format(DateTime.now()),
          readOnly: true,
          decoration: InputDecoration(labelText: '$label Date*'),
        ),
        const SizedBox(height: 14),
        const StaticSelect('Salesperson', 'Anwar'),
        const SizedBox(height: 24),
        const SectionTitle('Item Table'),
        field(item, 'Item details'),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final quantityField = field(
              quantity,
              'Quantity',
              number: true,
              onChanged: (_) => setState(() {}),
            );
            final rateField = field(
              rate,
              'Rate',
              number: true,
              onChanged: (_) => setState(() {}),
            );
            // Keep fields full-width on small phones and pair them when readable.
            if (constraints.maxWidth < 420) {
              return Column(
                children: [
                  quantityField,
                  const SizedBox(height: 12),
                  rateField,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: quantityField),
                const SizedBox(width: 12),
                Expanded(child: rateField),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Sub Total'),
          trailing: Text('₹${total.toStringAsFixed(2)}'),
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Total (₹)',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          trailing: Text(
            '₹${total.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 20),
        field(notes, 'Customer Notes', lines: 3),
        const SizedBox(height: 14),
        field(terms, 'Terms & Conditions', lines: 4),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.upload_file),
          label: Text('Attach File(s) to $label'),
        ),
      ],
    );
  }

  Future<void> save(double total) async {
    if (customer.text.trim().isEmpty) return;
    setState(() => saving = true);
    await ref
        .read(booksRepositoryProvider)
        .addTransaction(
          TransactionDraft(
            type: widget.type,
            customer: customer.text.trim(),
            number: number.text.trim(),
            date: DateTime.now(),
            amount: total,
          ),
        );
    ref.invalidate(transactionsProvider(widget.type));
    if (mounted) context.pop();
  }
}

class FormPage extends StatelessWidget {
  const FormPage({
    required this.title,
    required this.children,
    required this.onSave,
    required this.saving,
    this.maxWidth = AppLayout.maxFormWidth,
    super.key,
  });
  final String title;
  final List<Widget> children;
  final VoidCallback onSave;
  final bool saving;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFECF2FC), Color(0xFFECF2FC)],
      ),
    ),
    child: Column(
      children: [
        AppBar(title: Text(title)),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final gutter = AppLayout.gutter(constraints.maxWidth);
              return FadeSlideIn(
                child: ResponsiveContent(
                  maxWidth: maxWidth,
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 24),
                    children: [
                      GlassPanel(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: children,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final save = ElevatedButton(
                  onPressed: saving ? null : onSave,
                  child: Text(saving ? 'Saving...' : 'Save as Draft'),
                );
                final cancel = OutlinedButton(
                  onPressed: saving ? null : () => context.pop(),
                  child: const Text('Cancel'),
                );
                if (constraints.maxWidth < 380) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [save, const SizedBox(height: 8), cancel],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: save),
                    const SizedBox(width: 10),
                    cancel,
                  ],
                );
              },
            ),
          ),
        ),
      ],
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        const Icon(Icons.check_box, color: AppColors.active, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class StaticSelect extends StatelessWidget {
  const StaticSelect(this.label, this.value, {super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(labelText: label),
    child: Row(
      children: [
        Expanded(child: Text(value)),
        const Icon(Icons.keyboard_arrow_down),
      ],
    ),
  );
}

class _ItemInfoSection extends StatelessWidget {
  const _ItemInfoSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [SectionTitle(title), ...children],
  );
}

class ItemImageUpload extends StatefulWidget {
  const ItemImageUpload({super.key});

  @override
  State<ItemImageUpload> createState() => _ItemImageUploadState();
}

class _ItemImageUploadState extends State<ItemImageUpload> {
  Uint8List? imageBytes;
  bool dragging = false;

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= AppBreakpoints.laptop;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Item Image', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        DropTarget(
          onDragEntered: (_) => setState(() => dragging = true),
          onDragExited: (_) => setState(() => dragging = false),
          onDragDone: (details) async {
            setState(() => dragging = false);
            if (details.files.isNotEmpty) {
              await _setImage(await details.files.first.readAsBytes());
            }
          },
          child: InkWell(
            onTap: _pickImage,
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: desktop ? 290 : 190,
              decoration: BoxDecoration(
                color: dragging
                    ? AppColors.primary.withValues(alpha: .08)
                    : Colors.white.withValues(alpha: .72),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: dragging ? AppColors.primary : AppColors.divider,
                  width: dragging ? 2 : 1,
                ),
              ),
              child: imageBytes == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 42,
                          color: AppColors.active,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          desktop
                              ? 'Drag & drop an image here'
                              : 'Tap to upload an image',
                          textAlign: TextAlign.center,
                        ),
                        if (desktop) ...[
                          const SizedBox(height: 5),
                          const Text(
                            'or Browse',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Image.memory(imageBytes!, fit: BoxFit.cover),
                    ),
            ),
          ),
        ),
        if (imageBytes != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() => imageBytes = null),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove image'),
            ),
          ),
      ],
    );
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result?.files.single.bytes != null) {
      await _setImage(result!.files.single.bytes!);
    }
  }

  Future<void> _setImage(Uint8List bytes) async {
    if (!mounted) return;
    // The selected image is intentionally local form state; save APIs stay unchanged.
    setState(() => imageBytes = bytes);
  }
}

Widget field(
  TextEditingController c,
  String label, {
  String? prefix,
  bool number = false,
  int lines = 1,
  ValueChanged<String>? onChanged,
}) => TextField(
  controller: c,
  maxLines: lines,
  keyboardType: number ? TextInputType.number : TextInputType.text,
  onChanged: onChanged,
  decoration: InputDecoration(
    labelText: label,
    prefixText: prefix == null ? null : '$prefix  ',
    alignLabelWithHint: lines > 1,
  ),
);

class NewAdjustmentPage extends ConsumerStatefulWidget {
  const NewAdjustmentPage({super.key});
  @override
  ConsumerState<NewAdjustmentPage> createState() => _NewAdjustmentPageState();
}

class _NewAdjustmentPageState extends ConsumerState<NewAdjustmentPage> {
  final quantity = TextEditingController();
  final reference = TextEditingController(
    text: 'ADJ-${DateTime.now().millisecondsSinceEpoch}',
  );
  final description = TextEditingController();
  int? itemId;
  String reason = 'Stock Count Variance';
  bool applyNow = true;
  bool saving = false;

  @override
  Widget build(BuildContext context) => FormPage(
    title: 'New Inventory Adjustment',
    saving: saving,
    onSave: save,
    children: [
      ref
          .watch(itemsProvider)
          .when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Unable to load items: $e'),
            data: (items) => DropdownButtonFormField<int>(
              initialValue: itemId,
              decoration: const InputDecoration(labelText: 'Item*'),
              items: items
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(
                        '${item.name} · Stock ${item.stockOnHand.toStringAsFixed(0)}',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => itemId = value),
            ),
          ),
      const SizedBox(height: 14),
      field(quantity, 'Quantity Adjusted*', number: true),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        initialValue: reason,
        decoration: const InputDecoration(labelText: 'Reason*'),
        items: const ['Stock Count Variance', 'Damaged Goods', 'Theft', 'Other']
            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
            .toList(),
        onChanged: (value) => setState(() => reason = value ?? reason),
      ),
      const SizedBox(height: 14),
      field(reference, 'Reference Number*'),
      const SizedBox(height: 14),
      field(description, 'Description', lines: 4),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: applyNow,
        onChanged: (value) => setState(() => applyNow = value),
        title: Text(applyNow ? 'Apply stock adjustment now' : 'Save as draft'),
      ),
    ],
  );

  Future<void> save() async {
    final change = double.tryParse(quantity.text);
    if (itemId == null ||
        change == null ||
        change == 0 ||
        reference.text.trim().isEmpty) {
      return;
    }
    setState(() => saving = true);
    await ref
        .read(booksRepositoryProvider)
        .addAdjustment(
          AdjustmentDraft(
            itemId: itemId!,
            quantityAdjusted: change,
            reason: reason,
            referenceNumber: reference.text.trim(),
            description: description.text.trim(),
            applyNow: applyNow,
          ),
        );
    ref.invalidate(adjustmentsProvider);
    ref.invalidate(itemsProvider);
    ref.invalidate(dashboardMetricsProvider);
    if (mounted) context.pop();
  }
}
