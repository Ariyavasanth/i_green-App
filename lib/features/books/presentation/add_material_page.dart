import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/books_repository.dart';
import '../providers/books_providers.dart';
import 'books_forms.dart';

class AddMaterialPage extends ConsumerStatefulWidget {
  const AddMaterialPage({
    this.material,
    this.readOnly = false,
    super.key,
  });

  final MaterialItem? material;
  final bool readOnly;

  @override
  ConsumerState<AddMaterialPage> createState() => _AddMaterialPageState();
}

class _AddMaterialPageState extends ConsumerState<AddMaterialPage> {
  final formKey = GlobalKey<FormState>();
  final controllers = <String, TextEditingController>{};
  String sourceType = 'RAW';
  bool saving = false;

  static const rawFields = <String>[
    'Material Code',
    'Material Description',
    'Material Type',
    'Grade',
    'Size',
    'Unit',
    'Density',
    'Supplier',
    'Heat No',
    'Batch No',
    'Warehouse Location',
    'Rack Location',
    'Minimum Stock',
    'Maximum Stock',
    'Reorder Level',
  ];

  static const outsourceFields = <String>[
    'Item Code',
    'Description',
    'Make',
    'Model',
    'Size',
    'Unit',
    'Vendor',
    'Shelf Location',
    'Minimum Stock',
    'Maximum Stock',
    'Reorder Quantity',
  ];

  TextEditingController _controller(String label) =>
      controllers.putIfAbsent(label, TextEditingController.new);

  @override
  void initState() {
    super.initState();
    final item = widget.material;
    if (item != null) {
      sourceType = item.sourceType.toUpperCase();
      if (sourceType == 'RAW') {
        _controller('Material Code').text = item.code;
        _controller('Material Description').text = item.description;
        _controller('Material Type').text = item.materialType;
        _controller('Grade').text = item.grade;
        _controller('Size').text = item.size;
        _controller('Unit').text = item.unit;
        _controller('Density').text = item.density;
        _controller('Supplier').text = item.supplier;
        _controller('Heat No').text = item.heatNumber;
        _controller('Batch No').text = item.batchNumber;
        _controller('Warehouse Location').text = item.warehouseLocation;
        _controller('Rack Location').text = item.rackLocation;
        _controller('Minimum Stock').text = item.minimumStock;
        _controller('Maximum Stock').text = item.maximumStock;
        _controller('Reorder Level').text = item.reorderLevel;
      } else {
        _controller('Item Code').text = item.code;
        _controller('Description').text = item.description;
        _controller('Make').text = item.make;
        _controller('Model').text = item.model;
        _controller('Size').text = item.size;
        _controller('Unit').text = item.unit;
        _controller('Vendor').text = item.supplier;
        _controller('Shelf Location').text = item.warehouseLocation;
        _controller('Minimum Stock').text = item.minimumStock;
        _controller('Maximum Stock').text = item.maximumStock;
        _controller('Reorder Quantity').text = item.reorderLevel;
      }
    }
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fields = sourceType == 'RAW' ? rawFields : outsourceFields;
    return FormPage(
      title: 'Add Material',
      saving: saving,
      saveLabel: widget.readOnly ? 'Close' : 'Add Material',
      showAppBar: false,
      onSave: widget.readOnly ? () => context.go('/inventory-adjustments') : _save,
      children: [
        Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: sourceType,
                decoration: const InputDecoration(labelText: 'Raw or Outsource*'),
                items: const [
                  DropdownMenuItem(value: 'RAW', child: Text('Raw Materials')),
                  DropdownMenuItem(value: 'OUTSOURCE', child: Text('Outsource')),
                ],
                onChanged: widget.readOnly
                    ? null
                    : (value) {
                        if (value != null) setState(() => sourceType = value);
                      },
              ),
              const SizedBox(height: 14),
              for (var index = 0; index < fields.length; index++) ...[
                _requiredField(fields[index]),
                if (index != fields.length - 1) const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _requiredField(String label) => TextFormField(
        controller: _controller(label),
        readOnly: widget.readOnly,
        keyboardType: _isNumberField(label)
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(labelText: '$label*'),
        validator: (value) => value == null || value.trim().isEmpty
            ? '$label is required'
            : null,
      );

  bool _isNumberField(String label) =>
      label == 'Density' || label.contains('Stock') || label.startsWith('Reorder');

  String _value(String label) => _controller(label).text.trim();

  Future<void> _save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() => saving = true);
    try {
      await ref.read(booksRepositoryProvider).addMaterial(MaterialDraft(
            sourceType: sourceType,
            code: _value(sourceType == 'RAW' ? 'Material Code' : 'Item Code'),
            description: _value(sourceType == 'RAW' ? 'Material Description' : 'Description'),
            materialType: _value('Material Type'),
            grade: _value('Grade'),
            make: _value('Make'),
            model: _value('Model'),
            size: _value('Size'),
            unit: _value('Unit'),
            density: _value('Density'),
            supplier: _value(sourceType == 'RAW' ? 'Supplier' : 'Vendor'),
            heatNumber: _value('Heat No'),
            batchNumber: _value('Batch No'),
            warehouseLocation: _value(
              sourceType == 'RAW' ? 'Warehouse Location' : 'Shelf Location',
            ),
            rackLocation: _value('Rack Location'),
            minimumStock: _value('Minimum Stock'),
            maximumStock: _value('Maximum Stock'),
            reorderLevel: _value(
              sourceType == 'RAW' ? 'Reorder Level' : 'Reorder Quantity',
            ),
          ));
      ref.invalidate(materialsProvider(null));
      ref.invalidate(materialsProvider('RAW'));
      ref.invalidate(materialsProvider('OUTSOURCE'));
      if (mounted) context.go('/inventory-adjustments');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}
