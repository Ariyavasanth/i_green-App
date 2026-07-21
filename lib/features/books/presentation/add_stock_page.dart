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
  final grnNumber = TextEditingController();
  final supplier = TextEditingController();
  final poNumber = TextEditingController();
  final invoiceNumber = TextEditingController();
  final materialCode = TextEditingController();
  final description = TextEditingController();
  final heatNumber = TextEditingController();
  final batchNumber = TextEditingController();
  final quantity = TextEditingController();
  final weight = TextEditingController();
  final inspectionStatus = TextEditingController();
  final storeLocation = TextEditingController();
  DateTime poDate = DateTime.now();
  DateTime invoiceDate = DateTime.now();
  bool saving = false;

  @override
  void dispose() {
    for (final controller in [
      grnNumber,
      supplier,
      poNumber,
      invoiceNumber,
      materialCode,
      description,
      heatNumber,
      batchNumber,
      quantity,
      weight,
      inspectionStatus,
      storeLocation,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormPage(
    title: 'ADD STOCK',
    saving: saving,
    saveLabel: 'Add Stock',
    showLeading: false,
    onSave: _save,
    children: [
      Form(
        key: formKey,
        child: Column(
          children: [
            _requiredField(grnNumber, 'GRN Number'),
            const SizedBox(height: 14),
            _requiredField(supplier, 'Supplier'),
            const SizedBox(height: 14),
            _requiredField(poNumber, 'PO Number'),
            const SizedBox(height: 14),
            _dateField('PO Date', poDate, (date) => setState(() => poDate = date)),
            const SizedBox(height: 14),
            _requiredField(invoiceNumber, 'Invoice Number'),
            const SizedBox(height: 14),
            _dateField('Invoice Date', invoiceDate, (date) => setState(() => invoiceDate = date)),
            const SizedBox(height: 14),
            _requiredField(materialCode, 'Material Code'),
            const SizedBox(height: 14),
            _requiredField(description, 'Description', maxLines: 3),
            const SizedBox(height: 14),
            _requiredField(heatNumber, 'Heat Number'),
            const SizedBox(height: 14),
            _requiredField(batchNumber, 'Batch Number'),
            const SizedBox(height: 14),
            _numberField(quantity, 'Quantity'),
            const SizedBox(height: 14),
            _numberField(weight, 'Weight'),
            const SizedBox(height: 14),
            _requiredField(inspectionStatus, 'Inspection Status'),
            const SizedBox(height: 14),
            _requiredField(storeLocation, 'Store Location'),
          ],
        ),
      ),
    ],
  );

  Widget _requiredField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) =>
      TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: '$label*'),
        validator: (value) => value == null || value.trim().isEmpty
            ? '$label is required'
            : null,
      );

  Widget _dateField(
    String label,
    DateTime value,
    ValueChanged<DateTime> onChanged,
  ) => InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: () async {
      final date = await showDatePicker(
        context: context,
        initialDate: value,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (date != null) onChanged(date);
    },
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: '$label*',
        suffixIcon: const Icon(Icons.calendar_today_outlined),
      ),
      child: Text(DateFormat('dd/MM/yyyy').format(value)),
    ),
  );

  Widget _numberField(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: '$label*'),
        validator: (value) {
          final number = double.tryParse(value ?? '');
          return number == null || number <= 0
              ? 'Enter a valid $label'
              : null;
        },
      );

  Future<void> _save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() => saving = true);
    try {
      await ref.read(booksRepositoryProvider).addStock(
        StockEntryDraft(
          grnNumber: grnNumber.text.trim(),
          supplier: supplier.text.trim(),
          poNumber: poNumber.text.trim(),
          poDate: poDate,
          invoiceNumber: invoiceNumber.text.trim(),
          invoiceDate: invoiceDate,
          materialCode: materialCode.text.trim(),
          description: description.text.trim(),
          heatNumber: heatNumber.text.trim(),
          batchNumber: batchNumber.text.trim(),
          quantity: double.parse(quantity.text),
          weight: double.parse(weight.text),
          inspectionStatus: inspectionStatus.text.trim(),
          storeLocation: storeLocation.text.trim(),
        ),
      );
      ref.invalidate(itemsProvider);
      ref.invalidate(dashboardMetricsProvider);
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}
