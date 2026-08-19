import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../books/domain/books_repository.dart';
import '../../books/providers/books_providers.dart';
import '../../vendors/domain/vendor.dart';
import '../../vendors/providers/vendor_providers.dart';
import '../domain/purchase_order.dart';
import '../providers/purchase_order_providers.dart';
import 'widgets/send_purchase_order_dialog.dart';

class NewPurchaseOrderPage extends ConsumerStatefulWidget {
  const NewPurchaseOrderPage({super.key, this.existingPo});

  final PurchaseOrder? existingPo;

  @override
  ConsumerState<NewPurchaseOrderPage> createState() => _NewPurchaseOrderPageState();
}

class _NewPurchaseOrderPageState extends ConsumerState<NewPurchaseOrderPage> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _reference = TextEditingController();
  final _deliveryDate = TextEditingController();
  final _discount = TextEditingController(text: '0');
  final _roundOff = TextEditingController(text: '0');
  final _notes = TextEditingController();
  final _terms = TextEditingController();
  final _customDeliveryAddress = TextEditingController();
  final _items = <_PurchaseItemRow>[];
  final _dateFormat = DateFormat('dd/MM/yyyy');

  Vendor? _vendor;
  Customer? _selectedCustomer;
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

  static const List<String> _paymentTermsOptions = [
    'Due on Receipt',
    'Net 7',
    'Net 15',
    'Net 30',
    'Net 45',
    'Net 60',
    'Net 90',
    'Custom',
  ];

  static const List<String> _shipmentOptions = [
    'Standard Delivery',
    'Express Delivery',
    'Vendor Delivery',
    'Self Pickup',
    'Courier',
    'Transport',
    'Other',
  ];

  static const List<String> _accountOptions = [
    'Cost of Goods Sold',
    'Purchase Account',
    'Office Equipment',
    'Computer Equipment',
    'Raw Materials',
    'Inventory Purchase',
    'Office Supplies',
    'Furniture',
  ];

  static const List<String> _gstOptions = [
    'GST 0%',
    'GST 5%',
    'GST 12%',
    'GST 18%',
    'GST 28%',
  ];

  bool get _isEditMode => widget.existingPo != null;
  bool get _isReadOnly => widget.existingPo != null && widget.existingPo!.isReadOnly;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _initFromExistingPo(widget.existingPo!);
    } else {
      _items.add(_PurchaseItemRow());
      _initPoNumber();
      _terms.text =
          '1. Payment will be made according to agreed terms.\n2. Goods must be delivered in good condition.\n3. Invoice must reference PO number.';
    }
  }

  void _initFromExistingPo(PurchaseOrder po) {
    _number.text = po.number;
    _reference.text = po.reference;
    _date = po.date;
    _delivery = po.deliveryDate;
    if (po.deliveryDate != null) {
      _deliveryDate.text = _dateFormat.format(po.deliveryDate!);
    }
    _discount.text = po.discountValue.toString();
    _discountPercent = po.discountType == '%';
    _tds = po.tdsRate > 0 || (po.tcsRate == 0);
    if (po.tdsRate > 0) {
      _tax = '${po.tdsRate.toInt()}%';
    } else if (po.tcsRate > 0) {
      _tax = '${po.tcsRate.toInt()}%';
    }
    _roundOff.text = po.roundOff.toString();
    _notes.text = po.notes;
    _terms.text = po.terms;
    _shipmentPreference = po.shipmentPreference.isNotEmpty ? po.shipmentPreference : null;
    _paymentTerms = po.paymentTerms;
    _reverseCharge = po.reverseCharge;
    _organizationAddress = po.deliveryAddressType == 'Organization';

    if (po.items.isNotEmpty) {
      for (final item in po.items) {
        final row = _PurchaseItemRow();
        row.name.text = item.itemName;
        row.quantity.text = item.quantity.toString();
        row.rate.text = item.rate.toString();
        row.unit = item.unit;
        row.account = item.account;
        row.tax = item.tax;
        _items.add(row);
      }
    } else {
      _items.add(_PurchaseItemRow());
    }
  }

  Future<void> _initPoNumber() async {
    final nextNum = await ref.read(nextPoNumberProvider.future);
    if (mounted && !_isEditMode) {
      setState(() {
        _number.text = nextNum;
      });
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _number,
      _reference,
      _deliveryDate,
      _discount,
      _roundOff,
      _notes,
      _terms,
      _customDeliveryAddress
    ]) {
      controller.dispose();
    }
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  double get _subTotal => _items.fold<double>(0, (sum, item) => sum + item.amount);
  double get _gstTotal => _items.fold<double>(0, (sum, item) => sum + item.taxAmount);

  double get _discountValue {
    final val = double.tryParse(_discount.text) ?? 0;
    return _discountPercent ? (_subTotal * val / 100) : val;
  }

  double get _taxableAmount => (_subTotal - _discountValue).clamp(0, double.infinity);

  double get _tdsTcsRate {
    if (_tax == null) return 0;
    final match = RegExp(r'([0-9.]+)').firstMatch(_tax!);
    return double.tryParse(match?.group(1) ?? '') ?? 0;
  }

  double get _tdsTcsAmount => _taxableAmount * _tdsTcsRate / 100;

  double get _roundOffValue => double.tryParse(_roundOff.text) ?? 0;

  double get _total {
    final base = _taxableAmount + _gstTotal;
    final withTds = _tds ? (base - _tdsTcsAmount) : (base + _tdsTcsAmount);
    return (withTds + _roundOffValue).clamp(0, double.infinity);
  }

  DateTime? get _calculatedDueDate {
    if (_paymentTerms == 'Net 7') return _date.add(const Duration(days: 7));
    if (_paymentTerms == 'Net 15') return _date.add(const Duration(days: 15));
    if (_paymentTerms == 'Net 30') return _date.add(const Duration(days: 30));
    if (_paymentTerms == 'Net 45') return _date.add(const Duration(days: 45));
    if (_paymentTerms == 'Net 60') return _date.add(const Duration(days: 60));
    if (_paymentTerms == 'Net 90') return _date.add(const Duration(days: 90));
    return null;
  }

  Future<void> _pickDate({required bool delivery}) async {
    if (_isReadOnly) return;
    final initial = delivery ? (_delivery ?? _date) : _date;
    final first = delivery ? _date : DateTime(2020);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (delivery) {
        if (picked.isBefore(_date)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Delivery date cannot be before PO date')),
          );
          return;
        }
        _delivery = picked;
        _deliveryDate.text = _dateFormat.format(picked);
      } else {
        _date = picked;
      }
    });
  }

  Future<void> _save(String status) async {
    if (_isReadOnly) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purchase Order is in ${widget.existingPo!.status} status and cannot be edited.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_vendor == null && widget.existingPo?.vendorName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a vendor')),
      );
      return;
    }
    if (_items.isEmpty || _items.any((i) => i.name.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please specify details for all line items')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final draftItems = _items
          .map((i) => PurchaseOrderItemDraft(
                itemId: i.itemId ?? i.selectedBookItem?.id,
                itemName: i.name.text.trim(),
                account: i.account ?? 'Cost of Goods Sold',
                quantity: double.tryParse(i.quantity.text) ?? 1.0,
                unit: i.unit,
                rate: double.tryParse(i.rate.text) ?? 0.0,
                tax: i.tax ?? 'GST 18%',
                taxRate: i.taxRate,
                amount: i.amount,
              ))
          .toList();

      final vendorNameStr = _vendor != null
          ? (_vendor!.companyName.isNotEmpty ? _vendor!.companyName : _vendor!.name)
          : (widget.existingPo?.vendorName ?? '');

      final deliveryAddressStr = _organizationAddress
          ? 'IGreen Technologies\nNo. 25, Industrial Estate\nChennai - 600058, Tamil Nadu, India'
          : (_selectedCustomer != null
              ? '${_selectedCustomer!.name} (${_selectedCustomer!.company})\n${_selectedCustomer!.phone}'
              : _customDeliveryAddress.text.trim());

      final poDraft = PurchaseOrderDraft(
        number: _number.text.trim(),
        vendorId: _vendor?.id ?? widget.existingPo?.vendorId,
        vendorName: vendorNameStr,
        reference: _reference.text.trim(),
        date: _date,
        deliveryDate: _delivery ?? _calculatedDueDate,
        deliveryAddressType: _organizationAddress ? 'Organization' : 'Customer',
        deliveryAddress: deliveryAddressStr,
        customerId: _selectedCustomer?.id ?? widget.existingPo?.customerId,
        customerName: _selectedCustomer?.name ?? widget.existingPo?.customerName ?? '',
        shipmentPreference: _shipmentPreference ?? '',
        paymentTerms: _paymentTerms,
        reverseCharge: _reverseCharge,
        notes: _notes.text.trim(),
        terms: _terms.text.trim(),
        subTotal: _subTotal,
        discountType: _discountPercent ? '%' : '₹',
        discountValue: double.tryParse(_discount.text) ?? 0.0,
        discountAmount: _discountValue,
        taxAmount: _gstTotal,
        tdsRate: _tds ? _tdsTcsRate : 0.0,
        tdsAmount: _tds ? _tdsTcsAmount : 0.0,
        tcsRate: !_tds ? _tdsTcsRate : 0.0,
        tcsAmount: !_tds ? _tdsTcsAmount : 0.0,
        roundOff: _roundOffValue,
        amount: _total,
        status: status,
        attachments: _attachments.map((f) => f.name).toList(),
        items: draftItems,
      );

      if (_isEditMode) {
        await ref.read(purchaseOrderRepositoryProvider).updatePurchaseOrder(widget.existingPo!.id, poDraft);
      } else {
        await ref.read(purchaseOrderRepositoryProvider).addPurchaseOrder(poDraft);
      }

      ref.invalidate(purchaseOrdersProvider);
      ref.invalidate(nextPoNumberProvider);

      if (mounted) {
        if (status == 'SENT') {
          final tempPo = PurchaseOrder(
            id: widget.existingPo?.id ?? DateTime.now().millisecondsSinceEpoch,
            number: poDraft.number,
            vendorId: poDraft.vendorId,
            vendorName: poDraft.vendorName,
            reference: poDraft.reference,
            date: poDraft.date,
            deliveryDate: poDraft.deliveryDate,
            deliveryAddressType: poDraft.deliveryAddressType,
            deliveryAddress: poDraft.deliveryAddress,
            customerId: poDraft.customerId,
            customerName: poDraft.customerName,
            shipmentPreference: poDraft.shipmentPreference,
            paymentTerms: poDraft.paymentTerms,
            reverseCharge: poDraft.reverseCharge,
            notes: poDraft.notes,
            terms: poDraft.terms,
            subTotal: poDraft.subTotal,
            discountType: poDraft.discountType,
            discountValue: poDraft.discountValue,
            discountAmount: poDraft.discountAmount,
            taxAmount: poDraft.taxAmount,
            tdsRate: poDraft.tdsRate,
            tdsAmount: poDraft.tdsAmount,
            tcsRate: poDraft.tcsRate,
            tcsAmount: poDraft.tcsAmount,
            roundOff: poDraft.roundOff,
            amount: poDraft.amount,
            status: 'SENT',
            items: draftItems
                .map((i) => PurchaseOrderItem(
                      itemId: i.itemId,
                      itemName: i.itemName,
                      account: i.account,
                      quantity: i.quantity,
                      unit: i.unit,
                      rate: i.rate,
                      tax: i.tax,
                      taxRate: i.taxRate,
                      amount: i.amount,
                    ))
                .toList(),
          );

          await showDialog(
            context: context,
            builder: (_) => SendPurchaseOrderDialog(order: tempPo, vendor: _vendor),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Purchase Order saved as $status successfully')),
          );
        }
        if (mounted) context.pop();
      }
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

  Future<void> _updateStatus(String newStatus) async {
    if (widget.existingPo == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(purchaseOrderRepositoryProvider).updatePoStatus(widget.existingPo!.id, newStatus);
      ref.invalidate(purchaseOrdersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase Order status updated to $newStatus')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update status: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAttachments() async {
    if (_isReadOnly) return;
    final result = await FilePicker.pickFiles(allowMultiple: true, withData: false);
    if (result == null || !mounted) return;
    final validFiles = result.files
        .where((file) => file.size <= 10 * 1024 * 1024)
        .take(10 - _attachments.length);
    setState(() => _attachments.addAll(validFiles));
  }

  void _openBulkItemSelector(List<BookItem> availableItems) {
    if (_isReadOnly) return;
    final selectedIds = <int>{};
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add Items in Bulk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 480,
              height: 380,
              child: Column(
                children: [
                  const Text(
                    'Select items from inventory master to append to the Purchase Order:',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: availableItems.isEmpty
                        ? const Center(child: Text('No inventory items found'))
                        : ListView.separated(
                            itemCount: availableItems.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (_, index) {
                              final item = availableItems[index];
                              final isChecked = selectedIds.contains(item.id);
                              return CheckboxListTile(
                                value: isChecked,
                                title: Text(item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  'SKU: ${item.sku.isEmpty ? "-" : item.sku}  |  Purchase Rate: ₹${item.costPrice > 0 ? item.costPrice.toStringAsFixed(2) : item.rate.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                                onChanged: (val) {
                                  setDialogState(() {
                                    if (val == true) {
                                      selectedIds.add(item.id);
                                    } else {
                                      selectedIds.remove(item.id);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: selectedIds.isEmpty
                    ? null
                    : () {
                        setState(() {
                          for (final id in selectedIds) {
                            final bItem = availableItems.firstWhere((i) => i.id == id);
                            final row = _PurchaseItemRow();
                            row.selectItem(bItem);
                            _items.add(row);
                          }
                        });
                        Navigator.pop(context);
                      },
                child: Text('Add Selected (${selectedIds.length})'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openCustomerSelector(List<Customer> customers) {
    if (_isReadOnly) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Customer Destination', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 400,
          height: 300,
          child: customers.isEmpty
              ? const Center(child: Text('No customers found'))
              : ListView.builder(
                  itemCount: customers.length,
                  itemBuilder: (_, i) {
                    final c = customers[i];
                    return ListTile(
                      title: Text(c.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(c.company.isNotEmpty ? c.company : c.phone, style: const TextStyle(fontSize: 11)),
                      onTap: () {
                        setState(() {
                          _selectedCustomer = c;
                          _organizationAddress = false;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _openPoNumberSettingsDialog() {
    if (_isReadOnly) return;
    final prefixCtrl = TextEditingController(text: 'PO-');
    final startNumCtrl = TextEditingController(text: '1000');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Purchase Order Numbering Settings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: prefixCtrl,
              decoration: const InputDecoration(labelText: 'PO Prefix', hintText: 'e.g. PO-'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: startNumCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Starting Number', hintText: 'e.g. 1000'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final prefix = prefixCtrl.text.trim();
              final num = int.tryParse(startNumCtrl.text.trim()) ?? 1000;
              setState(() {
                _number.text = '$prefix${num.toString().padLeft(5, '0')}';
              });
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vendorState = ref.watch(activeVendorsProvider);
    final vendors = vendorState.valueOrNull ?? const <Vendor>[];

    final itemState = ref.watch(itemsProvider);
    final inventoryItems = itemState.valueOrNull ?? const <BookItem>[];

    final customerState = ref.watch(customersProvider);
    final customersList = customerState.valueOrNull ?? const <Customer>[];

    if (_vendor == null && widget.existingPo?.vendorId != null && vendors.isNotEmpty) {
      final match = vendors.where((v) => v.id == widget.existingPo!.vendorId).firstOrNull;
      if (match != null) _vendor = match;
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (vendorState.isLoading || itemState.isLoading)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_isReadOnly) _readOnlyBanner(),
                            _detailsSection(vendors, customersList),
                            const SizedBox(height: 24),
                            const Divider(height: 1),
                            const SizedBox(height: 16),
                            _itemTableSection(inventoryItems),
                            const SizedBox(height: 24),
                            _summaryAreaSection(),
                            const SizedBox(height: 24),
                            _termsAndAttachmentsSection(),
                            const SizedBox(height: 24),
                            const Text(
                              'Additional Fields: Customize fields for purchase orders in Settings > Purchases > Purchase Orders.',
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

  Widget _readOnlyBanner() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFFE082)),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, size: 22, color: Color(0xFFF57F17)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'This Purchase Order is in "${widget.existingPo!.status}" status and is LOCKED (View Only). Items, pricing, and accounting totals cannot be modified directly.',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF5D4037)),
              ),
            ),
          ],
        ),
      );



  Widget _detailsSection(List<Vendor> vendors, List<Customer> customersList) =>
      LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 820;
        final formWidth = wide ? (c.maxWidth > 1000 ? 1000.0 : c.maxWidth) : c.maxWidth;

        return SizedBox(
          width: formWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _labeled(
                'Vendor Name*',
                _isReadOnly
                    ? Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.divider),
                          borderRadius: BorderRadius.circular(4),
                          color: const Color(0xFFFAFAFA),
                        ),
                        child: Text(
                          _vendor?.companyName.isNotEmpty == true
                              ? _vendor!.companyName
                              : (widget.existingPo?.vendorName ?? 'Select Vendor'),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      )
                    : DropdownButtonFormField<Vendor>(
                        initialValue: _vendor,
                        isExpanded: true,
                        hint: Text(widget.existingPo?.vendorName.isNotEmpty == true ? widget.existingPo!.vendorName : 'Select a Vendor'),
                        items: vendors
                            .map((v) => DropdownMenuItem(
                                  value: v,
                                  child: Text(
                                    v.companyName.isNotEmpty ? '${v.vendorCode} — ${v.companyName}' : '${v.vendorCode} — ${v.name}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ))
                            .toList(),
                        onChanged: _isReadOnly
                            ? null
                            : (v) {
                                setState(() {
                                  _vendor = v;
                                  if (v != null) {
                                    if (_paymentTermsOptions.contains(v.paymentTerms)) {
                                      _paymentTerms = v.paymentTerms;
                                    }
                                    if (v.tds != null && v.tds!.isNotEmpty) {
                                      _tax = v.tds;
                                    }
                                  }
                                });
                              },
                        validator: (v) => v == null && widget.existingPo?.vendorName == null ? 'Please select a vendor' : null,
                        decoration: _input(prefixIcon: const Icon(Icons.search, size: 18)),
                      ),
              ),
              const SizedBox(height: 18),
              _labeled(
                'Delivery Address*',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        InkWell(
                          onTap: _isReadOnly ? null : () => setState(() => _organizationAddress = true),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                            child: Row(
                              children: [
                                Icon(
                                  _organizationAddress ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                  size: 18,
                                  color: _organizationAddress ? AppColors.active : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                const Text('Organization', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        InkWell(
                          onTap: _isReadOnly ? null : () => setState(() => _organizationAddress = false),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                            child: Row(
                              children: [
                                Icon(
                                  !_organizationAddress ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                  size: 18,
                                  color: !_organizationAddress ? AppColors.active : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                const Text('Customer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      child: Text(
                        _organizationAddress
                            ? 'IGreen Technologies'
                            : (_selectedCustomer != null
                                ? '${_selectedCustomer!.name} (${_selectedCustomer!.company})'
                                : (widget.existingPo?.customerName.isNotEmpty == true ? widget.existingPo!.customerName : 'Customer Delivery Destination')),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      child: Text(
                        _organizationAddress
                            ? 'No. 25, Industrial Estate, Chennai - 600058, Tamil Nadu, India'
                            : (widget.existingPo?.deliveryAddress.isNotEmpty == true
                                ? widget.existingPo!.deliveryAddress
                                : 'Select customer for delivery address.'),
                        style: const TextStyle(fontSize: 11, height: 1.4, color: AppColors.textSecondary),
                      ),
                    ),
                    if (!_isReadOnly) ...[
                      const SizedBox(height: 4),
                      TextButton.icon(
                        onPressed: () {
                          if (!_organizationAddress) {
                            _openCustomerSelector(customersList);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Switch to Customer destination to choose a customer address')),
                            );
                          }
                        },
                        icon: const Icon(Icons.edit_location_alt_outlined, size: 14),
                        label: const Text('Change destination to deliver', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ],
                ),
                topAlign: true,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: formWidth,
                child: Wrap(
                  spacing: 26,
                  runSpacing: 14,
                  children: [
                    SizedBox(
                      width: wide ? 440 : formWidth,
                      child: Column(
                        children: [
                          _labeled(
                            'Purchase Order#*',
                            TextFormField(
                              controller: _number,
                              readOnly: _isReadOnly,
                              validator: _required,
                              decoration: _input(
                                suffixIcon: _isReadOnly
                                    ? null
                                    : IconButton(
                                        icon: const Icon(Icons.settings_outlined, size: 16),
                                        onPressed: _openPoNumberSettingsDialog,
                                        tooltip: 'Numbering Settings',
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _labeled(
                            'Reference#',
                            TextFormField(
                              controller: _reference,
                              readOnly: _isReadOnly,
                              decoration: _input(hint: 'e.g. Quotation QT-2026-145'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _labeled(
                            'Date',
                            InkWell(
                              onTap: _isReadOnly ? null : () => _pickDate(delivery: false),
                              child: InputDecorator(
                                decoration: _input(suffixIcon: const Icon(Icons.calendar_today_outlined, size: 15)),
                                child: Text(_dateFormat.format(_date), style: const TextStyle(fontSize: 12)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _labeled(
                            'Delivery Date',
                            TextFormField(
                              controller: _deliveryDate,
                              readOnly: true,
                              onTap: _isReadOnly ? null : () => _pickDate(delivery: true),
                              decoration: _input(
                                hint: 'dd/MM/yyyy',
                                suffixIcon: const Icon(Icons.calendar_today_outlined, size: 15),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _labeled(
                            'Shipment Preference',
                            DropdownButtonFormField<String>(
                              initialValue: _shipmentPreference,
                              isExpanded: true,
                              hint: const Text('Select Shipment Preference'),
                              items: _shipmentOptions
                                  .map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 12))))
                                  .toList(),
                              onChanged: _isReadOnly ? null : (v) => setState(() => _shipmentPreference = v),
                              decoration: _input(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: wide ? 320 : formWidth,
                      child: Column(
                        children: [
                          if (wide) const SizedBox(height: 180),
                          _labeled(
                            'Payment Terms',
                            DropdownButtonFormField<String>(
                              initialValue: _paymentTerms,
                              isExpanded: true,
                              items: _paymentTermsOptions
                                  .map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 12))))
                                  .toList(),
                              onChanged: _isReadOnly
                                  ? null
                                  : (v) {
                                      setState(() {
                                        _paymentTerms = v!;
                                        final due = _calculatedDueDate;
                                        if (due != null) {
                                          _delivery = due;
                                          _deliveryDate.text = _dateFormat.format(due);
                                        }
                                      });
                                    },
                              decoration: _input(),
                            ),
                          ),
                          if (_calculatedDueDate != null) ...[
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Payment Due Date: ${_dateFormat.format(_calculatedDueDate!)}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: wide ? 142 : 0, top: 12),
                child: CheckboxListTile(
                  value: _reverseCharge,
                  onChanged: _isReadOnly ? null : (v) => setState(() => _reverseCharge = v!),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppColors.active,
                  title: const Text(
                    'This transaction is applicable for reverse charge',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        );
      });

  Widget _itemTableSection(List<BookItem> inventoryItems) => LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Item Table',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (constraints.maxWidth < 650)
              ..._items.asMap().entries.map((entry) => _mobileItemCard(entry.key, entry.value, inventoryItems))
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 940,
                  child: Column(
                    children: [
                      Container(
                        color: const Color(0xFFF7F8F8),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        child: const Row(
                          children: [
                            SizedBox(width: 320, child: Text('ITEM DETAILS', style: _tableHeader)),
                            SizedBox(width: 180, child: Text('ACCOUNT', style: _tableHeader)),
                            SizedBox(width: 90, child: Text('QUANTITY', style: _tableHeader)),
                            SizedBox(width: 110, child: Text('RATE (₹)', style: _tableHeader)),
                            SizedBox(width: 110, child: Text('TAX', style: _tableHeader)),
                            SizedBox(width: 90, child: Text('AMOUNT (₹)', style: _tableHeader, textAlign: TextAlign.right)),
                          ],
                        ),
                      ),
                      ..._items.asMap().entries.map((entry) => _itemRow(entry.key, entry.value, inventoryItems)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            if (!_isReadOnly)
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _items.add(_PurchaseItemRow())),
                    icon: const Icon(Icons.add_circle_outline, size: 16, color: AppColors.active),
                    label: const Text('Add New Row', style: TextStyle(color: AppColors.textPrimary)),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openBulkItemSelector(inventoryItems),
                    icon: const Icon(Icons.playlist_add, size: 16, color: AppColors.active),
                    label: const Text('Add Items in Bulk', style: TextStyle(color: AppColors.textPrimary)),
                  ),
                ],
              ),
          ],
        ),
      );

  Widget _itemRow(int index, _PurchaseItemRow item, List<BookItem> inventoryItems) => Container(
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            SizedBox(
              width: 320,
              child: _isReadOnly
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Text(item.name.text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    )
                  : Autocomplete<BookItem>(
                      initialValue: TextEditingValue(text: item.name.text),
                      displayStringForOption: (option) => option.name,
                      optionsBuilder: (textValue) {
                        if (textValue.text.isEmpty) return inventoryItems;
                        return inventoryItems.where((i) => i.name.toLowerCase().contains(textValue.text.toLowerCase()));
                      },
                      onSelected: (bItem) {
                        setState(() {
                          item.selectItem(bItem);
                        });
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          onChanged: (val) {
                            item.name.text = val;
                          },
                          decoration: _input(
                            hint: 'Select or enter item',
                            prefixIcon: const Icon(Icons.inventory_2_outlined, size: 16),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 172,
              child: DropdownButtonFormField<String>(
                initialValue: item.account,
                isExpanded: true,
                hint: const Text('Account', style: TextStyle(fontSize: 11)),
                items: _accountOptions
                    .map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: _isReadOnly ? null : (v) => setState(() => item.account = v),
                decoration: _input(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 84,
              child: TextFormField(
                controller: item.quantity,
                readOnly: _isReadOnly,
                textAlign: TextAlign.right,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: _input(suffixText: item.unit),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 104,
              child: TextFormField(
                controller: item.rate,
                readOnly: _isReadOnly,
                textAlign: TextAlign.right,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: _input(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 104,
              child: DropdownButtonFormField<String>(
                initialValue: item.tax,
                isExpanded: true,
                hint: const Text('Tax', style: TextStyle(fontSize: 11)),
                items: _gstOptions
                    .map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 11))))
                    .toList(),
                onChanged: _isReadOnly ? null : (v) => setState(() => item.tax = v),
                decoration: _input(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: Text(
                item.amount.toStringAsFixed(2),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            if (!_isReadOnly)
              SizedBox(
                width: 30,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: _items.length == 1 ? null : () => setState(() => _items.removeAt(index).dispose()),
                  icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                  tooltip: 'Remove Row',
                ),
              ),
          ],
        ),
      );

  Widget _mobileItemCard(int index, _PurchaseItemRow item, List<BookItem> inventoryItems) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Item ${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (!_isReadOnly)
                  IconButton(
                    tooltip: 'Remove Item',
                    visualDensity: VisualDensity.compact,
                    onPressed: _items.length == 1 ? null : () => setState(() => _items.removeAt(index).dispose()),
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                  ),
              ],
            ),
            _isReadOnly
                ? Text(item.name.text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))
                : Autocomplete<BookItem>(
                    initialValue: TextEditingValue(text: item.name.text),
                    displayStringForOption: (option) => option.name,
                    optionsBuilder: (textValue) {
                      if (textValue.text.isEmpty) return inventoryItems;
                      return inventoryItems.where((i) => i.name.toLowerCase().contains(textValue.text.toLowerCase()));
                    },
                    onSelected: (bItem) {
                      setState(() => item.selectItem(bItem));
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: (val) => item.name.text = val,
                        decoration: _input(hint: 'Search item master', prefixIcon: const Icon(Icons.inventory_2_outlined, size: 18)),
                      );
                    },
                  ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: item.account,
              isExpanded: true,
              hint: const Text('Select Account'),
              items: _accountOptions.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: _isReadOnly ? null : (v) => setState(() => item.account = v),
              decoration: _input(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: item.quantity,
                    readOnly: _isReadOnly,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: _input(hint: 'Quantity', suffixText: item.unit),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: item.rate,
                    readOnly: _isReadOnly,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: _input(hint: 'Rate (₹)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: item.tax,
                    isExpanded: true,
                    hint: const Text('Tax Rate'),
                    items: _gstOptions.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: _isReadOnly ? null : (v) => setState(() => item.tax = v),
                    decoration: _input(),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Amount', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    Text('₹${item.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ],
        ),
      );

  Widget _summaryAreaSection() => LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth > 720;
        final notesWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notes (Displayed on Purchase Order)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _notes,
              readOnly: _isReadOnly,
              maxLines: 4,
              decoration: _input(hint: 'Enter notes or instructions for the vendor...'),
            ),
          ],
        );

        final totalsWidget = Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8F8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _totalLine('Sub Total', _subTotal),
              if (_gstTotal > 0) ...[
                const SizedBox(height: 8),
                _totalLine('GST Tax Amount', _gstTotal),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(child: Text('Discount', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                  SizedBox(
                    width: 95,
                    child: TextField(
                      controller: _discount,
                      readOnly: _isReadOnly,
                      textAlign: TextAlign.right,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: _input(suffixText: _discountPercent ? '%' : '₹'),
                    ),
                  ),
                  if (!_isReadOnly)
                    IconButton(
                      tooltip: _discountPercent ? 'Switch to Amount (₹)' : 'Switch to Percentage (%)',
                      onPressed: () => setState(() => _discountPercent = !_discountPercent),
                      icon: const Icon(Icons.swap_horiz, size: 18, color: AppColors.active),
                    ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      '-₹${_discountValue.toStringAsFixed(2)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  InkWell(
                    onTap: _isReadOnly ? null : () => setState(() => _tds = true),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Row(
                        children: [
                          Icon(
                            _tds ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            size: 18,
                            color: _tds ? AppColors.active : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          const Text('TDS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: _isReadOnly ? null : () => setState(() => _tds = false),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Row(
                        children: [
                          Icon(
                            !_tds ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            size: 18,
                            color: !_tds ? AppColors.active : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          const Text('TCS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 120,
                    child: DropdownButtonFormField<String>(
                      initialValue: _tax,
                      isExpanded: true,
                      hint: const Text('Select Tax', style: TextStyle(fontSize: 11)),
                      items: const ['1%', '2%', '5%', '10%']
                          .map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 11))))
                          .toList(),
                      onChanged: _isReadOnly ? null : (v) => setState(() => _tax = v),
                      decoration: _input(),
                    ),
                  ),
                ],
              ),
              if (_tax != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${_tds ? '-' : '+'}₹${_tdsTcsAmount.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _tds ? Colors.redAccent : Colors.green),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(child: Text('Round Off', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                  SizedBox(
                    width: 95,
                    child: TextField(
                      controller: _roundOff,
                      readOnly: _isReadOnly,
                      textAlign: TextAlign.right,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      onChanged: (_) => setState(() {}),
                      decoration: _input(),
                    ),
                  ),
                  const SizedBox(width: 44),
                  SizedBox(
                    width: 80,
                    child: Text(
                      '₹${_roundOffValue.toStringAsFixed(2)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _totalLine('Final Total', _total, strong: true),
            ],
          ),
        );

        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [notesWidget, const SizedBox(height: 18), totalsWidget],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: notesWidget),
            const SizedBox(width: 24),
            SizedBox(width: 420, child: totalsWidget),
          ],
        );
      });

  Widget _termsAndAttachmentsSection() => Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8F8),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
        ),
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(builder: (context, c) {
          final termsWidget = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Terms & Conditions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _terms,
                readOnly: _isReadOnly,
                maxLines: 4,
                decoration: _input(hint: 'Enter business terms and conditions...'),
              ),
            ],
          );

          final attachWidget = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Attach File(s) to Purchase Order', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (!_isReadOnly)
                OutlinedButton.icon(
                  onPressed: _attachments.length >= 10 ? null : _pickAttachments,
                  icon: const Icon(Icons.upload_file, size: 16, color: AppColors.active),
                  label: const Text('Upload File', style: TextStyle(color: AppColors.textPrimary)),
                ),
              const SizedBox(height: 4),
              const Text('Maximum 10 files, 10MB each', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              if (_attachments.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._attachments.asMap().entries.map((entry) => Row(
                      children: [
                        const Icon(Icons.insert_drive_file_outlined, size: 15, color: AppColors.active),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            entry.value.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        if (!_isReadOnly)
                          IconButton(
                            tooltip: 'Remove Attachment',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(() => _attachments.removeAt(entry.key)),
                            icon: const Icon(Icons.close, size: 15, color: Colors.redAccent),
                          ),
                      ],
                    )),
              ],
            ],
          );

          return c.maxWidth > 700
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: termsWidget),
                    const SizedBox(width: 24),
                    Expanded(child: attachWidget),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [termsWidget, const SizedBox(height: 18), attachWidget],
                );
        }),
      );

  Widget _footer() => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 650;

          if (_isReadOnly) {
            final poStatus = widget.existingPo?.status.toUpperCase() ?? '';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Back'),
                  ),
                  const SizedBox(width: 12),
                  if (poStatus == 'SENT') ...[
                    FilledButton.icon(
                      onPressed: _saving ? null : () => _updateStatus('ACCEPTED'),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.active),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Mark as Accepted'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _saving ? null : () => _updateStatus('CANCELLED'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                      child: const Text('Cancel PO'),
                    ),
                  ] else if (poStatus == 'ACCEPTED') ...[
                    FilledButton.icon(
                      onPressed: _saving ? null : () => _updateStatus('RECEIVED'),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.active),
                      icon: const Icon(Icons.inventory, size: 16),
                      label: const Text('Mark as Received'),
                    ),
                  ] else if (poStatus == 'RECEIVED') ...[
                    FilledButton.icon(
                      onPressed: _saving ? null : () => _updateStatus('BILLED'),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.active),
                      icon: const Icon(Icons.receipt_long, size: 16),
                      label: const Text('Create Bill'),
                    ),
                  ],
                  const Spacer(),
                  const Text(
                    "PDF Template: 'Standard ERP Template'",
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          final closeIconBtn = IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.close, color: AppColors.textPrimary, size: 22),
            tooltip: 'Cancel & Close',
          );

          final draftBtn = OutlinedButton.icon(
            onPressed: _saving ? null : () => _save('DRAFT'),
            icon: const Icon(Icons.drafts_outlined, size: 16),
            label: Text(_saving ? 'Saving…' : (_isEditMode ? 'Update Draft' : 'Save as Draft')),
          );

          final sendBtn = FilledButton.icon(
            onPressed: _saving ? null : () => _save('SENT'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.active),
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Save and Send'),
          );

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                closeIconBtn,
                const SizedBox(width: 6),
                if (compact) ...[
                  Expanded(child: draftBtn),
                  const SizedBox(width: 8),
                  Expanded(child: sendBtn),
                ] else ...[
                  draftBtn,
                  const SizedBox(width: 12),
                  sendBtn,
                  const Spacer(),
                  const Text(
                    "PDF Template: 'Standard ERP Template'",
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          );
        },
      );

  Widget _labeled(String label, Widget field, {bool topAlign = false}) => LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: _labelStyle),
              const SizedBox(height: 5),
              field,
            ],
          );
        }
        return Row(
          crossAxisAlignment: topAlign ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 140,
              child: Padding(
                padding: EdgeInsets.only(top: topAlign ? 6 : 0),
                child: Text(label, style: _labelStyle),
              ),
            ),
            Expanded(child: field),
          ],
        );
      });

  Widget _totalLine(String label, double value, {bool strong = false}) => Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: strong ? 14 : 12,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            '₹${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: strong ? 15 : 12,
              fontWeight: FontWeight.w700,
              color: strong ? AppColors.active : AppColors.textPrimary,
            ),
          ),
        ],
      );

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Required' : null;

  InputDecoration _input({String? hint, Widget? prefixIcon, Widget? suffixIcon, String? suffixText}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        suffixText: suffixText,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: const OutlineInputBorder(borderSide: BorderSide(color: AppColors.divider)),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppColors.divider)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppColors.active, width: 1.5)),
      );
}

class _PurchaseItemRow {
  final name = TextEditingController();
  final quantity = TextEditingController(text: '1.00');
  final rate = TextEditingController(text: '0.00');
  int? itemId;
  String? account = 'Cost of Goods Sold';
  String? tax = 'GST 18%';
  String unit = 'pcs';
  BookItem? selectedBookItem;

  double get amount => (double.tryParse(quantity.text) ?? 0) * (double.tryParse(rate.text) ?? 0);

  double get taxRate {
    final match = RegExp(r'([0-9.]+)').firstMatch(tax ?? '');
    return double.tryParse(match?.group(1) ?? '') ?? 0;
  }

  double get taxAmount => amount * taxRate / 100;

  void selectItem(BookItem bItem) {
    selectedBookItem = bItem;
    itemId = bItem.id;
    name.text = bItem.name;
    unit = bItem.unit.isEmpty ? 'pcs' : bItem.unit;
    rate.text = bItem.costPrice > 0 ? bItem.costPrice.toStringAsFixed(2) : bItem.rate.toStringAsFixed(2);
    if (bItem.cogsAccount.isNotEmpty) {
      account = bItem.cogsAccount;
    }
    if (bItem.taxRate > 0) {
      tax = 'GST ${bItem.taxRate.toInt()}%';
    }
  }

  void dispose() {
    name.dispose();
    quantity.dispose();
    rate.dispose();
  }
}

const _labelStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
const _tableHeader = TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w700);
