import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../vendors/domain/vendor.dart';
import '../../vendors/providers/vendor_providers.dart';
import '../domain/purchase_order.dart';
import '../providers/purchase_order_providers.dart';

class NewPurchaseOrderPage extends ConsumerStatefulWidget {
  const NewPurchaseOrderPage({super.key});

  @override
  ConsumerState<NewPurchaseOrderPage> createState() => _NewPurchaseOrderPageState();
}

class _NewPurchaseOrderPageState extends ConsumerState<NewPurchaseOrderPage> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _reference = TextEditingController();
  final _deliveryDate = TextEditingController();
  final _discount = TextEditingController(text: '0');
  final _roundOff = TextEditingController();
  final _notes = TextEditingController();
  final _terms = TextEditingController();
  final _items = <_PurchaseItem>[_PurchaseItem()];
  final _dateFormat = DateFormat('dd/MM/yyyy');

  Vendor? _vendor;
  DateTime _date = DateTime.now();
  DateTime? _delivery;
  String _paymentTerms = 'Due on Receipt';
  String? _shipmentPreference;
  String? _tax;
  bool _reverseCharge = false;
  bool _organizationAddress = true;
  bool _discountPercent = true;
  bool _tds = true;
  bool _saving = false;
  final List<PlatformFile> _attachments = [];

  @override
  void initState() {
    super.initState();
    _number.text = 'PO-${(DateTime.now().millisecondsSinceEpoch % 100000).toString().padLeft(5, '0')}';
  }

  @override
  void dispose() {
    for (final controller in [_number, _reference, _deliveryDate, _discount, _roundOff, _notes, _terms]) {
      controller.dispose();
    }
    for (final item in _items) item.dispose();
    super.dispose();
  }

  double get _subTotal =>
      _items.fold<double>(0, (sum, item) => sum + item.amount);
  double get _taxTotal =>
      _items.fold<double>(0, (sum, item) => sum + item.taxAmount);
  double get _discountValue {
    final value = double.tryParse(_discount.text) ?? 0;
    return _discountPercent ? _subTotal * value / 100 : value;
  }
  double get _adjustmentRate =>
      double.tryParse((_tax ?? '').replaceAll('%', '')) ?? 0;
  double get _adjustmentValue =>
      (_subTotal - _discountValue).clamp(0, double.infinity).toDouble() *
      _adjustmentRate /
      100;
  double get _total =>
      (_subTotal +
              _taxTotal -
              _discountValue +
              (_tds ? -_adjustmentValue : _adjustmentValue) +
              (double.tryParse(_roundOff.text) ?? 0))
          .clamp(0, double.infinity)
          .toDouble();

  Future<void> _pickDate({required bool delivery}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: delivery ? (_delivery ?? _date) : _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (delivery) {
        _delivery = picked;
        _deliveryDate.text = _dateFormat.format(picked);
      } else {
        _date = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(purchaseOrderRepositoryProvider).addPurchaseOrder(
        PurchaseOrderDraft(
          number: _number.text.trim(),
          vendorName: _vendor!.companyName.isEmpty ? _vendor!.name : _vendor!.companyName,
          reference: _reference.text.trim(),
          date: _date,
          deliveryDate: _delivery,
          amount: _total,
        ),
      );
      ref.invalidate(purchaseOrdersProvider);
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save purchase order: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      withData: false,
    );
    if (result == null || !mounted) return;
    final validFiles = result.files
        .where((file) => file.size <= 10 * 1024 * 1024)
        .take(10 - _attachments.length);
    setState(() => _attachments.addAll(validFiles));
  }

  @override
  Widget build(BuildContext context) {
    final vendorState = ref.watch(vendorsProvider);
    final vendors = vendorState.valueOrNull ?? const <Vendor>[];
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            if (vendorState.isLoading)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _details(vendors),
                            const SizedBox(height: 28),
                            const Divider(height: 1),
                            const SizedBox(height: 14),
                            _itemTable(),
                            const SizedBox(height: 20),
                            _summaryArea(),
                            const SizedBox(height: 22),
                            _termsArea(),
                            const SizedBox(height: 28),
                            const Text(
                              'Additional Fields: Start adding custom fields for your purchase orders by going to Settings > Purchases > Purchase Orders.',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header() => Container(
    height: 52,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.divider))),
    child: Row(children: [
      const Icon(Icons.shopping_bag_outlined, size: 19),
      const SizedBox(width: 4),
      const Expanded(child: Text('New Purchase Order', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
      IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close, size: 20), tooltip: 'Close'),
    ]),
  );

  Widget _details(List<Vendor> vendors) => LayoutBuilder(builder: (context, c) {
    final wide = c.maxWidth >= 820;
    final formWidth = wide
        ? (c.maxWidth > 1000 ? 1000.0 : c.maxWidth)
        : c.maxWidth;
    return SizedBox(
      width: formWidth,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _labeled('Vendor Name*', DropdownButtonFormField<Vendor>(
          value: _vendor,
          isExpanded: true,
          hint: const Text('Select a Vendor'),
          items: vendors.map((v) => DropdownMenuItem(value: v, child: Text(v.companyName.isEmpty ? v.name : v.companyName, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) => setState(() => _vendor = v),
          validator: (v) => v == null ? 'Select a vendor' : null,
          decoration: _input(prefixIcon: const Icon(Icons.search, size: 18)),
        )),
        const SizedBox(height: 20),
        _labeled('Delivery Address*', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Radio<bool>(value: true, groupValue: _organizationAddress, onChanged: (value) => setState(() => _organizationAddress = value!), visualDensity: VisualDensity.compact),
            const Text('Organization', style: TextStyle(fontSize: 12)),
            Radio<bool>(value: false, groupValue: _organizationAddress, onChanged: (value) => setState(() => _organizationAddress = value!), visualDensity: VisualDensity.compact),
            const Text('Customer', style: TextStyle(fontSize: 12)),
          ]),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              _organizationAddress ? 'I greentec Engineering indi pvt ltd' : (_vendor?.companyName.isNotEmpty == true ? _vendor!.companyName : _vendor?.name ?? 'Select a vendor'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 6),
            child: Text(
              _organizationAddress
                  ? 'NO 94895\n12th cross street, Ventakeswara Nagar, thoraipakkam\nCHENNAI, Tamil Nadu\nIndia, 600097\n6385043612'
                  : 'Vendor delivery address will be used for this purchase order.',
              style: const TextStyle(fontSize: 11, height: 1.45, color: AppColors.textSecondary),
            ),
          ),
          TextButton(onPressed: () {}, child: const Text('Change destination to deliver', style: TextStyle(fontSize: 11))),
        ]), topAlign: true),
        const SizedBox(height: 6),
        SizedBox(width: formWidth, child: Wrap(spacing: 26, runSpacing: 12, children: [
          SizedBox(width: wide ? 440 : formWidth, child: Column(children: [
            _labeled('Purchase Order#*', TextFormField(controller: _number, validator: _required, decoration: _input(suffixIcon: const Icon(Icons.settings_outlined, size: 16)))),
            const SizedBox(height: 10),
            _labeled('Reference#', TextFormField(controller: _reference, decoration: _input())),
            const SizedBox(height: 10),
            _labeled('Date', InkWell(onTap: () => _pickDate(delivery: false), child: InputDecorator(decoration: _input(suffixIcon: const Icon(Icons.calendar_today_outlined, size: 15)), child: Text(_dateFormat.format(_date), style: const TextStyle(fontSize: 12))))),
            const SizedBox(height: 10),
            _labeled('Delivery Date', TextFormField(controller: _deliveryDate, readOnly: true, onTap: () => _pickDate(delivery: true), decoration: _input(hint: 'dd/MM/yyyy', suffixIcon: const Icon(Icons.calendar_today_outlined, size: 15)))),
            const SizedBox(height: 10),
            _labeled('Shipment Preference', DropdownButtonFormField<String>(value: _shipmentPreference, isExpanded: true, hint: const Text('Choose the shipment preference or type to add'), items: const ['Road', 'Rail', 'Air', 'Courier'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => _shipmentPreference = v), decoration: _input())),
          ])),
          SizedBox(
            width: wide ? 300 : formWidth,
            child: Column(
              children: [
                if (wide) const SizedBox(height: 174),
                _labeled(
                  'Payment Terms',
                  DropdownButtonFormField<String>(
                    value: _paymentTerms,
                    isExpanded: true,
                    items: const ['Due on Receipt', 'Net 15', 'Net 30', 'Net 45']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) => setState(() => _paymentTerms = v!),
                    decoration: _input(),
                  ),
                ),
              ],
            ),
          ),
        ])),
        Padding(padding: EdgeInsets.only(left: wide ? 142 : 0, top: 10), child: CheckboxListTile(value: _reverseCharge, onChanged: (v) => setState(() => _reverseCharge = v!), dense: true, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, title: const Text('This transaction is applicable for reverse charge', style: TextStyle(fontSize: 11)))),
      ]),
    );
  });

  Widget _itemTable() => LayoutBuilder(builder: (context, constraints) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [const Expanded(child: Text('Item Table', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700))), TextButton.icon(onPressed: () {}, icon: const Icon(Icons.check_circle_outline, size: 15), label: const Text('Bulk Actions', style: TextStyle(fontSize: 11)))]),
    if (constraints.maxWidth < 620)
      ..._items.asMap().entries.map((entry) => _mobileItemCard(entry.key, entry.value))
    else
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: 900, child: Column(children: [
      Container(color: const Color(0xFFF7F8F8), padding: const EdgeInsets.symmetric(vertical: 9), child: const Row(children: [
        SizedBox(width: 310, child: Text('  ITEM DETAILS', style: _tableHeader)), SizedBox(width: 190, child: Text('ACCOUNT', style: _tableHeader)), SizedBox(width: 90, child: Text('QUANTITY', style: _tableHeader)), SizedBox(width: 110, child: Text('RATE', style: _tableHeader)), SizedBox(width: 110, child: Text('TAX', style: _tableHeader)), SizedBox(width: 80, child: Text('AMOUNT', style: _tableHeader)),
      ])),
      ..._items.asMap().entries.map((entry) => _itemRow(entry.key, entry.value)),
    ]))),
    const SizedBox(height: 10),
    Wrap(spacing: 8, children: [
      OutlinedButton.icon(onPressed: () => setState(() => _items.add(_PurchaseItem())), icon: const Icon(Icons.add_circle, size: 15), label: const Text('Add New Row')),
      OutlinedButton.icon(onPressed: () => setState(() => _items.addAll([_PurchaseItem(), _PurchaseItem()])), icon: const Icon(Icons.add_circle, size: 15), label: const Text('Add Items in Bulk')),
    ]),
  ]));

  Widget _mobileItemCard(int index, _PurchaseItem item) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.divider),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Item ${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const Spacer(),
        IconButton(
          tooltip: 'Remove item',
          visualDensity: VisualDensity.compact,
          onPressed: _items.length == 1 ? null : () => setState(() => _items.removeAt(index).dispose()),
          icon: const Icon(Icons.delete_outline, size: 18),
        ),
      ]),
      TextFormField(controller: item.name, decoration: _input(hint: 'Type or click to select an item', prefixIcon: const Icon(Icons.inventory_2_outlined, size: 18))),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(value: item.account, isExpanded: true, hint: const Text('Select an account'), items: const ['Cost of Goods Sold', 'Purchase'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => item.account = v), decoration: _input()),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: TextFormField(controller: item.quantity, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: _input(hint: 'Quantity'))),
        const SizedBox(width: 10),
        Expanded(child: TextFormField(controller: item.rate, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: _input(hint: 'Rate'))),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: DropdownButtonFormField<String>(value: item.tax, isExpanded: true, hint: const Text('Select a Tax'), items: const ['GST 5%', 'GST 12%', 'GST 18%'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => item.tax = v), decoration: _input())),
        const SizedBox(width: 12),
        Text('₹${item.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      ]),
    ]),
  );

  Widget _itemRow(int index, _PurchaseItem item) => Container(
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      SizedBox(width: 310, child: TextFormField(controller: item.name, decoration: _input(hint: 'Type or click to select an item', prefixIcon: const Icon(Icons.inventory_2_outlined, size: 18)))),
      SizedBox(width: 190, child: DropdownButtonFormField<String>(value: item.account, hint: const Text('Select an account'), items: const ['Cost of Goods Sold', 'Purchase'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => item.account = v), decoration: _input())),
      SizedBox(width: 90, child: TextFormField(controller: item.quantity, textAlign: TextAlign.right, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: _input())),
      SizedBox(width: 110, child: TextFormField(controller: item.rate, textAlign: TextAlign.right, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: _input())),
      SizedBox(width: 110, child: DropdownButtonFormField<String>(value: item.tax, hint: const Text('Select a Tax'), items: const ['GST 5%', 'GST 12%', 'GST 18%'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => item.tax = v), decoration: _input())),
      SizedBox(width: 70, child: Text(item.amount.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
      SizedBox(width: 30, child: IconButton(padding: EdgeInsets.zero, onPressed: _items.length == 1 ? null : () => setState(() => _items.removeAt(index).dispose()), icon: const Icon(Icons.close, size: 16))),
    ]),
  );

  Widget _summaryArea() => LayoutBuilder(builder: (context, c) {
    final wide = c.maxWidth > 720;
    final notes = TextFormField(controller: _notes, maxLines: 4, decoration: _input(hint: 'Will be displayed on purchase order'));
    final totals = Container(
      color: const Color(0xFFF7F8F8),
      padding: const EdgeInsets.all(16),
      child: Column(children: [
      _totalLine('Sub Total', _subTotal),
      if (_taxTotal > 0) ...[
        const SizedBox(height: 10),
        _totalLine('Tax', _taxTotal),
      ],
      const SizedBox(height: 10),
      Row(children: [const Expanded(child: Text('Discount', style: TextStyle(fontSize: 12))), SizedBox(width: 105, child: TextField(controller: _discount, textAlign: TextAlign.right, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: _input(suffixText: _discountPercent ? '%' : '₹'))), IconButton(tooltip: _discountPercent ? 'Use amount' : 'Use percentage', onPressed: () => setState(() => _discountPercent = !_discountPercent), icon: const Icon(Icons.swap_horiz, size: 16)), SizedBox(width: 70, child: Text('-${_discountValue.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12)))]),
      Row(children: [Radio<bool>(value: true, groupValue: _tds, onChanged: (v) => setState(() => _tds = v!), visualDensity: VisualDensity.compact), const Text('TDS', style: TextStyle(fontSize: 11)), Radio<bool>(value: false, groupValue: _tds, onChanged: (v) => setState(() => _tds = v!), visualDensity: VisualDensity.compact), const Text('TCS', style: TextStyle(fontSize: 11)), const Spacer(), SizedBox(width: 125, child: DropdownButtonFormField<String>(value: _tax, isExpanded: true, hint: const Text('Select a Tax'), items: const ['1%', '2%', '5%'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => _tax = v), decoration: _input()))]),
      if (_tax != null) ...[
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${_tds ? '-' : '+'}${_adjustmentValue.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ],
      const SizedBox(height: 8),
      Row(children: [const Expanded(child: Text('R/off', style: TextStyle(fontSize: 12))), SizedBox(width: 105, child: TextField(controller: _roundOff, textAlign: TextAlign.right, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: (_) => setState(() {}), decoration: _input())), const SizedBox(width: 40), SizedBox(width: 70, child: Text((double.tryParse(_roundOff.text) ?? 0).toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12)))]),
      const Divider(height: 24),
      _totalLine('Total', _total, strong: true),
    ]));
    if (!wide) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Notes', style: TextStyle(fontSize: 11)), const SizedBox(height: 5), notes, const SizedBox(height: 16), totals]);
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Notes', style: TextStyle(fontSize: 11)), const SizedBox(height: 5), notes])), const SizedBox(width: 24), SizedBox(width: 410, child: totals)]);
  });

  Widget _termsArea() => Container(
    color: const Color(0xFFF7F8F8), padding: const EdgeInsets.all(14),
    child: LayoutBuilder(builder: (context, c) {
      final terms = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Terms & Conditions', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)), const SizedBox(height: 6), TextField(controller: _terms, maxLines: 3, decoration: _input(hint: 'Enter the terms and conditions of your business to be displayed in your transaction'))]);
      final attach = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Attach File(s) to Purchase Order', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 7),
        OutlinedButton.icon(onPressed: _attachments.length >= 10 ? null : _pickAttachments, icon: const Icon(Icons.upload_file, size: 16), label: const Text('Upload File')),
        const Text('You can upload a maximum of 10 files, 10MB each', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        if (_attachments.isNotEmpty) ...[
          const SizedBox(height: 8),
          ..._attachments.asMap().entries.map((entry) => Row(children: [
            const Icon(Icons.insert_drive_file_outlined, size: 15),
            const SizedBox(width: 6),
            Expanded(child: Text(entry.value.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11))),
            IconButton(
              tooltip: 'Remove attachment',
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _attachments.removeAt(entry.key)),
              icon: const Icon(Icons.close, size: 15),
            ),
          ])),
        ],
      ]);
      return c.maxWidth > 700 ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: terms), const SizedBox(width: 24), Expanded(child: attach)]) : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [terms, const SizedBox(height: 16), attach]);
    }),
  );

  Widget _footer() => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 650;
      final draftButton = FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Saving…' : 'Save as Draft'),
      );
      final sendButton = FilledButton(
        onPressed: _saving ? null : _save,
        style: FilledButton.styleFrom(backgroundColor: AppColors.active),
        child: const Text('Save and Send', overflow: TextOverflow.ellipsis),
      );
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            if (compact) Expanded(child: draftButton) else draftButton,
            const SizedBox(width: 8),
            if (compact) Expanded(child: sendButton) else sendButton,
            const SizedBox(width: 8),
            if (compact)
              IconButton(
                tooltip: 'Cancel',
                onPressed: () => context.pop(),
                icon: const Icon(Icons.close),
              )
            else ...[
              OutlinedButton(onPressed: () => context.pop(), child: const Text('Cancel')),
              const Spacer(),
              const Text(
                "PDF Template: 'Standard Template'",
                style: TextStyle(fontSize: 10),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('Change', style: TextStyle(fontSize: 10)),
              ),
            ],
          ],
        ),
      );
    },
  );

  Widget _labeled(String label, Widget field, {bool topAlign = false}) => LayoutBuilder(builder: (context, c) {
    if (c.maxWidth < 560) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: _labelStyle), const SizedBox(height: 5), field]);
    return Row(crossAxisAlignment: topAlign ? CrossAxisAlignment.start : CrossAxisAlignment.center, children: [SizedBox(width: 140, child: Padding(padding: EdgeInsets.only(top: topAlign ? 4 : 0), child: Text(label, style: _labelStyle))), Expanded(child: field)]);
  });

  Widget _totalLine(String label, double value, {bool strong = false}) => Row(children: [Expanded(child: Text(label, style: TextStyle(fontSize: strong ? 14 : 12, fontWeight: strong ? FontWeight.w700 : FontWeight.w600))), Text(value.toStringAsFixed(2), style: TextStyle(fontSize: strong ? 14 : 12, fontWeight: FontWeight.w700))]);
  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Required' : null;
  InputDecoration _input({String? hint, Widget? prefixIcon, Widget? suffixIcon, String? suffixText}) => InputDecoration(hintText: hint, prefixIcon: prefixIcon, suffixIcon: suffixIcon, suffixText: suffixText, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), border: const OutlineInputBorder(borderSide: BorderSide(color: AppColors.divider)), enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppColors.divider)));
}

class _PurchaseItem {
  final name = TextEditingController();
  final quantity = TextEditingController(text: '1.00');
  final rate = TextEditingController(text: '0.00');
  String? account;
  String? tax;
  double get amount => (double.tryParse(quantity.text) ?? 0) * (double.tryParse(rate.text) ?? 0);
  double get taxAmount {
    final match = RegExp(r'([0-9.]+)').firstMatch(tax ?? '');
    final rate = double.tryParse(match?.group(1) ?? '') ?? 0;
    return amount * rate / 100;
  }
  void dispose() { name.dispose(); quantity.dispose(); rate.dispose(); }
}

const _labelStyle = TextStyle(fontSize: 11, color: AppColors.textPrimary);
const _tableHeader = TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600);
