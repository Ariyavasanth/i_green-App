import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../domain/books_repository.dart';
import '../providers/books_providers.dart';
import 'books_forms.dart';

class MoveStockPage extends ConsumerStatefulWidget {
  const MoveStockPage({super.key});
  @override
  ConsumerState<MoveStockPage> createState() => _MoveStockPageState();
}

class _MoveStockPageState extends ConsumerState<MoveStockPage> {
  final _formKey = GlobalKey<FormState>();
  final _workOrder = TextEditingController();
  final _productionOrder = TextEditingController();
  final _jobCard = TextEditingController();
  final _machine = TextEditingController();
  final _operator = TextEditingController();
  final _captureWorkOrder = TextEditingController();
  final _quantityIssued = TextEditingController();
  final _weightIssued = TextEditingController();
  final _issuedBy = TextEditingController();
  final _receivedBy = TextEditingController();
  DateTime _date = DateTime.now();
  int? _materialId;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [_workOrder, _productionOrder, _jobCard, _machine, _operator, _captureWorkOrder, _quantityIssued, _weightIssued, _issuedBy, _receivedBy]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormPage(
    title: 'MOVE STOCK',
    saving: _saving,
    saveLabel: 'Move Stock',
    onSave: _save,
    children: [Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _requiredField(_workOrder, 'Work Order'),
        _gap,
        _requiredField(_productionOrder, 'Production Order'),
        _gap,
        _requiredField(_jobCard, 'Job Card'),
        const SizedBox(height: 24),
        Text('Capture', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 14),
        _dateField(),
        _gap,
        _requiredField(_machine, 'Machine'),
        _gap,
        _requiredField(_operator, 'Operator'),
        _gap,
        _requiredField(_captureWorkOrder, 'Work Order'),
        _gap,
        _materialField(),
        _gap,
        _numberField(_quantityIssued, 'Quantity Issued'),
        _gap,
        _numberField(_weightIssued, 'Weight Issued'),
        _gap,
        _requiredField(_issuedBy, 'Issued By'),
        _gap,
        _requiredField(_receivedBy, 'Received By'),
      ]),
    )],
  );

  static const _gap = SizedBox(height: 14);

  Widget _requiredField(TextEditingController controller, String label) => TextFormField(
    controller: controller,
    decoration: InputDecoration(labelText: '$label*'),
    validator: (value) => value == null || value.trim().isEmpty ? '$label is required' : null,
  );

  Widget _numberField(TextEditingController controller, String label) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: '$label*'),
    validator: (value) {
      final number = double.tryParse(value ?? '');
      return number == null || number <= 0 ? 'Enter a valid $label' : null;
    },
  );

  Widget _materialField() => ref.watch(itemsProvider).when(
    loading: () => const LinearProgressIndicator(),
    error: (_, _) => const Text('Unable to load materials'),
    data: (items) => DropdownButtonFormField<int>(
      initialValue: _materialId,
      decoration: const InputDecoration(labelText: 'Material*'),
      items: items.map((item) => DropdownMenuItem(value: item.id, child: Text('${item.name} (${item.stockOnHand.toStringAsFixed(0)} ${item.unit})'))).toList(),
      onChanged: (value) => setState(() => _materialId = value),
      validator: (value) => value == null ? 'Material is required' : null,
    ),
  );

  Widget _dateField() => InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: () async {
      final selected = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime(2100));
      if (selected != null) setState(() => _date = selected);
    },
    child: InputDecorator(
      decoration: const InputDecoration(labelText: 'Date*', suffixIcon: Icon(Icons.calendar_today_outlined)),
      child: Text(DateFormat('dd/MM/yyyy').format(_date)),
    ),
  );

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(booksRepositoryProvider).moveStock(MoveStockDraft(
        workOrder: _workOrder.text.trim(), productionOrder: _productionOrder.text.trim(),
        jobCard: _jobCard.text.trim(), date: _date, machine: _machine.text.trim(),
        operatorName: _operator.text.trim(), captureWorkOrder: _captureWorkOrder.text.trim(),
        materialId: _materialId!, quantityIssued: double.parse(_quantityIssued.text),
        weightIssued: double.parse(_weightIssued.text), issuedBy: _issuedBy.text.trim(),
        receivedBy: _receivedBy.text.trim(),
      ));
      ref.invalidate(itemsProvider);
      ref.invalidate(dashboardMetricsProvider);
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
