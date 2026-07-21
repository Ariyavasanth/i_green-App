import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/books_repository.dart';
import '../providers/books_providers.dart';
import 'books_forms.dart';

class AddMaterialPage extends ConsumerStatefulWidget {
  const AddMaterialPage({super.key});

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
      title: 'ADD MATERIAL',
      saving: saving,
      saveLabel: 'Add Material',
      onSave: _save,
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
                onChanged: (value) {
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
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}
