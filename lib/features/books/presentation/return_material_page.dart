import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/books_repository.dart';
import '../providers/books_providers.dart';

class ReturnMaterialPage extends ConsumerStatefulWidget {
  const ReturnMaterialPage({super.key});

  @override
  ConsumerState<ReturnMaterialPage> createState() => _ReturnMaterialPageState();
}

class _ReturnMaterialPageState extends ConsumerState<ReturnMaterialPage> {
  final _formKey = GlobalKey<FormState>();
  final _workOrder = TextEditingController();
  final _material = TextEditingController();
  final _quantityReturned = TextEditingController();
  final _weight = TextEditingController();
  final _reason = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [
      _workOrder,
      _material,
      _quantityReturned,
      _weight,
      _reason,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  String? _number(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final number = double.tryParse(value.trim());
    return number == null || number <= 0
        ? 'Enter a value greater than zero'
        : null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(booksRepositoryProvider).returnMaterial(
            MaterialReturnDraft(
              workOrder: _workOrder.text.trim(),
              material: _material.text.trim(),
              quantityReturned: double.parse(_quantityReturned.text.trim()),
              weight: double.parse(_weight.text.trim()),
              reason: _reason.text.trim(),
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Material return saved')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save return: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Return')),
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
                        Text(
                          'Material Return Details',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _workOrder,
                          decoration: _decoration('Work Order'),
                          validator: _required,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _material,
                          decoration: _decoration('Material'),
                          validator: _required,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _quantityReturned,
                          decoration: _decoration('Quantity Returned'),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: _number,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _weight,
                          decoration: _decoration('Weight'),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: _number,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _reason,
                          decoration: _decoration('Reason'),
                          minLines: 3,
                          maxLines: 5,
                          validator: _required,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _saving
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 12),
                            FilledButton(
                              onPressed: _saving ? null : _submit,
                              child: Text(
                                _saving ? 'Saving...' : 'Submit Return',
                              ),
                            ),
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
