import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../vendors/domain/vendor.dart';
import '../../vendors/providers/vendor_providers.dart';
import '../domain/bill.dart';
import '../providers/bill_providers.dart';

class NewBillPage extends ConsumerStatefulWidget {
  const NewBillPage({super.key});
  @override
  ConsumerState<NewBillPage> createState() => _NewBillPageState();
}

class _NewBillPageState extends ConsumerState<NewBillPage> {
  final _key = GlobalKey<FormState>();
  final _number = TextEditingController(),
      _reference = TextEditingController(),
      _notes = TextEditingController(),
      _discount = TextEditingController(text: '0'),
      _roundOff = TextEditingController(text: '0');
  final _items = <_BillItem>[_BillItem()];
  Vendor? _vendor;
  DateTime _billDate = DateTime.now(), _dueDate = DateTime.now();
  String _paymentTerms = 'Due on Receipt';
  bool _reverseCharge = false, _tds = true, _saving = false;
  String? _adjustmentTax;
  final _attachments = <PlatformFile>[];

  double get _subtotal =>
      _items.fold<double>(0, (sum, item) => sum + item.amount);
  double get _itemTax =>
      _items.fold<double>(0, (sum, item) => sum + item.taxAmount);
  double get _discountValue =>
      _subtotal * (double.tryParse(_discount.text) ?? 0) / 100;
  double get _adjustment =>
      _subtotal *
      (double.tryParse(
            RegExp(r'[0-9.]+').firstMatch(_adjustmentTax ?? '')?.group(0) ?? '',
          ) ??
          0) /
      100;
  double get _total =>
      _subtotal -
      _discountValue +
      _itemTax +
      (_tds ? -_adjustment : _adjustment) +
      (double.tryParse(_roundOff.text) ?? 0);

