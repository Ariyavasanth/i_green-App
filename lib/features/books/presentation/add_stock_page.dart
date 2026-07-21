import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../domain/books_repository.dart';
import '../providers/books_providers.dart';
import 'books_forms.dart';

class AddStockPage extends ConsumerStatefulWidget {
  const AddStockPage({super.key});
  @override
  ConsumerState<AddStockPage> createState() => _AddStockPageState();
}

class _AddStockPageState extends ConsumerState<AddStockPage> {
  final formKey = GlobalKey<FormState>();
  final purchaseOrderNumber = TextEditingController();
  final invoiceNumber = TextEditingController();
  final item = TextEditingController();
  final description = TextEditingController();
  final size = TextEditingController();
  final measurement = TextEditingController();
  final quantity = TextEditingController();
  final basicPrice = TextEditingController();
  final taxPercentage = TextEditingController();
  final netAverage = TextEditingController(text: '0.00');
  DateTime purchaseOrderDate = DateTime.now();
  DateTime invoiceDate = DateTime.now();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    basicPrice.addListener(_calculateNetAverage);
    taxPercentage.addListener(_calculateNetAverage);
  }

  @override
  void dispose() {
    for (final controller in [purchaseOrderNumber, invoiceNumber, item, description, size, measurement, quantity, basicPrice, taxPercentage, netAverage]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormPage(
    title: 'ADD STOCK',
    saving: saving,
    saveLabel: 'Add Stock',
    onSave: _save,
    children: [Form(
      key: formKey,
      child: Column(children: [
        _requiredField(purchaseOrderNumber, 'Purchase order no'),
        const SizedBox(height: 14),
        _dateField('Purchase order date', purchaseOrderDate, (date) => setState(() => purchaseOrderDate = date)),
        const SizedBox(height: 14),
        _requiredField(invoiceNumber, 'Invoice no'),
        const SizedBox(height: 14),
        _dateField('Invoice date', invoiceDate, (date) => setState(() => invoiceDate = date)),
        const SizedBox(height: 14),
        _requiredField(item, 'Item (manual)'),
        const SizedBox(height: 14),
        _textField(description, 'Description', lines: 3),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _textField(size, 'Size')),
          const SizedBox(width: 12),
          Expanded(child: _textField(measurement, 'Measurement')),
        ]),
        const SizedBox(height: 14),
        _numberField(quantity, 'Quantity'),
        const SizedBox(height: 14),
        _numberField(basicPrice, 'Basic Price', prefix: '₹'),
        const SizedBox(height: 14),
        _numberField(taxPercentage, 'Tax percentage', suffix: '%'),
        const SizedBox(height: 14),
        TextFormField(controller: netAverage, readOnly: true, decoration: const InputDecoration(labelText: 'Net average', prefixText: '₹  ')),
      ]),
    )],
  );

  Widget _textField(TextEditingController controller, String label, {int lines = 1}) => TextFormField(controller: controller, maxLines: lines, decoration: InputDecoration(labelText: label));

  Widget _requiredField(TextEditingController controller, String label) => TextFormField(
    controller: controller,
    decoration: InputDecoration(labelText: '$label*'),
    validator: (value) => value == null || value.trim().isEmpty ? '$label is required' : null,
  );

  Widget _numberField(TextEditingController controller, String label, {String? prefix, String? suffix}) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: '$label*', prefixText: prefix == null ? null : '$prefix  ', suffixText: suffix),
    validator: (value) {
      final number = double.tryParse(value ?? '');
      return number == null || number < 0 || (label == 'Quantity' && number == 0) ? 'Enter a valid $label' : null;
    },
  );

  Widget _dateField(String label, DateTime value, ValueChanged<DateTime> onChanged) => InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: () async {
      final date = await showDatePicker(context: context, initialDate: value, firstDate: DateTime(2000), lastDate: DateTime(2100));
      if (date != null) onChanged(date);
    },
    child: InputDecorator(
      decoration: InputDecoration(labelText: '$label*', suffixIcon: const Icon(Icons.calendar_today_outlined)),
      child: Text(DateFormat('dd/MM/yyyy').format(value)),
    ),
  );

  void _calculateNetAverage() {
    final basic = double.tryParse(basicPrice.text) ?? 0;
    final tax = double.tryParse(taxPercentage.text) ?? 0;
    netAverage.text = (basic * (1 + tax / 100)).toStringAsFixed(2);
  }

  Future<void> _save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() => saving = true);
    try {
      await ref.read(booksRepositoryProvider).addStock(StockEntryDraft(
        purchaseOrderNumber: purchaseOrderNumber.text.trim(), purchaseOrderDate: purchaseOrderDate,
        invoiceNumber: invoiceNumber.text.trim(), invoiceDate: invoiceDate, item: item.text.trim(),
        description: description.text.trim(), size: size.text.trim(), measurement: measurement.text.trim(),
        quantity: double.parse(quantity.text), basicPrice: double.parse(basicPrice.text),
        taxPercentage: double.parse(taxPercentage.text), netAverage: double.parse(netAverage.text),
      ));
      ref.invalidate(itemsProvider);
      ref.invalidate(dashboardMetricsProvider);
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}
