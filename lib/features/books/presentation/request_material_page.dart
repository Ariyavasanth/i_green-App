import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../domain/books_repository.dart';
import '../providers/books_providers.dart';
import 'books_forms.dart';

class RequestMaterialPage extends ConsumerStatefulWidget {
  const RequestMaterialPage({super.key});

  @override
  ConsumerState<RequestMaterialPage> createState() => _RequestMaterialPageState();
}

class _RequestMaterialPageState extends ConsumerState<RequestMaterialPage> {
  final _formKey = GlobalKey<FormState>();
  final _machine = TextEditingController();
  final _operator = TextEditingController();
  final _workOrder = TextEditingController();
  final _material = TextEditingController();
  final _quantity = TextEditingController();
  final _weight = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _selectedMaterial;

  @override
  void dispose() {
    for (final controller in [_machine, _operator, _workOrder, _material, _quantity, _weight]) {
      controller.dispose();
    }
    super.dispose();
  }

  InputDecoration _decoration(String label, {Widget? suffixIcon}) => InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: suffixIcon,
      );

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Required' : null;

  String? _number(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final number = double.tryParse(value.trim());
    return number == null || number <= 0 ? 'Enter a value greater than zero' : null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _onCancel() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/inventory-adjustments/requests');
    }
  }

  Future<void> _submit() async {
    final materialText = _selectedMaterial ?? _material.text.trim();
    if (materialText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or enter a material')),
      );
      return;
    }
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(booksRepositoryProvider).requestMaterial(
            MaterialRequestDraft(
              date: _date,
              machine: _machine.text.trim(),
              operatorName: _operator.text.trim(),
              workOrder: _workOrder.text.trim(),
              material: materialText,
              quantityIssued: double.parse(_quantity.text.trim()),
              weightIssued: double.parse(_weight.text.trim()),
            ),
          );
      ref.invalidate(materialRequestsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Material request saved successfully')),
      );
      _onCancel();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save request: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final materialsState = ref.watch(materialsProvider(null));
    final availableMaterials = materialsState.valueOrNull ?? <MaterialItem>[];

    return FormPage(
      title: 'Request Material',
      saveLabel: 'Submit Request',
      saving: _saving,
      showLeading: false,
      showAppBar: false,
      onSave: _submit,
      maxWidth: 760,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Material Request Details',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: _decoration('Date', suffixIcon: const Icon(Icons.calendar_today_outlined)),
                  child: Text(DateFormat('dd MMM yyyy').format(_date)),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _machine,
                decoration: _decoration('Machine'),
                validator: _required,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _operator,
                decoration: _decoration('Operator'),
                validator: _required,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _workOrder,
                decoration: _decoration('Work Order'),
                validator: _required,
              ),
              const SizedBox(height: 16),
              if (availableMaterials.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  value: _selectedMaterial,
                  isExpanded: true,
                  decoration: _decoration('Material (Dropdown / Search)'),
                  items: availableMaterials.map((m) {
                    final label = '${m.description} (${m.code})';
                    return DropdownMenuItem<String>(
                      value: m.description,
                      child: Text(label, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedMaterial = val;
                      if (val != null) _material.text = val;
                    });
                  },
                ),
                const SizedBox(height: 16),
              ] else ...[
                TextFormField(
                  controller: _material,
                  decoration: _decoration('Material'),
                  validator: _required,
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _quantity,
                decoration: _decoration('Quantity Issued'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _weight,
                decoration: _decoration('Weight Issued'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _number,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _saving ? null : _onCancel,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: Text(_saving ? 'Saving...' : 'Submit Request'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
