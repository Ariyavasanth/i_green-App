import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../domain/books_repository.dart';
import '../providers/books_providers.dart';

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(booksRepositoryProvider).requestMaterial(
            MaterialRequestDraft(
              date: _date,
              machine: _machine.text.trim(),
              operatorName: _operator.text.trim(),
              workOrder: _workOrder.text.trim(),
              material: _material.text.trim(),
              quantityIssued: double.parse(_quantity.text.trim()),
              weightIssued: double.parse(_weight.text.trim()),
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Material request saved')),
      );
      Navigator.of(context).pop();
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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Request Material')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Material Request Details', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 24),
                        InkWell(
                          onTap: _pickDate,
                          child: InputDecorator(
                            decoration: _decoration('Date', suffixIcon: const Icon(Icons.calendar_today_outlined)),
                            child: Text(DateFormat('dd MMM yyyy').format(_date)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(controller: _machine, decoration: _decoration('Machine'), validator: _required),
                        const SizedBox(height: 16),
                        TextFormField(controller: _operator, decoration: _decoration('Operator'), validator: _required),
                        const SizedBox(height: 16),
                        TextFormField(controller: _workOrder, decoration: _decoration('Work Order'), validator: _required),
                        const SizedBox(height: 16),
                        TextFormField(controller: _material, decoration: _decoration('Material'), validator: _required),
                        const SizedBox(height: 16),
                        TextFormField(controller: _quantity, decoration: _decoration('Quantity Issued'), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: _number),
                        const SizedBox(height: 16),
                        TextFormField(controller: _weight, decoration: _decoration('Weight Issued'), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: _number),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
                            const SizedBox(width: 12),
                            FilledButton(onPressed: _saving ? null : _submit, child: Text(_saving ? 'Saving...' : 'Submit Request')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