  @override
  void dispose() {
    for (final c in [_number, _reference, _notes, _discount, _roundOff])
      c.dispose();
    for (final i in _items) i.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vendors = ref.watch(vendorsProvider).valueOrNull ?? const <Vendor>[];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          onPressed: context.pop,
          icon: const Icon(Icons.close),
        ),
        title: const Text('New Bill'),
        centerTitle: false,
      ),
      body: Form(
        key: _key,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _section('Vendor Details', [
                    _label(
                      'Vendor Name*',
                      DropdownButtonFormField<Vendor>(
                        value: _vendor,
                        isExpanded: true,
                        hint: const Text('Select a Vendor'),
                        items: vendors
                            .map(
                              (v) => DropdownMenuItem(
                                value: v,
                                child: Text(
                                  v.companyName.isEmpty
                                      ? v.name
                                      : v.companyName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _vendor = v),
                        validator: (v) => v == null ? 'Select a vendor' : null,
                        decoration: _input(
                          prefixIcon: const Icon(Icons.storefront_outlined),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _section('Bill Details', [
                    _label(
                      'Bill#*',
                      TextFormField(
                        controller: _number,
                        validator: _required,
                        decoration: _input(),
                      ),
                    ),
                    _label(
                      'Order Number',
                      TextFormField(
                        controller: _reference,
                        decoration: _input(),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _dateField(
                            'Bill Date*',
                            _billDate,
                            (d) => setState(() => _billDate = d),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _dateField(
                            'Due Date',
                            _dueDate,
                            (d) => setState(() => _dueDate = d),
                          ),
                        ),
                      ],
                    ),
                    _label(
                      'Payment Terms',
                      DropdownButtonFormField<String>(
                        value: _paymentTerms,
                        items:
                            const [
                                  'Due on Receipt',
                                  'Net 15',
                                  'Net 30',
                                  'Net 45',
                                  'Net 60',
                                ]
                                .map(
                                  (v) => DropdownMenuItem(
                                    value: v,
                                    child: Text(v),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _paymentTerms = v;
                            final days =
                                int.tryParse(
                                  v.replaceAll(RegExp(r'[^0-9]'), ''),
                                ) ??
                                0;
                            _dueDate = _billDate.add(Duration(days: days));
                          });
                        },
                        decoration: _input(),
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: _reverseCharge,
                      onChanged: (v) =>
                          setState(() => _reverseCharge = v ?? false),
                      title: const Text(
                        'This transaction is applicable for reverse charge',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _section('Item Table', [_itemsArea()]),
                  const SizedBox(height: 14),
                  _totals(),
                  const SizedBox(height: 14),
                  _section('Notes & Attachments', [
                    _label(
                      'Notes',
                      TextField(
                        controller: _notes,
                        maxLines: 3,
                        decoration: _input(hint: 'It will not be shown in PDF'),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickFiles,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload File'),
                    ),
                    const Text(
                      'You can upload a maximum of 5 files, 10MB each',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    ..._attachments.map(
                      (f) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.insert_drive_file_outlined),
                        title: Text(f.name),
                        trailing: IconButton(
                          onPressed: () =>
                              setState(() => _attachments.remove(f)),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _itemsArea() => Column(
    children: [
      ..._items.asMap().entries.map(
        (e) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8F8),
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'Item ${e.key + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: _items.length == 1
                        ? null
                        : () =>
                              setState(() => _items.removeAt(e.key).dispose()),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
              TextField(
                controller: e.value.name,
                decoration: _input(
                  hint: 'Type or click to select an item',
                  prefixIcon: const Icon(Icons.image_outlined),
                ),
              ),
              const SizedBox(height: 9),
              DropdownButtonFormField<String>(
                value: e.value.account,
                hint: const Text('Select an account'),
                items: const ['Cost of Goods Sold', 'Purchase']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => e.value.account = v),
                decoration: _input(),
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: e.value.quantity,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: _input(hint: 'Quantity'),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: TextField(
                      controller: e.value.rate,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: _input(hint: 'Rate'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: e.value.tax,
                      hint: const Text('Select a Tax'),
                      items: const ['GST 5%', 'GST 12%', 'GST 18%']
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => e.value.tax = v),
                      decoration: _input(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '₹${e.value.amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => setState(() => _items.add(_BillItem())),
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Add New Row'),
        ),
      ),
    ],
  );

  Widget _totals() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F8F8),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        _totalRow('Sub Total', _subtotal),
        if (_itemTax != 0) ...[
          const SizedBox(height: 12),
          _totalRow('Tax', _itemTax),
        ],
        const SizedBox(height: 12),
        _summaryInputRow(
          label: 'Discount',
          controller: _discount,
          suffixText: '%',
          amount: -_discountValue,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Radio<bool>(
                    value: true,
                    groupValue: _tds,
                    visualDensity: VisualDensity.compact,
                    onChanged: (_) => setState(() => _tds = true),
                  ),
                  const Text('TDS'),
                  Radio<bool>(
                    value: false,
                    groupValue: _tds,
                    visualDensity: VisualDensity.compact,
                    onChanged: (_) => setState(() => _tds = false),
                  ),
                  const Text('TCS'),
                ],
              ),
            ),
            SizedBox(
              width: 120,
              child: DropdownButtonFormField<String>(
                value: _adjustmentTax,
                isExpanded: true,
                hint: const Text('Select a Tax'),
                items: const ['1%', '2%', '5%']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => _adjustmentTax = v),
                decoration: _input(),
              ),
            ),
          ],
        ),
        if (_adjustmentTax != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_tds ? '-' : '+'}${_adjustment.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _summaryInputRow(
          label: 'R/off',
          controller: _roundOff,
          amount: double.tryParse(_roundOff.text) ?? 0,
        ),
        const Divider(height: 28),
        _totalRow('Total', _total, strong: true),
      ],
    ),
  );

  Widget _summaryInputRow({
    required String label,
    required TextEditingController controller,
    required double amount,
    String? suffixText,
  }) => Row(
    children: [
      Expanded(child: Text(label)),
      SizedBox(
        width: 96,
        child: TextField(
          controller: controller,
          onChanged: (_) => setState(() {}),
          textAlign: TextAlign.right,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: _input(suffixText: suffixText),
        ),
      ),
      const SizedBox(width: 12),
      SizedBox(
        width: 72,
        child: Text(amount.toStringAsFixed(2), textAlign: TextAlign.right),
      ),
    ],
  );

  Widget _section(String title, List<Widget> children) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.divider),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        ...children,
      ],
    ),
  );
  Widget _label(String text, Widget field) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 5),
        field,
      ],
    ),
  );
  Widget _dateField(
    String label,
    DateTime value,
    ValueChanged<DateTime> changed,
  ) => _label(
    label,
    InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (d != null) changed(d);
      },
      child: InputDecorator(
        decoration: _input(
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 17),
        ),
        child: Text(DateFormat('dd/MM/yyyy').format(value)),
      ),
    ),
  );
  Widget _totalRow(String label, double value, {bool strong = false}) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
      Text(
        value.toStringAsFixed(2),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: strong ? 16 : 14,
        ),
      ),
    ],
  );
  Widget _footer() => Container(
    padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: AppColors.divider)),
    ),
    child: SafeArea(
      top: false,
      child: Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save as Draft'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.active),
              onPressed: _saving ? null : _save,
              child: const Text('Save and Submit'),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: context.pop,
            icon: const Icon(Icons.close),
            tooltip: 'Cancel',
          ),
        ],
      ),
    ),
  );
  InputDecoration _input({
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? suffixText,
  }) => InputDecoration(
    hintText: hint,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    suffixText: suffixText,
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
    border: const OutlineInputBorder(
      borderSide: BorderSide(color: AppColors.divider),
    ),
    enabledBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: AppColors.divider),
    ),
  );
  String? _required(String? v) =>
      v == null || v.trim().isEmpty ? 'Required' : null;
  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(allowMultiple: true);
    if (result != null)
      setState(
        () => _attachments.addAll(result.files.take(5 - _attachments.length)),
      );
  }

  Future<void> _save() async {
    if (!(_key.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    await ref
        .read(billRepositoryProvider)
        .addBill(
          BillDraft(
            number: _number.text.trim(),
            vendorName: _vendor!.companyName.isEmpty
                ? _vendor!.name
                : _vendor!.companyName,
            date: _billDate,
            dueDate: _dueDate,
            reference: _reference.text.trim(),
            amount: _total,
          ),
        );
    ref.invalidate(billsProvider);
    if (mounted) context.pop();
  }
}

class _BillItem {
  final name = TextEditingController(),
      quantity = TextEditingController(text: '1.00'),
      rate = TextEditingController(text: '0.00');
  String? account, tax;
  double get amount =>
      (double.tryParse(quantity.text) ?? 0) * (double.tryParse(rate.text) ?? 0);
  double get taxAmount {
    final percentage =
        double.tryParse(
          RegExp(r'[0-9.]+').firstMatch(tax ?? '')?.group(0) ?? '',
        ) ??
        0;
    return amount * percentage / 100;
  }

  void dispose() {
    name.dispose();
    quantity.dispose();
    rate.dispose();
  }
}
