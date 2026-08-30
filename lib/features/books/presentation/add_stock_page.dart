import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../domain/books_repository.dart';
import '../providers/books_providers.dart';
import 'books_forms.dart';

class AddStockPage extends ConsumerStatefulWidget {
  const AddStockPage({
    this.stockEntry,
    this.readOnly = false,
    super.key,
  });

  final StockEntry? stockEntry;
  final bool readOnly;

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
  String materialType = 'RAW';
  String? selectedSubMaterialId;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.stockEntry;
    if (entry != null) {
      grnNumber.text = entry.grnNumber;
      supplier.text = entry.supplier;
      poNumber.text = entry.poNumber;
      invoiceNumber.text = entry.invoiceNumber;
      materialCode.text = entry.materialCode;
      description.text = entry.description;
      heatNumber.text = entry.heatNumber;
      batchNumber.text = entry.batchNumber;
      quantity.text = entry.quantity > 0 ? entry.quantity.toString() : '';
      weight.text = entry.weight > 0 ? entry.weight.toString() : '';
      inspectionStatus.text = entry.inspectionStatus;
      storeLocation.text = entry.storeLocation;
      poDate = entry.poDate;
      invoiceDate = entry.invoiceDate;
    }
  }

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
  Widget build(BuildContext context) {
    final materialsState = ref.watch(materialsProvider(null));

    final rawMaterials = (materialsState.valueOrNull ?? <MaterialItem>[])
        .where((m) => m.isRawMaterial)
        .toList();
    final outsourceMaterials = (materialsState.valueOrNull ?? <MaterialItem>[])
        .where((m) => m.isOutsource)
        .toList();

    final List<_SubMaterialOption> subMaterialOptions = [];

    if (materialType == 'RAW') {
      for (final m in rawMaterials) {
        final loc = m.warehouseLocation.isNotEmpty
            ? (m.rackLocation.isNotEmpty
                ? '${m.warehouseLocation} - ${m.rackLocation}'
                : m.warehouseLocation)
            : m.rackLocation;
        subMaterialOptions.add(_SubMaterialOption(
          id: 'mat-${m.id}',
          label: '${m.description} (${m.code})',
          code: m.code,
          description: m.description,
          supplier: m.supplier,
          heatNumber: m.heatNumber,
          batchNumber: m.batchNumber,
          storeLocation: loc,
          weight: m.density,
        ));
      }
    } else {
      for (final m in outsourceMaterials) {
        final loc = m.warehouseLocation.isNotEmpty
            ? (m.rackLocation.isNotEmpty
                ? '${m.warehouseLocation} - ${m.rackLocation}'
                : m.warehouseLocation)
            : m.rackLocation;
        subMaterialOptions.add(_SubMaterialOption(
          id: 'mat-${m.id}',
          label: '${m.description} (${m.code})',
          code: m.code,
          description: m.description,
          supplier: m.supplier,
          heatNumber: m.heatNumber,
          batchNumber: m.batchNumber,
          storeLocation: loc,
          weight: m.density,
        ));
      }
    }

    final validSubMaterialId =
        subMaterialOptions.any((o) => o.id == selectedSubMaterialId)
            ? selectedSubMaterialId
            : null;

    return FormPage(
      title: 'Add Stock',
      saving: saving,
      saveLabel: widget.readOnly ? 'Close' : 'Add Stock',
      showLeading: false,
      showAppBar: false,
      onSave: widget.readOnly ? () => context.go('/inventory-adjustments') : _save,
      children: [
        Form(
          key: formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: materialType,
                decoration: const InputDecoration(labelText: 'Material Type*'),
                items: const [
                  DropdownMenuItem(value: 'RAW', child: Text('Raw Material')),
                  DropdownMenuItem(value: 'OUTSOURCE', child: Text('Outsource')),
                ],
                onChanged: widget.readOnly
                    ? null
                    : (value) {
                        if (value != null && value != materialType) {
                          setState(() {
                            materialType = value;
                            selectedSubMaterialId = null;
                          });
                        }
                      },
              ),
              const SizedBox(height: 14),
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
              DropdownButtonFormField<String>(
                value: validSubMaterialId,
                decoration: const InputDecoration(
                  labelText: 'Select Item / Sub-Material*',
                ),
                items: subMaterialOptions.map((opt) {
                  return DropdownMenuItem<String>(
                    value: opt.id,
                    child: Text(opt.label, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: widget.readOnly
                    ? null
                    : (value) {
                        if (value != null) {
                          final selected =
                              subMaterialOptions.firstWhere((o) => o.id == value);
                          setState(() {
                            selectedSubMaterialId = value;
                            materialCode.text = selected.code;
                            description.text = selected.description;
                            if (selected.supplier.isNotEmpty) {
                              supplier.text = selected.supplier;
                            }
                            if (selected.heatNumber.isNotEmpty) {
                              heatNumber.text = selected.heatNumber;
                            }
                            if (selected.batchNumber.isNotEmpty) {
                              batchNumber.text = selected.batchNumber;
                            }
                            if (selected.storeLocation.isNotEmpty) {
                              storeLocation.text = selected.storeLocation;
                            }
                            if (selected.weight.isNotEmpty) {
                              weight.text = selected.weight;
                            }
                            if (inspectionStatus.text.isEmpty) {
                              inspectionStatus.text = 'Passed';
                            }
                          });
                        }
                      },
              ),
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
  }

  Widget _requiredField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) =>
      TextFormField(
        controller: controller,
        readOnly: widget.readOnly,
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
    onTap: widget.readOnly
        ? null
        : () async {
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
        readOnly: widget.readOnly,
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
      ref.invalidate(materialsProvider(null));
      ref.invalidate(materialsProvider('RAW'));
      ref.invalidate(materialsProvider('OUTSOURCE'));
      ref.invalidate(stockEntriesProvider);
      ref.invalidate(dashboardMetricsProvider);
      if (mounted) context.go('/inventory-adjustments');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class _SubMaterialOption {
  const _SubMaterialOption({
    required this.id,
    required this.label,
    required this.code,
    required this.description,
    this.supplier = '',
    this.heatNumber = '',
    this.batchNumber = '',
    this.storeLocation = '',
    this.weight = '',
  });

  final String id;
  final String label;
  final String code;
  final String description;
  final String supplier;
  final String heatNumber;
  final String batchNumber;
  final String storeLocation;
  final String weight;
}
